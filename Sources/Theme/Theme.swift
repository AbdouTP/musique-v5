import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

/// Identité visuelle Freetify Musique.
enum Theme {
    static let primary = Color(hex: 0x8B35F5)
    static let deep = Color(hex: 0x171324)
    static let accent = Color(hex: 0xA7F36B)
    static let background = Color(hex: 0x100D18)
    static let card = Color(hex: 0x1F1A33)
    static let textSecondary = Color.white.opacity(0.62)

    static let cornerRadius: CGFloat = 14
}

extension Double {
    /// "m:ss" ou "h:mm:ss".
    var clockString: String {
        guard isFinite, self >= 0 else { return "0:00" }
        let total = Int(self.rounded(.down))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}

extension Int64 {
    var byteString: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}

/// Bouton avec petite animation d'appui.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension View {
    func appBackground() -> some View {
        background(Theme.background.ignoresSafeArea())
    }
}
