import MusicKit
import SwiftUI

struct AppleAlbumDetailView: View {
    @EnvironmentObject private var service: AppleMusicService

    let album: Album

    @State private var songs: [Song] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                AppleArtworkView(artwork: album.artwork, seed: album.title, cornerRadius: 16, pixelSize: 700)
                    .frame(width: 220, height: 220)
                    .shadow(color: .black.opacity(0.4), radius: 16, y: 8)
                VStack(spacing: 4) {
                    Text(album.title)
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text(album.artistName)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.horizontal, 16)

                ApplePlayShuffleBar(songs: songs)
                    .padding(.horizontal, 16)

                if isLoading {
                    ProgressView().tint(Theme.accent).padding(.top, 20)
                } else if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                } else {
                    VStack(spacing: 10) {
                        ForEach(songs, id: \.id) { song in
                            AppleSongRow(song: song, context: songs)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 12)
        }
        .appBackground()
        .withMiniPlayer()
        .navigationTitle(album.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do {
                songs = try await service.songs(of: album)
            } catch {
                errorMessage = AppleMusicError.message(for: error)
            }
            isLoading = false
        }
    }
}

struct AppleArtistDetailView: View {
    @EnvironmentObject private var service: AppleMusicService

    let artist: Artist

    @State private var songs: [Song] = []
    @State private var albums: [Album] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(spacing: 12) {
                    AppleArtworkView(artwork: artist.artwork, seed: artist.name, circle: true, pixelSize: 500)
                        .frame(width: 160, height: 160)
                        .shadow(color: .black.opacity(0.4), radius: 14, y: 6)
                    Text(artist.name)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)

                if isLoading {
                    ProgressView().tint(Theme.accent).frame(maxWidth: .infinity).padding(.top, 20)
                } else if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 24)
                } else {
                    if !songs.isEmpty {
                        SectionHeader(title: "Titres populaires")
                        ApplePlayShuffleBar(songs: songs)
                            .padding(.horizontal, 16)
                        VStack(spacing: 10) {
                            ForEach(songs.prefix(10), id: \.id) { song in
                                AppleSongRow(song: song, context: songs)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    if !albums.isEmpty {
                        SectionHeader(title: "Albums")
                        HorizontalRow {
                            ForEach(albums, id: \.id) { album in
                                AppleAlbumCard(album: album)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 12)
        }
        .appBackground()
        .withMiniPlayer()
        .navigationTitle(artist.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do {
                let content = try await service.content(of: artist)
                songs = content.songs
                albums = content.albums
            } catch {
                errorMessage = AppleMusicError.message(for: error)
            }
            isLoading = false
        }
    }
}
