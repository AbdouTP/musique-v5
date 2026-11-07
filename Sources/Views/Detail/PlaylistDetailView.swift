import PhotosUI
import SwiftUI

struct PlaylistDetailView: View {
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss

    let playlistID: UUID

    @State private var editMode: EditMode = .inactive
    @State private var showRename = false
    @State private var renameText = ""
    @State private var showDeleteConfirm = false
    @State private var showTrackPicker = false
    @State private var showPhotoPicker = false
    @State private var photoItem: PhotosPickerItem?
    @State private var coverFailed = false

    var body: some View {
        Group {
            if let playlist = library.playlist(withID: playlistID) {
                content(playlist)
            } else {
                ContentUnavailableView("Playlist introuvable", systemImage: "music.note.list")
            }
        }
        .appBackground()
        .withMiniPlayer()
    }

    private func content(_ playlist: Playlist) -> some View {
        let tracks = library.tracks(in: playlist)
        return List {
            header(playlist, tracks: tracks)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            ForEach(tracks) { track in
                TrackRow(
                    track: track,
                    context: tracks,
                    onRemoveFromPlaylist: { library.remove(trackID: track.id, from: playlist.id) }
                )
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 8))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .onDelete { offsets in
                library.removeTracks(atOffsets: offsets, from: playlist.id)
            }
            .onMove { source, destination in
                library.moveTracks(from: source, to: destination, in: playlist.id)
            }

            if tracks.isEmpty {
                Text("Cette playlist est vide. Ajoutez des musiques avec le bouton ci-dessus ou depuis le menu ⋯ d'une musique.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, $editMode)
        .navigationTitle(playlist.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 4) {
                    if !tracks.isEmpty { EditButton() }
                    Menu {
                        Button {
                            renameText = playlist.name
                            showRename = true
                        } label: {
                            Label("Renommer", systemImage: "pencil")
                        }
                        Button {
                            showTrackPicker = true
                        } label: {
                            Label("Ajouter des musiques", systemImage: "plus")
                        }
                        Button {
                            showPhotoPicker = true
                        } label: {
                            Label("Choisir une pochette", systemImage: "photo")
                        }
                        if playlist.coverFile != nil {
                            Button {
                                library.removeCover(for: playlist.id)
                            } label: {
                                Label("Retirer la pochette", systemImage: "photo.badge.minus")
                            }
                        }
                        Button {
                            library.toggleFavoritePlaylist(playlist.id)
                        } label: {
                            Label(
                                playlist.isFavorite ? "Retirer des favoris" : "Ajouter aux favoris",
                                systemImage: playlist.isFavorite ? "heart.slash" : "heart"
                            )
                        }
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Supprimer la playlist", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .alert("Renommer la playlist", isPresented: $showRename) {
            TextField("Nom", text: $renameText)
            Button("Enregistrer") {
                library.renamePlaylist(playlist.id, to: renameText)
            }
            Button("Annuler", role: .cancel) {}
        }
        .confirmationDialog(
            "Supprimer « \(playlist.name) » ?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Supprimer la playlist", role: .destructive) {
                library.deletePlaylist(playlist.id)
                dismiss()
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Les musiques restent dans votre bibliothèque.")
        }
        .sheet(isPresented: $showTrackPicker) {
            TrackPickerSheet(playlistID: playlist.id)
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                var success = false
                if let data = try? await item.loadTransferable(type: Data.self) {
                    success = await library.setCover(data, for: playlistID)
                }
                if !success { coverFailed = true }
                photoItem = nil
            }
        }
        .alert("Pochette", isPresented: $coverFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Impossible d'utiliser cette image comme pochette.")
        }
    }

    private func header(_ playlist: Playlist, tracks: [Track]) -> some View {
        VStack(spacing: 14) {
            PlaylistCoverView(playlist: playlist, cornerRadius: 14)
                .frame(width: 220, height: 220)
                .shadow(color: .black.opacity(0.4), radius: 16, y: 8)
            Text(playlist.name)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            let minutes = Int(tracks.reduce(0) { $0 + $1.duration } / 60)
            Text("\(tracks.count) titre\(tracks.count > 1 ? "s" : "") · \(minutes) min")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)

            PlayShuffleBar(tracks: tracks)

            HStack(spacing: 12) {
                Button {
                    showTrackPicker = true
                } label: {
                    Label("Ajouter des musiques", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Theme.card))
                }
                Button {
                    library.toggleFavoritePlaylist(playlist.id)
                } label: {
                    Image(systemName: playlist.isFavorite ? "heart.fill" : "heart")
                        .font(.headline)
                        .foregroundStyle(playlist.isFavorite ? Theme.accent : .white)
                        .frame(width: 44, height: 40)
                        .background(Capsule().fill(Theme.card))
                }
                .accessibilityLabel(playlist.isFavorite ? "Retirer des playlists favorites" : "Ajouter aux playlists favorites")
            }
            .buttonStyle(PressableStyle())
        }
        .frame(maxWidth: .infinity)
    }
}
