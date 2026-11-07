import SwiftUI

/// Onglet Découvrir : catalogue Apple Music (MusicKit) ou musique libre téléchargeable (Jamendo).
struct DiscoverHubView: View {
    enum Source: String, CaseIterable, Identifiable {
        case appleMusic = "Apple Music"
        case free = "Musique libre"

        var id: String { rawValue }
    }

    @AppStorage("discoverSource") private var sourceRaw = Source.appleMusic.rawValue

    private var source: Source { Source(rawValue: sourceRaw) ?? .appleMusic }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Source", selection: $sourceRaw) {
                ForEach(Source.allCases) { item in
                    Text(item.rawValue).tag(item.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            switch source {
            case .appleMusic:
                AppleMusicView()
            case .free:
                DiscoverView()
            }
        }
        .appBackground()
    }
}
