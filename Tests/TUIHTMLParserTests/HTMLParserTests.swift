import Testing
@testable import TUIHTMLParser

// Type alias to avoid conflict with Testing.Comment
typealias HTMLComment = TUIHTMLParser.Comment

@Suite("HTMLParser Tests")
struct HTMLParserTests {

    // MARK: - Basic Document Structure

    @Test("Parse minimal HTML document")
    func testMinimalDocument() {
        let html = "<html><head></head><body></body></html>"
        let document = HTMLParser.parse(html)

        #expect(document.documentElement != nil)
        #expect(document.documentElement?.tagName == "html")
        #expect(document.head != nil)
        #expect(document.body != nil)
    }

    @Test("Parse document with DOCTYPE")
    func testDocumentWithDoctype() {
        let html = "<!DOCTYPE html><html><head></head><body></body></html>"
        let document = HTMLParser.parse(html)

        #expect(document.doctype != nil)
        #expect(document.documentElement?.tagName == "html")
    }

    @Test("Parse document creates implied html element")
    func testImpliedHtmlElement() {
        let html = "<head></head><body></body>"
        let document = HTMLParser.parse(html)

        #expect(document.documentElement != nil)
        #expect(document.documentElement?.tagName == "html")
    }

    @Test("Parse document creates implied body")
    func testImpliedBody() {
        let html = "<html><div>content</div></html>"
        let document = HTMLParser.parse(html)

        #expect(document.body != nil)
    }

    // MARK: - Nested Elements

    @Test("Parse nested elements")
    func testNestedElements() {
        let html = "<div><p><span>text</span></p></div>"
        let document = HTMLParser.parse(html)

        let div = document.body?.childNodes.first { ($0 as? Element)?.tagName == "div" } as? Element
        #expect(div != nil)

        let p = div?.childNodes.first { ($0 as? Element)?.tagName == "p" } as? Element
        #expect(p != nil)

        let span = p?.childNodes.first { ($0 as? Element)?.tagName == "span" } as? Element
        #expect(span != nil)
    }

    @Test("Parse deeply nested elements")
    func testDeeplyNestedElements() {
        let html = "<div><div><div><div><span>deep</span></div></div></div></div>"
        let document = HTMLParser.parse(html)

        #expect(document.body != nil)
        // Document should parse without crashing
    }

    // MARK: - Mixed Content

    @Test("Parse element with text content")
    func testElementWithTextContent() {
        let html = "<p>Hello World</p>"
        let document = HTMLParser.parse(html)

        let p = document.body?.childNodes.first { ($0 as? Element)?.tagName == "p" } as? Element
        #expect(p?.textContent == "Hello World")
    }

    @Test("Parse mixed text and elements")
    func testMixedTextAndElements() {
        let html = "<p>Hello <strong>World</strong>!</p>"
        let document = HTMLParser.parse(html)

        let p = document.body?.childNodes.first { ($0 as? Element)?.tagName == "p" } as? Element
        #expect(p?.textContent == "Hello World!")
        #expect(p?.childNodes.count == 3) // text, strong, text
    }

    // MARK: - Attributes

    @Test("Parse element with id attribute")
    func testElementWithId() {
        let html = "<div id=\"main\"></div>"
        let document = HTMLParser.parse(html)

        let div = document.body?.childNodes.first { ($0 as? Element)?.tagName == "div" } as? Element
        #expect(div?.id == "main")
    }

    @Test("Parse element with class attribute")
    func testElementWithClass() {
        let html = "<div class=\"container wrapper\"></div>"
        let document = HTMLParser.parse(html)

        let div = document.body?.childNodes.first { ($0 as? Element)?.tagName == "div" } as? Element
        #expect(div?.classList.contains("container") == true)
        #expect(div?.classList.contains("wrapper") == true)
    }

    @Test("Parse element with multiple attributes")
    func testElementWithMultipleAttributes() {
        let html = "<a href=\"url\" target=\"_blank\" rel=\"noopener\">link</a>"
        let document = HTMLParser.parse(html)

        let a = document.body?.childNodes.first { ($0 as? Element)?.tagName == "a" } as? Element
        #expect(a?.getAttribute("href") == "url")
        #expect(a?.getAttribute("target") == "_blank")
        #expect(a?.getAttribute("rel") == "noopener")
    }

    // MARK: - getElementById

    @Test("getElementById finds element")
    func testGetElementById() {
        let html = "<div id=\"container\"><p id=\"intro\">Hello</p></div>"
        let document = HTMLParser.parse(html)

        let intro = document.getElementById("intro")
        #expect(intro != nil)
        #expect(intro?.tagName == "p")
        #expect(intro?.textContent == "Hello")
    }

    @Test("getElementById returns nil for missing id")
    func testGetElementByIdNotFound() {
        let html = "<div><p>Hello</p></div>"
        let document = HTMLParser.parse(html)

        let element = document.getElementById("missing")
        #expect(element == nil)
    }

    @Test("getElementById finds deeply nested element")
    func testGetElementByIdDeepNesting() {
        let html = "<div><div><div><span id=\"deep\">found</span></div></div></div>"
        let document = HTMLParser.parse(html)

        let deep = document.getElementById("deep")
        #expect(deep != nil)
        #expect(deep?.textContent == "found")
    }

    // MARK: - getElementsByTagName

    @Test("getElementsByTagName finds all matching elements")
    func testGetElementsByTagName() {
        let html = "<div><p>One</p><p>Two</p><span><p>Three</p></span></div>"
        let document = HTMLParser.parse(html)

        let paragraphs = document.getElementsByTagName("p")
        #expect(paragraphs.count == 3)
    }

    @Test("getElementsByTagName returns empty for no matches")
    func testGetElementsByTagNameNoMatches() {
        let html = "<div><span>text</span></div>"
        let document = HTMLParser.parse(html)

        let paragraphs = document.getElementsByTagName("p")
        #expect(paragraphs.isEmpty)
    }

    @Test("getElementsByTagName is case insensitive")
    func testGetElementsByTagNameCaseInsensitive() {
        let html = "<DIV><P>One</P></DIV>"
        let document = HTMLParser.parse(html)

        let divs = document.getElementsByTagName("div")
        #expect(divs.count == 1)
    }

    // MARK: - getElementsByClassName

    @Test("getElementsByClassName finds elements")
    func testGetElementsByClassName() {
        let html = "<div class=\"item\"></div><p class=\"item\"></p><span></span>"
        let document = HTMLParser.parse(html)

        let items = document.getElementsByClassName("item")
        #expect(items.count == 2)
    }

    @Test("getElementsByClassName matches partial class list")
    func testGetElementsByClassNamePartialMatch() {
        let html = "<div class=\"item active primary\"></div>"
        let document = HTMLParser.parse(html)

        let items = document.getElementsByClassName("active")
        #expect(items.count == 1)
    }

    // MARK: - querySelector

    @Test("querySelector with tag selector")
    func testQuerySelectorTag() {
        let html = "<div><p>First</p><p>Second</p></div>"
        let document = HTMLParser.parse(html)

        let p = document.querySelector("p")
        #expect(p?.textContent == "First")
    }

    @Test("querySelector with id selector")
    func testQuerySelectorId() {
        let html = "<div id=\"main\"><p id=\"intro\">Hello</p></div>"
        let document = HTMLParser.parse(html)

        let element = document.querySelector("#intro")
        #expect(element?.tagName == "p")
        #expect(element?.textContent == "Hello")
    }

    @Test("querySelector with class selector")
    func testQuerySelectorClass() {
        let html = "<div class=\"container\"><p class=\"highlight\">Text</p></div>"
        let document = HTMLParser.parse(html)

        let element = document.querySelector(".highlight")
        #expect(element?.tagName == "p")
    }

    @Test("querySelector with descendant selector")
    func testQuerySelectorDescendant() {
        let html = "<div><p><span>Target</span></p></div>"
        let document = HTMLParser.parse(html)

        let span = document.querySelector("div span")
        #expect(span?.textContent == "Target")
    }

    @Test("querySelector returns nil for no match")
    func testQuerySelectorNoMatch() {
        let html = "<div><p>text</p></div>"
        let document = HTMLParser.parse(html)

        let element = document.querySelector("article")
        #expect(element == nil)
    }

    // MARK: - querySelectorAll

    @Test("querySelectorAll returns all matches")
    func testQuerySelectorAll() {
        let html = "<div><p>One</p><p>Two</p><p>Three</p></div>"
        let document = HTMLParser.parse(html)

        let elements = document.querySelectorAll("p")
        #expect(elements.count == 3)
    }

    @Test("querySelectorAll with class selector")
    func testQuerySelectorAllClass() {
        let html = "<div class=\"a\"></div><div class=\"b\"></div><div class=\"a\"></div>"
        let document = HTMLParser.parse(html)

        let elements = document.querySelectorAll(".a")
        #expect(elements.count == 2)
    }

    // MARK: - textContent

    @Test("textContent concatenates all text")
    func testTextContent() {
        let html = "<div>Hello <span>Beautiful</span> World</div>"
        let document = HTMLParser.parse(html)

        let div = document.body?.childNodes.first { ($0 as? Element)?.tagName == "div" } as? Element
        #expect(div?.textContent == "Hello Beautiful World")
    }

    @Test("textContent handles nested elements")
    func testTextContentNested() {
        let html = "<div><p>Para 1</p><p>Para 2</p></div>"
        let document = HTMLParser.parse(html)

        let div = document.body?.childNodes.first { ($0 as? Element)?.tagName == "div" } as? Element
        #expect(div?.textContent == "Para 1Para 2")
    }

    // MARK: - innerHTML

    @Test("innerHTML returns inner HTML string")
    func testInnerHTML() {
        let html = "<div><p>Hello</p></div>"
        let document = HTMLParser.parse(html)

        let div = document.body?.childNodes.first { ($0 as? Element)?.tagName == "div" } as? Element
        let innerHTML = div?.innerHTML ?? ""
        #expect(innerHTML.contains("<p>"))
        #expect(innerHTML.contains("Hello"))
        #expect(innerHTML.contains("</p>"))
    }

    // MARK: - Node Relationships

    @Test("Parent node is set correctly")
    func testParentNode() {
        let html = "<div><p>text</p></div>"
        let document = HTMLParser.parse(html)

        let div = document.body?.childNodes.first { ($0 as? Element)?.tagName == "div" } as? Element
        let p = div?.childNodes.first { ($0 as? Element)?.tagName == "p" } as? Element

        #expect(p?.parentNode === div)
    }

    @Test("Child nodes include text nodes")
    func testChildNodesIncludeText() {
        let html = "<p>Hello</p>"
        let document = HTMLParser.parse(html)

        let p = document.body?.childNodes.first { ($0 as? Element)?.tagName == "p" } as? Element
        let textNode = p?.childNodes.first as? Text

        #expect(textNode != nil)
        #expect(textNode?.data == "Hello")
    }

    // MARK: - Self-Closing Tags

    @Test("Parse void elements correctly")
    func testVoidElements() {
        let html = "<div><br><hr><img src=\"test.png\"></div>"
        let document = HTMLParser.parse(html)

        let div = document.body?.childNodes.first { ($0 as? Element)?.tagName == "div" } as? Element
        #expect(div != nil)

        let br = div?.childNodes.first { ($0 as? Element)?.tagName == "br" } as? Element
        #expect(br != nil)
    }

    // MARK: - Implicit Tag Closing

    @Test("Paragraph closes implicitly before another paragraph")
    func testImplicitParagraphClose() {
        let html = "<p>First<p>Second"
        let document = HTMLParser.parse(html)

        let paragraphs = document.getElementsByTagName("p")
        #expect(paragraphs.count == 2)
        #expect(paragraphs[0].textContent == "First")
        #expect(paragraphs[1].textContent == "Second")
    }

    @Test("List item closes implicitly before another list item")
    func testImplicitListItemClose() {
        let html = "<ul><li>One<li>Two<li>Three</ul>"
        let document = HTMLParser.parse(html)

        let items = document.getElementsByTagName("li")
        #expect(items.count == 3)
    }

    // MARK: - Comments

    @Test("Parse comments in document")
    func testParseComments() {
        let html = "<div><!-- comment -->text</div>"
        let document = HTMLParser.parse(html)

        let div = document.body?.childNodes.first { ($0 as? Element)?.tagName == "div" } as? Element
        let hasComment = div?.childNodes.contains { $0 is HTMLComment } ?? false
        #expect(hasComment)
    }

    // MARK: - Title

    @Test("Document title is extracted")
    func testDocumentTitle() {
        let html = "<html><head><title>My Page</title></head><body></body></html>"
        let document = HTMLParser.parse(html)

        #expect(document.title == "My Page")
    }

    // MARK: - Complex HTML

    @Test("Parse complex HTML structure")
    func testComplexHTML() {
        let html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <title>Test Page</title>
        </head>
        <body>
            <header id="main-header">
                <nav class="primary-nav">
                    <a href="/">Home</a>
                    <a href="/about">About</a>
                </nav>
            </header>
            <main>
                <article class="post">
                    <h1>Article Title</h1>
                    <p>First paragraph with <strong>bold</strong> text.</p>
                    <p>Second paragraph.</p>
                </article>
            </main>
            <footer>
                <p>&copy; 2024</p>
            </footer>
        </body>
        </html>
        """
        let document = HTMLParser.parse(html)

        #expect(document.title == "Test Page")
        #expect(document.getElementById("main-header") != nil)

        let navLinks = document.querySelectorAll("nav a")
        #expect(navLinks.count == 2)

        let article = document.querySelector(".post")
        #expect(article != nil)
    }
}
