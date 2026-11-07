import AVFoundation
import CryptoKit
import Foundation
import UniformTypeIdentifiers

/// Résultat d'un import pour un fichier.
enum ImportOutcome: Sendable {
    case imported(Track)
    case duplicate
}

enum ImportError: LocalizedError {
    case unsupported(String)
    case notPlayable(String)

    var errorDescription: String? {
        switch self {
        case .unsupported(let name): return "\(name) : format non pris en charge."
        case .notPlayable(let name): return "\(name) : fichier illisible ou codec non pris en charge par iOS."
        }
    }
}

/// Opérations d'import (hors thread principal) : copie, empreinte, métadonnées, pochette.
enum ImportPipeline {
    static let supportedExtensions: Set<String> = [
        "mp3", "m4a", "aac", "wav", "wave", "aif", "aiff", "aifc", "flac", "caf", "mp4"
    ]

    static var contentTypes: [UTType] {
        var types: [UTType] = [.audio, .mp3, .mpeg4Audio, .wav, .aiff]
        for ext in ["flac", "aac", "m4a"] {
            if let type = UTType(filenameExtension: ext) { types.append(type) }
        }
        return types
    }

    static func ingest(url: URL, knownHashes: Set<String>) async throws -> ImportOutcome {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let name = url.lastPathComponent
        let ext = url.pathExtension.lowercased()
        guard supportedExtensions.contains(ext) else { throw ImportError.unsupported(name) }

        try Storage.prepare()
        let id = UUID()
        let fileName = id.uuidString + "." + ext
        let destination = Storage.musicURL(fileName: fileName)

        // Copie permanente (coordonnée : déclenche le téléchargement iCloud si nécessaire).
        try await Task.detached(priority: .userInitiated) {
            try coordinatedCopy(from: url, to: destination)
        }.value

        do {
            let hash = try await Task.detached(priority: .userInitiated) {
                try sha256(of: destination)
            }.value

            if knownHashes.contains(hash) {
                try? FileManager.default.removeItem(at: destination)
                return .duplicate
            }

            let metadata = await MetadataReader.read(url: destination)
            guard metadata.isPlayable else { throw ImportError.notPlayable(name) }

            var hasArtwork = false
            if let data = metadata.artworkData,
               let jpeg = ImageProcessing.jpegData(from: data) {
                do {
                    try jpeg.write(to: Storage.artworkURL(key: id.uuidString), options: .atomic)
                    hasArtwork = true
                } catch {
                    hasArtwork = false
                }
            }

            let parsed = FilenameParser.parse(url.deletingPathExtension().lastPathComponent)
            let track = Track(
                id: id,
                title: metadata.title ?? parsed.title,
                artist: metadata.artist ?? parsed.artist ?? Track.unknownArtist,
                album: metadata.album ?? Track.unknownAlbum,
                duration: metadata.duration,
                fileName: fileName,
                hasArtwork: hasArtwork,
                contentHash: hash,
                dateAdded: Date()
            )
            return .imported(track)
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }

    static func coordinatedCopy(from source: URL, to destination: URL) throws {
        var coordinationError: NSError?
        var copyError: Error?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(readingItemAt: source, options: [], error: &coordinationError) { readURL in
            do {
                try FileManager.default.copyItem(at: readURL, to: destination)
            } catch {
                copyError = error
            }
        }
        if let coordinationError { throw coordinationError }
        if let copyError { throw copyError }
    }

    static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let chunk = try handle.read(upToCount: 1 << 20) ?? Data()
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

/// Coordonne l'importation de plusieurs fichiers et publie la progression.
@MainActor
final class ImportService: ObservableObject {
    @Published private(set) var isImporting = false
    @Published private(set) var processed = 0
    @Published private(set) var total = 0
    @Published var reportMessage: String?

    private let library: LibraryStore

    init(library: LibraryStore) {
        self.library = library
    }

    func importFiles(_ urls: [URL]) async {
        guard !urls.isEmpty, !isImporting else { return }
        isImporting = true
        processed = 0
        total = urls.count

        var hashes = library.knownHashes
        var pending: [Track] = []
        var imported = 0
        var duplicates = 0
        var failures: [String] = []

        for url in urls {
            do {
                let outcome = try await ImportPipeline.ingest(url: url, knownHashes: hashes)
                switch outcome {
                case .imported(let track):
                    hashes.insert(track.contentHash)
                    pending.append(track)
                    imported += 1
                case .duplicate:
                    duplicates += 1
                }
            } catch {
                failures.append(error.localizedDescription)
            }
            processed += 1

            if pending.count >= 20 {
                library.add(pending)
                pending.removeAll()
            }
        }
        library.add(pending)
        isImporting = false

        reportMessage = Self.makeReport(imported: imported, duplicates: duplicates, failures: failures)
    }

    nonisolated static func makeReport(imported: Int, duplicates: Int, failures: [String]) -> String {
        var lines: [String] = []
        if imported > 0 { lines.append("\(imported) musique(s) importée(s).") }
        if duplicates > 0 { lines.append("\(duplicates) doublon(s) ignoré(s).") }
        if !failures.isEmpty {
            lines.append("\(failures.count) échec(s) :")
            lines.append(contentsOf: failures.prefix(5))
            if failures.count > 5 { lines.append("…") }
        }
        if lines.isEmpty { lines.append("Aucun fichier à importer.") }
        return lines.joined(separator: "\n")
    }
}
