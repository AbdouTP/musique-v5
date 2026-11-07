import Foundation

/// Recommandations calculées uniquement à partir de la bibliothèque locale.
enum Recommender {
    /// - Parameter history: du plus récent au plus ancien.
    static func recommendations(
        tracks: [Track],
        history: [HistoryEntry],
        favoriteIDs: Set<UUID>,
        limit: Int = 20
    ) -> [Track] {
        guard !tracks.isEmpty else { return [] }
        let byID = Dictionary(tracks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        // Affinité par artiste : écoutes + favoris (pondérés).
        var affinity: [String: Double] = [:]
        for entry in history {
            if let track = byID[entry.trackID] {
                affinity[track.artist.searchKey, default: 0] += 1
            }
        }
        for id in favoriteIDs {
            if let track = byID[id] {
                affinity[track.artist.searchKey, default: 0] += 2
            }
        }

        let playCounts = Dictionary(grouping: history, by: \.trackID).mapValues(\.count)
        let recentlyPlayed = Set(history.prefix(10).map(\.trackID))

        let scored: [(track: Track, score: Double)] = tracks
            .filter { !recentlyPlayed.contains($0.id) }
            .map { track in
                var score = affinity[track.artist.searchKey] ?? 0
                if playCounts[track.id] == nil { score += 1.5 }       // jamais écoutée
                if favoriteIDs.contains(track.id) { score += 0.5 }
                return (track, score)
            }

        return scored
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                if lhs.track.dateAdded != rhs.track.dateAdded { return lhs.track.dateAdded > rhs.track.dateAdded }
                return lhs.track.title.searchKey < rhs.track.title.searchKey
            }
            .prefix(limit)
            .map(\.track)
    }
}
