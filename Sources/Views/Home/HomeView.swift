import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var player: PlayerService
    @EnvironmentObject private var ui: UIState

    private var greeting: String {
        Calendar.current.component(.hour, from: Date()) < 18 ? "Bonjour" : "Bonsoir"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text(greeting)
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)

                    if library.tracks.isEmpty {
                        EmptyLibraryView()
                    } else {
                        content
                    }

                    Text("Dev by AbdouTP")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                }
                .padding(.vertical, 12)
            }
            .appBackground()
            .withMiniPlayer()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image("Logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                        Text("Freetify Musique")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        ui.showImporter = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Importer des musiques")
                }
            }
            .libraryDestinations()
        }
    }

    @ViewBuilder
    private var content: some View {
        quickTiles

        let recent = library.recentlyPlayed(limit: 12)
        if !recent.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Écoutés récemment")
                HorizontalRow {
                    ForEach(recent) { track in
                        TrackCard(track: track, context: recent)
                    }
                }
            }
        }

        let favoritePlaylists = library.playlists.filter(\.isFavorite)
        if !favoritePlaylists.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Playlists favorites")
                HorizontalRow {
                    ForEach(favoritePlaylists) { playlist in
                        PlaylistCard(playlist: playlist)
                    }
                }
            }
        }

        if !library.albums.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Albums importés")
                HorizontalRow {
                    ForEach(library.albums.prefix(15)) { album in
                        AlbumCard(album: album)
                    }
                }
            }
        }

        let suggestions = Recommender.recommendations(
            tracks: library.tracks,
            history: library.history,
            favoriteIDs: library.favoriteIDs,
            limit: 15
        )
        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Pour vous", subtitle: "Basé sur votre bibliothèque et vos écoutes")
                HorizontalRow {
                    ForEach(suggestions) { track in
                        TrackCard(track: track, context: suggestions)
                    }
                }
            }
        }
    }

    private var quickTiles: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            NavigationLink(value: Route.favorites) {
                QuickTileLabel(title: "Titres aimés", systemImage: "heart.fill", tint: Theme.primary)
            }
            NavigationLink(value: Route.history) {
                QuickTileLabel(title: "Historique", systemImage: "clock.fill", tint: Color(hex: 0x5B2BB0))
            }
            NavigationLink(value: Route.allSongs) {
                QuickTileLabel(title: "Toutes les musiques", systemImage: "music.note", tint: Color(hex: 0x3D7A3A))
            }
            Button {
                player.playAll(library.tracks, shuffled: true)
            } label: {
                QuickTileLabel(title: "Lecture aléatoire", systemImage: "shuffle", tint: Color(hex: 0x6D8F2E))
            }
        }
        .buttonStyle(PressableStyle())
        .padding(.horizontal, 16)
    }
}
