import Foundation

/// Une musique importée. Seul `fileName` (relatif) est stocké : le chemin complet
/// est recalculé à chaque lancement, car le conteneur de l'app peut changer de chemin.
struct Track: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String
    var artist: String
    var album: String
    var duration: Double
    var fileName: String
    var hasArtwork: Bool
    var contentHash: String
    var dateAdded: Date
    /// Identifiant du titre en ligne (ex. « jamendo:123 ») s'il a été téléchargé depuis Découvrir.
    var sourceID: String? = nil

    static let unknownArtist = "Artiste inconnu"
    static let unknownAlbum = "Album inconnu"

    var artworkKey: String? { hasArtwork ? id.uuidString : nil }
    var fileURL: URL { Storage.musicURL(fileName: fileName) }
}
