import AVFoundation
import MediaPlayer
import SwiftUI

/// Temps de lecture, publié à part pour que seuls les curseurs/horloges se redessinent.
@MainActor
final class PlaybackClock: ObservableObject {
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
}

/// Crée la pochette de l'écran verrouillé hors du contexte MainActor
/// (le système appelle ce bloc depuis une autre file).
enum NowPlayingArtwork {
    static func make(from image: UIImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }
}

/// Lecteur audio : AVPlayer + file d'attente + écran verrouillé / Centre de contrôle
/// + lecture en arrière-plan + interruptions et écouteurs.
@MainActor
final class PlayerService: ObservableObject {
    @Published private(set) var queue = PlayQueue()
    @Published private(set) var isPlaying = false
    @Published var repeatMode: RepeatMode = .off
    @Published var errorMessage: String?

    let clock = PlaybackClock()

    /// Appelé quand la lecture locale démarre (permet d'arrêter Apple Music : un seul lecteur à la fois).
    var onWillStartPlayback: (() -> Void)?

    private let library: LibraryStore
    private let player = AVPlayer()
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var statusObservation: NSKeyValueObservation?
    private var rateObservation: NSKeyValueObservation?
    private var notificationTokens: [NSObjectProtocol] = []

    /// Ce que l'utilisateur veut : sert à reprendre après une interruption.
    private var intendedPlaying = false
    private var isSeeking = false
    private var consecutiveFailures = 0

    var currentTrack: Track? { queue.current?.track }
    var isShuffled: Bool { queue.isShuffled }
    var upcoming: [QueueItem] { queue.upcoming }
    var canGoNext: Bool { queue.hasNext || repeatMode == .all }

    init(library: LibraryStore) {
        self.library = library
        configureAudioSession()
        observeSystemEvents()
        observePlayer()
        configureRemoteCommands()
    }

    // MARK: - Lecture

    func play(_ track: Track, in context: [Track]) {
        let list = context.contains(where: { $0.id == track.id }) ? context : [track]
        let start = list.firstIndex(where: { $0.id == track.id }) ?? 0
        queue.set(tracks: list, startAt: start, shuffled: queue.isShuffled)
        loadCurrent(autoplay: true)
    }

    func playAll(_ tracks: [Track], shuffled: Bool) {
        guard !tracks.isEmpty else { return }
        queue.set(tracks: tracks, startAt: shuffled ? nil : 0, shuffled: shuffled)
        loadCurrent(autoplay: true)
    }

    func togglePlayPause() {
        if isPlaying { pause() } else { resume() }
    }

    func resume() {
        guard queue.current != nil else { return }
        if player.currentItem == nil {
            loadCurrent(autoplay: true)
            return
        }
        willStartPlayback()
        activateSession()
        intendedPlaying = true
        player.play()
        isPlaying = true
        updateNowPlaying()
    }

    func pause() {
        intendedPlaying = false
        player.pause()
        isPlaying = false
        updateNowPlaying()
    }

    func next() {
        guard queue.current != nil else { return }
        if queue.advance(wrap: repeatMode == .all) {
            loadCurrent(autoplay: true)
        }
    }

    func previous() {
        guard queue.current != nil else { return }
        if clock.currentTime > 3 {
            seek(to: 0)
            return
        }
        if queue.goBack(wrap: repeatMode == .all) {
            loadCurrent(autoplay: true)
        } else {
            seek(to: 0)
        }
    }

    func seek(to seconds: Double) {
        let upper = clock.duration > 0 ? clock.duration : seconds
        let target = max(0, min(seconds, upper))
        clock.currentTime = target
        isSeeking = true
        let time = CMTime(seconds: target, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor in
                self?.isSeeking = false
                self?.updateNowPlaying()
            }
        }
    }

    func skip(by seconds: Double) {
        seek(to: clock.currentTime + seconds)
    }

    // MARK: - Mode aléatoire / répétition

    func toggleShuffle() {
        queue.toggleShuffle()
        objectWillChange.send()
    }

    func cycleRepeat() {
        repeatMode = repeatMode.next
    }

    // MARK: - File d'attente

    func playNext(_ track: Track) {
        let wasEmpty = queue.current == nil
        queue.playNext(track)
        if wasEmpty { loadCurrent(autoplay: true) }
    }

    func addToQueue(_ track: Track) {
        let wasEmpty = queue.current == nil
        queue.append(track)
        if wasEmpty { loadCurrent(autoplay: true) }
    }

    func removeFromQueue(id: UUID) {
        queue.remove(id: id)
    }

    func moveUpcoming(from source: IndexSet, to destination: Int) {
        queue.moveUpcoming(from: source, to: destination)
    }

    func clearUpcoming() {
        queue.clearUpcoming()
    }

    func jump(to item: QueueItem) {
        if queue.jump(to: item.id) {
            loadCurrent(autoplay: true)
        }
    }

    /// Appelé quand des musiques sont supprimées de la bibliothèque.
    func removeTracks(_ ids: Set<UUID>) {
        guard queue.items.contains(where: { ids.contains($0.track.id) }) else { return }
        let wasPlaying = intendedPlaying
        let removedCurrent = queue.removeTracks(ids)
        if queue.items.isEmpty {
            stop()
        } else if removedCurrent {
            loadCurrent(autoplay: wasPlaying)
        }
    }

    func stop() {
        player.pause()
        teardownItemObservers()
        player.replaceCurrentItem(with: nil)
        queue.clear()
        intendedPlaying = false
        isPlaying = false
        clock.currentTime = 0
        clock.duration = 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - Cohabitation avec Apple Music (MusicKit)

    private func willStartPlayback() {
        setRemoteCommandsEnabled(true)
        onWillStartPlayback?()
    }

    /// Apple Music (MusicKit) prend la main : on met la lecture locale en pause, sans toucher à sa file,
    /// et on libère l'écran verrouillé et les commandes à distance pour MusicKit.
    func yieldToExternalPlayer() {
        intendedPlaying = false
        player.pause()
        isPlaying = false
        setRemoteCommandsEnabled(false)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private func setRemoteCommandsEnabled(_ enabled: Bool) {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.isEnabled = enabled
        center.pauseCommand.isEnabled = enabled
        center.togglePlayPauseCommand.isEnabled = enabled
        center.nextTrackCommand.isEnabled = enabled
        center.previousTrackCommand.isEnabled = enabled
        center.changePlaybackPositionCommand.isEnabled = enabled
    }

    // MARK: - Chargement d'une musique

    private func loadCurrent(autoplay: Bool) {
        guard let track = queue.current?.track else { return }

        guard FileManager.default.fileExists(atPath: track.fileURL.path) else {
            handleUnplayable(track, reason: "fichier introuvable", autoplay: autoplay)
            return
        }

        teardownItemObservers()
        let item = AVPlayerItem(url: track.fileURL)

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.trackDidFinish() }
        }
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] observed, _ in
            let status = observed.status
            Task { @MainActor in self?.itemStatusChanged(status, track: track) }
        }

        isSeeking = false
        clock.currentTime = 0
        clock.duration = track.duration
        player.replaceCurrentItem(with: item)

        if autoplay {
            willStartPlayback()
            activateSession()
            intendedPlaying = true
            player.play()
            isPlaying = true
            library.recordPlay(track.id)
        } else {
            player.pause()
            isPlaying = false
        }
        updateNowPlaying()
    }

    private func itemStatusChanged(_ status: AVPlayerItem.Status, track: Track) {
        guard track.id == currentTrack?.id else { return }
        switch status {
        case .readyToPlay:
            consecutiveFailures = 0
            if let seconds = player.currentItem?.duration.seconds, seconds.isFinite, seconds > 0 {
                clock.duration = seconds
                updateNowPlaying()
            }
        case .failed:
            handleUnplayable(track, reason: "lecture impossible", autoplay: intendedPlaying)
        default:
            break
        }
    }

    private func handleUnplayable(_ track: Track, reason: String, autoplay: Bool) {
        consecutiveFailures += 1
        if errorMessage == nil {
            errorMessage = "« \(track.title) » : \(reason)."
        }
        let canContinue = consecutiveFailures <= queue.items.count
        if canContinue, queue.advance(wrap: repeatMode == .all) {
            loadCurrent(autoplay: autoplay)
        } else {
            consecutiveFailures = 0
            pause()
        }
    }

    private func trackDidFinish() {
        if repeatMode == .one {
            seek(to: 0)
            player.play()
            isPlaying = true
            if let track = currentTrack { library.recordPlay(track.id) }
            updateNowPlaying()
            return
        }
        if queue.advance(wrap: repeatMode == .all) {
            loadCurrent(autoplay: true)
        } else {
            // Fin de la file : on revient au début de la dernière musique, en pause.
            player.pause()
            intendedPlaying = false
            isPlaying = false
            seek(to: 0)
        }
    }

    private func teardownItemObservers() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
        statusObservation?.invalidate()
        statusObservation = nil
    }

    // MARK: - Observation du lecteur

    private func observePlayer() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            MainActor.assumeIsolated { self?.handleTick(time) }
        }
        rateObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] observed, _ in
            let status = observed.timeControlStatus
            Task { @MainActor in
                guard let self else { return }
                let playing = status != .paused
                if self.isPlaying != playing {
                    self.isPlaying = playing
                    self.updateNowPlaying()
                }
            }
        }
    }

    private func handleTick(_ time: CMTime) {
        guard !isSeeking else { return }
        let seconds = time.seconds
        if seconds.isFinite, seconds >= 0 {
            clock.currentTime = seconds
        }
    }

    // MARK: - Session audio, interruptions, écouteurs

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default)
        } catch {
            NSLog("Freetify : configuration AVAudioSession impossible : %@", error.localizedDescription)
        }
    }

    private func activateSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            NSLog("Freetify : activation AVAudioSession impossible : %@", error.localizedDescription)
        }
    }

    private func observeSystemEvents() {
        let center = NotificationCenter.default

        let interruption = center.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] note in
            let type = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt)
                .flatMap(AVAudioSession.InterruptionType.init(rawValue:))
            let options = (note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt) ?? 0
            MainActor.assumeIsolated { self?.handleInterruption(type: type, options: options) }
        }

        let route = center.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main
        ) { [weak self] note in
            let reason = (note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt)
                .flatMap(AVAudioSession.RouteChangeReason.init(rawValue:))
            MainActor.assumeIsolated { self?.handleRouteChange(reason: reason) }
        }

        notificationTokens = [interruption, route]
    }

    private func handleInterruption(type: AVAudioSession.InterruptionType?, options: UInt) {
        switch type {
        case .began:
            // Le système met la lecture en pause ; `intendedPlaying` est conservé pour la reprise.
            isPlaying = false
            updateNowPlaying()
        case .ended:
            let shouldResume = AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume)
            if shouldResume, intendedPlaying {
                activateSession()
                player.play()
                isPlaying = true
                updateNowPlaying()
            }
        default:
            break
        }
    }

    private func handleRouteChange(reason: AVAudioSession.RouteChangeReason?) {
        // Écouteurs débranchés / Bluetooth déconnecté : on met en pause.
        if reason == .oldDeviceUnavailable, isPlaying {
            pause()
        }
    }

    // MARK: - Écran verrouillé / Centre de contrôle

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.resume() }
            return .success
        }
        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayPause() }
            return .success
        }
        center.nextTrackCommand.isEnabled = true
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.next() }
            return .success
        }
        center.previousTrackCommand.isEnabled = true
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.previous() }
            return .success
        }
        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let position = event.positionTime
            Task { @MainActor in self?.seek(to: position) }
            return .success
        }
        // Les boutons « 15 s » remplaceraient précédent/suivant sur l'écran verrouillé.
        center.skipForwardCommand.isEnabled = false
        center.skipBackwardCommand.isEnabled = false
    }

    private func updateNowPlaying() {
        let infoCenter = MPNowPlayingInfoCenter.default()
        guard let track = currentTrack else {
            infoCenter.nowPlayingInfo = nil
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyAlbumTitle: track.album,
            MPMediaItemPropertyPlaybackDuration: clock.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: clock.currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue
        ]
        if let image = ArtworkStore.shared.imageSync(for: track.artworkKey) {
            info[MPMediaItemPropertyArtwork] = NowPlayingArtwork.make(from: image)
        }
        infoCenter.nowPlayingInfo = info
        infoCenter.playbackState = isPlaying ? .playing : .paused
    }
}
