import Testing
@testable import TUICSSParser

@Suite("CSS Tokenizer Tests")
struct CSSTokenizerTests {

    // MARK: - Basic Token Types

    @Test func testTokenizeIdentifier() {
        var tokenizer = CSSTokenizer("color")
        let tokens = tokenizer.tokenize()

        #expect(tokens.count == 2)
        #expect(tokens[0] == CSSToken.ident("color"))
        #expect(tokens[1] == CSSToken.eof)
    }

    @Test func testTokenizeIdentifierWithHyphen() {
        var tokenizer = CSSTokenizer("background-color")
        let tokens = tokenizer.tokenize()

        #expect(tokens.count == 2)
        #expect(tokens[0] == CSSToken.ident("background-color"))
        #expect(tokens[1] == CSSToken.eof)
    }

    @Test func testTokenizeIdentifierWithUnderscore() {
        var tokenizer = CSSTokenizer("my_class")
        let tokens = tokenizer.tokenize()

        #expect(tokens.count == 2)
        #expect(tokens[0] == CSSToken.ident("my_class"))
    }

    // MARK: - Hash (ID selectors)

    @Test func testTokenizeHash() {
        var tokenizer = CSSTokenizer("#myId")
        let tokens = tokenizer.tokenize()

        #expect(tokens.count == 2)
        #expect(tokens[0] == CSSToken.hash("myId"))
        #expect(tokens[1] == CSSToken.eof)
    }

    @Test func testTokenizeHashWithHyphen() {
        var tokenizer = CSSTokenizer("#my-id")
        let tokens = tokenizer.tokenize()

        #expect(tokens.count == 2)
        #expect(tokens[0] == CSSToken.hash("my-id"))
    }

    @Test func testTokenizeHexColor() {
        var tokenizer = CSSTokenizer("#FF0000")
        let tokens = tokenizer.tokenize()

        #expect(tokens.count == 2)
        #expect(tokens[0] == CSSToken.hash("FF0000"))
    }

    // MARK: - Strings

    @Test func testTokenizeDoubleQuotedString() {
        var tokenizer = CSSTokenizer("\"hello world\"")
        let tokens = tokenizer.tokenize()

        #expect(tokens.count == 2)
        #expect(tokens[0] == CSSToken.string("hello world"))
        #expect(tokens[1] == CSSToken.eof)
    }

    @Test func testTokenizeSingleQuotedString() {
        var tokenizer = CSSTokenizer("'hello world'")
        let tokens = tokenizer.tokenize()

        #expect(tokens.count == 2)
        #expect(tokens[0] == CSSToken.string("hello world"))
    }

    @Test func testTokenizeStringWithEscapedQuote() {
        var tokenizer = CSSTokenizer("\"hello \\\"world\\\"\"")
        let tokens = tokenizer.tokenize()

        #expect(tokens.count == 2)
        #expect(tokens[0] == CSSToken.string("hello \"world\""))
    }

    // MARK: - Numbers

    @Test func testTokenizeInteger() {
        var tokenizer = CSSTokenizer("42")
        let tokens = tokenizer.tokenize()

        #expect(tokens.count == 2)
        #expect(tokens[0] == CSSToken.number(42.0))
    }

    @Test func testTokenizeFloat() {
        var tokenizer = CSSTokenizer("3.14")
        let tokens = tokenizer.tokenize()

        #expect(tokens.count == 2)
        #expect(tokens[0] == CSSToken.number(3.14))
    }

    @Test func testTokenizeNegativeNumber() {
        var tokenizer = CSSTokenizer("-10")
        let tokens = tokenizer.tokenize()

        #expect(tokens.count == 2)
        #expect(tokens[0] == CSSToken.number(-10.0))
    }

    // MARK: - Percentages

    @Test func testTokenizePercentage() {
        var tokenizer = CSSTokenizer("50%")
        let tokens = tokenizer.tokenize()

        #expect(tokens.count == 2)
        #expect(tokens[0] == CSSToken.percentage(50.0))
    }

    @Test func testTokenizeFloatPercentage() {
        var tokenizer = CSSTokenizer("33.33%")
        let tokens = tokenizer.tokenize()

        #expect(tokens.count == 2)
        #expect(tokens[0] == CSSToken.percentage(33.33))
    }

    // MARK: - Dimensions

    @Test func testTokenizePxDimension() {
        var tokenizer = CSSTokenizer("10px")
        let tokens = tokenizer.tokenize()

        #expect(tokens.count == 2)
        #expect(tokens[0] == CSSToken.dimension(10.0, "px"))
    }

    @Test func testTokenizeEmDimension() {
        var tokenizer = CSSTokenizer("1.5em")
        let tokens = tokenizer.tokenize()

        #expect(tokens.count == 2)
        #expect(tokens[0] == CSSToken.dimension(1.5, "em"))
    }

    @Test func testTokenizeRemDimension() {
        var tokenizer = CSSTokenizer("2rem")
        let tokens = tokenizer.tokenize()

        #expect(tokens.count == 2)
        #expect(tokens[0] == CSSToken.dimension(2.0, "rem"))
    }

    @Test func testTokenizeVhDimension() {
        var tokenizer = CSSTokenizer("100vh")
        let tokens = tokenizer.tokenize()

        #expect(tokens.count == 2)
        #expect(tokens[0] == CSSToken.dimension(100.0, "vh"))
    }

    // MARK: - Delimiters

    @Test func testTokenizeColon() {
        var tokenizer = CSSTokenizer(":")
        let tokens = tokenizer.tokenize()

        #expect(tokens.count == 2)
        #expect(tokens[0] == CSSToken.colon)
    }

    @Test func testTokenizeSemicolon() {
        var tokenizer = CSSTokenizer(";")
        let tokens = tokenizer.tokenize()

        #expect(tokens.count == 2)
        #expect(tokens[0] == CSSToken.semicolon)
    }

    @Test func testTokenizeComma() {
        var tokenizer = CSSTokenizer(",")
        let tokens = tokenizer.tokenize()

        #expect(tokens.count == 2)
        #expect(tokens[0] == CSSToken.comma)
    }

    @Test func testTokenizeBraces() {
        var tokenizer = CSSTokenizer("{}")
        let tokens = tokenizer.tokenize()

        #expect(tokens.count == 3)
        #expect(tokens[0] == CSSToken.leftBrace)
        #expect(tokens[1] == CSSToken.rightBrace)
    }

    @Test func testTokenizeParentheses() {
        var tokenizer = CSSTokenizer("()")
        let tokens = tokenizer.tokenize()

        #expect(tokens.count == 3)
        #expect(tokens[0] == CSSToken.leftParen)
        #expect(tokens[1] == CSSToken.rightParen)
    }

    @Test func testTokenizeLeftBracket() {
        var tokenizer = CSSTokenizer("[")
        let tokens = tokenizer.tokenize()

        #expect(tokens.count == 2)
        #expect(tokens[0] == CSSToken.leftBracket)
    }

    @Test func testTokenizeRightBracket() {
        var tokenizer = CSSTokenizer("]")
        let tokens = tokenizer.tokenize()

        #expect(tokens.count == 2)
        #expect(tokens[0] == CSSToken.rightBracket)
    }

    // MARK: - At-Keywords

    @Test func testTokenizeAtKeyword() {
        var tokenizer = CSSTokenizer("@media")
        let tokens = tokenizer.tokenize()

        #expect(tokens.count == 2)
        #expect(tokens[0] == CSSToken.atKeyword("media"))
    }

    @Test func testTokenizeAtImport() {
        var tokenizer = CSSTokenizer("@import")
        let tokens = tokenizer.tokenize()

        #expect(tokens.count == 2)
        #expect(tokens[0] == CSSToken.atKeyword("import"))
    }

    // MARK: - Whitespace

    @Test func testTokenizeWhitespace() {
        var tokenizer = CSSTokenizer("  \t\n  ")
        let tokens = tokenizer.tokenize()

        #expect(tokens.count == 2)
        #expect(tokens[0] == CSSToken.whitespace)
        #expect(tokens[1] == CSSToken.eof)
    }

    @Test func testTokenizeWithWhitespaceBetween() {
        var tokenizer = CSSTokenizer("color : red")
        let tokens = tokenizer.tokenize()

        #expect(tokens.count == 6)
        #expect(tokens[0] == CSSToken.ident("color"))
        #expect(tokens[1] == CSSToken.whitespace)
        #expect(tokens[2] == CSSToken.colon)
        #expect(tokens[3] == CSSToken.whitespace)
        #expect(tokens[4] == CSSToken.ident("red"))
        #expect(tokens[5] == CSSToken.eof)
    }

    // MARK: - Comments

    @Test func testSkipBlockComment() {
        var tokenizer = CSSTokenizer("color /* comment */ red")
        let tokens = tokenizer.tokenize()

        #expect(tokens.count == 4)
        #expect(tokens[0] == CSSToken.ident("color"))
        #expect(tokens[1] == CSSToken.whitespace)
        #expect(tokens[2] == CSSToken.ident("red"))
    }

    @Test func testSkipMultilineComment() {
        var tokenizer = CSSTokenizer("""
            color /* this is
            a multiline
            comment */ red
            """)
        let tokens = tokenizer.tokenize()

        #expect(tokens[0] == CSSToken.ident("color"))
        #expect(tokens[2] == CSSToken.ident("red"))
    }

    // MARK: - Delim (Generic characters)

    @Test func testTokenizeDelimStar() {
        var tokenizer = CSSTokenizer("*")
        let tokens = tokenizer.tokenize()

        #expect(tokens.count == 2)
        #expect(tokens[0] == CSSToken.delim("*"))
    }

    @Test func testTokenizeDelimDot() {
        var tokenizer = CSSTokenizer(".")
        let tokens = tokenizer.tokenize()

        #expect(tokens.count == 2)
        #expect(tokens[0] == CSSToken.delim("."))
    }

    @Test func testTokenizeDelimGreaterThan() {
        var tokenizer = CSSTokenizer(">")
        let tokens = tokenizer.tokenize()

        #expect(tokens.count == 2)
        #expect(tokens[0] == CSSToken.delim(">"))
    }

    @Test func testTokenizeDelimPlus() {
        var tokenizer = CSSTokenizer("+")
        let tokens = tokenizer.tokenize()

        #expect(tokens.count == 2)
        #expect(tokens[0] == CSSToken.delim("+"))
    }

    @Test func testTokenizeDelimTilde() {
        var tokenizer = CSSTokenizer("~")
        let tokens = tokenizer.tokenize()

        #expect(tokens.count == 2)
        #expect(tokens[0] == CSSToken.delim("~"))
    }

    // MARK: - Complex Tokenization

    @Test func testTokenizeSimpleRule() {
        var tokenizer = CSSTokenizer("div { color: red; }")
        let tokens = tokenizer.tokenize()

        // div whitespace { whitespace color : whitespace red ; whitespace } EOF
        #expect(tokens.contains(CSSToken.ident("div")))
        #expect(tokens.contains(CSSToken.leftBrace))
        #expect(tokens.contains(CSSToken.ident("color")))
        #expect(tokens.contains(CSSToken.colon))
        #expect(tokens.contains(CSSToken.ident("red")))
        #expect(tokens.contains(CSSToken.semicolon))
        #expect(tokens.contains(CSSToken.rightBrace))
    }

    @Test func testTokenizeMultipleDeclarations() {
        var tokenizer = CSSTokenizer("color: red; background: blue;")
        let tokens = tokenizer.tokenize()

        #expect(tokens.contains(CSSToken.ident("color")))
        #expect(tokens.contains(CSSToken.ident("red")))
        #expect(tokens.contains(CSSToken.ident("background")))
        #expect(tokens.contains(CSSToken.ident("blue")))
    }

    @Test func testTokenizeClassSelector() {
        var tokenizer = CSSTokenizer(".my-class")
        let tokens = tokenizer.tokenize()

        #expect(tokens.count == 3)
        #expect(tokens[0] == CSSToken.delim("."))
        #expect(tokens[1] == CSSToken.ident("my-class"))
    }

    @Test func testTokenizeComplexSelector() {
        var tokenizer = CSSTokenizer("div.class#id")
        let tokens = tokenizer.tokenize()

        #expect(tokens.contains(CSSToken.ident("div")))
        #expect(tokens.contains(CSSToken.delim(".")))
        #expect(tokens.contains(CSSToken.ident("class")))
        #expect(tokens.contains(CSSToken.hash("id")))
    }

    @Test func testTokenizeImportant() {
        var tokenizer = CSSTokenizer("!important")
        let tokens = tokenizer.tokenize()

        #expect(tokens.count == 3)
        #expect(tokens[0] == CSSToken.delim("!"))
        #expect(tokens[1] == CSSToken.ident("important"))
    }

    @Test func testTokenizeFunctionNotation() {
        var tokenizer = CSSTokenizer("rgb(255, 0, 0)")
        let tokens = tokenizer.tokenize()

        #expect(tokens.contains(CSSToken.function("rgb")))
        #expect(tokens.contains(CSSToken.number(255.0)))
        #expect(tokens.contains(CSSToken.comma))
        #expect(tokens.contains(CSSToken.rightParen))
    }

    @Test func testTokenizeUrl() {
        var tokenizer = CSSTokenizer("url(\"image.png\")")
        let tokens = tokenizer.tokenize()

        #expect(tokens.contains(CSSToken.function("url")))
        #expect(tokens.contains(CSSToken.string("image.png")))
        #expect(tokens.contains(CSSToken.rightParen))
    }
}
