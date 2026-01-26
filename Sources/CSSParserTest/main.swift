// Standalone test for TUICSSParser
import TUICore
import TUICSSParser

print("=== TUICSSParser Tests ===\n")

var passed = 0
var failed = 0

func test(_ name: String, _ condition: Bool) {
    if condition {
        print("PASS: \(name)")
        passed += 1
    } else {
        print("FAIL: \(name)")
        failed += 1
    }
}

// MARK: - Tokenizer Tests

print("\n--- Tokenizer Tests ---")

do {
    var tokenizer = CSSTokenizer("color")
    let tokens = tokenizer.tokenize()
    test("Tokenize identifier", tokens[0] == CSSToken.ident("color"))
}

do {
    var tokenizer = CSSTokenizer("#myId")
    let tokens = tokenizer.tokenize()
    test("Tokenize hash", tokens[0] == CSSToken.hash("myId"))
}

do {
    var tokenizer = CSSTokenizer("10px")
    let tokens = tokenizer.tokenize()
    test("Tokenize dimension", tokens[0] == CSSToken.dimension(10.0, "px"))
}

do {
    var tokenizer = CSSTokenizer("50%")
    let tokens = tokenizer.tokenize()
    test("Tokenize percentage", tokens[0] == CSSToken.percentage(50.0))
}

do {
    var tokenizer = CSSTokenizer("\"hello\"")
    let tokens = tokenizer.tokenize()
    test("Tokenize string", tokens[0] == CSSToken.string("hello"))
}

do {
    var tokenizer = CSSTokenizer("{}")
    let tokens = tokenizer.tokenize()
    test("Tokenize braces", tokens[0] == CSSToken.leftBrace && tokens[1] == CSSToken.rightBrace)
}

do {
    var tokenizer = CSSTokenizer("@media")
    let tokens = tokenizer.tokenize()
    test("Tokenize at-keyword", tokens[0] == CSSToken.atKeyword("media"))
}

// MARK: - Selector Tests

print("\n--- Selector Tests ---")

do {
    let selector = CSSParser.parseSelector("div")
    test("Parse tag selector", selector?.components[0].0.tagName == "div")
}

do {
    let selector = CSSParser.parseSelector(".my-class")
    test("Parse class selector", selector?.components[0].0.classes == ["my-class"])
}

do {
    let selector = CSSParser.parseSelector("#my-id")
    test("Parse ID selector", selector?.components[0].0.id == "my-id")
}

do {
    let selector = CSSParser.parseSelector("div.container")
    test("Parse compound selector",
         selector?.components[0].0.tagName == "div" &&
         selector?.components[0].0.classes == ["container"])
}

do {
    let selector = CSSParser.parseSelector("div > p")
    test("Parse child combinator",
         selector?.components.count == 2 &&
         selector?.components[0].1 == .child)
}

do {
    let selector = CSSParser.parseSelector("div p")
    test("Parse descendant combinator",
         selector?.components.count == 2 &&
         selector?.components[0].1 == .descendant)
}

// MARK: - Specificity Tests

print("\n--- Specificity Tests ---")

do {
    let selector = CSSParser.parseSelector("div")
    test("Specificity for type selector", selector?.specificity == Specificity(a: 0, b: 0, c: 1))
}

do {
    let selector = CSSParser.parseSelector(".class")
    test("Specificity for class selector", selector?.specificity == Specificity(a: 0, b: 1, c: 0))
}

do {
    let selector = CSSParser.parseSelector("#id")
    test("Specificity for ID selector", selector?.specificity == Specificity(a: 1, b: 0, c: 0))
}

do {
    let selector = CSSParser.parseSelector("div.class#id")
    test("Specificity for compound selector", selector?.specificity == Specificity(a: 1, b: 1, c: 1))
}

do {
    let low = Specificity(a: 0, b: 0, c: 1)
    let high = Specificity(a: 0, b: 1, c: 0)
    test("Specificity comparison", low < high)
}

// MARK: - Declaration Tests

print("\n--- Declaration Tests ---")

do {
    let declarations = CSSParser.parseDeclarations("color: red;")
    test("Parse simple declaration",
         declarations.count == 1 &&
         declarations[0].property == "color" &&
         declarations[0].value == .keyword("red"))
}

do {
    let declarations = CSSParser.parseDeclarations("color: red !important;")
    test("Parse important declaration",
         declarations[0].important == true)
}

do {
    let declarations = CSSParser.parseDeclarations("width: 100px;")
    test("Parse length value",
         declarations[0].value == .length(100.0, .px))
}

do {
    let declarations = CSSParser.parseDeclarations("width: 50%;")
    test("Parse percentage value",
         declarations[0].value == .percentage(50.0))
}

do {
    let declarations = CSSParser.parseDeclarations("color: #FF0000;")
    test("Parse hex color",
         declarations[0].value == .color(Color(r: 255, g: 0, b: 0)))
}

do {
    let declarations = CSSParser.parseDeclarations("color: inherit;")
    test("Parse inherit value",
         declarations[0].value == .inherit)
}

// MARK: - Stylesheet Tests

print("\n--- Stylesheet Tests ---")

do {
    let stylesheet = CSSParser.parseStylesheet("div { color: red; }")
    test("Parse simple rule",
         stylesheet.rules.count == 1 &&
         stylesheet.rules[0].selectors[0].components[0].0.tagName == "div" &&
         stylesheet.rules[0].declarations[0].property == "color")
}

do {
    let stylesheet = CSSParser.parseStylesheet("h1, h2, h3 { font-weight: bold; }")
    test("Parse multiple selectors",
         stylesheet.rules.count == 1 &&
         stylesheet.rules[0].selectors.count == 3)
}

do {
    let css = """
        div { color: red; }
        p { color: blue; }
        """
    let stylesheet = CSSParser.parseStylesheet(css)
    test("Parse multiple rules", stylesheet.rules.count == 2)
}

do {
    let stylesheet = CSSParser.parseStylesheet("""
        div {
            color: red;
            background-color: blue;
            font-weight: bold;
        }
        """)
    test("Parse multiple declarations",
         stylesheet.rules[0].declarations.count == 3)
}

do {
    let stylesheet = CSSParser.parseStylesheet("")
    test("Parse empty stylesheet", stylesheet.rules.isEmpty)
}

do {
    let css = """
        /* Header styles */
        h1 {
            color: blue; /* Main heading color */
        }
        """
    let stylesheet = CSSParser.parseStylesheet(css)
    test("Parse with comments",
         stylesheet.rules.count == 1 &&
         stylesheet.rules[0].declarations[0].value == .keyword("blue"))
}

// MARK: - Summary

print("\n=== Test Summary ===")
print("Passed: \(passed)")
print("Failed: \(failed)")
print("Total: \(passed + failed)")

if failed > 0 {
    print("\nSome tests failed!")
    exit(1)
} else {
    print("\nAll tests passed!")
}
