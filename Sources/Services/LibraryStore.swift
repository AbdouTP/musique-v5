import Foundation
import SwiftUI

/// Source de vérité de la bibliothèque : musiques, playlists, favoris, historique.
/// Persistée dans `library.json` (Application Support) après chaque modification.
@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var tracks: [Track] = []
    @Published private(set) var playlists: [Playlist] = []
    @Published private(set) var favoriteIDs: Set<UUID> = []
    /// Historique d'écoute, du plus récent au plus ancien.
    @Published private(set) var history: [HistoryEntry] = []
    @Published private(set) var albums: [Album] = []
    @Published private(set) var artists: [Artist] = []
    @Published var loadWarning: String?

    /// Appelé avant la suppression de musiques (pour arrêter la lecture concernée).
    var onTracksDeleted: ((Set<UUID>) -> Void)?

    private var trackIndex: [UUID: Track] = [:]
    private static let historyLimit = 500
    private static let writeQueue = DispatchQueue(label: "com.abdoutp.freetifymusique.library-write", qos: .utility)

    init() {
        load()
    }

    // MARK: - Chargement / sauvegarde

    private func load() {
        do {
            try Storage.prepare()
        } catch {
            loadWarning = "Impossible de préparer le stockage : \(error.localizedDescription)"
            return
        }

        let url = Storage.libraryFile
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        do {
            let data = try Data(contentsOf: url)
            let snapshot = try JSONDecoder().decode(LibrarySnapshot.self, from: data)
            tracks = snapshot.tracks
            playlists = snapshot.playlists
            favoriteIDs = Set(snapshot.favoriteTrackIDs)
            history = snapshot.history
            reconcile()
            rebuildIndex()
        } catch {
            let stamp = Int(Date().timeIntervalSince1970)
            let backup = url.deletingLastPathComponent().appendingPathComponent("library.corrupt-\(stamp).json")
            try? FileManager.default.moveItem(at: url, to: backup)
            loadWarning = "La bibliothèque n'a pas pu être lue. Une copie du fichier a été conservée (\(error.localizedDescription))."
        }
    }

    /// Retire les musiques dont le fichier a disparu et nettoie les références orphelines.
    private func reconcile() {
        var changed = false

        let existing = tracks.filter { FileManager.default.fileExists(atPath: $0.fileURL.path) }
        if existing.count != tracks.count {
            tracks = existing
            changed = true
        }
        let valid = Set(tracks.map(\.id))

        for index in playlists.indices {
            let kept = playlists[index].trackIDs.filter { valid.contains($0) }
            if kept.count != playlists[index].trackIDs.count {
                playlists[index].trackIDs = kept
                changed = true
            }
        }
        let keptFavorites = favoriteIDs.intersection(valid)
        if keptFavorites.count != favoriteIDs.count {
            favoriteIDs = keptFavorites
            changed = true
        }
        let keptHistory = history.filter { valid.contains($0.trackID) }
        if keptHistory.count != history.count {
            history = keptHistory
            changed = true
        }

        purgeOrphanFiles(validTrackFiles: Set(tracks.map(\.fileName)))
        if changed { persist() }
    }

    /// Supprime les fichiers audio copiés mais jamais enregistrés (ex. import interrompu).
    private func purgeOrphanFiles(validTrackFiles: Set<String>) {
        let dir = Storage.musicDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else { return }
        for name in files where !validTrackFiles.contains(name) {
            try? FileManager.default.removeItem(at: dir.appendingPathComponent(name))
        }
    }

    private func persist() {
        let snapshot = LibrarySnapshot(
            tracks: tracks,
            playlists: playlists,
            favoriteTrackIDs: favoriteIDs.map { $0 }.sorted { $0.uuidString < $1.uuidString },
            history: history
        )
        let url = Storage.libraryFile
        Self.writeQueue.async {
            do {
                let data = try JSONEncoder().encode(snapshot)
                try data.write(to: url, options: .atomic)
            } catch {
                NSLog("Freetify : échec de la sauvegarde de la bibliothèque : %@", error.localizedDescription)
            }
        }
    }

    /// Attend la fin des écritures en cours (utile pour les tests).
    func flush() {
        Self.writeQueue.sync {}
    }

    private func rebuildIndex() {
        trackIndex = Dictionary(tracks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        albums = LibraryIndex.albums(from: tracks)
        artists = LibraryIndex.artists(from: tracks)
    }

    // MARK: - Musiques

    var knownHashes: Set<String> { Set(tracks.map(\.contentHash)) }

    func track(withID id: UUID) -> Track? { trackIndex[id] }

    func tracks(for ids: [UUID]) -> [Track] { ids.compactMap { trackIndex[$0] } }

    func add(_ newTracks: [Track]) {
        guard !newTracks.isEmpty else { return }
        tracks.append(contentsOf: newTracks)
        rebuildIndex()
        persist()
    }

    func deleteTracks(_ ids: Set<UUID>) {
        let removed = tracks.filter { ids.contains($0.id) }
        guard !removed.isEmpty else { return }

        onTracksDeleted?(ids)

        tracks.removeAll { ids.contains($0.id) }
        for index in playlists.indices {
            playlists[index].trackIDs.removeAll { ids.contains($0) }
        }
        favoriteIDs.subtract(ids)
        history.removeAll { ids.contains($0.trackID) }
        rebuildIndex()
        persist()

        var urls: [URL] = []
        for track in removed {
            urls.append(track.fileURL)
            if let key = track.artworkKey {
                urls.append(Storage.artworkURL(key: key))
                ArtworkStore.shared.invalidate(key: key)
            }
        }
        Task.detached(priority: .utility) {
            for url in urls { try? FileManager.default.removeItem(at: url) }
        }
    }

    func deleteAllTracks() {
        deleteTracks(Set(tracks.map(\.id)))
    }

    /// Supprime tout : musiques, playlists, favoris, historique.
    func resetLibrary() {
        deleteAllTracks()
        for playlist in playlists {
            if let cover = playlist.coverFile { deleteArtworkFile(key: cover) }
        }
        playlists.removeAll()
        favoriteIDs.removeAll()
        history.removeAll()
        persist()
    }

    // MARK: - Favoris

    func isFavorite(_ id: UUID) -> Bool { favoriteIDs.contains(id) }

    func toggleFavorite(_ id: UUID) {
        if favoriteIDs.contains(id) {
            favoriteIDs.remove(id)
        } else if trackIndex[id] != nil {
            favoriteIDs.insert(id)
        }
        persist()
    }

    var favoriteTracks: [Track] {
        tracks.filter { favoriteIDs.contains($0.id) }
            .sorted { $0.title.searchKey < $1.title.searchKey }
    }

    // MARK: - Historique

    func recordPlay(_ id: UUID) {
        guard trackIndex[id] != nil else { return }
        history.insert(HistoryEntry(id: UUID(), trackID: id, playedAt: Date()), at: 0)
        if history.count > Self.historyLimit {
            history.removeLast(history.count - Self.historyLimit)
        }
        persist()
    }

    func clearHistory() {
        history.removeAll()
        persist()
    }

    /// Dernières musiques écoutées, sans doublons.
    func recentlyPlayed(limit: Int = 20) -> [Track] {
        var seen = Set<UUID>()
        var result: [Track] = []
        for entry in history {
            guard seen.insert(entry.trackID).inserted, let track = trackIndex[entry.trackID] else { continue }
            result.append(track)
            if result.count >= limit { break }
        }
        return result
    }

    // MARK: - Playlists

    func playlist(withID id: UUID) -> Playlist? { playlists.first { $0.id == id } }

    func tracks(in playlist: Playlist) -> [Track] { tracks(for: playlist.trackIDs) }

    @discardableResult
    func createPlaylist(name: String, trackIDs: [UUID] = []) -> Playlist {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var seen = Set<UUID>()
        let unique = trackIDs.filter { trackIndex[$0] != nil && seen.insert($0).inserted }
        let playlist = Playlist(
            id: UUID(),
            name: trimmed.isEmpty ? "Ma playlist n°\(playlists.count + 1)" : trimmed,
            trackIDs: unique,
            createdAt: Date(),
            isFavorite: false,
            coverFile: nil
        )
        playlists.append(playlist)
        persist()
        return playlist
    }

    func renamePlaylist(_ id: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = playlists.firstIndex(where: { $0.id == id }) else { return }
        playlists[index].name = trimmed
        persist()
    }

    func deletePlaylist(_ id: UUID) {
        guard let index = playlists.firstIndex(where: { $0.id == id }) else { return }
        if let cover = playlists[index].coverFile { deleteArtworkFile(key: cover) }
        playlists.remove(at: index)
        persist()
    }

    func toggleFavoritePlaylist(_ id: UUID) {
        guard let index = playlists.firstIndex(where: { $0.id == id }) else { return }
        playlists[index].isFavorite.toggle()
        persist()
    }

    /// Ajoute des musiques (sans doublon). Retourne le nombre réellement ajouté.
    @discardableResult
    func add(_ ids: [UUID], to playlistID: UUID) -> Int {
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }) else { return 0 }
        var existing = Set(playlists[index].trackIDs)
        var added = 0
        for id in ids where trackIndex[id] != nil && existing.insert(id).inserted {
            playlists[index].trackIDs.append(id)
            added += 1
        }
        if added > 0 { persist() }
        return added
    }

    func removeTracks(atOffsets offsets: IndexSet, from playlistID: UUID) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        playlists[index].trackIDs.remove(atOffsets: offsets)
        persist()
    }

    func remove(trackID: UUID, from playlistID: UUID) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        playlists[index].trackIDs.removeAll { $0 == trackID }
        persist()
    }

    func moveTracks(from source: IndexSet, to destination: Int, in playlistID: UUID) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        playlists[index].trackIDs.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    // MARK: - Pochettes de playlist

    @discardableResult
    func setCover(_ imageData: Data, for playlistID: UUID) async -> Bool {
        let processed = await Task.detached(priority: .userInitiated) {
            ImageProcessing.jpegData(from: imageData)
        }.value
        guard let jpeg = processed,
              let index = playlists.firstIndex(where: { $0.id == playlistID }) else { return false }

        let key = "playlist-\(playlistID.uuidString)-\(UUID().uuidString.prefix(8))"
        do {
            try jpeg.write(to: Storage.artworkURL(key: key), options: .atomic)
        } catch {
            return false
        }
        if let old = playlists[index].coverFile { deleteArtworkFile(key: old) }
        playlists[index].coverFile = key
        persist()
        return true
    }

    func removeCover(for playlistID: UUID) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }),
              let old = playlists[index].coverFile else { return }
        deleteArtworkFile(key: old)
        playlists[index].coverFile = nil
        persist()
    }

    private func deleteArtworkFile(key: String) {
        ArtworkStore.shared.invalidate(key: key)
        try? FileManager.default.removeItem(at: Storage.artworkURL(key: key))
    }
}
