import Testing
@testable import TUIURL

@Suite("TUIURL Tests")
struct TUIURLTests {
    @Test func testVersion() {
        #expect(TUIURL.version == "0.1.0")
    }
}
