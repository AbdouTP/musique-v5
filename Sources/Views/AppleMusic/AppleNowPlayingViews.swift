import MusicKit
import SwiftUI

/// Mini-lecteur Apple Music (même style que le mini-lecteur local).
struct AppleMiniPlayerView: View {
    @EnvironmentObject private var apple: AppleMusicPlayer
    @EnvironmentObject private var ui: UIState

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                AppleArtworkView(artwork: apple.artwork, seed: apple.album, cornerRadius: 8, pixelSize: 120)
                    .frame(width: 42, height: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text(apple.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Image(systemName: "applelogo")
                            .font(.caption2)
                        Text(apple.artist)
                            .lineLimit(1)
                    }
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 8)
                Button {
                    apple.togglePlayPause()
                } label: {
                    Image(systemName: apple.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(apple.isPlaying ? "Pause" : "Lecture")
                Button {
                    apple.next()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Musique suivante")
            }
            .foregroundStyle(.white)
            .buttonStyle(PressableStyle())
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            MiniProgressBar(clock: apple.clock)
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
        .onTapGesture { ui.showAppleMusicPlayer = true }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

/// Lecteur plein écran Apple Music.
struct AppleMusicNowPlayingView: View {
    @EnvironmentObject private var apple: AppleMusicPlayer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.primary.opacity(0.55), Theme.deep, Theme.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if apple.isActive {
                content
            } else {
                ContentUnavailableView("Rien en lecture", systemImage: "music.note")
            }
        }
        .presentationDragIndicator(.visible)
        .onChange(of: apple.isActive) { _, active in
            if !active { dismiss() }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
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
                    Text("APPLE MUSIC")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                    if !apple.album.isEmpty {
                        Text(apple.album)
                            .font(.footnote.weight(.semibold))
                            .lineLimit(1)
                    }
                }
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            .foregroundStyle(.white)
            .buttonStyle(PressableStyle())
            .padding(.top, 20)

            Spacer(minLength: 8)

            AppleArtworkView(artwork: apple.artwork, seed: apple.album, cornerRadius: 18, pixelSize: 900)
                .shadow(color: .black.opacity(0.45), radius: 24, y: 12)
                .scaleEffect(apple.isPlaying ? 1 : 0.9)
                .animation(.spring(response: 0.5, dampingFraction: 0.75), value: apple.isPlaying)
                .padding(.horizontal, 8)

            Spacer(minLength: 16)

            VStack(alignment: .leading, spacing: 4) {
                Text(apple.title)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(apple.artist)
                    .font(.body)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ProgressSlider(clock: apple.clock) { apple.seek(to: $0) }
                .padding(.top, 8)

            controls
                .padding(.top, 8)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    private var controls: some View {
        HStack {
            Button {
                apple.toggleShuffle()
            } label: {
                Image(systemName: "shuffle")
                    .font(.title3)
                    .foregroundStyle(apple.isShuffled ? Theme.accent : .white)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Mode aléatoire")

            Spacer()

            Button {
                apple.previous()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
            }
            .accessibilityLabel("Musique précédente")

            Spacer()

            Button {
                apple.togglePlayPause()
            } label: {
                ZStack {
                    Circle().fill(Color.white)
                    Image(systemName: apple.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(Theme.background)
                        .offset(x: apple.isPlaying ? 0 : 2)
                }
                .frame(width: 72, height: 72)
            }
            .accessibilityLabel(apple.isPlaying ? "Pause" : "Lecture")

            Spacer()

            Button {
                apple.next()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
            }
            .accessibilityLabel("Musique suivante")

            Spacer()

            Button {
                apple.cycleRepeat()
            } label: {
                Image(systemName: apple.repeatMode == .one ? "repeat.1" : "repeat")
                    .font(.title3)
                    .foregroundStyle(apple.repeatMode == .none ? .white : Theme.accent)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Répétition")
        }
        .buttonStyle(PressableStyle())
    }
}
