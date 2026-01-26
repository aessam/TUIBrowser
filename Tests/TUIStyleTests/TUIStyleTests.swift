import Testing
@testable import TUIStyle

@Suite("TUIStyle Tests")
struct TUIStyleTests {
    @Test func testVersion() {
        #expect(TUIStyle.version == "0.1.0")
    }
}
