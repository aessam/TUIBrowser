// TUICSSParser - CSS Token Types

/// Represents a CSS token produced by the tokenizer
public enum CSSToken: Equatable, Sendable {
    /// An identifier (e.g., "color", "div", "background-color")
    case ident(String)

    /// A hash token (e.g., "#myId", "#FF0000")
    case hash(String)

    /// A string token (e.g., "hello world")
    case string(String)

    /// A numeric value
    case number(Double)

    /// A percentage value (e.g., 50%)
    case percentage(Double)

    /// A dimension value with unit (e.g., 10px, 1.5em)
    case dimension(Double, String)

    /// A function token (identifier followed by '(')
    case function(String)

    /// Colon (:)
    case colon

    /// Semicolon (;)
    case semicolon

    /// Comma (,)
    case comma

    /// Left brace ({)
    case leftBrace

    /// Right brace (})
    case rightBrace

    /// Left parenthesis (()
    case leftParen

    /// Right parenthesis ())
    case rightParen

    /// Left bracket ([)
    case leftBracket

    /// Right bracket (])
    case rightBracket

    /// At-keyword (e.g., @media, @import)
    case atKeyword(String)

    /// A delimiter character (e.g., *, ., >, +, ~, !)
    case delim(String)

    /// Whitespace (spaces, tabs, newlines)
    case whitespace

    /// End of file
    case eof
}

extension CSSToken: CustomStringConvertible {
    public var description: String {
        switch self {
        case .ident(let value):
            return "IDENT(\(value))"
        case .hash(let value):
            return "HASH(\(value))"
        case .string(let value):
            return "STRING(\(value))"
        case .number(let value):
            return "NUMBER(\(value))"
        case .percentage(let value):
            return "PERCENTAGE(\(value)%)"
        case .dimension(let value, let unit):
            return "DIMENSION(\(value)\(unit))"
        case .function(let name):
            return "FUNCTION(\(name))"
        case .colon:
            return "COLON"
        case .semicolon:
            return "SEMICOLON"
        case .comma:
            return "COMMA"
        case .leftBrace:
            return "LEFT_BRACE"
        case .rightBrace:
            return "RIGHT_BRACE"
        case .leftParen:
            return "LEFT_PAREN"
        case .rightParen:
            return "RIGHT_PAREN"
        case .leftBracket:
            return "LEFT_BRACKET"
        case .rightBracket:
            return "RIGHT_BRACKET"
        case .atKeyword(let value):
            return "AT_KEYWORD(\(value))"
        case .delim(let char):
            return "DELIM(\(char))"
        case .whitespace:
            return "WHITESPACE"
        case .eof:
            return "EOF"
        }
    }
}
