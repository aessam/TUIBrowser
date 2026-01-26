import Testing
@testable import TUIHTMLParser

@Suite("HTMLTokenizer Tests")
struct HTMLTokenizerTests {

    // MARK: - Simple Tags

    @Test("Tokenize simple start tag")
    func testSimpleStartTag() {
        let tokenizer = HTMLTokenizer("<div>")
        let tokens = tokenizer.tokenize()

        #expect(tokens.count == 2)
        if case let .startTag(name, attributes, selfClosing) = tokens[0] {
            #expect(name == "div")
            #expect(attributes.isEmpty)
            #expect(selfClosing == false)
        } else {
            Issue.record("Expected start tag")
        }
        #expect(tokens[1] == .eof)
    }

    @Test("Tokenize simple end tag")
    func testSimpleEndTag() {
        let tokenizer = HTMLTokenizer("</div>")
        let tokens = tokenizer.tokenize()

        #expect(tokens.count == 2)
        if case let .endTag(name) = tokens[0] {
            #expect(name == "div")
        } else {
            Issue.record("Expected end tag")
        }
        #expect(tokens[1] == .eof)
    }

    @Test("Tokenize uppercase tags normalized to lowercase")
    func testTagNameCaseNormalization() {
        let tokenizer = HTMLTokenizer("<DIV></DIV>")
        let tokens = tokenizer.tokenize()

        #expect(tokens.count == 3)
        if case let .startTag(name, _, _) = tokens[0] {
            #expect(name == "div")
        }
        if case let .endTag(name) = tokens[1] {
            #expect(name == "div")
        }
    }

    // MARK: - Attributes

    @Test("Tokenize tag with single attribute")
    func testSingleAttribute() {
        let tokenizer = HTMLTokenizer("<a href=\"https://example.com\">")
        let tokens = tokenizer.tokenize()

        #expect(tokens.count == 2)
        if case let .startTag(name, attributes, _) = tokens[0] {
            #expect(name == "a")
            #expect(attributes.count == 1)
            #expect(attributes[0].name == "href")
            #expect(attributes[0].value == "https://example.com")
        } else {
            Issue.record("Expected start tag with attribute")
        }
    }

    @Test("Tokenize tag with multiple attributes")
    func testMultipleAttributes() {
        let tokenizer = HTMLTokenizer("<input type=\"text\" name=\"username\" value=\"\">")
        let tokens = tokenizer.tokenize()

        #expect(tokens.count == 2)
        if case let .startTag(name, attributes, _) = tokens[0] {
            #expect(name == "input")
            #expect(attributes.count == 3)
            #expect(attributes[0].name == "type")
            #expect(attributes[0].value == "text")
            #expect(attributes[1].name == "name")
            #expect(attributes[1].value == "username")
            #expect(attributes[2].name == "value")
            #expect(attributes[2].value == "")
        } else {
            Issue.record("Expected start tag with multiple attributes")
        }
    }

    @Test("Tokenize tag with single-quoted attribute")
    func testSingleQuotedAttribute() {
        let tokenizer = HTMLTokenizer("<a href='https://example.com'>")
        let tokens = tokenizer.tokenize()

        if case let .startTag(_, attributes, _) = tokens[0] {
            #expect(attributes[0].value == "https://example.com")
        } else {
            Issue.record("Expected start tag")
        }
    }

    @Test("Tokenize tag with unquoted attribute")
    func testUnquotedAttribute() {
        let tokenizer = HTMLTokenizer("<div class=container>")
        let tokens = tokenizer.tokenize()

        if case let .startTag(_, attributes, _) = tokens[0] {
            #expect(attributes[0].name == "class")
            #expect(attributes[0].value == "container")
        } else {
            Issue.record("Expected start tag")
        }
    }

    @Test("Tokenize tag with boolean attribute")
    func testBooleanAttribute() {
        let tokenizer = HTMLTokenizer("<input disabled>")
        let tokens = tokenizer.tokenize()

        if case let .startTag(_, attributes, _) = tokens[0] {
            #expect(attributes[0].name == "disabled")
            #expect(attributes[0].value == "")
        } else {
            Issue.record("Expected start tag")
        }
    }

    // MARK: - Self-Closing Tags

    @Test("Tokenize self-closing tag with slash")
    func testSelfClosingTag() {
        let tokenizer = HTMLTokenizer("<br/>")
        let tokens = tokenizer.tokenize()

        #expect(tokens.count == 2)
        if case let .startTag(name, _, selfClosing) = tokens[0] {
            #expect(name == "br")
            #expect(selfClosing == true)
        } else {
            Issue.record("Expected self-closing tag")
        }
    }

    @Test("Tokenize self-closing tag with space before slash")
    func testSelfClosingTagWithSpace() {
        let tokenizer = HTMLTokenizer("<br />")
        let tokens = tokenizer.tokenize()

        if case let .startTag(name, _, selfClosing) = tokens[0] {
            #expect(name == "br")
            #expect(selfClosing == true)
        } else {
            Issue.record("Expected self-closing tag")
        }
    }

    @Test("Tokenize self-closing tag with attributes")
    func testSelfClosingTagWithAttributes() {
        let tokenizer = HTMLTokenizer("<img src=\"image.png\" alt=\"test\"/>")
        let tokens = tokenizer.tokenize()

        if case let .startTag(name, attributes, selfClosing) = tokens[0] {
            #expect(name == "img")
            #expect(selfClosing == true)
            #expect(attributes.count == 2)
        } else {
            Issue.record("Expected self-closing tag")
        }
    }

    // MARK: - Comments

    @Test("Tokenize comment")
    func testComment() {
        let tokenizer = HTMLTokenizer("<!-- this is a comment -->")
        let tokens = tokenizer.tokenize()

        #expect(tokens.count == 2)
        if case let .comment(data) = tokens[0] {
            #expect(data == " this is a comment ")
        } else {
            Issue.record("Expected comment token")
        }
    }

    @Test("Tokenize empty comment")
    func testEmptyComment() {
        let tokenizer = HTMLTokenizer("<!---->")
        let tokens = tokenizer.tokenize()

        if case let .comment(data) = tokens[0] {
            #expect(data == "")
        } else {
            Issue.record("Expected empty comment")
        }
    }

    @Test("Tokenize comment with dashes")
    func testCommentWithDashes() {
        let tokenizer = HTMLTokenizer("<!-- a--b -->")
        let tokens = tokenizer.tokenize()

        if case let .comment(data) = tokens[0] {
            #expect(data == " a--b ")
        } else {
            Issue.record("Expected comment")
        }
    }

    // MARK: - Text Content

    @Test("Tokenize text content")
    func testTextContent() {
        let tokenizer = HTMLTokenizer("Hello, World!")
        let tokens = tokenizer.tokenize()

        #expect(tokens.count == 2)
        if case let .character(char) = tokens[0] {
            #expect(char == "Hello, World!")
        } else {
            Issue.record("Expected character token")
        }
    }

    @Test("Tokenize mixed content")
    func testMixedContent() {
        let tokenizer = HTMLTokenizer("<p>Hello</p>")
        let tokens = tokenizer.tokenize()

        #expect(tokens.count == 4)
        if case let .startTag(name, _, _) = tokens[0] {
            #expect(name == "p")
        }
        if case let .character(text) = tokens[1] {
            #expect(text == "Hello")
        }
        if case let .endTag(name) = tokens[2] {
            #expect(name == "p")
        }
        #expect(tokens[3] == .eof)
    }

    @Test("Tokenize whitespace")
    func testWhitespace() {
        let tokenizer = HTMLTokenizer("   ")
        let tokens = tokenizer.tokenize()

        #expect(tokens.count == 2)
        if case let .character(text) = tokens[0] {
            #expect(text == "   ")
        }
    }

    // MARK: - Entity References

    @Test("Tokenize amp entity")
    func testAmpEntity() {
        let tokenizer = HTMLTokenizer("&amp;")
        let tokens = tokenizer.tokenize()

        if case let .character(text) = tokens[0] {
            #expect(text == "&")
        } else {
            Issue.record("Expected decoded entity")
        }
    }

    @Test("Tokenize lt entity")
    func testLtEntity() {
        let tokenizer = HTMLTokenizer("&lt;")
        let tokens = tokenizer.tokenize()

        if case let .character(text) = tokens[0] {
            #expect(text == "<")
        }
    }

    @Test("Tokenize gt entity")
    func testGtEntity() {
        let tokenizer = HTMLTokenizer("&gt;")
        let tokens = tokenizer.tokenize()

        if case let .character(text) = tokens[0] {
            #expect(text == ">")
        }
    }

    @Test("Tokenize quot entity")
    func testQuotEntity() {
        let tokenizer = HTMLTokenizer("&quot;")
        let tokens = tokenizer.tokenize()

        if case let .character(text) = tokens[0] {
            #expect(text == "\"")
        }
    }

    @Test("Tokenize apos entity")
    func testAposEntity() {
        let tokenizer = HTMLTokenizer("&apos;")
        let tokens = tokenizer.tokenize()

        if case let .character(text) = tokens[0] {
            #expect(text == "'")
        }
    }

    @Test("Tokenize nbsp entity")
    func testNbspEntity() {
        let tokenizer = HTMLTokenizer("&nbsp;")
        let tokens = tokenizer.tokenize()

        if case let .character(text) = tokens[0] {
            #expect(text == "\u{00A0}")
        }
    }

    @Test("Tokenize numeric entity decimal")
    func testNumericEntityDecimal() {
        let tokenizer = HTMLTokenizer("&#65;") // 'A'
        let tokens = tokenizer.tokenize()

        if case let .character(text) = tokens[0] {
            #expect(text == "A")
        }
    }

    @Test("Tokenize numeric entity hex")
    func testNumericEntityHex() {
        let tokenizer = HTMLTokenizer("&#x41;") // 'A'
        let tokens = tokenizer.tokenize()

        if case let .character(text) = tokens[0] {
            #expect(text == "A")
        }
    }

    @Test("Tokenize entities in text")
    func testEntitiesInText() {
        let tokenizer = HTMLTokenizer("Tom &amp; Jerry")
        let tokens = tokenizer.tokenize()

        if case let .character(text) = tokens[0] {
            #expect(text == "Tom & Jerry")
        }
    }

    @Test("Tokenize entity in attribute")
    func testEntityInAttribute() {
        let tokenizer = HTMLTokenizer("<a href=\"?a=1&amp;b=2\">")
        let tokens = tokenizer.tokenize()

        if case let .startTag(_, attributes, _) = tokens[0] {
            #expect(attributes[0].value == "?a=1&b=2")
        }
    }

    // MARK: - DOCTYPE

    @Test("Tokenize DOCTYPE")
    func testDoctype() {
        let tokenizer = HTMLTokenizer("<!DOCTYPE html>")
        let tokens = tokenizer.tokenize()

        #expect(tokens.count == 2)
        if case let .doctype(name, _, _) = tokens[0] {
            #expect(name == "html")
        } else {
            Issue.record("Expected DOCTYPE token")
        }
    }

    @Test("Tokenize DOCTYPE case insensitive")
    func testDoctypeCaseInsensitive() {
        let tokenizer = HTMLTokenizer("<!doctype html>")
        let tokens = tokenizer.tokenize()

        if case let .doctype(name, _, _) = tokens[0] {
            #expect(name == "html")
        }
    }

    // MARK: - Complex Documents

    @Test("Tokenize complete HTML document")
    func testCompleteDocument() {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>Test</title>
        </head>
        <body>
            <h1>Hello</h1>
            <p>World</p>
        </body>
        </html>
        """
        let tokenizer = HTMLTokenizer(html)
        let tokens = tokenizer.tokenize()

        // Should have DOCTYPE, tags, text content, whitespace, and EOF
        #expect(tokens.count > 10)
        if case .doctype = tokens[0] {} else {
            Issue.record("Expected DOCTYPE first")
        }
        #expect(tokens.last == .eof)
    }

    // MARK: - Malformed HTML Recovery

    @Test("Handle unclosed tag gracefully")
    func testUnclosedTag() {
        let tokenizer = HTMLTokenizer("<div")
        let tokens = tokenizer.tokenize()

        // Should not crash, might emit partial tag or just EOF
        #expect(tokens.contains(.eof))
    }

    @Test("Handle missing closing angle bracket")
    func testMissingClosingBracket() {
        let tokenizer = HTMLTokenizer("<div class=\"test\"")
        let tokens = tokenizer.tokenize()

        #expect(tokens.contains(.eof))
    }

    @Test("Handle unexpected characters in tag name")
    func testUnexpectedCharactersInTagName() {
        let tokenizer = HTMLTokenizer("<div!>")
        let tokens = tokenizer.tokenize()

        #expect(tokens.contains(.eof))
    }
}
