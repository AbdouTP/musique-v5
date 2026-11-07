import AVFoundation
import MediaPlayer
import UIKit

struct AppleMusicPlaylist: Identifiable, Hashable {
    let id: UInt64
    let name: String
    let totalCount: Int
    /// Morceaux réellement copiables (présents sur l'iPhone, sans protection).
    let importableCount: Int
}

struct AppleMusicReport: Identifiable {
    let id = UUID()
    let playlistName: String
    var copied = 0
    var alreadyInLibrary = 0
    var skipped: [String] = []
}

enum AppleMusicError: LocalizedError {
    case exportUnavailable
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .exportUnavailable: return "Export audio indisponible pour ce morceau."
        case .exportFailed: return "L'export du morceau a échoué."
        }
    }
}

/// Copie un morceau non protégé de la médiathèque iOS vers un fichier de l'app (M4A).
enum AppleMusicExport {
    static func exportM4A(from source: URL, to destination: URL) async throws {
        let asset = AVURLAsset(url: source)
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw AppleMusicError.exportUnavailable
        }
        session.outputURL = destination
        session.outputFileType = .m4a
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            session.exportAsynchronously { continuation.resume() }
        }
        guard session.status == .completed else {
            try? FileManager.default.removeItem(at: destination)
            throw session.error ?? AppleMusicError.exportFailed
        }
    }
}

/// Recrée des playlists Apple Music dans Freetify Musique.
///
/// Limite imposée par Apple : les morceaux en streaming ou protégés (DRM) n'ont pas de fichier
/// accessible et ne peuvent pas être copiés. Ils sont repris dans la playlist uniquement si
/// le même titre existe déjà dans la bibliothèque Freetify.
@MainActor
final class AppleMusicImporter: ObservableObject {
    enum Access { case unknown, denied, authorized }

    @Published private(set) var access: Access = .unknown
    @Published private(set) var playlists: [AppleMusicPlaylist] = []
    @Published private(set) var isWorking = false
    @Published private(set) var progressText = ""
    @Published private(set) var reports: [AppleMusicReport] = []

    private let library: LibraryStore

    init(library: LibraryStore) {
        self.library = library
    }

    // MARK: - Autorisation

    func refreshAccess() {
        switch MPMediaLibrary.authorizationStatus() {
        case .authorized:
            access = .authorized
            loadPlaylists()
        case .notDetermined:
            access = .unknown
        default:
            access = .denied
        }
    }

    func requestAccess() async {
        let status = await withCheckedContinuation { (continuation: CheckedContinuation<MPMediaLibraryAuthorizationStatus, Never>) in
            MPMediaLibrary.requestAuthorization { continuation.resume(returning: $0) }
        }
        if status == .authorized {
            access = .authorized
            loadPlaylists()
        } else {
            access = .denied
        }
    }

    func resetReports() {
        reports = []
    }

    // MARK: - Lecture des playlists

    func loadPlaylists() {
        let collections = MPMediaQuery.playlists().collections ?? []
        playlists = collections.compactMap { collection -> AppleMusicPlaylist? in
            guard let playlist = collection as? MPMediaPlaylist else { return nil }
            let items = playlist.items
            guard !items.isEmpty else { return nil }
            return AppleMusicPlaylist(
                id: playlist.persistentID,
                name: playlist.name ?? "Playlist",
                totalCount: items.count,
                importableCount: items.filter { Self.isImportable($0) }.count
            )
        }
        .sorted { $0.name.searchKey < $1.name.searchKey }
    }

    nonisolated static func isImportable(_ item: MPMediaItem) -> Bool {
        item.assetURL != nil && !item.hasProtectedAsset && !item.isCloudItem
    }

    // MARK: - Import

    func importPlaylists(ids: Set<UInt64>) async {
        guard !isWorking, !ids.isEmpty else { return }
        isWorking = true
        reports = []
        defer {
            isWorking = false
            progressText = ""
        }

        let all = (MPMediaQuery.playlists().collections ?? []).compactMap { $0 as? MPMediaPlaylist }
        for playlist in all where ids.contains(playlist.persistentID) {
            let name = playlist.name ?? "Playlist"
            let items = playlist.items
            var report = AppleMusicReport(playlistName: name)
            var resolved: [UUID] = []

            for (index, item) in items.enumerated() {
                progressText = "\(name) : \(index + 1)/\(items.count)"
                let title = item.title ?? "Sans titre"
                let artist = item.artist ?? Track.unknownArtist
                let label = "\(title) — \(artist)"

                if let existing = TrackMatcher.match(
                    title: title, artist: artist, duration: item.playbackDuration, in: library.tracks
                ) {
                    resolved.append(existing.id)
                    report.alreadyInLibrary += 1
                    continue
                }

                guard Self.isImportable(item), let url = item.assetURL else {
                    report.skipped.append(label)
                    continue
                }

                do {
                    let (track, isNew) = try await copy(item: item, from: url, title: title, artist: artist)
                    resolved.append(track.id)
                    if isNew { report.copied += 1 } else { report.alreadyInLibrary += 1 }
                } catch {
                    report.skipped.append(label)
                }
            }

            mergePlaylist(named: name, trackIDs: resolved)
            reports.append(report)
        }
    }

    private func mergePlaylist(named name: String, trackIDs: [UUID]) {
        if let existing = library.playlists.first(where: { $0.name.searchKey == name.searchKey }) {
            library.add(trackIDs, to: existing.id)
        } else {
            library.createPlaylist(name: name, trackIDs: trackIDs)
        }
    }

    private func copy(item: MPMediaItem, from url: URL, title: String, artist: String) async throws -> (Track, Bool) {
        try Storage.prepare()
        let id = UUID()
        let fileName = id.uuidString + ".m4a"
        let destination = Storage.musicURL(fileName: fileName)

        try await AppleMusicExport.exportM4A(from: url, to: destination)

        let hash: String
        do {
            hash = try await Task.detached(priority: .userInitiated) {
                try ImportPipeline.sha256(of: destination)
            }.value
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }

        if let duplicate = library.tracks.first(where: { $0.contentHash == hash }) {
            try? FileManager.default.removeItem(at: destination)
            return (duplicate, false)
        }

        var hasArtwork = false
        if let image = item.artwork?.image(at: CGSize(width: 600, height: 600)),
           let data = image.jpegData(compressionQuality: 0.85) {
            do {
                try data.write(to: Storage.artworkURL(key: id.uuidString), options: .atomic)
                hasArtwork = true
            } catch {
                hasArtwork = false
            }
        }

        let metadata = await MetadataReader.read(url: destination)
        let track = Track(
            id: id,
            title: title,
            artist: artist,
            album: item.albumTitle ?? Track.unknownAlbum,
            duration: item.playbackDuration > 0 ? item.playbackDuration : metadata.duration,
            fileName: fileName,
            hasArtwork: hasArtwork,
            contentHash: hash,
            dateAdded: Date()
        )
        library.add([track])
        return (track, true)
    }
}
