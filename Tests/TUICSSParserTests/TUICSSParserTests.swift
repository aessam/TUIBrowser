import Testing
@testable import TUICSSParser

@Suite("TUICSSParser Tests")
struct TUICSSParserTests {
    @Test func testVersion() {
        #expect(TUICSSParser.version == "0.1.0")
    }
}
