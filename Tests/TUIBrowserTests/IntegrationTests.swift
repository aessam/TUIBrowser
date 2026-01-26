import Testing
import Foundation
@testable import TUIBrowser
@testable import TUIHTMLParser
@testable import TUIStyle
@testable import TUILayout
@testable import TUICSSParser

@Suite("Integration Tests")
struct IntegrationTests {

    @Test("Parse HTML and resolve styles")
    func testParseAndResolveStyles() {
        print("Starting HTML parse...")
        let html = """
        <!DOCTYPE html>
        <html>
        <head><title>Test</title></head>
        <body><p>Hello World</p></body>
        </html>
        """

        let document = HTMLParser.parse(html)
        print("HTML parsed. Title: \(document.title)")

        #expect(document.title == "Test")
        #expect(document.body != nil)

        print("Starting style resolution...")
        let styles = StyleResolver.resolve(
            document: document,
            stylesheets: []
        )
        print("Styles resolved. Count: \(styles.count)")

        #expect(styles.count > 0)
    }

    @Test("Parse HTML, resolve styles, and layout")
    func testFullPipeline() {
        print("Starting full pipeline test...")

        let html = """
        <!DOCTYPE html>
        <html>
        <head><title>Test</title></head>
        <body><p>Hello World</p></body>
        </html>
        """

        print("1. Parsing HTML...")
        let document = HTMLParser.parse(html)
        print("   Done. Title: \(document.title)")

        print("2. Resolving styles...")
        let styles = StyleResolver.resolve(
            document: document,
            stylesheets: []
        )
        print("   Done. Style count: \(styles.count)")

        print("3. Running layout...")
        let layout = LayoutEngine.layout(
            document: document,
            styles: styles,
            width: 80
        )
        print("   Done. Layout height: \(layout.dimensions.content.height)")

        #expect(layout.dimensions.content.width == 80)
    }

    @Test("Parse example.com-like HTML")
    func testExampleComHTML() {
        print("Testing example.com-like HTML...")

        // Simplified version of what example.com returns
        let html = """
        <!doctype html>
        <html>
        <head>
            <title>Example Domain</title>
            <meta charset="utf-8" />
            <style type="text/css">
            body { background-color: #f0f0f2; }
            div { width: 600px; margin: 5em auto; }
            </style>
        </head>
        <body>
        <div>
            <h1>Example Domain</h1>
            <p>This domain is for use in illustrative examples in documents.</p>
            <p><a href="https://www.iana.org/domains/example">More information...</a></p>
        </div>
        </body>
        </html>
        """

        print("1. Parsing HTML...")
        let document = HTMLParser.parse(html)
        print("   Title: \(document.title)")
        #expect(document.title == "Example Domain")

        print("2. Parsing stylesheets...")
        var stylesheets: [Stylesheet] = []
        let styleElements = document.getElementsByTagName("style")
        print("   Found \(styleElements.count) style element(s)")
        for styleElement in styleElements {
            let cssText = styleElement.textContent
            print("   CSS: \(cssText.prefix(50))...")
            let stylesheet = CSSParser.parseStylesheet(cssText)
            stylesheets.append(stylesheet)
        }
        print("   Parsed \(stylesheets.count) stylesheet(s)")

        print("3. Resolving styles...")
        let styles = StyleResolver.resolve(
            document: document,
            stylesheets: stylesheets
        )
        print("   Style count: \(styles.count)")

        print("4. Running layout...")
        let layout = LayoutEngine.layout(
            document: document,
            styles: styles,
            width: 80
        )
        print("   Layout height: \(layout.dimensions.content.height)")

        #expect(layout.dimensions.content.height > 0)
        print("Done!")
    }
}
