// TUICSSParser - CSS Tokenizer

import Foundation

/// Tokenizes CSS input into a sequence of tokens
public struct CSSTokenizer: Sendable {
    private let input: String
    private var index: String.Index
    private let endIndex: String.Index

    public init(_ input: String) {
        self.input = input
        self.index = input.startIndex
        self.endIndex = input.endIndex
    }

    /// Tokenize the entire input and return all tokens
    public mutating func tokenize() -> [CSSToken] {
        var tokens: [CSSToken] = []

        while let token = nextToken() {
            tokens.append(token)
            if case .eof = token {
                break
            }
        }

        return tokens
    }

    /// Get the next token from the input
    public mutating func nextToken() -> CSSToken? {
        skipComments()

        guard !isAtEnd else {
            return .eof
        }

        let char = currentChar

        // Whitespace
        if char.isWhitespace {
            return consumeWhitespace()
        }

        // String (double or single quoted)
        if char == "\"" || char == "'" {
            return consumeString(quote: char)
        }

        // Hash
        if char == "#" {
            advance()
            let name = consumeName()
            return .hash(name)
        }

        // At-keyword
        if char == "@" {
            advance()
            let name = consumeName()
            return .atKeyword(name)
        }

        // Number, percentage, or dimension
        if char.isNumber || (char == "-" && peekNext?.isNumber == true) ||
           (char == "." && peekNext?.isNumber == true) ||
           (char == "-" && peekNext == "." && peek(offset: 2)?.isNumber == true) {
            return consumeNumeric()
        }

        // Identifier or function
        if isNameStart(char) {
            return consumeIdentOrFunction()
        }

        // Single character tokens
        switch char {
        case ":":
            advance()
            return .colon
        case ";":
            advance()
            return .semicolon
        case ",":
            advance()
            return .comma
        case "{":
            advance()
            return .leftBrace
        case "}":
            advance()
            return .rightBrace
        case "(":
            advance()
            return .leftParen
        case ")":
            advance()
            return .rightParen
        case "[":
            advance()
            return .leftBracket
        case "]":
            advance()
            return .rightBracket
        default:
            // Generic delimiter
            advance()
            return .delim(String(char))
        }
    }

    // MARK: - Helper Properties

    private var isAtEnd: Bool {
        index >= endIndex
    }

    private var currentChar: Character {
        input[index]
    }

    private var peekNext: Character? {
        let nextIndex = input.index(after: index)
        guard nextIndex < endIndex else { return nil }
        return input[nextIndex]
    }

    private func peek(offset: Int) -> Character? {
        var idx = index
        for _ in 0..<offset {
            guard idx < endIndex else { return nil }
            idx = input.index(after: idx)
        }
        guard idx < endIndex else { return nil }
        return input[idx]
    }

    // MARK: - Helper Methods

    private mutating func advance() {
        if index < endIndex {
            index = input.index(after: index)
        }
    }

    private func isNameStart(_ char: Character) -> Bool {
        char.isLetter || char == "_" || char == "-"
    }

    private func isNameChar(_ char: Character) -> Bool {
        char.isLetter || char.isNumber || char == "_" || char == "-"
    }

    private mutating func skipComments() {
        while !isAtEnd {
            // Check for block comments /* ... */
            if currentChar == "/" && peekNext == "*" {
                advance() // skip /
                advance() // skip *

                while !isAtEnd {
                    if currentChar == "*" && peekNext == "/" {
                        advance() // skip *
                        advance() // skip /
                        break
                    }
                    advance()
                }

                // After skipping a comment, skip any trailing whitespace
                while !isAtEnd && currentChar.isWhitespace {
                    advance()
                }
                // Continue loop to check for more comments
            } else {
                break
            }
        }
    }

    private mutating func consumeWhitespace() -> CSSToken {
        while !isAtEnd && currentChar.isWhitespace {
            advance()
        }
        return .whitespace
    }

    private mutating func consumeName() -> String {
        var name = ""
        while !isAtEnd && isNameChar(currentChar) {
            name.append(currentChar)
            advance()
        }
        return name
    }

    private mutating func consumeString(quote: Character) -> CSSToken {
        advance() // skip opening quote
        var value = ""

        while !isAtEnd && currentChar != quote {
            if currentChar == "\\" {
                advance() // skip backslash
                if !isAtEnd {
                    value.append(currentChar)
                    advance()
                }
            } else {
                value.append(currentChar)
                advance()
            }
        }

        if !isAtEnd {
            advance() // skip closing quote
        }

        return .string(value)
    }

    private mutating func consumeNumeric() -> CSSToken {
        var numStr = ""

        // Handle negative sign
        if currentChar == "-" {
            numStr.append(currentChar)
            advance()
        }

        // Integer part
        while !isAtEnd && currentChar.isNumber {
            numStr.append(currentChar)
            advance()
        }

        // Decimal part
        if !isAtEnd && currentChar == "." && peekNext?.isNumber == true {
            numStr.append(currentChar)
            advance()
            while !isAtEnd && currentChar.isNumber {
                numStr.append(currentChar)
                advance()
            }
        }

        let value = Double(numStr) ?? 0.0

        // Check for percentage
        if !isAtEnd && currentChar == "%" {
            advance()
            return .percentage(value)
        }

        // Check for dimension unit
        if !isAtEnd && isNameStart(currentChar) {
            let unit = consumeName()
            return .dimension(value, unit)
        }

        return .number(value)
    }

    private mutating func consumeIdentOrFunction() -> CSSToken {
        let name = consumeName()

        // Check if followed by '(' - makes it a function
        if !isAtEnd && currentChar == "(" {
            advance() // consume the '('
            return .function(name)
        }

        return .ident(name)
    }
}
