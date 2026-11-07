import Combine
import Foundation
import MusicKit

/// Lecture des titres du catalogue Apple Music avec MusicKit (`ApplicationMusicPlayer`).
/// Nécessite un abonnement Apple Music actif : sans lui, rien n'est lu et l'app l'indique clairement.
/// Le lecteur local (`PlayerService`) reste indépendant : un seul des deux joue à la fois.
@MainActor
final class AppleMusicPlayer: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var isPlaying = false
    @Published private(set) var title = ""
    @Published private(set) var artist = ""
    @Published private(set) var album = ""
    @Published private(set) var artwork: Artwork?
    @Published private(set) var isShuffled = false
    @Published private(set) var repeatMode: MusicPlayer.RepeatMode = MusicPlayer.RepeatMode.none
    @Published var errorMessage: String?
    @Published var subscriptionRequired = false

    let clock = PlaybackClock()

    /// Appelé juste avant de lancer la lecture Apple Music (pour mettre le lecteur local en retrait).
    var onWillPlay: (() -> Void)?

    private let service: AppleMusicService
    private let player = ApplicationMusicPlayer.shared
    private var cancellables = Set<AnyCancellable>()
    private var ticker: Timer?
    private var playTask: Task<Void, Never>?
    private var currentEntryID: String?

    init(service: AppleMusicService) {
        self.service = service

        // `objectWillChange` est émis avant le changement : on relit l'état juste après.
        player.state.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            }
            .store(in: &cancellables)
        player.queue.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            }
            .store(in: &cancellables)

        ticker = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    // MARK: - Lecture

    /// Lance une liste de titres du catalogue. `shuffled` = nil conserve le réglage actuel.
    func play(_ songs: [Song], startingAt start: Song? = nil, shuffled: Bool? = nil) {
        guard !songs.isEmpty else { return }
        playTask?.cancel()
        playTask = Task { [weak self] in
            await self?.startPlayback(songs, start: start, shuffled: shuffled)
        }
    }

    private func startPlayback(_ songs: [Song], start: Song?, shuffled: Bool?) async {
        guard await service.ensureCanPlay() else {
            subscriptionRequired = true
            return
        }
        guard !Task.isCancelled else { return }

        onWillPlay?()
        do {
            player.queue = ApplicationMusicPlayer.Queue(for: songs, startingAt: start)
            if let shuffled {
                player.state.shuffleMode = shuffled ? .songs : .off
            }
            try await player.play()
            isActive = true
            currentEntryID = nil
            refresh()
        } catch {
            if error is CancellationError { return }
            errorMessage = AppleMusicError.message(for: error)
        }
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    func pause() {
        player.pause()
        refresh()
    }

    func resume() {
        guard isActive else { return }
        onWillPlay?()
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.player.play()
                self.refresh()
            } catch {
                self.errorMessage = AppleMusicError.message(for: error)
            }
        }
    }

    func next() {
        guard isActive else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.player.skipToNextEntry()
            } catch {
                self.errorMessage = AppleMusicError.message(for: error)
            }
        }
    }

    func previous() {
        guard isActive else { return }
        if clock.currentTime > 3 {
            seek(to: 0)
            return
        }
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.player.skipToPreviousEntry()
            } catch {
                self.errorMessage = AppleMusicError.message(for: error)
            }
        }
    }

    func seek(to seconds: Double) {
        guard isActive else { return }
        let upper = clock.duration > 0 ? clock.duration : seconds
        let target = max(0, min(seconds, upper))
        clock.currentTime = target
        player.playbackTime = target
    }

    func skip(by seconds: Double) {
        seek(to: clock.currentTime + seconds)
    }

    // MARK: - Aléatoire / répétition

    func toggleShuffle() {
        player.state.shuffleMode = isShuffled ? .off : .songs
        refresh()
    }

    func cycleRepeat() {
        switch repeatMode {
        case .none:
            player.state.repeatMode = .all
        case .all:
            player.state.repeatMode = .one
        default:
            player.state.repeatMode = MusicPlayer.RepeatMode.none
        }
        refresh()
    }

    // MARK: - Cohabitation avec le lecteur local

    /// Le lecteur local démarre : on arrête Apple Music (le lecteur local garde sa file).
    func yieldToLocal() {
        guard isActive else { return }
        playTask?.cancel()
        player.stop()
        isActive = false
        isPlaying = false
        currentEntryID = nil
        clock.currentTime = 0
        clock.duration = 0
    }

    // MARK: - Synchronisation avec MusicKit

    private func tick() {
        guard isActive else { return }
        refresh()
        let time = player.playbackTime
        if time.isFinite, time >= 0, abs(clock.currentTime - time) > 0.05 {
            clock.currentTime = time
        }
    }

    /// Relit l'état du lecteur MusicKit ; ne publie que ce qui a changé pour éviter des redessins inutiles.
    private func refresh() {
        guard isActive else { return }

        let playing = player.state.playbackStatus == .playing
        if isPlaying != playing { isPlaying = playing }

        let shuffled = player.state.shuffleMode == .songs
        if isShuffled != shuffled { isShuffled = shuffled }

        let mode = player.state.repeatMode ?? MusicPlayer.RepeatMode.none
        if repeatMode != mode { repeatMode = mode }

        guard let entry = player.queue.currentEntry, entry.id != currentEntryID else { return }
        currentEntryID = entry.id
        title = entry.title
        artist = entry.subtitle ?? ""
        album = ""
        artwork = entry.artwork
        var duration = 0.0
        if let item = entry.item, case .song(let song) = item {
            artist = song.artistName
            album = song.albumTitle ?? ""
            duration = song.duration ?? 0
        }
        clock.duration = duration
        clock.currentTime = 0
    }
}
