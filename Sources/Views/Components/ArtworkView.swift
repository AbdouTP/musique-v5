import SwiftUI

/// Pochette générée quand aucune image n'est disponible (jamais téléchargée depuis Internet).
struct PlaceholderArt: View {
    let seed: String

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: "music.note")
                    .font(.system(size: geo.size.width * 0.38, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
    }

    private var colors: [Color] {
        let sum = seed.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        let shift = Double(sum % 60) / 360.0
        return [
            Theme.primary,
            Color(hue: 0.70 + shift * 0.4, saturation: 0.65, brightness: 0.32)
        ]
    }
}

/// Pochette carrée chargée depuis le disque. Le cadre est donné par l'appelant (`.frame`).
struct ArtworkView: View {
    let key: String?
    var seed: String = ""
    var cornerRadius: CGFloat = 10
    var circle: Bool = false

    @State private var image: UIImage?

    init(key: String?, seed: String = "", cornerRadius: CGFloat = 10, circle: Bool = false) {
        self.key = key
        self.seed = seed
        self.cornerRadius = cornerRadius
        self.circle = circle
        _image = State(initialValue: ArtworkStore.shared.cachedImage(for: key))
    }

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    PlaceholderArt(seed: seed)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: circle ? 1000 : cornerRadius, style: .continuous))
            .task(id: key) {
                image = await ArtworkStore.shared.image(for: key)
            }
    }
}

/// Pochette d'une playlist : image choisie, sinon mosaïque de pochettes, sinon pochette générée.
struct PlaylistCoverView: View {
    @EnvironmentObject private var library: LibraryStore
    let playlist: Playlist
    var cornerRadius: CGFloat = 10

    private var artworkKeys: [String] {
        var seen = Set<String>()
        var keys: [String] = []
        for track in library.tracks(in: playlist) {
            if let key = track.artworkKey, seen.insert(key).inserted {
                keys.append(key)
                if keys.count == 4 { break }
            }
        }
        return keys
    }

    var body: some View {
        if let cover = playlist.coverFile {
            ArtworkView(key: cover, seed: playlist.name, cornerRadius: cornerRadius)
        } else {
            let keys = artworkKeys
            if keys.count >= 4 {
                Color.clear
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        GeometryReader { geo in
                            let side = geo.size.width / 2
                            VStack(spacing: 0) {
                                HStack(spacing: 0) {
                                    tile(keys[0], side)
                                    tile(keys[1], side)
                                }
                                HStack(spacing: 0) {
                                    tile(keys[2], side)
                                    tile(keys[3], side)
                                }
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            } else {
                ArtworkView(key: keys.first, seed: playlist.name, cornerRadius: cornerRadius)
            }
        }
    }

    private func tile(_ key: String, _ side: CGFloat) -> some View {
        ArtworkView(key: key, cornerRadius: 0)
            .frame(width: side, height: side)
    }
}
