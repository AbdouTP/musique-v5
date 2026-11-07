import SwiftUI

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(.white)
            if let subtitle {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
    }
}

struct HorizontalRow<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 14) {
                content()
            }
            .padding(.horizontal, 16)
        }
    }
}

struct TrackCard: View {
    @EnvironmentObject private var player: PlayerService
    let track: Track
    let context: [Track]

    var body: some View {
        Button {
            player.play(track, in: context)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ArtworkView(key: track.artworkKey, seed: track.album, cornerRadius: 12)
                    .frame(width: 140, height: 140)
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
            }
            .frame(width: 140, alignment: .leading)
        }
        .buttonStyle(PressableStyle())
    }
}

struct AlbumCard: View {
    let album: Album
    var width: CGFloat = 140

    var body: some View {
        NavigationLink(value: Route.album(album.id)) {
            VStack(alignment: .leading, spacing: 8) {
                ArtworkView(key: album.artworkKey, seed: album.title, cornerRadius: 12)
                    .frame(width: width, height: width)
                VStack(alignment: .leading, spacing: 2) {
                    Text(album.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(album.artist)
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

struct PlaylistCard: View {
    let playlist: Playlist
    var width: CGFloat = 140

    var body: some View {
        NavigationLink(value: Route.playlist(playlist.id)) {
            VStack(alignment: .leading, spacing: 8) {
                PlaylistCoverView(playlist: playlist, cornerRadius: 12)
                    .frame(width: width, height: width)
                VStack(alignment: .leading, spacing: 2) {
                    Text(playlist.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("\(playlist.trackIDs.count) titre\(playlist.trackIDs.count > 1 ? "s" : "")")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(width: width, alignment: .leading)
        }
        .buttonStyle(PressableStyle())
    }
}

/// Grande tuile d'accès rapide (accueil).
struct QuickTileLabel: View {
    let title: String
    let systemImage: String
    var tint: Color = Theme.primary

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(tint))
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.card))
    }
}

struct EmptyLibraryView: View {
    @EnvironmentObject private var ui: UIState

    var body: some View {
        VStack(spacing: 16) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
            Text("Votre bibliothèque est vide")
                .font(.title2.bold())
                .foregroundStyle(.white)
            Text("Importez vos fichiers MP3, M4A, AAC, WAV, AIFF ou FLAC, ou téléchargez de la musique libre depuis l'onglet Découvrir. Tout reste lisible sans connexion.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textSecondary)
            Button {
                ui.showImporter = true
            } label: {
                Label("Importer des musiques", systemImage: "square.and.arrow.down")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Theme.primary))
            }
            .buttonStyle(PressableStyle())
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}
