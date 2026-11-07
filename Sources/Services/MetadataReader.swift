import AVFoundation

struct TrackMetadata: Sendable {
    var title: String?
    var artist: String?
    var album: String?
    var duration: Double = 0
    var artworkData: Data?
    var isPlayable: Bool = false
}

/// Lit les métadonnées intégrées au fichier (ID3, iTunes, etc.) via AVFoundation, hors connexion.
enum MetadataReader {
    static func read(url: URL) async -> TrackMetadata {
        let asset = AVURLAsset(url: url)
        var meta = TrackMetadata()

        meta.isPlayable = (try? await asset.load(.isPlayable)) ?? false
        if let time = try? await asset.load(.duration) {
            let seconds = time.seconds
            if seconds.isFinite, seconds > 0 { meta.duration = seconds }
        }

        guard let items = try? await asset.load(.commonMetadata) else { return meta }
        meta.title = await string(.commonIdentifierTitle, in: items)
        meta.artist = await string(.commonIdentifierArtist, in: items)
        meta.album = await string(.commonIdentifierAlbumName, in: items)
        meta.artworkData = await artwork(in: items)
        return meta
    }

    private static func string(_ identifier: AVMetadataIdentifier, in items: [AVMetadataItem]) async -> String? {
        let matches = AVMetadataItem.metadataItems(from: items, filteredByIdentifier: identifier)
        for item in matches {
            if let value = try? await item.load(.stringValue) {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return nil
    }

    private static func artwork(in items: [AVMetadataItem]) async -> Data? {
        let matches = AVMetadataItem.metadataItems(from: items, filteredByIdentifier: .commonIdentifierArtwork)
        for item in matches {
            if let data = try? await item.load(.dataValue), !data.isEmpty { return data }
            if let value = try? await item.load(.value), let nsData = value as? NSData, nsData.length > 0 {
                return Data(referencing: nsData)
            }
        }
        return nil
    }
}

/// Déduit "Artiste - Titre" du nom de fichier quand les métadonnées sont absentes.
enum FilenameParser {
    static func parse(_ baseName: String) -> (artist: String?, title: String) {
        let cleaned = baseName
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = cleaned.range(of: " - ") {
            let artist = String(cleaned[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let title = String(cleaned[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            if !artist.isEmpty, !title.isEmpty { return (artist, title) }
        }
        return (nil, cleaned.isEmpty ? "Sans titre" : cleaned)
    }
}
