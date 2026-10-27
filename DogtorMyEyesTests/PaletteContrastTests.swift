import XCTest
@testable import DogtorMyEyes

/// WCAG AA requires 4.5:1 for normal-size text. These pairs are every text/background combination the theme uses.
final class PaletteContrastTests: XCTestCase {
    private let minimum = 4.5

    private func assertReadable(_ text: RGBColor, on background: RGBColor, _ name: String, file: StaticString = #filePath, line: UInt = #line) {
        let ratio = text.contrastRatio(with: background)
        XCTAssertGreaterThanOrEqual(ratio, minimum, "\(name) is \(String(format: "%.2f", ratio)):1", file: file, line: line)
    }

    func testBodyTextColorsOnBackgrounds() {
        for (name, color) in [("ink", Palette.ink), ("muted", Palette.muted), ("deepTeal", Palette.deepTeal), ("teal", Palette.teal)] {
            assertReadable(color, on: Palette.sand, "\(name) on sand")
            assertReadable(color, on: Palette.card, "\(name) on card")
        }
    }

    func testBadgeTextOnItsOwnTint() {
        for (name, color) in [("success", Palette.success), ("warning", Palette.warning), ("teal", Palette.teal)] {
            let tint = color.composited(over: Palette.card, opacity: Palette.tintOpacity)
            assertReadable(color, on: tint, "\(name) badge")
        }
        let tealTint = Palette.teal.composited(over: Palette.card, opacity: Palette.tintOpacity)
        assertReadable(Palette.deepTeal, on: tealTint, "deepTeal chip")
    }

    func testWhiteOnSelectedChip() {
        assertReadable(Palette.card, on: Palette.teal, "white on teal")
    }

    func testWarningOnSandForInlineErrors() {
        assertReadable(Palette.warning, on: Palette.sand, "warning on sand")
    }

    func testHexParsing() {
        XCTAssertEqual(RGBColor(hex: "#FF0000"), RGBColor(red: 1, green: 0, blue: 0))
        XCTAssertNil(RGBColor(hex: "+12345"))
        XCTAssertNil(RGBColor(hex: "GGGGGG"))
        XCTAssertNil(RGBColor(hex: "FFF"))
    }
}
