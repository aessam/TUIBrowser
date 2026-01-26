// TUIJSEngine - Abstract Syntax Tree

import TUICore

/// A variable declaration binding (name and optional initializer)
public struct VariableBinding: Sendable, Equatable {
    public let name: String
    public let initializer: Expression?

    public init(name: String, initializer: Expression?) {
        self.name = name
        self.initializer = initializer
    }
}

/// An object property (key-value pair)
public struct ObjectProperty: Sendable, Equatable {
    public let key: String
    public let value: Expression

    public init(key: String, value: Expression) {
        self.key = key
        self.value = value
    }
}

/// Literal values in JavaScript
public enum LiteralValue: Sendable, Equatable {
    case number(Double)
    case string(String)
    case boolean(Bool)
    case null
    case undefined
}

/// Arrow function body can be either an expression or a block
public enum ArrowBody: Sendable, Equatable {
    case expression(Expression)
    case block([Statement])
}

/// Variable declaration kind
public enum VarKind: String, Sendable, Equatable {
    case `var`
    case `let`
    case `const`
}

/// JavaScript expressions
public indirect enum Expression: Sendable, Equatable {
    /// Literal value (number, string, boolean, null, undefined)
    case literal(LiteralValue)

    /// Variable reference
    case identifier(String)

    /// Binary operation: left op right
    case binary(left: Expression, op: String, right: Expression)

    /// Unary operation: op operand (prefix) or operand op (postfix)
    case unary(op: String, operand: Expression, prefix: Bool)

    /// Function call: callee(arguments)
    case call(callee: Expression, arguments: [Expression])

    /// Member access: object.property or object[property]
    case member(object: Expression, property: String, computed: Bool)

    /// Assignment: target = value (or +=, -=, etc.)
    case assignment(target: Expression, op: String, value: Expression)

    /// Array literal: [elements]
    case array([Expression])

    /// Object literal: { key: value, ... }
    case object([ObjectProperty])

    /// Function expression: function name?(params) { body }
    case function(name: String?, params: [String], body: [Statement])

    /// Arrow function: (params) => body
    case arrowFunction(params: [String], body: ArrowBody)

    /// Conditional (ternary): test ? consequent : alternate
    case conditional(test: Expression, consequent: Expression, alternate: Expression)

    /// this keyword
    case `this`

    /// new expression: new callee(arguments)
    case new(callee: Expression, arguments: [Expression])

    /// typeof expression
    case typeof(Expression)

    /// Update expression: ++x, x++, --x, x--
    case update(op: String, operand: Expression, prefix: Bool)

    /// Logical expression (short-circuit): && or ||
    case logical(left: Expression, op: String, right: Expression)
}

/// JavaScript statements
public indirect enum Statement: Sendable, Equatable {
    /// Expression statement
    case expression(Expression)

    /// Variable declaration: var/let/const name = init
    case variableDeclaration(kind: VarKind, declarations: [VariableBinding])

    /// Block statement: { statements }
    case block([Statement])

    /// If statement: if (test) consequent else alternate
    case ifStatement(test: Expression, consequent: Statement, alternate: Statement?)

    /// For statement: for (init; test; update) body
    case forStatement(init: ForInit?, test: Expression?, update: Expression?, body: Statement)

    /// While statement: while (test) body
    case whileStatement(test: Expression, body: Statement)

    /// Return statement: return expression?
    case returnStatement(Expression?)

    /// Break statement
    case breakStatement

    /// Continue statement
    case continueStatement

    /// Function declaration: function name(params) { body }
    case functionDeclaration(name: String, params: [String], body: [Statement])

    /// Empty statement (just a semicolon)
    case empty
}

/// For loop initializer can be a variable declaration or an expression
public enum ForInit: Sendable, Equatable {
    case declaration(kind: VarKind, declarations: [VariableBinding])
    case expression(Expression)
}

/// Program is a collection of statements
public struct Program: Sendable, Equatable {
    public let statements: [Statement]

    public init(statements: [Statement]) {
        self.statements = statements
    }
}
