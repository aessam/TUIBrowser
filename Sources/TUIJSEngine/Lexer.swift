// TUIJSEngine - JavaScript Lexer

import TUICore

/// Error types for the lexer
public enum LexerError: TUIError {
    case unexpectedCharacter(Character, line: Int, column: Int)
    case unterminatedString(line: Int, column: Int)
    case invalidNumber(String, line: Int, column: Int)

    public var description: String {
        switch self {
        case .unexpectedCharacter(let char, let line, let column):
            return "Unexpected character '\(char)' at line \(line), column \(column)"
        case .unterminatedString(let line, let column):
            return "Unterminated string starting at line \(line), column \(column)"
        case .invalidNumber(let str, let line, let column):
            return "Invalid number '\(str)' at line \(line), column \(column)"
        }
    }
}

/// JavaScript lexer that tokenizes source code
public struct Lexer {
    private let source: String
    private var sourceArray: [Character]
    private var current: Int = 0
    private var start: Int = 0
    private var line: Int = 1
    private var column: Int = 1
    private var startColumn: Int = 1
    private var tokens: [Token] = []
    private var errors: [LexerError] = []

    public init(source: String) {
        self.source = source
        self.sourceArray = Array(source)
    }

    /// Scan all tokens from the source
    public mutating func scanTokens() -> [Token] {
        tokens = []
        errors = []

        while !isAtEnd {
            start = current
            startColumn = column
            scanToken()
        }

        tokens.append(Token(type: .eof, lexeme: "", line: line, column: column))
        return tokens
    }

    /// Get any errors that occurred during scanning
    public var lexerErrors: [LexerError] {
        errors
    }

    // MARK: - Private helpers

    private var isAtEnd: Bool {
        current >= sourceArray.count
    }

    private mutating func advance() -> Character {
        let char = sourceArray[current]
        current += 1
        column += 1
        return char
    }

    private func peek() -> Character {
        guard !isAtEnd else { return "\0" }
        return sourceArray[current]
    }

    private func peekNext() -> Character {
        guard current + 1 < sourceArray.count else { return "\0" }
        return sourceArray[current + 1]
    }

    private mutating func match(_ expected: Character) -> Bool {
        guard !isAtEnd else { return false }
        guard sourceArray[current] == expected else { return false }
        current += 1
        column += 1
        return true
    }

    private var currentLexeme: String {
        String(sourceArray[start..<current])
    }

    private mutating func addToken(_ type: TokenType, literal: TokenLiteral? = nil) {
        tokens.append(Token(
            type: type,
            lexeme: currentLexeme,
            literal: literal,
            line: line,
            column: startColumn
        ))
    }

    // MARK: - Scanning

    private mutating func scanToken() {
        let char = advance()

        switch char {
        // Single-character tokens
        case "(": addToken(.leftParen)
        case ")": addToken(.rightParen)
        case "{": addToken(.leftBrace)
        case "}": addToken(.rightBrace)
        case "[": addToken(.leftBracket)
        case "]": addToken(.rightBracket)
        case ",": addToken(.comma)
        case ".": addToken(.dot)
        case ";": addToken(.semicolon)
        case ":": addToken(.colon)
        case "?": addToken(.question)

        // Operators that can be one or two characters
        case "+":
            if match("+") {
                addToken(.plusPlus)
            } else if match("=") {
                addToken(.plusEqual)
            } else {
                addToken(.plus)
            }
        case "-":
            if match("-") {
                addToken(.minusMinus)
            } else if match("=") {
                addToken(.minusEqual)
            } else {
                addToken(.minus)
            }
        case "*":
            if match("=") {
                addToken(.starEqual)
            } else {
                addToken(.star)
            }
        case "/":
            if match("/") {
                // Single-line comment
                while peek() != "\n" && !isAtEnd {
                    _ = advance()
                }
            } else if match("*") {
                // Multi-line comment
                scanMultiLineComment()
            } else if match("=") {
                addToken(.slashEqual)
            } else {
                addToken(.slash)
            }
        case "%": addToken(.percent)

        case "=":
            if match("=") {
                if match("=") {
                    addToken(.equalEqualEqual)
                } else {
                    addToken(.equalEqual)
                }
            } else if match(">") {
                addToken(.arrow)
            } else {
                addToken(.equal)
            }
        case "!":
            if match("=") {
                if match("=") {
                    addToken(.bangEqualEqual)
                } else {
                    addToken(.bangEqual)
                }
            } else {
                addToken(.bang)
            }
        case "<":
            if match("=") {
                addToken(.lessEqual)
            } else {
                addToken(.less)
            }
        case ">":
            if match("=") {
                addToken(.greaterEqual)
            } else {
                addToken(.greater)
            }
        case "&":
            if match("&") {
                addToken(.ampAmp)
            } else {
                errors.append(.unexpectedCharacter(char, line: line, column: startColumn))
            }
        case "|":
            if match("|") {
                addToken(.pipePipe)
            } else {
                errors.append(.unexpectedCharacter(char, line: line, column: startColumn))
            }

        // Whitespace
        case " ", "\r", "\t":
            break
        case "\n":
            line += 1
            column = 1

        // Strings
        case "\"", "'":
            scanString(terminator: char)

        default:
            if char.isNumber {
                scanNumber()
            } else if char.isLetter || char == "_" || char == "$" {
                scanIdentifier()
            } else {
                errors.append(.unexpectedCharacter(char, line: line, column: startColumn))
            }
        }
    }

    private mutating func scanMultiLineComment() {
        while !isAtEnd {
            if peek() == "*" && peekNext() == "/" {
                _ = advance() // consume *
                _ = advance() // consume /
                return
            }
            if peek() == "\n" {
                line += 1
                column = 0
            }
            _ = advance()
        }
        // Unterminated comment - we just ignore it
    }

    private mutating func scanString(terminator: Character) {
        let startLine = line
        let startCol = startColumn

        while peek() != terminator && !isAtEnd {
            if peek() == "\n" {
                line += 1
                column = 0
            }
            if peek() == "\\" && !isAtEnd {
                _ = advance() // consume backslash
                if !isAtEnd {
                    _ = advance() // consume escaped character
                }
            } else {
                _ = advance()
            }
        }

        if isAtEnd {
            errors.append(.unterminatedString(line: startLine, column: startCol))
            return
        }

        // Consume the closing quote
        _ = advance()

        // Extract the string value (without quotes)
        let value = processEscapeSequences(String(sourceArray[(start + 1)..<(current - 1)]))
        addToken(.string, literal: .string(value))
    }

    private func processEscapeSequences(_ str: String) -> String {
        var result = ""
        let chars = Array(str)
        var i = 0

        while i < chars.count {
            if chars[i] == "\\" && i + 1 < chars.count {
                i += 1
                switch chars[i] {
                case "n": result.append("\n")
                case "t": result.append("\t")
                case "r": result.append("\r")
                case "\\": result.append("\\")
                case "\"": result.append("\"")
                case "'": result.append("'")
                case "0": result.append("\0")
                default: result.append(chars[i])
                }
            } else {
                result.append(chars[i])
            }
            i += 1
        }

        return result
    }

    private mutating func scanNumber() {
        while peek().isNumber {
            _ = advance()
        }

        // Look for fractional part
        if peek() == "." && peekNext().isNumber {
            _ = advance() // consume .
            while peek().isNumber {
                _ = advance()
            }
        }

        // Look for exponent
        if peek() == "e" || peek() == "E" {
            _ = advance()
            if peek() == "+" || peek() == "-" {
                _ = advance()
            }
            while peek().isNumber {
                _ = advance()
            }
        }

        let lexeme = currentLexeme
        if let value = Double(lexeme) {
            addToken(.number, literal: .number(value))
        } else {
            errors.append(.invalidNumber(lexeme, line: line, column: startColumn))
        }
    }

    private mutating func scanIdentifier() {
        while peek().isLetter || peek().isNumber || peek() == "_" || peek() == "$" {
            _ = advance()
        }

        let text = currentLexeme

        // Check if it's a keyword
        if let keywordType = jsKeywords[text] {
            switch keywordType {
            case .true:
                addToken(.true, literal: .boolean(true))
            case .false:
                addToken(.false, literal: .boolean(false))
            default:
                addToken(keywordType)
            }
        } else {
            addToken(.identifier)
        }
    }
}
