import SwiftUI

/// Ligne de musique : lecture au toucher, menu d'actions (favori, file d'attente, playlist, suppression).
struct TrackRow: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var player: PlayerService

    let track: Track
    /// Liste dans laquelle la lecture démarre (devient la file d'attente).
    let context: [Track]
    var subtitleSuffix: String? = nil
    var onRemoveFromPlaylist: (() -> Void)? = nil

    @State private var showAddToPlaylist = false
    @State private var confirmDelete = false

    private var isCurrent: Bool { player.currentTrack?.id == track.id }

    var body: some View {
        HStack(spacing: 8) {
            Button {
                player.play(track, in: context)
            } label: {
                HStack(spacing: 12) {
                    ArtworkView(key: track.artworkKey, seed: track.album, cornerRadius: 6)
                        .frame(width: 48, height: 48)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.body)
                            .foregroundStyle(isCurrent ? Theme.accent : .white)
                            .lineLimit(1)
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    if library.isFavorite(track.id) {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.accent)
                    }
                    if isCurrent {
                        Image(systemName: "waveform")
                            .font(.subheadline)
                            .foregroundStyle(Theme.accent)
                            .symbolEffect(.variableColor.iterative, isActive: player.isPlaying)
                    }
                    Text(track.duration.clockString)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(Theme.textSecondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                actions
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 32, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .contextMenu { actions }
        .sheet(isPresented: $showAddToPlaylist) {
            AddToPlaylistSheet(trackIDs: [track.id])
        }
        .confirmationDialog(
            "Supprimer « \(track.title) » de l'appareil ?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) {
                library.deleteTracks([track.id])
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Le fichier sera supprimé de Freetify Musique, ainsi que des playlists et favoris.")
        }
    }

    private var subtitle: String {
        if let subtitleSuffix { return track.artist + " · " + subtitleSuffix }
        return track.artist
    }

    @ViewBuilder
    private var actions: some View {
        Button {
            player.play(track, in: context)
        } label: {
            Label("Lire", systemImage: "play.fill")
        }
        Button {
            library.toggleFavorite(track.id)
        } label: {
            if library.isFavorite(track.id) {
                Label("Retirer des favoris", systemImage: "heart.slash")
            } else {
                Label("Ajouter aux favoris", systemImage: "heart")
            }
        }
        Button {
            player.playNext(track)
        } label: {
            Label("Lire ensuite", systemImage: "text.insert")
        }
        Button {
            player.addToQueue(track)
        } label: {
            Label("Ajouter à la file d'attente", systemImage: "text.append")
        }
        Button {
            showAddToPlaylist = true
        } label: {
            Label("Ajouter à une playlist", systemImage: "music.note.list")
        }
        if let onRemoveFromPlaylist {
            Button(role: .destructive) {
                onRemoveFromPlaylist()
            } label: {
                Label("Retirer de la playlist", systemImage: "minus.circle")
            }
        }
        Button(role: .destructive) {
            confirmDelete = true
        } label: {
            Label("Supprimer de l'appareil", systemImage: "trash")
        }
    }
}

/// Boutons « Lecture » et « Aléatoire » pour une liste de musiques.
struct PlayShuffleBar: View {
    @EnvironmentObject private var player: PlayerService
    let tracks: [Track]

    var body: some View {
        HStack(spacing: 12) {
            Button {
                player.playAll(tracks, shuffled: false)
            } label: {
                Label("Lecture", systemImage: "play.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Theme.primary))
            }
            Button {
                player.playAll(tracks, shuffled: true)
            } label: {
                Label("Aléatoire", systemImage: "shuffle")
                    .font(.headline)
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule().stroke(Theme.accent, lineWidth: 1.5))
            }
        }
        .buttonStyle(PressableStyle())
        .disabled(tracks.isEmpty)
    }
}

/// Liste de musiques avec en-tête optionnel, boutons de lecture et état vide.
struct TrackList<Header: View>: View {
    let tracks: [Track]
    let emptyTitle: String
    let emptyIcon: String
    let emptyMessage: String
    let showsPlayButtons: Bool
    let header: Header

    init(
        tracks: [Track],
        emptyTitle: String = "Aucune musique",
        emptyIcon: String = "music.note",
        emptyMessage: String = "",
        showsPlayButtons: Bool = true,
        @ViewBuilder header: () -> Header
    ) {
        self.tracks = tracks
        self.emptyTitle = emptyTitle
        self.emptyIcon = emptyIcon
        self.emptyMessage = emptyMessage
        self.showsPlayButtons = showsPlayButtons
        self.header = header()
    }

    var body: some View {
        if tracks.isEmpty {
            VStack(spacing: 0) {
                header
                ContentUnavailableView(emptyTitle, systemImage: emptyIcon, description: Text(emptyMessage))
                    .frame(maxHeight: .infinity)
            }
        } else {
            List {
                if Header.self != EmptyView.self {
                    header
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                if showsPlayButtons {
                    PlayShuffleBar(tracks: tracks)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                ForEach(tracks) { track in
                    TrackRow(track: track, context: tracks)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 8))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
}

extension TrackList where Header == EmptyView {
    init(
        tracks: [Track],
        emptyTitle: String = "Aucune musique",
        emptyIcon: String = "music.note",
        emptyMessage: String = "",
        showsPlayButtons: Bool = true
    ) {
        self.init(
            tracks: tracks,
            emptyTitle: emptyTitle,
            emptyIcon: emptyIcon,
            emptyMessage: emptyMessage,
            showsPlayButtons: showsPlayButtons,
            header: { EmptyView() }
        )
    }
}
