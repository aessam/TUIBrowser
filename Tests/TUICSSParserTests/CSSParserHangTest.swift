import Testing
@testable import TUICSSParser

@Suite("CSS Parser Hang Tests")
struct CSSParserHangTests {

    @Test("Parse CSS from example.com")
    func testExampleComCSS() {
        // This is the CSS from example.com that causes a hang
        let css = """
        body{background:#eee;width:60vw;margin:15vh auto;font-family:system-ui,sans-serif}h1{font-size:1.5em}
        """

        print("Testing CSS: \(css)")
        print("Parsing...")
        let stylesheet = CSSParser.parseStylesheet(css)
        print("Done! Rules: \(stylesheet.rules.count)")

        #expect(stylesheet.rules.count > 0)
    }

    @Test("Parse CSS with vw unit")
    func testVWUnit() {
        let css = "body { width: 60vw; }"
        print("Testing: \(css)")
        let stylesheet = CSSParser.parseStylesheet(css)
        print("Rules: \(stylesheet.rules.count)")
        #expect(stylesheet.rules.count == 1)
    }

    @Test("Parse CSS with vh unit")
    func testVHUnit() {
        let css = "body { margin: 15vh; }"
        print("Testing: \(css)")
        let stylesheet = CSSParser.parseStylesheet(css)
        print("Rules: \(stylesheet.rules.count)")
        #expect(stylesheet.rules.count == 1)
    }

    @Test("Parse CSS with font-family")
    func testFontFamily() {
        let css = "body { font-family: system-ui, sans-serif; }"
        print("Testing: \(css)")
        let stylesheet = CSSParser.parseStylesheet(css)
        print("Rules: \(stylesheet.rules.count)")
        #expect(stylesheet.rules.count == 1)
    }

    @Test("Parse CSS with auto keyword")
    func testAutoKeyword() {
        let css = "body { margin: 15vh auto; }"
        print("Testing: \(css)")
        let stylesheet = CSSParser.parseStylesheet(css)
        print("Rules: \(stylesheet.rules.count)")
        #expect(stylesheet.rules.count == 1)
    }
}
