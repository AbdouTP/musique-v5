import Foundation

struct SearchResults {
    var tracks: [Track] = []
    var artists: [Artist] = []
    var albums: [Album] = []
    var playlists: [Playlist] = []

    var isEmpty: Bool {
        tracks.isEmpty && artists.isEmpty && albums.isEmpty && playlists.isEmpty
    }
}

/// Recherche instantanée dans les données locales (insensible à la casse et aux accents).
enum SearchService {
    static func search(
        _ query: String,
        tracks: [Track],
        albums: [Album],
        artists: [Artist],
        playlists: [Playlist]
    ) -> SearchResults {
        let key = query.searchKey
        guard !key.isEmpty else { return SearchResults() }
        let tokens = key.split(separator: " ").map(String.init)

        func matches(_ fields: [String]) -> Bool {
            let haystack = fields.joined(separator: " ").searchKey
            return tokens.allSatisfy { haystack.contains($0) }
        }

        var results = SearchResults()
        results.tracks = tracks
            .filter { matches([$0.title, $0.artist, $0.album]) }
            .sorted { lhs, rhs in
                let l = lhs.title.searchKey.hasPrefix(key)
                let r = rhs.title.searchKey.hasPrefix(key)
                if l != r { return l }
                return lhs.title.searchKey < rhs.title.searchKey
            }
        results.artists = artists.filter { matches([$0.name]) }
        results.albums = albums.filter { matches([$0.title, $0.artist]) }
        results.playlists = playlists.filter { matches([$0.name]) }
        return results
    }
}
