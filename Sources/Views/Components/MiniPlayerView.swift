import SwiftUI

struct MiniPlayerView: View {
    @EnvironmentObject private var player: PlayerService
    @EnvironmentObject private var apple: AppleMusicPlayer
    @EnvironmentObject private var ui: UIState

    var body: some View {
        if apple.isActive {
            AppleMiniPlayerView()
        } else if let track = player.currentTrack {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    ArtworkView(key: track.artworkKey, seed: track.album, cornerRadius: 8)
                        .frame(width: 42, height: 42)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(track.artist)
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Button {
                        player.togglePlayPause()
                    } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .frame(width: 40, height: 40)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(player.isPlaying ? "Pause" : "Lecture")
                    Button {
                        player.next()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.title3)
                            .frame(width: 40, height: 40)
                            .contentShape(Rectangle())
                    }
                    .disabled(!player.canGoNext)
                    .accessibilityLabel("Musique suivante")
                }
                .foregroundStyle(.white)
                .buttonStyle(PressableStyle())
                .padding(.horizontal, 10)
                .padding(.vertical, 8)

                MiniProgressBar(clock: player.clock)
            }
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.card))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
            .contentShape(Rectangle())
            .onTapGesture { ui.showFullPlayer = true }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

struct MiniProgressBar: View {
    @ObservedObject var clock: PlaybackClock

    var body: some View {
        GeometryReader { geo in
            let fraction = clock.duration > 0 ? min(max(clock.currentTime / clock.duration, 0), 1) : 0
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.white.opacity(0.12))
                Rectangle()
                    .fill(Theme.accent)
                    .frame(width: geo.size.width * fraction)
            }
        }
        .frame(height: 2.5)
    }
}
