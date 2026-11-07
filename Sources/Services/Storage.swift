import Foundation

/// Emplacements de stockage permanent (Application Support/Freetify).
/// Tout est local : aucune connexion Internet n'est jamais utilisée.
enum Storage {
    /// Permet aux tests d'utiliser un dossier temporaire.
    nonisolated(unsafe) static var customRoot: URL?

    static var root: URL {
        if let customRoot { return customRoot }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Freetify", isDirectory: true)
    }

    static var musicDirectory: URL { root.appendingPathComponent("Music", isDirectory: true) }
    static var artworkDirectory: URL { root.appendingPathComponent("Artwork", isDirectory: true) }
    static var libraryFile: URL { root.appendingPathComponent("library.json") }

    static func musicURL(fileName: String) -> URL {
        musicDirectory.appendingPathComponent(fileName)
    }

    static func artworkURL(key: String) -> URL {
        artworkDirectory.appendingPathComponent(key + ".jpg")
    }

    static func prepare() throws {
        for dir in [root, musicDirectory, artworkDirectory] {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    /// Taille cumulée d'un dossier (appel synchrone : à exécuter hors du thread principal).
    static func directorySize(_ url: URL) -> Int64 {
        let keys: [URLResourceKey] = [.fileSizeKey, .isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]
        ) else { return 0 }
        var total: Int64 = 0
        while let item = enumerator.nextObject() as? URL {
            let values = try? item.resourceValues(forKeys: Set(keys))
            if values?.isRegularFile == true {
                total += Int64(values?.fileSize ?? 0)
            }
        }
        return total
    }
}
