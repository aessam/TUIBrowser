import Testing
@testable import TUIHTMLParser

@Suite("TUIHTMLParser Tests")
struct TUIHTMLParserTests {
    @Test func testVersion() {
        #expect(HTMLParser.version == "0.1.0")
    }
}
