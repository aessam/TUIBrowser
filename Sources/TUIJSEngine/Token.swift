// TUIJSEngine - Token types for JavaScript lexer

import TUICore

/// All token types recognized by the JavaScript lexer
public enum TokenType: Sendable, Equatable {
    // Literals
    case number
    case string
    case boolean
    case null
    case undefined
    case identifier

    // Operators
    case plus           // +
    case minus          // -
    case star           // *
    case slash          // /
    case percent        // %
    case equal          // =
    case equalEqual     // ==
    case equalEqualEqual // ===
    case bang           // !
    case bangEqual      // !=
    case bangEqualEqual // !==
    case less           // <
    case lessEqual      // <=
    case greater        // >
    case greaterEqual   // >=
    case ampAmp         // &&
    case pipePipe       // ||
    case plusEqual      // +=
    case minusEqual     // -=
    case starEqual      // *=
    case slashEqual     // /=
    case plusPlus       // ++
    case minusMinus     // --

    // Delimiters
    case leftParen      // (
    case rightParen     // )
    case leftBrace      // {
    case rightBrace     // }
    case leftBracket    // [
    case rightBracket   // ]
    case comma          // ,
    case dot            // .
    case colon          // :
    case semicolon      // ;
    case question       // ?
    case arrow          // =>

    // Keywords
    case `var`
    case `let`
    case `const`
    case `function`
    case `return`
    case `if`
    case `else`
    case `for`
    case `while`
    case `break`
    case `continue`
    case `true`
    case `false`
    case `new`
    case `typeof`
    case `instanceof`
    case `this`

    case eof
}

/// Represents a literal value in a token
public enum TokenLiteral: Sendable, Equatable {
    case number(Double)
    case string(String)
    case boolean(Bool)
}

/// A single token from the JavaScript source code
public struct Token: Sendable, Equatable {
    public let type: TokenType
    public let lexeme: String
    public let literal: TokenLiteral?
    public let line: Int
    public let column: Int

    public init(type: TokenType, lexeme: String, literal: TokenLiteral? = nil, line: Int, column: Int) {
        self.type = type
        self.lexeme = lexeme
        self.literal = literal
        self.line = line
        self.column = column
    }
}

/// Keywords mapping
public let jsKeywords: [String: TokenType] = [
    "var": .var,
    "let": .let,
    "const": .const,
    "function": .function,
    "return": .return,
    "if": .if,
    "else": .else,
    "for": .for,
    "while": .while,
    "break": .break,
    "continue": .continue,
    "true": .true,
    "false": .false,
    "new": .new,
    "typeof": .typeof,
    "instanceof": .instanceof,
    "this": .this,
    "null": .null,
    "undefined": .undefined
]
