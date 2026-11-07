import SwiftUI

/// Curseur de progression : seul ce composant observe l'horloge de lecture.
struct ProgressSlider: View {
    @ObservedObject var clock: PlaybackClock
    let onSeek: (Double) -> Void

    @State private var isDragging = false
    @State private var dragValue: Double = 0

    private var shown: Double { isDragging ? dragValue : clock.currentTime }

    var body: some View {
        VStack(spacing: 2) {
            Slider(
                value: Binding(
                    get: { shown },
                    set: { dragValue = $0 }
                ),
                in: 0...max(clock.duration, 1),
                onEditingChanged: { editing in
                    if editing {
                        dragValue = clock.currentTime
                        isDragging = true
                    } else {
                        onSeek(dragValue)
                        isDragging = false
                    }
                }
            )
            .tint(Theme.accent)

            HStack {
                Text(shown.clockString)
                Spacer()
                Text("-" + max(clock.duration - shown, 0).clockString)
            }
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(Theme.textSecondary)
        }
    }
}

struct FullPlayerView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var player: PlayerService
    @Environment(\.dismiss) private var dismiss

    @State private var showQueue = false
    @State private var showAddToPlaylist = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.primary.opacity(0.55), Theme.deep, Theme.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if let track = player.currentTrack {
                content(track)
            } else {
                ContentUnavailableView("Rien en lecture", systemImage: "music.note")
            }
        }
        .sheet(isPresented: $showQueue) {
            QueueView()
        }
        .sheet(isPresented: $showAddToPlaylist) {
            if let track = player.currentTrack {
                AddToPlaylistSheet(trackIDs: [track.id])
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func content(_ track: Track) -> some View {
        VStack(spacing: 0) {
            topBar
                .padding(.top, 20)

            Spacer(minLength: 8)

            ArtworkView(key: track.artworkKey, seed: track.album, cornerRadius: 18)
                .shadow(color: .black.opacity(0.45), radius: 24, y: 12)
                .scaleEffect(player.isPlaying ? 1 : 0.9)
                .animation(.spring(response: 0.5, dampingFraction: 0.75), value: player.isPlaying)
                .padding(.horizontal, 8)

            Spacer(minLength: 16)

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.body)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Button {
                    library.toggleFavorite(track.id)
                } label: {
                    Image(systemName: library.isFavorite(track.id) ? "heart.fill" : "heart")
                        .font(.title2)
                        .foregroundStyle(library.isFavorite(track.id) ? Theme.accent : .white)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(library.isFavorite(track.id) ? "Retirer des favoris" : "Ajouter aux favoris")
            }

            ProgressSlider(clock: player.clock) { player.seek(to: $0) }
                .padding(.top, 8)

            controls
                .padding(.top, 8)

            secondaryControls
                .padding(.top, 14)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Fermer le lecteur")
            Spacer()
            VStack(spacing: 2) {
                Text("EN LECTURE")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                if let album = player.currentTrack?.album {
                    Text(album)
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                }
            }
            Spacer()
            Button {
                showAddToPlaylist = true
            } label: {
                Image(systemName: "text.badge.plus")
                    .font(.title3)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Ajouter à une playlist")
        }
        .foregroundStyle(.white)
        .buttonStyle(PressableStyle())
    }

    private var controls: some View {
        HStack {
            Button {
                player.toggleShuffle()
            } label: {
                Image(systemName: "shuffle")
                    .font(.title3)
                    .foregroundStyle(player.isShuffled ? Theme.accent : .white)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Mode aléatoire")

            Spacer()

            Button {
                player.previous()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
            }
            .accessibilityLabel("Musique précédente")

            Spacer()

            Button {
                player.togglePlayPause()
            } label: {
                ZStack {
                    Circle().fill(Color.white)
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(Theme.background)
                        .offset(x: player.isPlaying ? 0 : 2)
                }
                .frame(width: 72, height: 72)
            }
            .accessibilityLabel(player.isPlaying ? "Pause" : "Lecture")

            Spacer()

            Button {
                player.next()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(player.canGoNext ? .white : Theme.textSecondary)
                    .frame(width: 52, height: 52)
            }
            .disabled(!player.canGoNext)
            .accessibilityLabel("Musique suivante")

            Spacer()

            Button {
                player.cycleRepeat()
            } label: {
                Image(systemName: player.repeatMode == .one ? "repeat.1" : "repeat")
                    .font(.title3)
                    .foregroundStyle(player.repeatMode == .off ? .white : Theme.accent)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Répétition")
        }
        .buttonStyle(PressableStyle())
    }

    private var secondaryControls: some View {
        HStack {
            Button {
                player.skip(by: -15)
            } label: {
                Image(systemName: "gobackward.15")
                    .font(.title2)
                    .frame(width: 48, height: 44)
            }
            .accessibilityLabel("Reculer de 15 secondes")
            Spacer()
            Button {
                showQueue = true
            } label: {
                Label("File d'attente", systemImage: "list.bullet")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
            }
            Spacer()
            Button {
                player.skip(by: 15)
            } label: {
                Image(systemName: "goforward.15")
                    .font(.title2)
                    .frame(width: 48, height: 44)
            }
            .accessibilityLabel("Avancer de 15 secondes")
        }
        .foregroundStyle(.white)
        .buttonStyle(PressableStyle())
    }
}
