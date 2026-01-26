import Testing
@testable import TUIURL

@Suite("TUIURL Tests")
struct TUIURLTests {
    @Test func testVersion() {
        #expect(TUIURLModule.version == "0.1.0")
    }
}
