import SwiftUI

enum Route: Hashable {
    case album(String)
    case artist(String)
    case playlist(UUID)
    case favorites
    case history
    case allSongs
}

struct RouteView: View {
    let route: Route

    var body: some View {
        switch route {
        case .album(let id):
            AlbumDetailView(albumID: id)
        case .artist(let id):
            ArtistDetailView(artistID: id)
        case .playlist(let id):
            PlaylistDetailView(playlistID: id)
        case .favorites:
            FavoritesContent()
                .appBackground()
                .navigationTitle("Titres aimés")
                .navigationBarTitleDisplayMode(.inline)
                .withMiniPlayer()
        case .history:
            HistoryContent()
                .appBackground()
                .navigationTitle("Historique")
                .navigationBarTitleDisplayMode(.inline)
                .withMiniPlayer()
        case .allSongs:
            SongsContent()
                .appBackground()
                .navigationTitle("Toutes les musiques")
                .navigationBarTitleDisplayMode(.inline)
                .withMiniPlayer()
        }
    }
}

extension View {
    /// Enregistre les destinations de navigation de la bibliothèque dans une NavigationStack.
    func libraryDestinations() -> some View {
        navigationDestination(for: Route.self) { route in
            RouteView(route: route)
        }
    }

    /// Place le mini-lecteur au-dessus de la barre d'onglets.
    func withMiniPlayer() -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            MiniPlayerView()
        }
    }
}
