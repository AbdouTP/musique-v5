import Foundation

struct Playlist: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var trackIDs: [UUID]
    var createdAt: Date
    var isFavorite: Bool
    /// Clé du fichier de pochette personnalisée (dans le dossier Artwork), si choisie.
    var coverFile: String?
}

struct HistoryEntry: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let trackID: UUID
    let playedAt: Date
}

/// Contenu complet de `library.json`.
struct LibrarySnapshot: Codable, Sendable {
    var version: Int = 1
    var tracks: [Track]
    var playlists: [Playlist]
    var favoriteTrackIDs: [UUID]
    var history: [HistoryEntry]
}
