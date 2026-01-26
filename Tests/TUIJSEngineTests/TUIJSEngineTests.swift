import Testing
@testable import TUIJSEngine

@Suite("TUIJSEngine Tests")
struct TUIJSEngineTests {
    @Test func testVersion() {
        #expect(TUIJSEngine.version == "0.1.0")
    }
}
