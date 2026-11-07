import Foundation

/// Retrouve dans la bibliothèque une musique correspondant à un titre Apple Music.
enum TrackMatcher {
    static func match(title: String, artist: String, duration: Double, in tracks: [Track]) -> Track? {
        let wantedTitle = title.searchKey
        let wantedArtist = artist.searchKey
        guard !wantedTitle.isEmpty else { return nil }

        return tracks.first { track in
            guard track.title.searchKey == wantedTitle else { return false }
            let artistMatches = track.artist.searchKey == wantedArtist
                || track.artist == Track.unknownArtist
                || artist == Track.unknownArtist
            guard artistMatches else { return false }
            if duration > 0, track.duration > 0 {
                return abs(track.duration - duration) <= 3
            }
            return true
        }
    }
}
