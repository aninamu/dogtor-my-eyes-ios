import SwiftUI

enum Theme {
    static let teal = Color(red: 0.18, green: 0.45, blue: 0.48)
    static let deepTeal = Color(red: 0.10, green: 0.28, blue: 0.32)
    static let sand = Color(red: 0.96, green: 0.94, blue: 0.90)
    static let ink = Color(red: 0.14, green: 0.16, blue: 0.18)
    static let muted = Color(red: 0.42, green: 0.45, blue: 0.48)
    static let card = Color.white
    static let success = Color(red: 0.20, green: 0.55, blue: 0.38)
    static let warning = Color(red: 0.75, green: 0.45, blue: 0.18)

    static let titleFont = Font.system(.title2, design: .rounded).weight(.bold)
    static let headlineFont = Font.system(.headline, design: .rounded)
    static let bodyFont = Font.system(.body, design: .rounded)
    static let captionFont = Font.system(.caption, design: .rounded)
}

struct NetworkBadge: View {
    let inNetwork: Bool

    var body: some View {
        Text(inNetwork ? "In-network" : "Out-of-network")
            .font(Theme.captionFont.weight(.semibold))
            .foregroundStyle(inNetwork ? Theme.success : Theme.warning)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                (inNetwork ? Theme.success : Theme.warning).opacity(0.14),
                in: Capsule()
            )
    }
}

struct ProviderAvatar: View {
    let provider: Provider
    var size: CGFloat = 52

    var body: some View {
        ZStack {
            Circle()
                .fill(provider.color.gradient)
            Image(systemName: "dog.fill")
                .font(.system(size: size * 0.42))
                .foregroundStyle(.white.opacity(0.95))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
