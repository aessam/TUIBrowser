import Testing
@testable import TUICSSParser
import TUICore

@Suite("CSS Parser Tests")
struct CSSParserTests {

    // MARK: - Parse Declarations

    @Test func testParseSimpleDeclaration() {
        let declarations = CSSParser.parseDeclarations("color: red;")

        #expect(declarations.count == 1)
        #expect(declarations[0].property == "color")
        #expect(declarations[0].value == .keyword("red"))
        #expect(declarations[0].important == false)
    }

    @Test func testParseMultipleDeclarations() {
        let declarations = CSSParser.parseDeclarations("color: red; background: blue;")

        #expect(declarations.count == 2)
        #expect(declarations[0].property == "color")
        #expect(declarations[0].value == .keyword("red"))
        #expect(declarations[1].property == "background")
        #expect(declarations[1].value == .keyword("blue"))
    }

    @Test func testParseDeclarationWithoutTrailingSemicolon() {
        let declarations = CSSParser.parseDeclarations("color: red")

        #expect(declarations.count == 1)
        #expect(declarations[0].property == "color")
        #expect(declarations[0].value == .keyword("red"))
    }

    @Test func testParseImportantDeclaration() {
        let declarations = CSSParser.parseDeclarations("color: red !important;")

        #expect(declarations.count == 1)
        #expect(declarations[0].property == "color")
        #expect(declarations[0].value == .keyword("red"))
        #expect(declarations[0].important == true)
    }

    @Test func testParseImportantWithoutSpace() {
        let declarations = CSSParser.parseDeclarations("color: red!important;")

        #expect(declarations.count == 1)
        #expect(declarations[0].important == true)
    }

    // MARK: - Parse Values

    @Test func testParseKeywordValue() {
        let declarations = CSSParser.parseDeclarations("display: block;")

        #expect(declarations[0].value == .keyword("block"))
    }

    @Test func testParseLengthValuePx() {
        let declarations = CSSParser.parseDeclarations("width: 100px;")

        #expect(declarations[0].value == .length(100.0, .px))
    }

    @Test func testParseLengthValueEm() {
        let declarations = CSSParser.parseDeclarations("font-size: 1.5em;")

        #expect(declarations[0].value == .length(1.5, .em))
    }

    @Test func testParseLengthValueRem() {
        let declarations = CSSParser.parseDeclarations("margin: 2rem;")

        #expect(declarations[0].value == .length(2.0, .rem))
    }

    @Test func testParsePercentageValue() {
        let declarations = CSSParser.parseDeclarations("width: 50%;")

        #expect(declarations[0].value == .percentage(50.0))
    }

    @Test func testParseNumberValue() {
        let declarations = CSSParser.parseDeclarations("line-height: 1.5;")

        #expect(declarations[0].value == .number(1.5))
    }

    @Test func testParseStringValue() {
        let declarations = CSSParser.parseDeclarations("content: \"hello\";")

        #expect(declarations[0].value == .string("hello"))
    }

    @Test func testParseInheritValue() {
        let declarations = CSSParser.parseDeclarations("color: inherit;")

        #expect(declarations[0].value == .inherit)
    }

    @Test func testParseInitialValue() {
        let declarations = CSSParser.parseDeclarations("color: initial;")

        #expect(declarations[0].value == .initial)
    }

    // MARK: - Parse Colors

    @Test func testParseNamedColor() {
        let declarations = CSSParser.parseDeclarations("color: red;")

        #expect(declarations[0].value == .keyword("red"))
    }

    @Test func testParseHexColor6() {
        let declarations = CSSParser.parseDeclarations("color: #FF0000;")

        #expect(declarations[0].value == .color(Color(r: 255, g: 0, b: 0)))
    }

    @Test func testParseHexColor3() {
        let declarations = CSSParser.parseDeclarations("color: #F00;")

        #expect(declarations[0].value == .color(Color(r: 255, g: 0, b: 0)))
    }

    // MARK: - Parse Complete Rules

    @Test func testParseSimpleRule() {
        let stylesheet = CSSParser.parseStylesheet("div { color: red; }")

        #expect(stylesheet.rules.count == 1)
        #expect(stylesheet.rules[0].selectors.count == 1)
        #expect(stylesheet.rules[0].selectors[0].components[0].0.tagName == "div")
        #expect(stylesheet.rules[0].declarations.count == 1)
        #expect(stylesheet.rules[0].declarations[0].property == "color")
    }

    @Test func testParseMultipleSelectorsSameRule() {
        let stylesheet = CSSParser.parseStylesheet("h1, h2, h3 { font-weight: bold; }")

        #expect(stylesheet.rules.count == 1)
        #expect(stylesheet.rules[0].selectors.count == 3)
        #expect(stylesheet.rules[0].selectors[0].components[0].0.tagName == "h1")
        #expect(stylesheet.rules[0].selectors[1].components[0].0.tagName == "h2")
        #expect(stylesheet.rules[0].selectors[2].components[0].0.tagName == "h3")
    }

    @Test func testParseMultipleRules() {
        let css = """
            div { color: red; }
            p { color: blue; }
            """
        let stylesheet = CSSParser.parseStylesheet(css)

        #expect(stylesheet.rules.count == 2)
        #expect(stylesheet.rules[0].selectors[0].components[0].0.tagName == "div")
        #expect(stylesheet.rules[1].selectors[0].components[0].0.tagName == "p")
    }

    @Test func testParseMultipleDeclarationsInRule() {
        let stylesheet = CSSParser.parseStylesheet("""
            div {
                color: red;
                background-color: blue;
                font-weight: bold;
            }
            """)

        #expect(stylesheet.rules.count == 1)
        #expect(stylesheet.rules[0].declarations.count == 3)
    }

    @Test func testParseRuleWithComplexSelector() {
        let stylesheet = CSSParser.parseStylesheet("div.container > p { margin: 10px; }")

        #expect(stylesheet.rules.count == 1)
        let selector = stylesheet.rules[0].selectors[0]
        #expect(selector.components.count == 2)
        #expect(selector.components[0].0.tagName == "div")
        #expect(selector.components[0].0.classes == ["container"])
        #expect(selector.components[0].1 == .child)
        #expect(selector.components[1].0.tagName == "p")
    }

    // MARK: - Important Properties

    @Test func testParseColorProperty() {
        let declarations = CSSParser.parseDeclarations("color: navy;")

        #expect(declarations[0].property == "color")
        #expect(declarations[0].value == .keyword("navy"))
    }

    @Test func testParseBackgroundColorProperty() {
        let declarations = CSSParser.parseDeclarations("background-color: #FFFFFF;")

        #expect(declarations[0].property == "background-color")
        #expect(declarations[0].value == .color(Color(r: 255, g: 255, b: 255)))
    }

    @Test func testParseFontWeightBold() {
        let declarations = CSSParser.parseDeclarations("font-weight: bold;")

        #expect(declarations[0].property == "font-weight")
        #expect(declarations[0].value == .keyword("bold"))
    }

    @Test func testParseFontWeightNormal() {
        let declarations = CSSParser.parseDeclarations("font-weight: normal;")

        #expect(declarations[0].property == "font-weight")
        #expect(declarations[0].value == .keyword("normal"))
    }

    @Test func testParseTextDecorationUnderline() {
        let declarations = CSSParser.parseDeclarations("text-decoration: underline;")

        #expect(declarations[0].property == "text-decoration")
        #expect(declarations[0].value == .keyword("underline"))
    }

    @Test func testParseTextDecorationNone() {
        let declarations = CSSParser.parseDeclarations("text-decoration: none;")

        #expect(declarations[0].property == "text-decoration")
        #expect(declarations[0].value == .keyword("none"))
    }

    @Test func testParseDisplayBlock() {
        let declarations = CSSParser.parseDeclarations("display: block;")

        #expect(declarations[0].property == "display")
        #expect(declarations[0].value == .keyword("block"))
    }

    @Test func testParseDisplayInline() {
        let declarations = CSSParser.parseDeclarations("display: inline;")

        #expect(declarations[0].property == "display")
        #expect(declarations[0].value == .keyword("inline"))
    }

    @Test func testParseDisplayNone() {
        let declarations = CSSParser.parseDeclarations("display: none;")

        #expect(declarations[0].property == "display")
        #expect(declarations[0].value == .keyword("none"))
    }

    @Test func testParseMarginWithPx() {
        let declarations = CSSParser.parseDeclarations("margin: 10px;")

        #expect(declarations[0].property == "margin")
        #expect(declarations[0].value == .length(10.0, .px))
    }

    @Test func testParsePaddingWithEm() {
        let declarations = CSSParser.parseDeclarations("padding: 1em;")

        #expect(declarations[0].property == "padding")
        #expect(declarations[0].value == .length(1.0, .em))
    }

    // MARK: - Edge Cases

    @Test func testParseEmptyStylesheet() {
        let stylesheet = CSSParser.parseStylesheet("")

        #expect(stylesheet.rules.isEmpty)
    }

    @Test func testParseWhitespaceOnlyStylesheet() {
        let stylesheet = CSSParser.parseStylesheet("   \n\t   ")

        #expect(stylesheet.rules.isEmpty)
    }

    @Test func testParseRuleWithExtraWhitespace() {
        let stylesheet = CSSParser.parseStylesheet("   div   {   color  :  red  ;   }   ")

        #expect(stylesheet.rules.count == 1)
        #expect(stylesheet.rules[0].declarations[0].property == "color")
        #expect(stylesheet.rules[0].declarations[0].value == .keyword("red"))
    }

    @Test func testParseWithComments() {
        let css = """
            /* Header styles */
            h1 {
                color: blue; /* Main heading color */
            }
            """
        let stylesheet = CSSParser.parseStylesheet(css)

        #expect(stylesheet.rules.count == 1)
        #expect(stylesheet.rules[0].selectors[0].components[0].0.tagName == "h1")
        #expect(stylesheet.rules[0].declarations[0].value == .keyword("blue"))
    }

    @Test func testParseZeroValue() {
        let declarations = CSSParser.parseDeclarations("margin: 0;")

        #expect(declarations[0].value == .number(0.0))
    }

    @Test func testParseNegativeLength() {
        let declarations = CSSParser.parseDeclarations("margin-left: -10px;")

        #expect(declarations[0].value == .length(-10.0, .px))
    }

    @Test func testParseVhUnit() {
        let declarations = CSSParser.parseDeclarations("height: 100vh;")

        #expect(declarations[0].value == .length(100.0, .vh))
    }

    @Test func testParseVwUnit() {
        let declarations = CSSParser.parseDeclarations("width: 100vw;")

        #expect(declarations[0].value == .length(100.0, .vw))
    }

    @Test func testParseChUnit() {
        let declarations = CSSParser.parseDeclarations("width: 40ch;")

        #expect(declarations[0].value == .length(40.0, .ch))
    }
}

@Suite("CSS Value Tests")
struct CSSValueTests {

    @Test func testKeywordEquality() {
        let a = CSSValue.keyword("red")
        let b = CSSValue.keyword("red")
        let c = CSSValue.keyword("blue")

        #expect(a == b)
        #expect(a != c)
    }

    @Test func testLengthEquality() {
        let a = CSSValue.length(10.0, .px)
        let b = CSSValue.length(10.0, .px)
        let c = CSSValue.length(10.0, .em)
        let d = CSSValue.length(20.0, .px)

        #expect(a == b)
        #expect(a != c)
        #expect(a != d)
    }

    @Test func testPercentageEquality() {
        let a = CSSValue.percentage(50.0)
        let b = CSSValue.percentage(50.0)
        let c = CSSValue.percentage(75.0)

        #expect(a == b)
        #expect(a != c)
    }

    @Test func testColorEquality() {
        let a = CSSValue.color(Color.red)
        let b = CSSValue.color(Color.red)
        let c = CSSValue.color(Color.blue)

        #expect(a == b)
        #expect(a != c)
    }
}

@Suite("CSS Declaration Tests")
struct CSSDeclarationTests {

    @Test func testDeclarationEquality() {
        let a = CSSDeclaration(property: "color", value: .keyword("red"), important: false)
        let b = CSSDeclaration(property: "color", value: .keyword("red"), important: false)
        let c = CSSDeclaration(property: "color", value: .keyword("red"), important: true)

        #expect(a == b)
        #expect(a != c)
    }

    @Test func testDeclarationPropertyAccess() {
        let decl = CSSDeclaration(property: "background-color", value: .keyword("blue"), important: true)

        #expect(decl.property == "background-color")
        #expect(decl.value == .keyword("blue"))
        #expect(decl.important == true)
    }
}

@Suite("Stylesheet Tests")
struct StylesheetTests {

    @Test func testEmptyStylesheet() {
        let stylesheet = Stylesheet(rules: [])

        #expect(stylesheet.rules.isEmpty)
    }

    @Test func testStylesheetWithRules() {
        let selector = Selector(
            components: [(SimpleSelector(tagName: "div", id: nil, classes: []), nil)],
            specificity: Specificity(a: 0, b: 0, c: 1)
        )
        let declaration = CSSDeclaration(property: "color", value: .keyword("red"), important: false)
        let rule = CSSRule(selectors: [selector], declarations: [declaration])
        let stylesheet = Stylesheet(rules: [rule])

        #expect(stylesheet.rules.count == 1)
    }
}
