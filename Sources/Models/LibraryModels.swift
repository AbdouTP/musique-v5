import Foundation

extension String {
    /// Clé de comparaison insensible à la casse, aux accents et aux espaces autour.
    var searchKey: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct Album: Identifiable, Hashable {
    let id: String
    let title: String
    let artist: String
    let tracks: [Track]

    var artworkKey: String? { tracks.first(where: { $0.hasArtwork })?.artworkKey }
    var duration: Double { tracks.reduce(0) { $0 + $1.duration } }
}

struct Artist: Identifiable, Hashable {
    let id: String
    let name: String
    let tracks: [Track]
    let albumCount: Int

    var artworkKey: String? { tracks.first(where: { $0.hasArtwork })?.artworkKey }
}

/// Construit les albums et artistes à partir des musiques (tout est dérivé, rien n'est stocké en double).
enum LibraryIndex {
    static func albumID(for track: Track) -> String {
        if track.album == Track.unknownAlbum {
            return "unknown|" + track.artist.searchKey
        }
        return track.album.searchKey + "|" + track.artist.searchKey
    }

    static func albums(from tracks: [Track]) -> [Album] {
        let grouped = Dictionary(grouping: tracks, by: albumID(for:))
        return grouped.map { key, items in
            let sorted = items.sorted(by: trackOrder)
            let first = sorted[0]
            return Album(id: key, title: first.album, artist: first.artist, tracks: sorted)
        }
        .sorted { $0.title.searchKey < $1.title.searchKey }
    }

    static func artists(from tracks: [Track]) -> [Artist] {
        let grouped = Dictionary(grouping: tracks, by: { $0.artist.searchKey })
        return grouped.map { key, items in
            let sorted = items.sorted(by: trackOrder)
            let albumCount = Set(sorted.map(albumID(for:))).count
            return Artist(id: key, name: sorted[0].artist, tracks: sorted, albumCount: albumCount)
        }
        .sorted { $0.name.searchKey < $1.name.searchKey }
    }

    private static func trackOrder(_ a: Track, _ b: Track) -> Bool {
        if a.dateAdded != b.dateAdded { return a.dateAdded < b.dateAdded }
        return a.title.searchKey < b.title.searchKey
    }
}
