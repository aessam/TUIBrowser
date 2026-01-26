import Testing
@testable import TUITerminal

@Suite("ANSICode Tests")
struct ANSICodeTests {

    // MARK: - Escape Sequences

    @Test func testEscapeConstant() {
        #expect(ANSICode.escape == "\u{1B}[")
    }

    @Test func testResetConstant() {
        #expect(ANSICode.reset == "\u{1B}[0m")
    }

    // MARK: - Cursor Movement

    @Test func testMoveTo() {
        // ANSI uses 1-based coordinates
        #expect(ANSICode.moveTo(x: 1, y: 1) == "\u{1B}[1;1H")
        #expect(ANSICode.moveTo(x: 10, y: 5) == "\u{1B}[5;10H")
        #expect(ANSICode.moveTo(x: 80, y: 24) == "\u{1B}[24;80H")
    }

    @Test func testMoveUp() {
        #expect(ANSICode.moveUp(1) == "\u{1B}[1A")
        #expect(ANSICode.moveUp(5) == "\u{1B}[5A")
    }

    @Test func testMoveDown() {
        #expect(ANSICode.moveDown(1) == "\u{1B}[1B")
        #expect(ANSICode.moveDown(10) == "\u{1B}[10B")
    }

    @Test func testMoveRight() {
        #expect(ANSICode.moveRight(1) == "\u{1B}[1C")
        #expect(ANSICode.moveRight(20) == "\u{1B}[20C")
    }

    @Test func testMoveLeft() {
        #expect(ANSICode.moveLeft(1) == "\u{1B}[1D")
        #expect(ANSICode.moveLeft(15) == "\u{1B}[15D")
    }

    @Test func testHome() {
        #expect(ANSICode.home == "\u{1B}[H")
    }

    @Test func testSaveAndRestoreCursor() {
        #expect(ANSICode.saveCursor == "\u{1B}[s")
        #expect(ANSICode.restoreCursor == "\u{1B}[u")
    }

    @Test func testHideAndShowCursor() {
        #expect(ANSICode.hideCursor == "\u{1B}[?25l")
        #expect(ANSICode.showCursor == "\u{1B}[?25h")
    }

    // MARK: - Screen Clearing

    @Test func testClearScreen() {
        #expect(ANSICode.clearScreen == "\u{1B}[2J")
    }

    @Test func testClearLine() {
        #expect(ANSICode.clearLine == "\u{1B}[2K")
    }

    @Test func testClearToEndOfLine() {
        #expect(ANSICode.clearToEndOfLine == "\u{1B}[K")
    }

    @Test func testClearToEndOfScreen() {
        #expect(ANSICode.clearToEndOfScreen == "\u{1B}[J")
    }

    // MARK: - 16 Color Mode

    @Test func testForeground16Color() {
        #expect(ANSICode.foreground(.black) == "\u{1B}[30m")
        #expect(ANSICode.foreground(.red) == "\u{1B}[31m")
        #expect(ANSICode.foreground(.green) == "\u{1B}[32m")
        #expect(ANSICode.foreground(.yellow) == "\u{1B}[33m")
        #expect(ANSICode.foreground(.blue) == "\u{1B}[34m")
        #expect(ANSICode.foreground(.magenta) == "\u{1B}[35m")
        #expect(ANSICode.foreground(.cyan) == "\u{1B}[36m")
        #expect(ANSICode.foreground(.white) == "\u{1B}[37m")
        #expect(ANSICode.foreground(.default) == "\u{1B}[39m")
    }

    @Test func testForeground16ColorBright() {
        #expect(ANSICode.foreground(.brightBlack) == "\u{1B}[90m")
        #expect(ANSICode.foreground(.brightRed) == "\u{1B}[91m")
        #expect(ANSICode.foreground(.brightGreen) == "\u{1B}[92m")
        #expect(ANSICode.foreground(.brightYellow) == "\u{1B}[93m")
        #expect(ANSICode.foreground(.brightBlue) == "\u{1B}[94m")
        #expect(ANSICode.foreground(.brightMagenta) == "\u{1B}[95m")
        #expect(ANSICode.foreground(.brightCyan) == "\u{1B}[96m")
        #expect(ANSICode.foreground(.brightWhite) == "\u{1B}[97m")
    }

    @Test func testBackground16Color() {
        #expect(ANSICode.background(.black) == "\u{1B}[40m")
        #expect(ANSICode.background(.red) == "\u{1B}[41m")
        #expect(ANSICode.background(.green) == "\u{1B}[42m")
        #expect(ANSICode.background(.yellow) == "\u{1B}[43m")
        #expect(ANSICode.background(.blue) == "\u{1B}[44m")
        #expect(ANSICode.background(.magenta) == "\u{1B}[45m")
        #expect(ANSICode.background(.cyan) == "\u{1B}[46m")
        #expect(ANSICode.background(.white) == "\u{1B}[47m")
        #expect(ANSICode.background(.default) == "\u{1B}[49m")
    }

    @Test func testBackground16ColorBright() {
        #expect(ANSICode.background(.brightBlack) == "\u{1B}[100m")
        #expect(ANSICode.background(.brightRed) == "\u{1B}[101m")
        #expect(ANSICode.background(.brightWhite) == "\u{1B}[107m")
    }

    // MARK: - 256 Color Mode

    @Test func testForeground256Color() {
        #expect(ANSICode.foreground256(0) == "\u{1B}[38;5;0m")
        #expect(ANSICode.foreground256(15) == "\u{1B}[38;5;15m")
        #expect(ANSICode.foreground256(196) == "\u{1B}[38;5;196m")
        #expect(ANSICode.foreground256(255) == "\u{1B}[38;5;255m")
    }

    @Test func testBackground256Color() {
        #expect(ANSICode.background256(0) == "\u{1B}[48;5;0m")
        #expect(ANSICode.background256(15) == "\u{1B}[48;5;15m")
        #expect(ANSICode.background256(196) == "\u{1B}[48;5;196m")
        #expect(ANSICode.background256(255) == "\u{1B}[48;5;255m")
    }

    // MARK: - True Color (24-bit)

    @Test func testForegroundRGB() {
        #expect(ANSICode.foregroundRGB(0, 0, 0) == "\u{1B}[38;2;0;0;0m")
        #expect(ANSICode.foregroundRGB(255, 255, 255) == "\u{1B}[38;2;255;255;255m")
        #expect(ANSICode.foregroundRGB(255, 0, 0) == "\u{1B}[38;2;255;0;0m")
        #expect(ANSICode.foregroundRGB(0, 128, 255) == "\u{1B}[38;2;0;128;255m")
    }

    @Test func testBackgroundRGB() {
        #expect(ANSICode.backgroundRGB(0, 0, 0) == "\u{1B}[48;2;0;0;0m")
        #expect(ANSICode.backgroundRGB(255, 255, 255) == "\u{1B}[48;2;255;255;255m")
        #expect(ANSICode.backgroundRGB(255, 0, 0) == "\u{1B}[48;2;255;0;0m")
    }

    // MARK: - Text Attributes

    @Test func testBold() {
        #expect(ANSICode.bold == "\u{1B}[1m")
    }

    @Test func testDim() {
        #expect(ANSICode.dim == "\u{1B}[2m")
    }

    @Test func testItalic() {
        #expect(ANSICode.italic == "\u{1B}[3m")
    }

    @Test func testUnderline() {
        #expect(ANSICode.underline == "\u{1B}[4m")
    }

    @Test func testInverse() {
        #expect(ANSICode.inverse == "\u{1B}[7m")
    }

    @Test func testStrikethrough() {
        #expect(ANSICode.strikethrough == "\u{1B}[9m")
    }

    // MARK: - ANSIColor Enum

    @Test func testANSIColorRawValues() {
        #expect(ANSIColor.black.rawValue == 30)
        #expect(ANSIColor.red.rawValue == 31)
        #expect(ANSIColor.green.rawValue == 32)
        #expect(ANSIColor.yellow.rawValue == 33)
        #expect(ANSIColor.blue.rawValue == 34)
        #expect(ANSIColor.magenta.rawValue == 35)
        #expect(ANSIColor.cyan.rawValue == 36)
        #expect(ANSIColor.white.rawValue == 37)
        #expect(ANSIColor.default.rawValue == 39)
        #expect(ANSIColor.brightBlack.rawValue == 90)
        #expect(ANSIColor.brightWhite.rawValue == 97)
    }
}
