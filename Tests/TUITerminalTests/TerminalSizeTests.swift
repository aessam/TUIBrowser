import Testing
@testable import TUITerminal
import TUICore

@Suite("TerminalSize Tests")
struct TerminalSizeTests {

    @Test func testCurrentReturnsValidSize() {
        let size = TerminalSize.current()

        // Terminal size should be positive
        // In a test environment without a TTY, it might return defaults
        #expect(size.width > 0)
        #expect(size.height > 0)
    }

    @Test func testCurrentReturnsReasonableDefaults() {
        let size = TerminalSize.current()

        // Even in a non-TTY environment, should return reasonable defaults
        // Common terminal sizes are 80x24 or larger
        #expect(size.width >= 1)
        #expect(size.height >= 1)
    }
}
