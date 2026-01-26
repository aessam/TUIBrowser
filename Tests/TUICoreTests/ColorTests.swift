// TUICore Color Tests

import Testing
@testable import TUICore

@Suite("Color Tests")
struct ColorTests {
    @Test func testColorCreation() {
        let color = Color(r: 255, g: 128, b: 64, a: 200)
        #expect(color.r == 255)
        #expect(color.g == 128)
        #expect(color.b == 64)
        #expect(color.a == 200)
    }

    @Test func testColorDefaults() {
        let color = Color(r: 100, g: 100, b: 100)
        #expect(color.a == 255)  // default alpha
    }

    @Test func testPredefinedColors() {
        #expect(Color.black == Color(r: 0, g: 0, b: 0))
        #expect(Color.white == Color(r: 255, g: 255, b: 255))
        #expect(Color.red == Color(r: 255, g: 0, b: 0))
    }

    @Test func testHexParsing6Char() {
        let color = Color.fromHex("#FF8040")
        #expect(color != nil)
        #expect(color?.r == 255)
        #expect(color?.g == 128)
        #expect(color?.b == 64)
    }

    @Test func testHexParsing3Char() {
        let color = Color.fromHex("#F00")
        #expect(color != nil)
        #expect(color?.r == 255)
        #expect(color?.g == 0)
        #expect(color?.b == 0)
    }

    @Test func testHexParsingNoHash() {
        let color = Color.fromHex("00FF00")
        #expect(color != nil)
        #expect(color?.r == 0)
        #expect(color?.g == 255)
        #expect(color?.b == 0)
    }

    @Test func testHexParsing8Char() {
        let color = Color.fromHex("#FF804080")
        #expect(color != nil)
        #expect(color?.r == 255)
        #expect(color?.g == 128)
        #expect(color?.b == 64)
        #expect(color?.a == 128)
    }

    @Test func testHexParsingInvalid() {
        #expect(Color.fromHex("invalid") == nil)
        #expect(Color.fromHex("#12") == nil)
        #expect(Color.fromHex("#12345") == nil)
    }

    @Test func testColorNameParsing() {
        #expect(Color.fromName("red") == Color.red)
        #expect(Color.fromName("RED") == Color.red)  // case insensitive
        #expect(Color.fromName("blue") == Color.blue)
        #expect(Color.fromName("unknown") == nil)
    }

    @Test func testToHex() {
        let color = Color(r: 255, g: 128, b: 64)
        #expect(color.toHex() == "#FF8040")
    }

    @Test func testBlend() {
        let black = Color.black
        let white = Color.white
        let gray = black.blend(with: white, ratio: 0.5)
        #expect(gray.r == 127 || gray.r == 128)  // rounding
        #expect(gray.g == 127 || gray.g == 128)
        #expect(gray.b == 127 || gray.b == 128)
    }

    @Test func testLighten() {
        let dark = Color(r: 100, g: 100, b: 100)
        let lighter = dark.lightened(by: 0.5)
        #expect(lighter.r > dark.r)
        #expect(lighter.g > dark.g)
        #expect(lighter.b > dark.b)
    }

    @Test func testDarken() {
        let light = Color(r: 200, g: 200, b: 200)
        let darker = light.darkened(by: 0.5)
        #expect(darker.r < light.r)
        #expect(darker.g < light.g)
        #expect(darker.b < light.b)
    }
}
