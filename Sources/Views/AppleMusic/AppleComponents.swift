import MusicKit
import SwiftUI

/// Pochette Apple Music (chargée depuis Internet par MusicKit ; repli sur la pochette générée).
struct AppleArtworkView: View {
    let artwork: Artwork?
    var seed: String = ""
    var cornerRadius: CGFloat = 10
    var circle: Bool = false
    var pixelSize: Int = 400

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let url = artwork?.url(width: pixelSize, height: pixelSize) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            PlaceholderArt(seed: seed)
                        }
                    }
                } else {
                    PlaceholderArt(seed: seed)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: circle ? 1000 : cornerRadius, style: .continuous))
    }
}

enum AppleRoute: Hashable {
    case album(Album)
    case artist(Artist)
}

struct AppleSongRow: View {
    @EnvironmentObject private var applePlayer: AppleMusicPlayer

    let song: Song
    let context: [Song]

    private var isCurrent: Bool {
        applePlayer.isActive && applePlayer.title == song.title && applePlayer.artist == song.artistName
    }

    var body: some View {
        Button {
            applePlayer.play(context, startingAt: song)
        } label: {
            HStack(spacing: 12) {
                AppleArtworkView(artwork: song.artwork, seed: song.albumTitle ?? song.title, cornerRadius: 8, pixelSize: 120)
                    .frame(width: 50, height: 50)
                VStack(alignment: .leading, spacing: 2) {
                    Text(song.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isCurrent ? Theme.accent : .white)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if isCurrent {
                    Image(systemName: applePlayer.isPlaying ? "waveform" : "pause.fill")
                        .foregroundStyle(Theme.accent)
                        .symbolEffect(.variableColor.iterative, isActive: applePlayer.isPlaying)
                } else if let duration = song.duration {
                    Text(duration.clockString)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }

    private var subtitle: String {
        if let album = song.albumTitle, !album.isEmpty {
            return "\(song.artistName) · \(album)"
        }
        return song.artistName
    }
}

struct AppleAlbumCard: View {
    let album: Album
    var width: CGFloat = 140

    var body: some View {
        NavigationLink(value: AppleRoute.album(album)) {
            VStack(alignment: .leading, spacing: 8) {
                AppleArtworkView(artwork: album.artwork, seed: album.title, cornerRadius: 12, pixelSize: 360)
                    .frame(width: width, height: width)
                VStack(alignment: .leading, spacing: 2) {
                    Text(album.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(album.artistName)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
            }
            .frame(width: width, alignment: .leading)
        }
        .buttonStyle(PressableStyle())
    }
}

struct AppleArtistCard: View {
    let artist: Artist
    var width: CGFloat = 110

    var body: some View {
        NavigationLink(value: AppleRoute.artist(artist)) {
            VStack(spacing: 8) {
                AppleArtworkView(artwork: artist.artwork, seed: artist.name, circle: true, pixelSize: 300)
                    .frame(width: width, height: width)
                Text(artist.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .frame(width: width)
        }
        .buttonStyle(PressableStyle())
    }
}

/// Boutons Lecture / Aléatoire pour une liste de titres du catalogue.
struct ApplePlayShuffleBar: View {
    @EnvironmentObject private var applePlayer: AppleMusicPlayer
    let songs: [Song]

    var body: some View {
        HStack(spacing: 12) {
            Button {
                applePlayer.play(songs, shuffled: false)
            } label: {
                Label("Lecture", systemImage: "play.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Theme.primary))
            }
            Button {
                applePlayer.play(songs, shuffled: true)
            } label: {
                Label("Aléatoire", systemImage: "shuffle")
                    .font(.headline)
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule().stroke(Theme.accent, lineWidth: 1.5))
            }
        }
        .buttonStyle(PressableStyle())
        .disabled(songs.isEmpty)
    }
}

/// Bandeau affiché quand l'abonnement Apple Music est nécessaire pour écouter.
struct AppleSubscriptionBanner: View {
    let canSubscribe: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Abonnement Apple Music nécessaire", systemImage: "exclamationmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)
            Text("Vous pouvez chercher dans le catalogue, mais Apple n'autorise l'écoute des titres du catalogue qu'avec un abonnement Apple Music actif. Freetify ne contourne pas cette règle : sans abonnement, aucun titre du catalogue n'est lu. Votre bibliothèque locale reste lisible normalement.")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
            if canSubscribe, let url = URL(string: "https://www.apple.com/apple-music/") {
                Link("Découvrir l'abonnement Apple Music", destination: url)
                    .font(.footnote.weight(.semibold))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous).fill(Theme.card))
        .padding(.horizontal, 16)
    }
}
