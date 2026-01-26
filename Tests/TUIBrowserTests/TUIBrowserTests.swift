import Testing
@testable import TUIBrowser

@Suite("TUIBrowser Tests")
struct TUIBrowserTests {
    @Test func testVersion() {
        #expect(Browser.version == "0.1.0")
    }

    @Test func testName() {
        #expect(Browser.name == "TUIBrowser")
    }
}
