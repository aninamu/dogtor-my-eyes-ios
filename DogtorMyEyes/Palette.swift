import Foundation

/// Platform-independent color values behind `Theme`, so contrast can be unit-tested without SwiftUI.
struct RGBColor: Equatable {
    let red: Double
    let green: Double
    let blue: Double

    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    init?(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") {
            cleaned.removeFirst()
        }
        guard cleaned.count == 6, cleaned.allSatisfy(\.isHexDigit), let value = UInt64(cleaned, radix: 16) else {
            return nil
        }
        red = Double((value >> 16) & 0xFF) / 255
        green = Double((value >> 8) & 0xFF) / 255
        blue = Double(value & 0xFF) / 255
    }

    /// WCAG 2.x relative luminance.
    var relativeLuminance: Double {
        func linear(_ channel: Double) -> Double {
            channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    func contrastRatio(with other: RGBColor) -> Double {
        let lighter = max(relativeLuminance, other.relativeLuminance)
        let darker = min(relativeLuminance, other.relativeLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// This color at `opacity` composited over `background`.
    func composited(over background: RGBColor, opacity: Double) -> RGBColor {
        RGBColor(
            red: red * opacity + background.red * (1 - opacity),
            green: green * opacity + background.green * (1 - opacity),
            blue: blue * opacity + background.blue * (1 - opacity)
        )
    }
}

enum Palette {
    static let teal = RGBColor(red: 0.18, green: 0.45, blue: 0.48)
    static let deepTeal = RGBColor(red: 0.10, green: 0.28, blue: 0.32)
    static let sand = RGBColor(red: 0.96, green: 0.94, blue: 0.90)
    static let ink = RGBColor(red: 0.14, green: 0.16, blue: 0.18)
    static let muted = RGBColor(red: 0.36, green: 0.38, blue: 0.41)
    static let card = RGBColor(red: 1, green: 1, blue: 1)
    static let success = RGBColor(red: 0.13, green: 0.42, blue: 0.27)
    static let warning = RGBColor(red: 0.58, green: 0.32, blue: 0.08)

    /// Opacity of the tinted capsule behind badge and chip text.
    static let tintOpacity = 0.14
}
