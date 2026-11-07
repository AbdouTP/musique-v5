import SwiftUI

struct AlbumDetailView: View {
    @EnvironmentObject private var library: LibraryStore
    let albumID: String

    var body: some View {
        Group {
            if let album = library.albums.first(where: { $0.id == albumID }) {
                TrackList(tracks: album.tracks) {
                    VStack(spacing: 12) {
                        ArtworkView(key: album.artworkKey, seed: album.title, cornerRadius: 14)
                            .frame(width: 220, height: 220)
                            .shadow(color: .black.opacity(0.4), radius: 16, y: 8)
                        Text(album.title)
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                        Text("\(album.artist) · \(album.tracks.count) titre\(album.tracks.count > 1 ? "s" : "") · \(Int(album.duration / 60)) min")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                ContentUnavailableView("Album introuvable", systemImage: "square.stack")
            }
        }
        .appBackground()
        .navigationBarTitleDisplayMode(.inline)
        .withMiniPlayer()
    }
}

struct ArtistDetailView: View {
    @EnvironmentObject private var library: LibraryStore
    let artistID: String

    var body: some View {
        Group {
            if let artist = library.artists.first(where: { $0.id == artistID }) {
                let albums = library.albums.filter { $0.artist.searchKey == artist.id }
                TrackList(tracks: artist.tracks) {
                    VStack(spacing: 14) {
                        ArtworkView(key: artist.artworkKey, seed: artist.name, circle: true)
                            .frame(width: 180, height: 180)
                            .shadow(color: .black.opacity(0.4), radius: 16, y: 8)
                        Text(artist.name)
                            .font(.title.bold())
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                        Text("\(artist.tracks.count) titre\(artist.tracks.count > 1 ? "s" : "") · \(artist.albumCount) album\(artist.albumCount > 1 ? "s" : "")")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                        if albums.count > 1 {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Albums")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(alignment: .top, spacing: 14) {
                                        ForEach(albums) { album in
                                            AlbumCard(album: album, width: 120)
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                ContentUnavailableView("Artiste introuvable", systemImage: "person.2")
            }
        }
        .appBackground()
        .navigationBarTitleDisplayMode(.inline)
        .withMiniPlayer()
    }
}
