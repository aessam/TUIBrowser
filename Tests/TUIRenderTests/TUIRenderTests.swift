import Testing
@testable import TUIRender

@Suite("TUIRender Tests")
struct TUIRenderTests {
    @Test func testVersion() {
        #expect(TUIRender.version == "0.1.0")
    }
}
