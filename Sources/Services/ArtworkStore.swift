import UIKit

/// Charge les pochettes depuis le disque (jamais depuis Internet) avec un cache mémoire.
final class ArtworkStore: @unchecked Sendable {
    static let shared = ArtworkStore()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 200
    }

    func cachedImage(for key: String?) -> UIImage? {
        guard let key else { return nil }
        return cache.object(forKey: key as NSString)
    }

    func image(for key: String?) async -> UIImage? {
        guard let key else { return nil }
        if let hit = cache.object(forKey: key as NSString) { return hit }
        let path = Storage.artworkURL(key: key).path
        let loaded = await Task.detached(priority: .utility) { () -> UIImage? in
            guard let raw = UIImage(contentsOfFile: path) else { return nil }
            return raw.preparingForDisplay() ?? raw
        }.value
        if let loaded { cache.setObject(loaded, forKey: key as NSString) }
        return loaded
    }

    /// Lecture synchrone (petites images JPEG) pour l'écran verrouillé.
    func imageSync(for key: String?) -> UIImage? {
        guard let key else { return nil }
        if let hit = cache.object(forKey: key as NSString) { return hit }
        guard let image = UIImage(contentsOfFile: Storage.artworkURL(key: key).path) else { return nil }
        cache.setObject(image, forKey: key as NSString)
        return image
    }

    func invalidate(key: String?) {
        guard let key else { return }
        cache.removeObject(forKey: key as NSString)
    }
}
