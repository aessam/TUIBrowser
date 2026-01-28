// TUICSSParser - High-level CSS Parser API

import TUICore
import Foundation

/// High-level CSS parser providing static methods for parsing CSS
public struct CSSParser: Sendable {

    // MARK: - Public API

    /// Parse a complete CSS stylesheet
    public static func parseStylesheet(_ css: String) -> Stylesheet {
        var parser = CSSParserImpl(css)
        return parser.parseStylesheet()
    }

    /// Parse a single selector string
    public static func parseSelector(_ selector: String) -> Selector? {
        var parser = CSSParserImpl(selector)
        return parser.parseSelector()
    }

    /// Parse a declaration block (without braces)
    public static func parseDeclarations(_ declarations: String) -> [CSSDeclaration] {
        var parser = CSSParserImpl(declarations)
        return parser.parseDeclarations()
    }
}

// MARK: - Internal Parser Implementation

private struct CSSParserImpl {
    private var tokens: [CSSToken]
    private var index: Int = 0

    init(_ css: String) {
        var tokenizer = CSSTokenizer(css)
        self.tokens = tokenizer.tokenize()
    }

    // MARK: - Token Navigation

    private var currentToken: CSSToken {
        guard index < tokens.count else { return .eof }
        return tokens[index]
    }

    private var isAtEnd: Bool {
        if case .eof = currentToken { return true }
        return index >= tokens.count
    }

    private mutating func advance() {
        if index < tokens.count {
            index += 1
        }
    }

    private mutating func skipWhitespace() {
        while case .whitespace = currentToken {
            advance()
        }
    }

    private func peek(offset: Int = 1) -> CSSToken {
        let targetIndex = index + offset
        guard targetIndex < tokens.count else { return .eof }
        return tokens[targetIndex]
    }

    // MARK: - Stylesheet Parsing

    mutating func parseStylesheet() -> Stylesheet {
        var rules: [CSSRule] = []

        skipWhitespace()

        var iterations = 0
        // Prevent runaway parsing on pathological CSS: cap work to 5x tokens, max 500k steps.
        let iterationLimit = min(500_000, max(100_000, tokens.count * 5))
        let deadline = Date().addingTimeInterval(1.5) // wall-clock cap

        while !isAtEnd && iterations < iterationLimit {
            if Date() >= deadline {
                break
            }
            let startIndex = index  // Track position before parsing

            if let rule = parseRule() {
                rules.append(rule)
            }

            // If we didn't advance, skip the current token to avoid infinite loop
            if index == startIndex && !isAtEnd {
                advance()
            }

            skipWhitespace()
            iterations += 1
        }

        return Stylesheet(rules: rules)
    }

    private mutating func parseRule() -> CSSRule? {
        skipWhitespace()

        // Parse selectors (comma-separated)
        var selectors: [Selector] = []

        while !isAtEnd {
            skipWhitespace()

            if case .leftBrace = currentToken {
                break
            }

            if let selector = parseSelector() {
                selectors.append(selector)
            }

            skipWhitespace()

            if case .comma = currentToken {
                advance() // skip comma
            } else if case .leftBrace = currentToken {
                break
            } else {
                // Unexpected token, try to recover
                break
            }
        }

        guard !selectors.isEmpty else { return nil }

        // Expect left brace
        skipWhitespace()
        guard case .leftBrace = currentToken else { return nil }
        advance()

        // Parse declarations
        let declarations = parseDeclarationsUntilBrace()

        // Expect right brace
        skipWhitespace()
        if case .rightBrace = currentToken {
            advance()
        }

        return CSSRule(selectors: selectors, declarations: declarations)
    }

    private mutating func parseDeclarationsUntilBrace() -> [CSSDeclaration] {
        var declarations: [CSSDeclaration] = []

        while !isAtEnd {
            skipWhitespace()

            if case .rightBrace = currentToken {
                break
            }

            if let decl = parseDeclaration() {
                declarations.append(decl)
            } else {
                // Failed to parse declaration - skip to next semicolon or brace to recover
                skipToDeclarationEnd()
            }

            skipWhitespace()

            // Optional semicolon
            if case .semicolon = currentToken {
                advance()
            }
        }

        return declarations
    }

    /// Skip tokens until we reach a semicolon or right brace (for error recovery)
    private mutating func skipToDeclarationEnd() {
        while !isAtEnd {
            switch currentToken {
            case .semicolon, .rightBrace, .eof:
                return
            default:
                advance()
            }
        }
    }

    // MARK: - Selector Parsing

    mutating func parseSelector() -> Selector? {
        var components: [(SimpleSelector, Combinator?)] = []

        skipWhitespace()

        guard let firstSimple = parseSimpleSelector() else { return nil }

        var currentSimple = firstSimple

        while !isAtEnd {
            // Check for combinator or end of selector
            let hasWhitespace = (currentToken == .whitespace)
            if hasWhitespace {
                skipWhitespace()
            }

            // Check for end conditions
            if case .leftBrace = currentToken { break }
            if case .comma = currentToken { break }
            if case .eof = currentToken { break }

            // Check for explicit combinators
            var combinator: Combinator? = nil

            if case .delim(let d) = currentToken {
                switch d {
                case ">":
                    combinator = .child
                    advance()
                    skipWhitespace()
                case "+":
                    combinator = .adjacentSibling
                    advance()
                    skipWhitespace()
                case "~":
                    combinator = .generalSibling
                    advance()
                    skipWhitespace()
                default:
                    break
                }
            }

            // If no explicit combinator but had whitespace, it's a descendant
            if combinator == nil && hasWhitespace {
                combinator = .descendant
            }

            // Try to parse next simple selector
            if let nextSimple = parseSimpleSelector() {
                // Save current with combinator
                components.append((currentSimple, combinator ?? .descendant))
                currentSimple = nextSimple
            } else {
                break
            }
        }

        // Add the last simple selector (no combinator after it)
        components.append((currentSimple, nil))

        let specificity = Selector.calculateSpecificity(from: components)
        return Selector(components: components, specificity: specificity)
    }

    private mutating func parseSimpleSelector() -> SimpleSelector? {
        var tagName: String? = nil
        var id: String? = nil
        var classes: [String] = []

        // Universal selector
        if case .delim("*") = currentToken {
            tagName = "*"
            advance()
        }
        // Type selector
        else if case .ident(let name) = currentToken {
            tagName = name
            advance()
        }

        // Parse class and ID parts
        while !isAtEnd {
            // Class selector
            if case .delim(".") = currentToken {
                advance()
                if case .ident(let className) = currentToken {
                    classes.append(className)
                    advance()
                }
            }
            // ID selector
            else if case .hash(let idName) = currentToken {
                id = idName
                advance()
            }
            else {
                break
            }
        }

        // Must have at least something
        if tagName == nil && id == nil && classes.isEmpty {
            return nil
        }

        return SimpleSelector(tagName: tagName, id: id, classes: classes)
    }

    // MARK: - Declaration Parsing

    mutating func parseDeclarations() -> [CSSDeclaration] {
        var declarations: [CSSDeclaration] = []

        while !isAtEnd {
            skipWhitespace()

            if let decl = parseDeclaration() {
                declarations.append(decl)
            }

            skipWhitespace()

            // Optional semicolon
            if case .semicolon = currentToken {
                advance()
            }

            // Check for end
            if case .eof = currentToken { break }
            if case .rightBrace = currentToken { break }
        }

        return declarations
    }

    private mutating func parseDeclaration() -> CSSDeclaration? {
        skipWhitespace()

        // Property name
        guard case .ident(let property) = currentToken else { return nil }
        advance()

        skipWhitespace()

        // Colon
        guard case .colon = currentToken else { return nil }
        advance()

        skipWhitespace()

        // Value
        guard let value = parseValue() else { return nil }

        skipWhitespace()

        // Check for !important
        var important = false
        if case .delim("!") = currentToken {
            advance()
            if case .ident(let keyword) = currentToken, keyword.lowercased() == "important" {
                important = true
                advance()
            }
        }

        return CSSDeclaration(property: property, value: value, important: important)
    }

    private mutating func parseValue() -> CSSValue? {
        var values: [CSSValue] = []

        while !isAtEnd {
            // Check for terminators
            if case .semicolon = currentToken { break }
            if case .rightBrace = currentToken { break }
            if case .delim("!") = currentToken { break }

            if let val = parseComponentValue() {
                values.append(val)
            } else {
                break
            }

            skipWhitespace()

            // Handle commas in value lists (e.g. font-family)
            if case .comma = currentToken {
                advance()
                skipWhitespace()
            }
        }

        if values.isEmpty { return nil }
        if values.count == 1 { return values[0] }
        return .list(values)
    }

    private mutating func parseComponentValue() -> CSSValue? {
        skipWhitespace()

        switch currentToken {
        case .ident(let keyword):
            advance()
            // Check for special keywords
            switch keyword.lowercased() {
            case "inherit":
                return .inherit
            case "initial":
                return .initial
            case "unset":
                return .unset
            default:
                return .keyword(keyword)
            }

        case .hash(let hexValue):
            advance()
            // Try to parse as color
            if let color = Color.fromHex(hexValue) {
                return .color(color)
            }
            return .keyword("#\(hexValue)")

        case .string(let str):
            advance()
            return .string(str)

        case .number(let num):
            advance()
            return .number(num)

        case .percentage(let num):
            advance()
            return .percentage(num)

        case .dimension(let num, let unit):
            advance()
            if let lengthUnit = LengthUnit(from: unit) {
                return .length(num, lengthUnit)
            }
            // Unknown unit, treat as keyword
            return .keyword("\(num)\(unit)")

        case .function(let name):
            // For now, skip function contents
            advance()
            skipFunctionContents()
            return .keyword("\(name)(...)")

        default:
            return nil
        }
    }

    private mutating func skipFunctionContents() {
        var depth = 1
        while !isAtEnd && depth > 0 {
            switch currentToken {
            case .leftParen:
                depth += 1
            case .rightParen:
                depth -= 1
            default:
                break
            }
            advance()
        }
    }
}

// Keep backward compatibility with existing placeholder
extension TUICSSParser {
    /// Parse a complete CSS stylesheet
    public static func parseStylesheet(_ css: String) -> Stylesheet {
        CSSParser.parseStylesheet(css)
    }

    /// Parse a single selector string
    public static func parseSelector(_ selector: String) -> Selector? {
        CSSParser.parseSelector(selector)
    }

    /// Parse a declaration block (without braces)
    public static func parseDeclarations(_ declarations: String) -> [CSSDeclaration] {
        CSSParser.parseDeclarations(declarations)
    }
}
