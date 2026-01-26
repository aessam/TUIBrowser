// TUIJSEngine - JavaScript Parser (Pratt Parser)

import TUICore

/// Error types for the parser
public enum ParserError: TUIError, Equatable {
    case unexpectedToken(TokenType, expected: String, line: Int, column: Int)
    case unexpectedEndOfInput
    case invalidAssignmentTarget(line: Int, column: Int)
    case invalidSyntax(String, line: Int, column: Int)

    public var description: String {
        switch self {
        case .unexpectedToken(let type, let expected, let line, let column):
            return "Unexpected token '\(type)' at line \(line), column \(column). Expected \(expected)"
        case .unexpectedEndOfInput:
            return "Unexpected end of input"
        case .invalidAssignmentTarget(let line, let column):
            return "Invalid assignment target at line \(line), column \(column)"
        case .invalidSyntax(let message, let line, let column):
            return "\(message) at line \(line), column \(column)"
        }
    }
}

/// Operator precedence levels
private enum Precedence: Int, Comparable {
    case none = 0
    case assignment = 1     // =, +=, -=, etc.
    case conditional = 2    // ?:
    case logicalOr = 3      // ||
    case logicalAnd = 4     // &&
    case equality = 5       // ==, ===, !=, !==
    case comparison = 6     // <, >, <=, >=
    case term = 7           // +, -
    case factor = 8         // *, /, %
    case unary = 9          // !, -, ++, --
    case call = 10          // (), [], .
    case primary = 11

    static func < (lhs: Precedence, rhs: Precedence) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// JavaScript Pratt parser
public struct Parser {
    private var tokens: [Token]
    private var current: Int = 0
    private var errors: [ParserError] = []

    public init(tokens: [Token]) {
        self.tokens = tokens
    }

    /// Parse the token stream into statements
    public mutating func parse() -> [Statement] {
        var statements: [Statement] = []

        while !isAtEnd {
            if let stmt = parseDeclaration() {
                statements.append(stmt)
            }
        }

        return statements
    }

    /// Get parsing errors
    public var parserErrors: [ParserError] {
        errors
    }

    // MARK: - Token Access

    private var isAtEnd: Bool {
        peek().type == .eof
    }

    private func peek() -> Token {
        tokens[current]
    }

    private func peekNext() -> Token? {
        guard current + 1 < tokens.count else { return nil }
        return tokens[current + 1]
    }

    private func previous() -> Token {
        tokens[current - 1]
    }

    @discardableResult
    private mutating func advance() -> Token {
        if !isAtEnd {
            current += 1
        }
        return previous()
    }

    private func check(_ type: TokenType) -> Bool {
        !isAtEnd && peek().type == type
    }

    private mutating func match(_ types: TokenType...) -> Bool {
        for type in types {
            if check(type) {
                advance()
                return true
            }
        }
        return false
    }

    private mutating func consume(_ type: TokenType, _ message: String) -> Token? {
        if check(type) {
            return advance()
        }
        let token = peek()
        errors.append(.unexpectedToken(token.type, expected: message, line: token.line, column: token.column))
        return nil
    }

    // MARK: - Declarations

    private mutating func parseDeclaration() -> Statement? {
        if match(.var, .let, .const) {
            return parseVariableDeclaration()
        }
        if match(.function) {
            return parseFunctionDeclaration()
        }
        return parseStatement()
    }

    private mutating func parseVariableDeclaration() -> Statement? {
        let kindToken = previous()
        let kind: VarKind
        switch kindToken.type {
        case .var: kind = .var
        case .let: kind = .let
        case .const: kind = .const
        default: return nil
        }

        var declarations: [VariableBinding] = []

        repeat {
            guard let nameToken = consume(.identifier, "variable name") else {
                synchronize()
                return nil
            }

            var initializer: Expression? = nil
            if match(.equal) {
                initializer = parseExpression()
            }

            declarations.append(VariableBinding(name: nameToken.lexeme, initializer: initializer))
        } while match(.comma)

        _ = consume(.semicolon, "';' after variable declaration")
        return .variableDeclaration(kind: kind, declarations: declarations)
    }

    private mutating func parseFunctionDeclaration() -> Statement? {
        guard let nameToken = consume(.identifier, "function name") else {
            synchronize()
            return nil
        }

        guard consume(.leftParen, "'(' after function name") != nil else {
            synchronize()
            return nil
        }

        var params: [String] = []
        if !check(.rightParen) {
            repeat {
                if let param = consume(.identifier, "parameter name") {
                    params.append(param.lexeme)
                }
            } while match(.comma)
        }

        guard consume(.rightParen, "')' after parameters") != nil else {
            synchronize()
            return nil
        }

        guard consume(.leftBrace, "'{' before function body") != nil else {
            synchronize()
            return nil
        }

        let body = parseBlock()
        return .functionDeclaration(name: nameToken.lexeme, params: params, body: body)
    }

    // MARK: - Statements

    private mutating func parseStatement() -> Statement? {
        if match(.leftBrace) {
            return .block(parseBlock())
        }
        if match(.if) {
            return parseIfStatement()
        }
        if match(.for) {
            return parseForStatement()
        }
        if match(.while) {
            return parseWhileStatement()
        }
        if match(.return) {
            return parseReturnStatement()
        }
        if match(.break) {
            _ = consume(.semicolon, "';' after 'break'")
            return .breakStatement
        }
        if match(.continue) {
            _ = consume(.semicolon, "';' after 'continue'")
            return .continueStatement
        }
        if match(.semicolon) {
            return .empty
        }
        return parseExpressionStatement()
    }

    private mutating func parseBlock() -> [Statement] {
        var statements: [Statement] = []

        while !check(.rightBrace) && !isAtEnd {
            if let decl = parseDeclaration() {
                statements.append(decl)
            }
        }

        _ = consume(.rightBrace, "'}' after block")
        return statements
    }

    private mutating func parseIfStatement() -> Statement? {
        guard consume(.leftParen, "'(' after 'if'") != nil else {
            synchronize()
            return nil
        }

        guard let test = parseExpression() else {
            synchronize()
            return nil
        }

        guard consume(.rightParen, "')' after if condition") != nil else {
            synchronize()
            return nil
        }

        guard let consequent = parseStatement() else {
            return nil
        }

        var alternate: Statement? = nil
        if match(.else) {
            alternate = parseStatement()
        }

        return .ifStatement(test: test, consequent: consequent, alternate: alternate)
    }

    private mutating func parseForStatement() -> Statement? {
        guard consume(.leftParen, "'(' after 'for'") != nil else {
            synchronize()
            return nil
        }

        var initializer: ForInit? = nil
        if match(.semicolon) {
            // No initializer
        } else if match(.var, .let, .const) {
            let kindToken = previous()
            let kind: VarKind
            switch kindToken.type {
            case .var: kind = .var
            case .let: kind = .let
            case .const: kind = .const
            default: kind = .var
            }

            var declarations: [VariableBinding] = []
            repeat {
                if let nameToken = consume(.identifier, "variable name") {
                    var init_: Expression? = nil
                    if match(.equal) {
                        init_ = parseExpression()
                    }
                    declarations.append(VariableBinding(name: nameToken.lexeme, initializer: init_))
                }
            } while match(.comma)

            _ = consume(.semicolon, "';' after for initializer")
            initializer = .declaration(kind: kind, declarations: declarations)
        } else {
            if let expr = parseExpression() {
                initializer = .expression(expr)
            }
            _ = consume(.semicolon, "';' after for initializer")
        }

        var test: Expression? = nil
        if !check(.semicolon) {
            test = parseExpression()
        }
        _ = consume(.semicolon, "';' after for condition")

        var update: Expression? = nil
        if !check(.rightParen) {
            update = parseExpression()
        }

        guard consume(.rightParen, "')' after for clauses") != nil else {
            synchronize()
            return nil
        }

        guard let body = parseStatement() else {
            return nil
        }

        return .forStatement(init: initializer, test: test, update: update, body: body)
    }

    private mutating func parseWhileStatement() -> Statement? {
        guard consume(.leftParen, "'(' after 'while'") != nil else {
            synchronize()
            return nil
        }

        guard let test = parseExpression() else {
            synchronize()
            return nil
        }

        guard consume(.rightParen, "')' after while condition") != nil else {
            synchronize()
            return nil
        }

        guard let body = parseStatement() else {
            return nil
        }

        return .whileStatement(test: test, body: body)
    }

    private mutating func parseReturnStatement() -> Statement? {
        var value: Expression? = nil
        if !check(.semicolon) && !isAtEnd {
            value = parseExpression()
        }
        _ = consume(.semicolon, "';' after return value")
        return .returnStatement(value)
    }

    private mutating func parseExpressionStatement() -> Statement? {
        guard let expr = parseExpression() else {
            synchronize()
            return nil
        }
        _ = consume(.semicolon, "';' after expression")
        return .expression(expr)
    }

    // MARK: - Expressions (Pratt Parser)

    private mutating func parseExpression() -> Expression? {
        return parseExpressionWithPrecedence(.assignment)
    }

    private mutating func parseExpressionWithPrecedence(_ precedence: Precedence) -> Expression? {
        guard var left = parsePrefixExpression() else {
            return nil
        }

        while !isAtEnd && precedence.rawValue <= getPrecedence(peek().type).rawValue {
            left = parseInfixExpression(left) ?? left
        }

        return left
    }

    private mutating func parsePrefixExpression() -> Expression? {
        let token = peek()

        switch token.type {
        // Literals
        case .number:
            advance()
            if case .number(let value) = token.literal {
                return .literal(.number(value))
            }
            return nil

        case .string:
            advance()
            if case .string(let value) = token.literal {
                return .literal(.string(value))
            }
            return nil

        case .true:
            advance()
            return .literal(.boolean(true))

        case .false:
            advance()
            return .literal(.boolean(false))

        case .null:
            advance()
            return .literal(.null)

        case .undefined:
            advance()
            return .literal(.undefined)

        // Identifier - check for arrow function with single unparenthesized param
        case .identifier:
            let savedPos = current
            advance()
            let identifier = token.lexeme

            // Check if this is a single-param arrow function
            if check(.arrow) {
                advance() // consume '=>'
                if let body = parseArrowBody(params: [identifier]) {
                    return body
                } else {
                    current = savedPos
                    advance()
                    return .identifier(identifier)
                }
            }
            return .identifier(identifier)

        // this
        case .this:
            advance()
            return .this

        // Grouping or arrow function
        case .leftParen:
            return parseGroupingOrArrow()

        // Array literal
        case .leftBracket:
            return parseArrayLiteral()

        // Object literal
        case .leftBrace:
            return parseObjectLiteral()

        // Function expression
        case .function:
            return parseFunctionExpression()

        // Unary operators
        case .bang, .minus:
            advance()
            if let operand = parseExpressionWithPrecedence(.unary) {
                return .unary(op: token.lexeme, operand: operand, prefix: true)
            }
            return nil

        // Prefix increment/decrement
        case .plusPlus, .minusMinus:
            advance()
            if let operand = parseExpressionWithPrecedence(.unary) {
                return .update(op: token.lexeme, operand: operand, prefix: true)
            }
            return nil

        // typeof
        case .typeof:
            advance()
            if let operand = parseExpressionWithPrecedence(.unary) {
                return .typeof(operand)
            }
            return nil

        // new
        case .new:
            return parseNewExpression()

        default:
            errors.append(.unexpectedToken(token.type, expected: "expression", line: token.line, column: token.column))
            return nil
        }
    }

    private mutating func parseInfixExpression(_ left: Expression) -> Expression? {
        let token = peek()

        switch token.type {
        // Binary operators
        case .plus, .minus, .star, .slash, .percent:
            advance()
            let precedence = getPrecedence(token.type)
            if let right = parseExpressionWithPrecedence(Precedence(rawValue: precedence.rawValue + 1)!) {
                return .binary(left: left, op: token.lexeme, right: right)
            }

        // Comparison operators
        case .less, .lessEqual, .greater, .greaterEqual:
            advance()
            if let right = parseExpressionWithPrecedence(.term) {
                return .binary(left: left, op: token.lexeme, right: right)
            }

        // Equality operators
        case .equalEqual, .equalEqualEqual, .bangEqual, .bangEqualEqual:
            advance()
            if let right = parseExpressionWithPrecedence(.comparison) {
                return .binary(left: left, op: token.lexeme, right: right)
            }

        // Logical operators
        case .ampAmp:
            advance()
            if let right = parseExpressionWithPrecedence(.logicalAnd) {
                return .logical(left: left, op: "&&", right: right)
            }

        case .pipePipe:
            advance()
            if let right = parseExpressionWithPrecedence(.logicalOr) {
                return .logical(left: left, op: "||", right: right)
            }

        // Assignment operators
        case .equal, .plusEqual, .minusEqual, .starEqual, .slashEqual:
            advance()
            if let right = parseExpressionWithPrecedence(.assignment) {
                return .assignment(target: left, op: token.lexeme, value: right)
            }

        // Conditional (ternary)
        case .question:
            advance()
            if let consequent = parseExpression() {
                if consume(.colon, "':' in conditional") != nil {
                    if let alternate = parseExpressionWithPrecedence(.conditional) {
                        return .conditional(test: left, consequent: consequent, alternate: alternate)
                    }
                }
            }

        // Call expression
        case .leftParen:
            return parseCallExpression(left)

        // Member access
        case .dot:
            advance()
            if let nameToken = consume(.identifier, "property name") {
                return .member(object: left, property: nameToken.lexeme, computed: false)
            }

        // Computed member access
        case .leftBracket:
            advance()
            if let property = parseExpression() {
                if consume(.rightBracket, "']' after computed property") != nil {
                    // Convert property expression to string for computed access
                    let propertyString: String
                    if case .literal(.string(let s)) = property {
                        propertyString = s
                    } else if case .literal(.number(let n)) = property {
                        propertyString = String(Int(n))
                    } else if case .identifier(let name) = property {
                        // For computed access with identifier, we need to keep it as computed
                        return .member(object: left, property: name, computed: true)
                    } else {
                        propertyString = "computed"
                    }
                    return .member(object: left, property: propertyString, computed: true)
                }
            }

        // Postfix increment/decrement
        case .plusPlus, .minusMinus:
            advance()
            return .update(op: token.lexeme, operand: left, prefix: false)

        default:
            break
        }

        return nil
    }

    // MARK: - Special Expression Parsers

    private mutating func parseGroupingOrArrow() -> Expression? {
        advance() // consume '('

        // Check for arrow function: () => or (params) =>
        if check(.rightParen) {
            advance()
            if match(.arrow) {
                return parseArrowBody(params: [])
            }
            // Empty grouping - error
            return nil
        }

        // Look ahead to determine if this is an arrow function
        var isArrow = false
        var savedCurrent = current

        // Try to parse as arrow function parameters
        if check(.identifier) {
            // Could be (x) => or (x, y) =>
            var depth = 1
            while depth > 0 && current < tokens.count {
                let t = tokens[current]
                if t.type == .leftParen {
                    depth += 1
                } else if t.type == .rightParen {
                    depth -= 1
                } else if t.type == .eof {
                    break
                }
                current += 1
            }
            if current < tokens.count && tokens[current].type == .arrow {
                isArrow = true
            }
            current = savedCurrent
        }

        if isArrow {
            // Parse as arrow function parameters
            var params: [String] = []
            while !check(.rightParen) {
                if let nameToken = consume(.identifier, "parameter name") {
                    params.append(nameToken.lexeme)
                }
                if !check(.rightParen) {
                    _ = consume(.comma, "',' between parameters")
                }
            }
            _ = consume(.rightParen, "')' after parameters")
            _ = consume(.arrow, "'=>' after parameters")
            return parseArrowBody(params: params)
        }

        // Regular grouping
        if let expr = parseExpression() {
            _ = consume(.rightParen, "')' after expression")

            // Check for arrow function with single unparenthesized parameter
            if match(.arrow) {
                if case .identifier(let name) = expr {
                    return parseArrowBody(params: [name])
                }
            }

            return expr
        }

        return nil
    }

    private mutating func parseArrowBody(params: [String]) -> Expression? {
        if match(.leftBrace) {
            // Block body
            let body = parseBlock()
            return .arrowFunction(params: params, body: .block(body))
        } else {
            // Expression body
            if let expr = parseExpressionWithPrecedence(.assignment) {
                return .arrowFunction(params: params, body: .expression(expr))
            }
        }
        return nil
    }

    private mutating func parseArrayLiteral() -> Expression? {
        advance() // consume '['

        var elements: [Expression] = []

        while !check(.rightBracket) && !isAtEnd {
            if let element = parseExpressionWithPrecedence(.assignment) {
                elements.append(element)
            }

            if !check(.rightBracket) {
                _ = consume(.comma, "',' between array elements")
            }
        }

        _ = consume(.rightBracket, "']' after array elements")
        return .array(elements)
    }

    private mutating func parseObjectLiteral() -> Expression? {
        advance() // consume '{'

        var properties: [ObjectProperty] = []

        while !check(.rightBrace) && !isAtEnd {
            // Key can be identifier or string
            let key: String
            if check(.identifier) {
                key = advance().lexeme
            } else if check(.string) {
                let token = advance()
                if case .string(let s) = token.literal {
                    key = s
                } else {
                    return nil
                }
            } else {
                let token = peek()
                errors.append(.unexpectedToken(token.type, expected: "property name", line: token.line, column: token.column))
                return nil
            }

            _ = consume(.colon, "':' after property name")

            if let value = parseExpressionWithPrecedence(.assignment) {
                properties.append(ObjectProperty(key: key, value: value))
            }

            if !check(.rightBrace) {
                _ = consume(.comma, "',' between properties")
            }
        }

        _ = consume(.rightBrace, "'}' after object properties")
        return .object(properties)
    }

    private mutating func parseFunctionExpression() -> Expression? {
        advance() // consume 'function'

        var name: String? = nil
        if check(.identifier) {
            name = advance().lexeme
        }

        guard consume(.leftParen, "'(' after function") != nil else {
            return nil
        }

        var params: [String] = []
        if !check(.rightParen) {
            repeat {
                if let param = consume(.identifier, "parameter name") {
                    params.append(param.lexeme)
                }
            } while match(.comma)
        }

        guard consume(.rightParen, "')' after parameters") != nil else {
            return nil
        }

        guard consume(.leftBrace, "'{' before function body") != nil else {
            return nil
        }

        let body = parseBlock()
        return .function(name: name, params: params, body: body)
    }

    private mutating func parseCallExpression(_ callee: Expression) -> Expression? {
        advance() // consume '('

        var arguments: [Expression] = []

        if !check(.rightParen) {
            repeat {
                if let arg = parseExpressionWithPrecedence(.assignment) {
                    arguments.append(arg)
                }
            } while match(.comma)
        }

        _ = consume(.rightParen, "')' after arguments")
        return .call(callee: callee, arguments: arguments)
    }

    private mutating func parseNewExpression() -> Expression? {
        advance() // consume 'new'

        guard let callee = parsePrefixExpression() else {
            return nil
        }

        var arguments: [Expression] = []
        if match(.leftParen) {
            if !check(.rightParen) {
                repeat {
                    if let arg = parseExpressionWithPrecedence(.assignment) {
                        arguments.append(arg)
                    }
                } while match(.comma)
            }
            _ = consume(.rightParen, "')' after arguments")
        }

        return .new(callee: callee, arguments: arguments)
    }

    // MARK: - Precedence

    private func getPrecedence(_ type: TokenType) -> Precedence {
        switch type {
        case .equal, .plusEqual, .minusEqual, .starEqual, .slashEqual:
            return .assignment
        case .question:
            return .conditional
        case .pipePipe:
            return .logicalOr
        case .ampAmp:
            return .logicalAnd
        case .equalEqual, .equalEqualEqual, .bangEqual, .bangEqualEqual:
            return .equality
        case .less, .lessEqual, .greater, .greaterEqual:
            return .comparison
        case .plus, .minus:
            return .term
        case .star, .slash, .percent:
            return .factor
        case .leftParen, .leftBracket, .dot:
            return .call
        case .plusPlus, .minusMinus:
            return .unary
        default:
            return .none
        }
    }

    // MARK: - Error Recovery

    private mutating func synchronize() {
        advance()

        while !isAtEnd {
            if previous().type == .semicolon {
                return
            }

            switch peek().type {
            case .function, .var, .let, .const, .for, .if, .while, .return:
                return
            default:
                advance()
            }
        }
    }
}

// Helper to create a precedence from raw value
extension Precedence {
    init?(rawValue: Int) {
        switch rawValue {
        case 0: self = .none
        case 1: self = .assignment
        case 2: self = .conditional
        case 3: self = .logicalOr
        case 4: self = .logicalAnd
        case 5: self = .equality
        case 6: self = .comparison
        case 7: self = .term
        case 8: self = .factor
        case 9: self = .unary
        case 10: self = .call
        case 11: self = .primary
        default: return nil
        }
    }
}
