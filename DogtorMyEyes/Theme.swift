import SwiftUI

enum Theme {
    static let teal = Color(Palette.teal)
    static let deepTeal = Color(Palette.deepTeal)
    static let sand = Color(Palette.sand)
    static let ink = Color(Palette.ink)
    static let muted = Color(Palette.muted)
    static let card = Color(Palette.card)
    static let success = Color(Palette.success)
    static let warning = Color(Palette.warning)

    static let titleFont = Font.system(.title2, design: .rounded).weight(.bold)
    static let headlineFont = Font.system(.headline, design: .rounded)
    static let bodyFont = Font.system(.body, design: .rounded)
    static let captionFont = Font.system(.caption, design: .rounded)
}

extension Color {
    init(_ rgb: RGBColor) {
        self.init(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }

    init?(hex: String) {
        guard let rgb = RGBColor(hex: hex) else { return nil }
        self.init(rgb)
    }
}

extension Provider {
    var color: Color {
        Color(hex: avatarColor) ?? Theme.teal
    }
}

struct NetworkBadge: View {
    let status: NetworkStatus

    private var tint: Color {
        status == .inNetwork ? Theme.success : Theme.warning
    }

    var body: some View {
        Text(status == .inNetwork ? "In-network" : "Out-of-network")
            .font(Theme.captionFont.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint.opacity(Palette.tintOpacity), in: Capsule())
    }
}

struct ProviderAvatar: View {
    let color: Color
    var size: CGFloat = 52

    init(provider: Provider, size: CGFloat = 52) {
        color = provider.color
        self.size = size
    }

    init(colorHex: String, size: CGFloat = 52) {
        color = Color(hex: colorHex) ?? Theme.teal
        self.size = size
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(color.gradient)
            Image(systemName: "dog.fill")
                .font(.system(size: size * 0.42))
                .foregroundStyle(.white.opacity(0.95))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
