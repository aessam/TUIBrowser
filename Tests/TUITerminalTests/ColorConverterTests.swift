import Testing
@testable import TUITerminal
import TUICore

@Suite("ColorConverter Tests")
struct ColorConverterTests {

    // MARK: - RGB to ANSI 16 Color

    @Test func testBlackToANSI16() {
        let color = Color(r: 0, g: 0, b: 0)
        #expect(ColorConverter.toANSI16(color) == .black)
    }

    @Test func testWhiteToANSI16() {
        let color = Color(r: 255, g: 255, b: 255)
        #expect(ColorConverter.toANSI16(color) == .brightWhite)
    }

    @Test func testPureRedToANSI16() {
        let color = Color(r: 255, g: 0, b: 0)
        #expect(ColorConverter.toANSI16(color) == .brightRed)
    }

    @Test func testDarkRedToANSI16() {
        let color = Color(r: 128, g: 0, b: 0)
        #expect(ColorConverter.toANSI16(color) == .red)
    }

    @Test func testPureGreenToANSI16() {
        let color = Color(r: 0, g: 255, b: 0)
        #expect(ColorConverter.toANSI16(color) == .brightGreen)
    }

    @Test func testDarkGreenToANSI16() {
        let color = Color(r: 0, g: 128, b: 0)
        #expect(ColorConverter.toANSI16(color) == .green)
    }

    @Test func testPureBlueToANSI16() {
        let color = Color(r: 0, g: 0, b: 255)
        #expect(ColorConverter.toANSI16(color) == .brightBlue)
    }

    @Test func testDarkBlueToANSI16() {
        let color = Color(r: 0, g: 0, b: 128)
        #expect(ColorConverter.toANSI16(color) == .blue)
    }

    @Test func testYellowToANSI16() {
        let color = Color(r: 255, g: 255, b: 0)
        #expect(ColorConverter.toANSI16(color) == .brightYellow)
    }

    @Test func testCyanToANSI16() {
        let color = Color(r: 0, g: 255, b: 255)
        #expect(ColorConverter.toANSI16(color) == .brightCyan)
    }

    @Test func testMagentaToANSI16() {
        let color = Color(r: 255, g: 0, b: 255)
        #expect(ColorConverter.toANSI16(color) == .brightMagenta)
    }

    @Test func testGrayToANSI16() {
        // Mid-gray should map to bright black (gray)
        let color = Color(r: 128, g: 128, b: 128)
        #expect(ColorConverter.toANSI16(color) == .brightBlack)
    }

    @Test func testDarkGrayToANSI16() {
        let color = Color(r: 64, g: 64, b: 64)
        #expect(ColorConverter.toANSI16(color) == .brightBlack)
    }

    @Test func testLightGrayToANSI16() {
        let color = Color(r: 192, g: 192, b: 192)
        #expect(ColorConverter.toANSI16(color) == .white)
    }

    // MARK: - RGB to ANSI 256 Color

    @Test func testBlackToANSI256() {
        let color = Color(r: 0, g: 0, b: 0)
        #expect(ColorConverter.toANSI256(color) == 16) // First extended color (black)
    }

    @Test func testWhiteToANSI256() {
        let color = Color(r: 255, g: 255, b: 255)
        #expect(ColorConverter.toANSI256(color) == 231) // White in 216 color cube
    }

    @Test func testPureRedToANSI256() {
        let color = Color(r: 255, g: 0, b: 0)
        #expect(ColorConverter.toANSI256(color) == 196) // Pure red in color cube
    }

    @Test func testPureGreenToANSI256() {
        let color = Color(r: 0, g: 255, b: 0)
        #expect(ColorConverter.toANSI256(color) == 46) // Pure green in color cube
    }

    @Test func testPureBlueToANSI256() {
        let color = Color(r: 0, g: 0, b: 255)
        #expect(ColorConverter.toANSI256(color) == 21) // Pure blue in color cube
    }

    @Test func testGrayscaleToANSI256() {
        // Test grayscale values (232-255 range)
        let darkGray = Color(r: 28, g: 28, b: 28)
        let result = ColorConverter.toANSI256(darkGray)
        // Should be in grayscale range 232-255 or very close color
        #expect(result >= 232 || result == 16) // Either grayscale or black
    }

    @Test func testMidGrayToANSI256() {
        let midGray = Color(r: 128, g: 128, b: 128)
        let result = ColorConverter.toANSI256(midGray)
        // Should be in the grayscale range
        #expect(result >= 232 || (result >= 16 && result <= 231))
    }

    // MARK: - Color Support Detection

    @Test func testColorSupportEnumValues() {
        // Just verify the enum cases exist and are distinct
        let none = ColorSupport.none
        let ansi16 = ColorSupport.ansi16
        let ansi256 = ColorSupport.ansi256
        let trueColor = ColorSupport.trueColor

        #expect(none != ansi16)
        #expect(ansi16 != ansi256)
        #expect(ansi256 != trueColor)
    }

    @Test func testDetectColorSupportReturnsValidValue() {
        let support = ColorConverter.detectColorSupport()
        // Should return one of the valid enum values
        switch support {
        case .none, .ansi16, .ansi256, .trueColor:
            // Valid
            break
        }
    }

    // MARK: - Edge Cases

    @Test func testNearBlackToANSI16() {
        let nearBlack = Color(r: 10, g: 10, b: 10)
        #expect(ColorConverter.toANSI16(nearBlack) == .black)
    }

    @Test func testNearWhiteToANSI16() {
        let nearWhite = Color(r: 245, g: 245, b: 245)
        #expect(ColorConverter.toANSI16(nearWhite) == .brightWhite)
    }

    @Test func testOrangeToANSI16() {
        // Orange should map to yellow or red
        let orange = Color(r: 255, g: 165, b: 0)
        let result = ColorConverter.toANSI16(orange)
        #expect(result == .brightYellow || result == .yellow || result == .brightRed)
    }
}
