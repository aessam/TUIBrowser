import Testing
@testable import TUILayout

@Suite("TUILayout Tests")
struct TUILayoutTests {
    @Test func testVersion() {
        #expect(TUILayout.version == "0.1.0")
    }
}
