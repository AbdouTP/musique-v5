import SwiftUI

/// Choisir une playlist (ou en créer une) pour y ajouter des musiques.
struct AddToPlaylistSheet: View {
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss

    let trackIDs: [UUID]

    @State private var showNew = false
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            List {
                Button {
                    newName = ""
                    showNew = true
                } label: {
                    Label("Nouvelle playlist", systemImage: "plus.circle.fill")
                        .foregroundStyle(Theme.accent)
                }
                .listRowBackground(Theme.card)

                ForEach(library.playlists) { playlist in
                    Button {
                        library.add(trackIDs, to: playlist.id)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            PlaylistCoverView(playlist: playlist, cornerRadius: 6)
                                .frame(width: 44, height: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(playlist.name).foregroundStyle(.white)
                                Text("\(playlist.trackIDs.count) titre\(playlist.trackIDs.count > 1 ? "s" : "")")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                        }
                    }
                    .listRowBackground(Theme.card)
                }
            }
            .scrollContentBackground(.hidden)
            .appBackground()
            .navigationTitle("Ajouter à une playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .alert("Nouvelle playlist", isPresented: $showNew) {
                TextField("Nom de la playlist", text: $newName)
                Button("Créer") {
                    library.createPlaylist(name: newName, trackIDs: trackIDs)
                    dismiss()
                }
                Button("Annuler", role: .cancel) {}
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Sélection multiple de musiques à ajouter à une playlist.
struct TrackPickerSheet: View {
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss

    let playlistID: UUID

    @State private var selection = Set<UUID>()
    @State private var query = ""

    private var candidates: [Track] {
        let existing = Set(library.playlist(withID: playlistID)?.trackIDs ?? [])
        let key = query.searchKey
        return library.tracks
            .filter { track in
                guard !existing.contains(track.id) else { return false }
                if key.isEmpty { return true }
                return [track.title, track.artist, track.album].joined(separator: " ").searchKey.contains(key)
            }
            .sorted { $0.title.searchKey < $1.title.searchKey }
    }

    var body: some View {
        NavigationStack {
            Group {
                let items = candidates
                if items.isEmpty {
                    ContentUnavailableView(
                        "Rien à ajouter",
                        systemImage: "music.note",
                        description: Text("Toutes vos musiques sont déjà dans cette playlist, ou aucune ne correspond.")
                    )
                } else {
                    List(items) { track in
                        Button {
                            if selection.contains(track.id) {
                                selection.remove(track.id)
                            } else {
                                selection.insert(track.id)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                ArtworkView(key: track.artworkKey, seed: track.album, cornerRadius: 6)
                                    .frame(width: 44, height: 44)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(track.title).foregroundStyle(.white).lineLimit(1)
                                    Text(track.artist)
                                        .font(.caption)
                                        .foregroundStyle(Theme.textSecondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: selection.contains(track.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(selection.contains(track.id) ? Theme.accent : Theme.textSecondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .appBackground()
            .navigationTitle("Ajouter des musiques")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Rechercher")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter (\(selection.count))") {
                        let ordered = library.tracks.map(\.id).filter { selection.contains($0) }
                        library.add(ordered, to: playlistID)
                        dismiss()
                    }
                    .disabled(selection.isEmpty)
                }
            }
        }
    }
}
