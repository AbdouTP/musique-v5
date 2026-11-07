import SwiftUI

// MARK: - Musiques

enum SongSort: String, CaseIterable, Identifiable {
    case recent = "Ajouts récents"
    case title = "Titre"
    case artist = "Artiste"

    var id: String { rawValue }
}

struct SongsContent: View {
    @EnvironmentObject private var library: LibraryStore
    @State private var sort: SongSort = .recent

    private var sorted: [Track] {
        switch sort {
        case .recent:
            return library.tracks.sorted { $0.dateAdded > $1.dateAdded }
        case .title:
            return library.tracks.sorted { $0.title.searchKey < $1.title.searchKey }
        case .artist:
            return library.tracks.sorted {
                if $0.artist.searchKey != $1.artist.searchKey { return $0.artist.searchKey < $1.artist.searchKey }
                return $0.title.searchKey < $1.title.searchKey
            }
        }
    }

    var body: some View {
        if library.tracks.isEmpty {
            ScrollView { EmptyLibraryView() }
        } else {
            TrackList(tracks: sorted) {
                HStack {
                    Text("\(library.tracks.count) musique\(library.tracks.count > 1 ? "s" : "")")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Menu {
                        Picker("Trier par", selection: $sort) {
                            ForEach(SongSort.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                    } label: {
                        Label(sort.rawValue, systemImage: "arrow.up.arrow.down")
                            .font(.subheadline)
                    }
                }
            }
        }
    }
}

// MARK: - Albums

struct AlbumsContent: View {
    @EnvironmentObject private var library: LibraryStore

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 16, alignment: .top)]

    var body: some View {
        if library.albums.isEmpty {
            ContentUnavailableView(
                "Aucun album",
                systemImage: "square.stack",
                description: Text("Les albums apparaissent dès que vous importez des musiques.")
            )
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(library.albums) { album in
                        AlbumCard(album: album, width: 160)
                    }
                }
                .padding(16)
            }
        }
    }
}

// MARK: - Artistes

struct ArtistsContent: View {
    @EnvironmentObject private var library: LibraryStore

    var body: some View {
        if library.artists.isEmpty {
            ContentUnavailableView(
                "Aucun artiste",
                systemImage: "person.2",
                description: Text("Les artistes apparaissent dès que vous importez des musiques.")
            )
        } else {
            List(library.artists) { artist in
                NavigationLink(value: Route.artist(artist.id)) {
                    HStack(spacing: 12) {
                        ArtworkView(key: artist.artworkKey, seed: artist.name, circle: true)
                            .frame(width: 52, height: 52)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(artist.name)
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text("\(artist.tracks.count) titre\(artist.tracks.count > 1 ? "s" : "")")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
}

// MARK: - Playlists

struct PlaylistsContent: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var ui: UIState

    @State private var showNew = false
    @State private var newName = ""
    @State private var pendingDelete: Playlist?

    var body: some View {
        List {
            Button {
                newName = ""
                showNew = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "plus")
                        .font(.title3.bold())
                        .foregroundStyle(Theme.accent)
                        .frame(width: 52, height: 52)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.card))
                    Text("Nouvelle playlist")
                        .foregroundStyle(.white)
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            Button {
                ui.showAppleMusicImport = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.title3)
                        .foregroundStyle(Theme.accent)
                        .frame(width: 52, height: 52)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.card))
                    Text("Importer depuis Apple Music")
                        .foregroundStyle(.white)
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            ForEach(library.playlists) { playlist in
                NavigationLink(value: Route.playlist(playlist.id)) {
                    HStack(spacing: 12) {
                        PlaylistCoverView(playlist: playlist, cornerRadius: 8)
                            .frame(width: 52, height: 52)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(playlist.name)
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text("\(playlist.trackIDs.count) titre\(playlist.trackIDs.count > 1 ? "s" : "")")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                        if playlist.isFavorite {
                            Image(systemName: "heart.fill")
                                .font(.caption)
                                .foregroundStyle(Theme.accent)
                        }
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        pendingDelete = playlist
                    } label: {
                        Label("Supprimer", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .alert("Nouvelle playlist", isPresented: $showNew) {
            TextField("Nom de la playlist", text: $newName)
            Button("Créer") {
                library.createPlaylist(name: newName)
            }
            Button("Annuler", role: .cancel) {}
        }
        .confirmationDialog(
            "Supprimer la playlist « \(pendingDelete?.name ?? "") » ?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) {
                if let pendingDelete { library.deletePlaylist(pendingDelete.id) }
                pendingDelete = nil
            }
            Button("Annuler", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("Les musiques restent dans votre bibliothèque.")
        }
    }
}

// MARK: - Favoris

struct FavoritesContent: View {
    @EnvironmentObject private var library: LibraryStore

    var body: some View {
        TrackList(
            tracks: library.favoriteTracks,
            emptyTitle: "Aucun favori",
            emptyIcon: "heart",
            emptyMessage: "Touchez le cœur dans le lecteur ou utilisez le menu ⋯ d'une musique pour l'ajouter aux favoris."
        )
    }
}

// MARK: - Historique

struct HistoryContent: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var player: PlayerService

    @State private var confirmClear = false

    private var entries: [(entry: HistoryEntry, track: Track)] {
        library.history.compactMap { entry in
            library.track(withID: entry.trackID).map { (entry, $0) }
        }
    }

    var body: some View {
        let items = entries
        if items.isEmpty {
            ContentUnavailableView(
                "Aucun historique",
                systemImage: "clock",
                description: Text("Les musiques que vous écoutez apparaîtront ici.")
            )
        } else {
            let context = items.map(\.track)
            List {
                HStack {
                    Text("\(items.count) écoute\(items.count > 1 ? "s" : "")")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Button("Effacer", role: .destructive) { confirmClear = true }
                        .font(.subheadline)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                ForEach(items, id: \.entry.id) { item in
                    TrackRow(
                        track: item.track,
                        context: context,
                        subtitleSuffix: item.entry.playedAt.formatted(.relative(presentation: .named, unitsStyle: .wide))
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 8))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .confirmationDialog("Effacer tout l'historique d'écoute ?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Effacer l'historique", role: .destructive) { library.clearHistory() }
                Button("Annuler", role: .cancel) {}
            }
        }
    }
}
