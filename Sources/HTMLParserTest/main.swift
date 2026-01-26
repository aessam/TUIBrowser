// Simple test runner for TUIHTMLParser
// This is a standalone test that doesn't require building other modules

import TUIHTMLParser
import Foundation

print("=== TUIHTMLParser Tests ===\n")

var passed = 0
var failed = 0

func test(_ name: String, _ condition: @autoclosure () -> Bool) {
    if condition() {
        print("PASS: \(name)")
        passed += 1
    } else {
        print("FAIL: \(name)")
        failed += 1
    }
}

// MARK: - HTMLTokenizer Tests

print("\n--- HTMLTokenizer Tests ---\n")

// Test simple start tag
do {
    let tokenizer = HTMLTokenizer("<div>")
    let tokens = tokenizer.tokenize()
    test("Simple start tag - token count", tokens.count == 2)
    if case let .startTag(name, attributes, selfClosing) = tokens[0] {
        test("Simple start tag - name", name == "div")
        test("Simple start tag - no attributes", attributes.isEmpty)
        test("Simple start tag - not self-closing", selfClosing == false)
    } else {
        test("Simple start tag - is start tag", false)
    }
}

// Test simple end tag
do {
    let tokenizer = HTMLTokenizer("</div>")
    let tokens = tokenizer.tokenize()
    test("Simple end tag - token count", tokens.count == 2)
    if case let .endTag(name) = tokens[0] {
        test("Simple end tag - name", name == "div")
    } else {
        test("Simple end tag - is end tag", false)
    }
}

// Test tag with attributes
do {
    let tokenizer = HTMLTokenizer("<a href=\"https://example.com\">")
    let tokens = tokenizer.tokenize()
    if case let .startTag(name, attributes, _) = tokens[0] {
        test("Attribute tag - name", name == "a")
        test("Attribute tag - has attribute", attributes.count == 1)
        test("Attribute tag - attribute name", attributes[0].name == "href")
        test("Attribute tag - attribute value", attributes[0].value == "https://example.com")
    } else {
        test("Attribute tag - is start tag", false)
    }
}

// Test self-closing tag
do {
    let tokenizer = HTMLTokenizer("<br/>")
    let tokens = tokenizer.tokenize()
    if case let .startTag(name, _, selfClosing) = tokens[0] {
        test("Self-closing tag - name", name == "br")
        test("Self-closing tag - is self-closing", selfClosing == true)
    } else {
        test("Self-closing tag - is start tag", false)
    }
}

// Test comment
do {
    let tokenizer = HTMLTokenizer("<!-- comment -->")
    let tokens = tokenizer.tokenize()
    if case let .comment(data) = tokens[0] {
        test("Comment - content", data == " comment ")
    } else {
        test("Comment - is comment", false)
    }
}

// Test text content
do {
    let tokenizer = HTMLTokenizer("Hello, World!")
    let tokens = tokenizer.tokenize()
    if case let .character(text) = tokens[0] {
        test("Text content", text == "Hello, World!")
    } else {
        test("Text content - is character", false)
    }
}

// Test entities
do {
    let tokenizer = HTMLTokenizer("&amp;")
    let tokens = tokenizer.tokenize()
    if case let .character(text) = tokens[0] {
        test("Entity amp", text == "&")
    } else {
        test("Entity amp - is character", false)
    }
}

do {
    let tokenizer = HTMLTokenizer("&lt;")
    let tokens = tokenizer.tokenize()
    if case let .character(text) = tokens[0] {
        test("Entity lt", text == "<")
    }
}

do {
    let tokenizer = HTMLTokenizer("&gt;")
    let tokens = tokenizer.tokenize()
    if case let .character(text) = tokens[0] {
        test("Entity gt", text == ">")
    }
}

do {
    let tokenizer = HTMLTokenizer("&#65;")
    let tokens = tokenizer.tokenize()
    if case let .character(text) = tokens[0] {
        test("Numeric entity decimal", text == "A")
    }
}

do {
    let tokenizer = HTMLTokenizer("&#x41;")
    let tokens = tokenizer.tokenize()
    if case let .character(text) = tokens[0] {
        test("Numeric entity hex", text == "A")
    }
}

// Test DOCTYPE
do {
    let tokenizer = HTMLTokenizer("<!DOCTYPE html>")
    let tokens = tokenizer.tokenize()
    if case let .doctype(name, _, _) = tokens[0] {
        test("DOCTYPE - name", name == "html")
    } else {
        test("DOCTYPE - is doctype", false)
    }
}

// MARK: - HTMLParser Tests

print("\n--- HTMLParser Tests ---\n")

// Test basic document
do {
    let html = "<html><head></head><body></body></html>"
    let document = HTMLParser.parse(html)
    test("Basic doc - has html element", document.documentElement != nil)
    test("Basic doc - html tagName", document.documentElement?.tagName == "html")
    test("Basic doc - has head", document.head != nil)
    test("Basic doc - has body", document.body != nil)
}

// Test document with DOCTYPE
do {
    let html = "<!DOCTYPE html><html><head></head><body></body></html>"
    let document = HTMLParser.parse(html)
    test("DOCTYPE doc - has doctype", document.doctype != nil)
}

// Test nested elements
do {
    let html = "<div><p><span>text</span></p></div>"
    let document = HTMLParser.parse(html)
    let body = document.body
    let div = body?.childNodes.first { ($0 as? Element)?.tagName == "div" } as? Element
    test("Nested - has div", div != nil)
    let p = div?.childNodes.first { ($0 as? Element)?.tagName == "p" } as? Element
    test("Nested - has p", p != nil)
    let span = p?.childNodes.first { ($0 as? Element)?.tagName == "span" } as? Element
    test("Nested - has span", span != nil)
}

// Test textContent
do {
    let html = "<p>Hello World</p>"
    let document = HTMLParser.parse(html)
    let p = document.body?.childNodes.first { ($0 as? Element)?.tagName == "p" } as? Element
    test("textContent", p?.textContent == "Hello World")
}

// Test getElementById
do {
    let html = "<div id=\"container\"><p id=\"intro\">Hello</p></div>"
    let document = HTMLParser.parse(html)
    let intro = document.getElementById("intro")
    test("getElementById - finds element", intro != nil)
    test("getElementById - correct tag", intro?.tagName == "p")
    test("getElementById - correct content", intro?.textContent == "Hello")
}

// Test getElementsByTagName
do {
    let html = "<div><p>One</p><p>Two</p><span><p>Three</p></span></div>"
    let document = HTMLParser.parse(html)
    let paragraphs = document.getElementsByTagName("p")
    test("getElementsByTagName - count", paragraphs.count == 3)
}

// Test getElementsByClassName
do {
    let html = "<div class=\"item\"></div><p class=\"item\"></p><span></span>"
    let document = HTMLParser.parse(html)
    let items = document.getElementsByClassName("item")
    test("getElementsByClassName - count", items.count == 2)
}

// Test querySelector with tag
do {
    let html = "<div><p>First</p><p>Second</p></div>"
    let document = HTMLParser.parse(html)
    let p = document.querySelector("p")
    test("querySelector tag - finds first", p?.textContent == "First")
}

// Test querySelector with id
do {
    let html = "<div id=\"main\"><p id=\"intro\">Hello</p></div>"
    let document = HTMLParser.parse(html)
    let element = document.querySelector("#intro")
    test("querySelector id - finds element", element?.tagName == "p")
}

// Test querySelector with class
do {
    let html = "<div class=\"container\"><p class=\"highlight\">Text</p></div>"
    let document = HTMLParser.parse(html)
    let element = document.querySelector(".highlight")
    test("querySelector class - finds element", element?.tagName == "p")
}

// Test querySelectorAll
do {
    let html = "<div><p>One</p><p>Two</p><p>Three</p></div>"
    let document = HTMLParser.parse(html)
    let elements = document.querySelectorAll("p")
    test("querySelectorAll - count", elements.count == 3)
}

// Test element with attributes
do {
    let html = "<div id=\"main\" class=\"container wrapper\"></div>"
    let document = HTMLParser.parse(html)
    let div = document.body?.childNodes.first { ($0 as? Element)?.tagName == "div" } as? Element
    test("Attributes - id", div?.id == "main")
    test("Attributes - classList has container", div?.classList.contains("container") == true)
    test("Attributes - classList has wrapper", div?.classList.contains("wrapper") == true)
}

// Test title
do {
    let html = "<html><head><title>My Page</title></head><body></body></html>"
    let document = HTMLParser.parse(html)
    test("Document title", document.title == "My Page")
}

// Test implicit tag closing (paragraphs)
do {
    let html = "<p>First<p>Second"
    let document = HTMLParser.parse(html)
    let paragraphs = document.getElementsByTagName("p")
    test("Implicit close - count", paragraphs.count == 2)
}

// Test void elements
do {
    let html = "<div><br><hr><img src=\"test.png\"></div>"
    let document = HTMLParser.parse(html)
    let div = document.body?.childNodes.first { ($0 as? Element)?.tagName == "div" } as? Element
    test("Void elements - div exists", div != nil)
    let br = div?.childNodes.first { ($0 as? Element)?.tagName == "br" } as? Element
    test("Void elements - br exists", br != nil)
}

// Test mixed content
do {
    let html = "<p>Hello <strong>World</strong>!</p>"
    let document = HTMLParser.parse(html)
    let p = document.body?.childNodes.first { ($0 as? Element)?.tagName == "p" } as? Element
    test("Mixed content - textContent", p?.textContent == "Hello World!")
}

// Test innerHTML
do {
    let html = "<div><p>Hello</p></div>"
    let document = HTMLParser.parse(html)
    let div = document.body?.childNodes.first { ($0 as? Element)?.tagName == "div" } as? Element
    let innerHTML = div?.innerHTML ?? ""
    test("innerHTML contains p tag", innerHTML.contains("<p>"))
    test("innerHTML contains text", innerHTML.contains("Hello"))
}

// Test complex document
do {
    let html = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
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
                <p>First paragraph.</p>
            </article>
        </main>
    </body>
    </html>
    """
    let document = HTMLParser.parse(html)
    test("Complex - title", document.title == "Test Page")
    test("Complex - header exists", document.getElementById("main-header") != nil)
    let navLinks = document.querySelectorAll("nav a")
    test("Complex - nav links count", navLinks.count == 2)
    let article = document.querySelector(".post")
    test("Complex - article exists", article != nil)
}

// Print summary
print("\n=== Test Summary ===")
print("Passed: \(passed)")
print("Failed: \(failed)")
print("Total:  \(passed + failed)")

if failed > 0 {
    print("\nSome tests failed!")
    Foundation.exit(1)
} else {
    print("\nAll tests passed!")
}
