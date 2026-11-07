import SwiftUI

enum LibrarySection: String, CaseIterable, Identifiable {
    case songs = "Musiques"
    case albums = "Albums"
    case artists = "Artistes"
    case playlists = "Playlists"
    case favorites = "Favoris"
    case history = "Historique"

    var id: String { rawValue }
}

struct LibraryView: View {
    @EnvironmentObject private var ui: UIState

    @State private var section: LibrarySection = .songs

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                chips
                Group {
                    switch section {
                    case .songs: SongsContent()
                    case .albums: AlbumsContent()
                    case .artists: ArtistsContent()
                    case .playlists: PlaylistsContent()
                    case .favorites: FavoritesContent()
                    case .history: HistoryContent()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .appBackground()
            .withMiniPlayer()
            .navigationTitle("Bibliothèque")
            .toolbar {
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

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LibrarySection.allCases) { item in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { section = item }
                    } label: {
                        Text(item.rawValue)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(section == item ? Theme.background : .white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(section == item ? Theme.accent : Theme.card)
                            )
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}
