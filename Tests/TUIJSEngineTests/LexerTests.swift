import Testing
@testable import TUIJSEngine

@Suite("Lexer Tests")
struct LexerTests {

    // MARK: - Number Tests

    @Test func testLexIntegers() {
        var lexer = Lexer(source: "42 0 123")
        let tokens = lexer.scanTokens()

        #expect(tokens.count == 4) // 3 numbers + EOF
        #expect(tokens[0].type == .number)
        #expect(tokens[0].literal == .number(42))
        #expect(tokens[1].type == .number)
        #expect(tokens[1].literal == .number(0))
        #expect(tokens[2].type == .number)
        #expect(tokens[2].literal == .number(123))
    }

    @Test func testLexFloats() {
        var lexer = Lexer(source: "3.14 0.5 10.0")
        let tokens = lexer.scanTokens()

        #expect(tokens.count == 4)
        #expect(tokens[0].type == .number)
        #expect(tokens[0].literal == .number(3.14))
        #expect(tokens[1].literal == .number(0.5))
        #expect(tokens[2].literal == .number(10.0))
    }

    @Test func testLexScientificNotation() {
        var lexer = Lexer(source: "1e10 2.5E-3 3e+2")
        let tokens = lexer.scanTokens()

        #expect(tokens.count == 4)
        #expect(tokens[0].literal == .number(1e10))
        #expect(tokens[1].literal == .number(2.5e-3))
        #expect(tokens[2].literal == .number(3e+2))
    }

    // MARK: - String Tests

    @Test func testLexSingleQuoteStrings() {
        var lexer = Lexer(source: "'hello' 'world'")
        let tokens = lexer.scanTokens()

        #expect(tokens.count == 3)
        #expect(tokens[0].type == .string)
        #expect(tokens[0].literal == .string("hello"))
        #expect(tokens[1].literal == .string("world"))
    }

    @Test func testLexDoubleQuoteStrings() {
        var lexer = Lexer(source: "\"hello\" \"world\"")
        let tokens = lexer.scanTokens()

        #expect(tokens.count == 3)
        #expect(tokens[0].type == .string)
        #expect(tokens[0].literal == .string("hello"))
    }

    @Test func testLexStringEscapes() {
        var lexer = Lexer(source: #"'hello\nworld' "tab\there""#)
        let tokens = lexer.scanTokens()

        #expect(tokens.count == 3)
        #expect(tokens[0].literal == .string("hello\nworld"))
        #expect(tokens[1].literal == .string("tab\there"))
    }

    @Test func testLexEmptyString() {
        var lexer = Lexer(source: "'' \"\"")
        let tokens = lexer.scanTokens()

        #expect(tokens.count == 3)
        #expect(tokens[0].literal == .string(""))
        #expect(tokens[1].literal == .string(""))
    }

    // MARK: - Operator Tests

    @Test func testLexArithmeticOperators() {
        var lexer = Lexer(source: "+ - * / %")
        let tokens = lexer.scanTokens()

        #expect(tokens.count == 6)
        #expect(tokens[0].type == .plus)
        #expect(tokens[1].type == .minus)
        #expect(tokens[2].type == .star)
        #expect(tokens[3].type == .slash)
        #expect(tokens[4].type == .percent)
    }

    @Test func testLexComparisonOperators() {
        var lexer = Lexer(source: "< <= > >= == === != !==")
        let tokens = lexer.scanTokens()

        #expect(tokens.count == 9)
        #expect(tokens[0].type == .less)
        #expect(tokens[1].type == .lessEqual)
        #expect(tokens[2].type == .greater)
        #expect(tokens[3].type == .greaterEqual)
        #expect(tokens[4].type == .equalEqual)
        #expect(tokens[5].type == .equalEqualEqual)
        #expect(tokens[6].type == .bangEqual)
        #expect(tokens[7].type == .bangEqualEqual)
    }

    @Test func testLexLogicalOperators() {
        var lexer = Lexer(source: "&& || !")
        let tokens = lexer.scanTokens()

        #expect(tokens.count == 4)
        #expect(tokens[0].type == .ampAmp)
        #expect(tokens[1].type == .pipePipe)
        #expect(tokens[2].type == .bang)
    }

    @Test func testLexAssignmentOperators() {
        var lexer = Lexer(source: "= += -= *= /=")
        let tokens = lexer.scanTokens()

        #expect(tokens.count == 6)
        #expect(tokens[0].type == .equal)
        #expect(tokens[1].type == .plusEqual)
        #expect(tokens[2].type == .minusEqual)
        #expect(tokens[3].type == .starEqual)
        #expect(tokens[4].type == .slashEqual)
    }

    @Test func testLexIncrementDecrement() {
        var lexer = Lexer(source: "++ --")
        let tokens = lexer.scanTokens()

        #expect(tokens.count == 3)
        #expect(tokens[0].type == .plusPlus)
        #expect(tokens[1].type == .minusMinus)
    }

    @Test func testLexArrowOperator() {
        var lexer = Lexer(source: "=>")
        let tokens = lexer.scanTokens()

        #expect(tokens.count == 2)
        #expect(tokens[0].type == .arrow)
    }

    // MARK: - Delimiter Tests

    @Test func testLexDelimiters() {
        var lexer = Lexer(source: "( ) { } [ ] , . : ; ?")
        let tokens = lexer.scanTokens()

        #expect(tokens.count == 12)
        #expect(tokens[0].type == .leftParen)
        #expect(tokens[1].type == .rightParen)
        #expect(tokens[2].type == .leftBrace)
        #expect(tokens[3].type == .rightBrace)
        #expect(tokens[4].type == .leftBracket)
        #expect(tokens[5].type == .rightBracket)
        #expect(tokens[6].type == .comma)
        #expect(tokens[7].type == .dot)
        #expect(tokens[8].type == .colon)
        #expect(tokens[9].type == .semicolon)
        #expect(tokens[10].type == .question)
    }

    // MARK: - Keyword Tests

    @Test func testLexKeywords() {
        var lexer = Lexer(source: "var let const function return if else for while break continue")
        let tokens = lexer.scanTokens()

        #expect(tokens.count == 12)
        #expect(tokens[0].type == .var)
        #expect(tokens[1].type == .let)
        #expect(tokens[2].type == .const)
        #expect(tokens[3].type == .function)
        #expect(tokens[4].type == .return)
        #expect(tokens[5].type == .if)
        #expect(tokens[6].type == .else)
        #expect(tokens[7].type == .for)
        #expect(tokens[8].type == .while)
        #expect(tokens[9].type == .break)
        #expect(tokens[10].type == .continue)
    }

    @Test func testLexBooleanKeywords() {
        var lexer = Lexer(source: "true false")
        let tokens = lexer.scanTokens()

        #expect(tokens.count == 3)
        #expect(tokens[0].type == .true)
        #expect(tokens[0].literal == .boolean(true))
        #expect(tokens[1].type == .false)
        #expect(tokens[1].literal == .boolean(false))
    }

    @Test func testLexNullUndefined() {
        var lexer = Lexer(source: "null undefined")
        let tokens = lexer.scanTokens()

        #expect(tokens.count == 3)
        #expect(tokens[0].type == .null)
        #expect(tokens[1].type == .undefined)
    }

    @Test func testLexOtherKeywords() {
        var lexer = Lexer(source: "new typeof instanceof this")
        let tokens = lexer.scanTokens()

        #expect(tokens.count == 5)
        #expect(tokens[0].type == .new)
        #expect(tokens[1].type == .typeof)
        #expect(tokens[2].type == .instanceof)
        #expect(tokens[3].type == .this)
    }

    // MARK: - Identifier Tests

    @Test func testLexIdentifiers() {
        var lexer = Lexer(source: "foo bar_baz $test _private camelCase")
        let tokens = lexer.scanTokens()

        #expect(tokens.count == 6)
        for i in 0..<5 {
            #expect(tokens[i].type == .identifier)
        }
        #expect(tokens[0].lexeme == "foo")
        #expect(tokens[1].lexeme == "bar_baz")
        #expect(tokens[2].lexeme == "$test")
        #expect(tokens[3].lexeme == "_private")
        #expect(tokens[4].lexeme == "camelCase")
    }

    @Test func testIdentifiersWithNumbers() {
        var lexer = Lexer(source: "test123 foo2bar")
        let tokens = lexer.scanTokens()

        #expect(tokens.count == 3)
        #expect(tokens[0].type == .identifier)
        #expect(tokens[0].lexeme == "test123")
        #expect(tokens[1].lexeme == "foo2bar")
    }

    // MARK: - Comment Tests

    @Test func testSingleLineComment() {
        var lexer = Lexer(source: "foo // comment\nbar")
        let tokens = lexer.scanTokens()

        #expect(tokens.count == 3)
        #expect(tokens[0].lexeme == "foo")
        #expect(tokens[1].lexeme == "bar")
    }

    @Test func testMultiLineComment() {
        var lexer = Lexer(source: "foo /* multi\nline\ncomment */ bar")
        let tokens = lexer.scanTokens()

        #expect(tokens.count == 3)
        #expect(tokens[0].lexeme == "foo")
        #expect(tokens[1].lexeme == "bar")
    }

    // MARK: - Line and Column Tracking

    @Test func testLineTracking() {
        var lexer = Lexer(source: "foo\nbar\nbaz")
        let tokens = lexer.scanTokens()

        #expect(tokens[0].line == 1)
        #expect(tokens[1].line == 2)
        #expect(tokens[2].line == 3)
    }

    @Test func testColumnTracking() {
        var lexer = Lexer(source: "foo bar")
        let tokens = lexer.scanTokens()

        #expect(tokens[0].column == 1)
        #expect(tokens[1].column == 5)
    }

    // MARK: - Complex Expressions

    @Test func testVariableDeclaration() {
        var lexer = Lexer(source: "let x = 5;")
        let tokens = lexer.scanTokens()

        #expect(tokens.count == 6)
        #expect(tokens[0].type == .let)
        #expect(tokens[1].type == .identifier)
        #expect(tokens[1].lexeme == "x")
        #expect(tokens[2].type == .equal)
        #expect(tokens[3].type == .number)
        #expect(tokens[4].type == .semicolon)
    }

    @Test func testFunctionDeclaration() {
        var lexer = Lexer(source: "function add(a, b) { return a + b; }")
        let tokens = lexer.scanTokens()

        #expect(tokens.count == 15)
        #expect(tokens[0].type == .function)
        #expect(tokens[1].type == .identifier)
        #expect(tokens[2].type == .leftParen)
    }

    @Test func testArrowFunction() {
        var lexer = Lexer(source: "const double = x => x * 2;")
        let tokens = lexer.scanTokens()

        #expect(tokens.count == 10)
        #expect(tokens[0].type == .const)
        #expect(tokens[4].type == .arrow)
    }

    @Test func testObjectLiteral() {
        var lexer = Lexer(source: "{ name: 'test', value: 42 }")
        let tokens = lexer.scanTokens()

        // { name : 'test' , value : 42 } EOF = 10 tokens
        #expect(tokens.count == 10)
        #expect(tokens[0].type == .leftBrace)
        #expect(tokens[1].type == .identifier)
        #expect(tokens[2].type == .colon)
        #expect(tokens[3].type == .string)
        #expect(tokens[4].type == .comma)
        #expect(tokens[8].type == .rightBrace)
        #expect(tokens[9].type == .eof)
    }

    @Test func testArrayLiteral() {
        var lexer = Lexer(source: "[1, 2, 3]")
        let tokens = lexer.scanTokens()

        #expect(tokens.count == 8)
        #expect(tokens[0].type == .leftBracket)
        #expect(tokens[6].type == .rightBracket)
    }
}
