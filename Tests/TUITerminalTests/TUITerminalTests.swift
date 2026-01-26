import Testing
@testable import TUITerminal

@Suite("TUITerminal Tests")
struct TUITerminalTests {
    @Test func testVersion() {
        #expect(TUITerminal.version == "0.1.0")
    }
}
