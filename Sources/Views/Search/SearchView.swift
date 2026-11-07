import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var library: LibraryStore

    @State private var query = ""

    var body: some View {
        NavigationStack {
            Group {
                if query.searchKey.isEmpty {
                    ContentUnavailableView(
                        "Rechercher",
                        systemImage: "magnifyingglass",
                        description: Text("Titres, artistes, albums et playlists de votre bibliothèque.")
                    )
                } else {
                    let results = SearchService.search(
                        query,
                        tracks: library.tracks,
                        albums: library.albums,
                        artists: library.artists,
                        playlists: library.playlists
                    )
                    if results.isEmpty {
                        ContentUnavailableView.search(text: query)
                    } else {
                        resultsList(results)
                    }
                }
            }
            .appBackground()
            .withMiniPlayer()
            .navigationTitle("Recherche")
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Que voulez-vous écouter ?"
            )
            .libraryDestinations()
        }
    }

    private func resultsList(_ results: SearchResults) -> some View {
        List {
            if !results.tracks.isEmpty {
                Section {
                    let shown = Array(results.tracks.prefix(50))
                    ForEach(shown) { track in
                        TrackRow(track: track, context: shown)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 8))
                            .listRowBackground(Color.clear)
                    }
                } header: {
                    sectionTitle("Titres")
                }
            }

            if !results.artists.isEmpty {
                Section {
                    ForEach(results.artists) { artist in
                        NavigationLink(value: Route.artist(artist.id)) {
                            HStack(spacing: 12) {
                                ArtworkView(key: artist.artworkKey, seed: artist.name, circle: true)
                                    .frame(width: 48, height: 48)
                                Text(artist.name)
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                            }
                        }
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    sectionTitle("Artistes")
                }
            }

            if !results.albums.isEmpty {
                Section {
                    ForEach(results.albums) { album in
                        NavigationLink(value: Route.album(album.id)) {
                            HStack(spacing: 12) {
                                ArtworkView(key: album.artworkKey, seed: album.title, cornerRadius: 6)
                                    .frame(width: 48, height: 48)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(album.title)
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    Text(album.artist)
                                        .font(.caption)
                                        .foregroundStyle(Theme.textSecondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    sectionTitle("Albums")
                }
            }

            if !results.playlists.isEmpty {
                Section {
                    ForEach(results.playlists) { playlist in
                        NavigationLink(value: Route.playlist(playlist.id)) {
                            HStack(spacing: 12) {
                                PlaylistCoverView(playlist: playlist, cornerRadius: 6)
                                    .frame(width: 48, height: 48)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(playlist.name)
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    Text("\(playlist.trackIDs.count) titre\(playlist.trackIDs.count > 1 ? "s" : "")")
                                        .font(.caption)
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                        }
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    sectionTitle("Playlists")
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.title3.bold())
            .foregroundStyle(.white)
            .textCase(nil)
    }
}
