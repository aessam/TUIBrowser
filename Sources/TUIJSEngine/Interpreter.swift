// TUIJSEngine - JavaScript Interpreter
//
// Executes JavaScript AST by walking the tree and evaluating expressions/statements.

import Foundation

// MARK: - Control Flow

/// Control flow signals for return, break, continue
public enum ControlFlow: Sendable {
    case none
    case `return`(JSValue)
    case `break`
    case `continue`
}

// MARK: - Interpreter

/// JavaScript interpreter
public final class Interpreter: @unchecked Sendable {
    /// Global scope
    public let globalScope: Scope

    /// Current scope
    private var currentScope: Scope

    /// Console output handler
    public var consoleOutput: (@Sendable (String) -> Void)?

    /// Maximum recursion depth
    public let maxCallDepth: Int

    /// Current call depth
    private var callDepth: Int = 0

    private let lock = NSLock()

    // MARK: - Initialization

    public init(maxCallDepth: Int = 1000) {
        self.maxCallDepth = maxCallDepth
        self.globalScope = Scope.createGlobal()
        self.currentScope = globalScope
    }

    // MARK: - Public API

    /// Execute a program (list of statements)
    /// - Parameter program: The program to execute
    /// - Returns: The result of the last statement
    /// - Throws: JSError if execution fails
    @discardableResult
    public func execute(_ program: Program) throws -> JSValue {
        return try execute(program.statements)
    }

    /// Execute a list of statements
    /// - Parameter statements: The statements to execute
    /// - Returns: The result of the last statement
    /// - Throws: JSError if execution fails
    @discardableResult
    public func execute(_ statements: [Statement]) throws -> JSValue {
        var result: JSValue = .undefined

        for statement in statements {
            let (value, flow) = try executeStatement(statement)
            result = value

            switch flow {
            case .return(let retVal):
                return retVal
            case .break, .continue:
                return result
            case .none:
                continue
            }
        }

        return result
    }

    /// Evaluate a single expression
    /// - Parameter expression: The expression to evaluate
    /// - Returns: The result value
    /// - Throws: JSError if evaluation fails
    public func evaluate(_ expression: Expression) throws -> JSValue {
        return try evaluateExpression(expression)
    }

    /// Get a global variable
    public func getGlobal(_ name: String) -> JSValue? {
        return try? globalScope.get(name)
    }

    /// Set a global variable
    public func setGlobal(_ name: String, value: JSValue) {
        try? globalScope.declare(name, value: value, kind: .var)
    }

    // MARK: - Statement Execution

    private func executeStatement(_ statement: Statement) throws -> (JSValue, ControlFlow) {
        switch statement {
        case .expression(let expr):
            let value = try evaluateExpression(expr)
            return (value, .none)

        case .variableDeclaration(let kind, let declarations):
            for decl in declarations {
                let value: JSValue
                if let initializer = decl.initializer {
                    value = try evaluateExpression(initializer)
                } else {
                    value = .undefined
                }
                try currentScope.declare(decl.name, value: value, kind: kind)
            }
            return (.undefined, .none)

        case .block(let statements):
            // Create a new block scope
            let previousScope = currentScope
            currentScope = previousScope.createBlockScope()
            defer { currentScope = previousScope }

            for stmt in statements {
                let (_, flow) = try executeStatement(stmt)
                if case .return = flow { return (.undefined, flow) }
                if case .break = flow { return (.undefined, flow) }
                if case .continue = flow { return (.undefined, flow) }
            }
            return (.undefined, .none)

        case .ifStatement(let test, let consequent, let alternate):
            let condition = try evaluateExpression(test)
            if condition.toBoolean {
                return try executeStatement(consequent)
            } else if let alt = alternate {
                return try executeStatement(alt)
            }
            return (.undefined, .none)

        case .forStatement(let initClause, let test, let update, let body):
            // Create scope for loop
            let previousScope = currentScope
            currentScope = previousScope.createBlockScope()
            defer { currentScope = previousScope }

            // Initialize
            if let initClause = initClause {
                switch initClause {
                case .declaration(let kind, let declarations):
                    for decl in declarations {
                        let value = decl.initializer != nil
                            ? try evaluateExpression(decl.initializer!)
                            : .undefined
                        try currentScope.declare(decl.name, value: value, kind: kind)
                    }
                case .expression(let expr):
                    _ = try evaluateExpression(expr)
                }
            }

            // Loop
            while true {
                // Test condition
                if let test = test {
                    let cond = try evaluateExpression(test)
                    if !cond.toBoolean {
                        break
                    }
                }

                // Execute body
                let (_, flow) = try executeStatement(body)
                if case .return = flow { return (.undefined, flow) }
                if case .break = flow { break }
                // Continue falls through to update

                // Update
                if let update = update {
                    _ = try evaluateExpression(update)
                }
            }
            return (.undefined, .none)

        case .whileStatement(let test, let body):
            while true {
                let cond = try evaluateExpression(test)
                if !cond.toBoolean {
                    break
                }

                let (_, flow) = try executeStatement(body)
                if case .return = flow { return (.undefined, flow) }
                if case .break = flow { break }
                // Continue just continues the loop
            }
            return (.undefined, .none)

        case .returnStatement(let expr):
            let value = expr != nil ? try evaluateExpression(expr!) : .undefined
            return (value, .return(value))

        case .breakStatement:
            return (.undefined, .break)

        case .continueStatement:
            return (.undefined, .continue)

        case .functionDeclaration(let name, let params, let body):
            let function = JSFunction(name: name, params: params, body: body, closure: currentScope)
            try currentScope.declare(name, value: .function(function), kind: .var)
            return (.undefined, .none)

        case .empty:
            return (.undefined, .none)
        }
    }

    // MARK: - Expression Evaluation

    private func evaluateExpression(_ expression: Expression) throws -> JSValue {
        switch expression {
        case .literal(let value):
            return .from(value)

        case .identifier(let name):
            return try currentScope.get(name)

        case .binary(let left, let op, let right):
            return try evaluateBinary(left: left, op: op, right: right)

        case .unary(let op, let operand, let prefix):
            return try evaluateUnary(op: op, operand: operand, prefix: prefix)

        case .call(let callee, let arguments):
            return try evaluateCall(callee: callee, arguments: arguments)

        case .member(let object, let property, let computed):
            return try evaluateMember(object: object, property: property, computed: computed)

        case .assignment(let target, let op, let value):
            return try evaluateAssignment(target: target, op: op, value: value)

        case .array(let elements):
            let values = try elements.map { try evaluateExpression($0) }
            return .array(JSArray(elements: values))

        case .object(let properties):
            let obj = JSObject()
            for prop in properties {
                let value = try evaluateExpression(prop.value)
                obj.set(prop.key, value)
            }
            return .object(obj)

        case .function(let name, let params, let body):
            let fn = JSFunction(name: name ?? "", params: params, body: body, closure: currentScope)
            return .function(fn)

        case .arrowFunction(let params, let body):
            let fn = JSFunction(params: params, arrowBody: body, closure: currentScope)
            return .function(fn)

        case .conditional(let test, let consequent, let alternate):
            let condition = try evaluateExpression(test)
            if condition.toBoolean {
                return try evaluateExpression(consequent)
            } else {
                return try evaluateExpression(alternate)
            }

        case .this:
            return currentScope.thisBinding

        case .new(let callee, let arguments):
            return try evaluateNew(callee: callee, arguments: arguments)

        case .typeof(let operand):
            // Special handling for undefined references
            if case .identifier(let name) = operand {
                if !currentScope.has(name) {
                    return .string("undefined")
                }
            }
            let value = try evaluateExpression(operand)
            return .string(value.typeOf)

        case .update(let op, let operand, let prefix):
            return try evaluateUpdate(op: op, operand: operand, prefix: prefix)

        case .logical(let left, let op, let right):
            return try evaluateLogical(left: left, op: op, right: right)
        }
    }

    // MARK: - Binary Operations

    private func evaluateBinary(left: Expression, op: String, right: Expression) throws -> JSValue {
        let lhs = try evaluateExpression(left)
        let rhs = try evaluateExpression(right)

        switch op {
        // Arithmetic
        case "+":
            // String concatenation if either is a string
            if case .string(let ls) = lhs {
                return .string(ls + rhs.toString)
            }
            if case .string(let rs) = rhs {
                return .string(lhs.toString + rs)
            }
            return .number(lhs.toNumber + rhs.toNumber)

        case "-":
            return .number(lhs.toNumber - rhs.toNumber)

        case "*":
            return .number(lhs.toNumber * rhs.toNumber)

        case "/":
            let divisor = rhs.toNumber
            if divisor == 0 {
                return .number(lhs.toNumber > 0 ? .infinity : (lhs.toNumber < 0 ? -.infinity : .nan))
            }
            return .number(lhs.toNumber / divisor)

        case "%":
            return .number(lhs.toNumber.truncatingRemainder(dividingBy: rhs.toNumber))

        case "**":
            return .number(pow(lhs.toNumber, rhs.toNumber))

        // Comparison
        case "==":
            return .boolean(looseEquals(lhs, rhs))

        case "!=":
            return .boolean(!looseEquals(lhs, rhs))

        case "===":
            return .boolean(strictEquals(lhs, rhs))

        case "!==":
            return .boolean(!strictEquals(lhs, rhs))

        case "<":
            return .boolean(lhs.toNumber < rhs.toNumber)

        case "<=":
            return .boolean(lhs.toNumber <= rhs.toNumber)

        case ">":
            return .boolean(lhs.toNumber > rhs.toNumber)

        case ">=":
            return .boolean(lhs.toNumber >= rhs.toNumber)

        // Bitwise
        case "&":
            return .number(Double(Int32(lhs.toNumber) & Int32(rhs.toNumber)))

        case "|":
            return .number(Double(Int32(lhs.toNumber) | Int32(rhs.toNumber)))

        case "^":
            return .number(Double(Int32(lhs.toNumber) ^ Int32(rhs.toNumber)))

        case "<<":
            return .number(Double(Int32(lhs.toNumber) << Int(rhs.toNumber)))

        case ">>":
            return .number(Double(Int32(lhs.toNumber) >> Int(rhs.toNumber)))

        case ">>>":
            return .number(Double(UInt32(bitPattern: Int32(lhs.toNumber)) >> Int(rhs.toNumber)))

        default:
            throw JSError.syntaxError("Unknown binary operator: \(op)")
        }
    }

    // MARK: - Unary Operations

    private func evaluateUnary(op: String, operand: Expression, prefix: Bool) throws -> JSValue {
        let value = try evaluateExpression(operand)

        switch op {
        case "-":
            return .number(-value.toNumber)

        case "+":
            return .number(value.toNumber)

        case "!":
            return .boolean(!value.toBoolean)

        case "~":
            return .number(Double(~Int32(value.toNumber)))

        case "void":
            return .undefined

        default:
            throw JSError.syntaxError("Unknown unary operator: \(op)")
        }
    }

    // MARK: - Update Operations (++/--)

    private func evaluateUpdate(op: String, operand: Expression, prefix: Bool) throws -> JSValue {
        let oldValue = try evaluateExpression(operand)
        let numValue = oldValue.toNumber

        let newValue: Double
        switch op {
        case "++":
            newValue = numValue + 1
        case "--":
            newValue = numValue - 1
        default:
            throw JSError.syntaxError("Unknown update operator: \(op)")
        }

        // Assign the new value
        try assignTo(operand, value: .number(newValue))

        // Return old or new value based on prefix
        return .number(prefix ? newValue : numValue)
    }

    // MARK: - Logical Operations

    private func evaluateLogical(left: Expression, op: String, right: Expression) throws -> JSValue {
        let lhs = try evaluateExpression(left)

        switch op {
        case "&&":
            // Short-circuit: return lhs if falsy, else evaluate and return rhs
            if !lhs.toBoolean {
                return lhs
            }
            return try evaluateExpression(right)

        case "||":
            // Short-circuit: return lhs if truthy, else evaluate and return rhs
            if lhs.toBoolean {
                return lhs
            }
            return try evaluateExpression(right)

        case "??":
            // Nullish coalescing: return rhs if lhs is null or undefined
            if lhs.isNullOrUndefined {
                return try evaluateExpression(right)
            }
            return lhs

        default:
            throw JSError.syntaxError("Unknown logical operator: \(op)")
        }
    }

    // MARK: - Member Access

    private func evaluateMember(object: Expression, property: String, computed: Bool) throws -> JSValue {
        let obj = try evaluateExpression(object)

        switch obj {
        case .object(let jsObj):
            return jsObj.get(property)

        case .array(let arr):
            if property == "length" {
                return .number(Double(arr.length))
            }
            if let index = Int(property) {
                return arr.get(index)
            }
            return .undefined

        case .string(let str):
            if property == "length" {
                return .number(Double(str.count))
            }
            if let index = Int(property), index >= 0 && index < str.count {
                let idx = str.index(str.startIndex, offsetBy: index)
                return .string(String(str[idx]))
            }
            return .undefined

        default:
            return .undefined
        }
    }

    // MARK: - Assignment

    private func evaluateAssignment(target: Expression, op: String, value: Expression) throws -> JSValue {
        let rhs = try evaluateExpression(value)

        if op == "=" {
            try assignTo(target, value: rhs)
            return rhs
        }

        // Compound assignment
        let lhs = try evaluateExpression(target)
        let result: JSValue

        switch op {
        case "+=":
            if case .string(let ls) = lhs {
                result = .string(ls + rhs.toString)
            } else {
                result = .number(lhs.toNumber + rhs.toNumber)
            }
        case "-=":
            result = .number(lhs.toNumber - rhs.toNumber)
        case "*=":
            result = .number(lhs.toNumber * rhs.toNumber)
        case "/=":
            result = .number(lhs.toNumber / rhs.toNumber)
        case "%=":
            result = .number(lhs.toNumber.truncatingRemainder(dividingBy: rhs.toNumber))
        case "&=":
            result = .number(Double(Int32(lhs.toNumber) & Int32(rhs.toNumber)))
        case "|=":
            result = .number(Double(Int32(lhs.toNumber) | Int32(rhs.toNumber)))
        case "^=":
            result = .number(Double(Int32(lhs.toNumber) ^ Int32(rhs.toNumber)))
        default:
            throw JSError.syntaxError("Unknown assignment operator: \(op)")
        }

        try assignTo(target, value: result)
        return result
    }

    private func assignTo(_ target: Expression, value: JSValue) throws {
        switch target {
        case .identifier(let name):
            try currentScope.set(name, value: value)

        case .member(let object, let property, _):
            let obj = try evaluateExpression(object)
            switch obj {
            case .object(let jsObj):
                jsObj.set(property, value)
            case .array(let arr):
                if let index = Int(property) {
                    arr.set(index, value)
                }
            default:
                throw JSError.typeError("Cannot set property '\(property)' of \(obj.typeOf)")
            }

        default:
            throw JSError.referenceError("Invalid assignment target")
        }
    }

    // MARK: - Function Calls

    private func evaluateCall(callee: Expression, arguments: [Expression]) throws -> JSValue {
        // Check call depth
        if callDepth >= maxCallDepth {
            throw JSError(name: "RangeError", message: "Maximum call stack size exceeded")
        }

        let args = try arguments.map { try evaluateExpression($0) }

        // Handle member calls (method calls)
        var thisValue: JSValue = .undefined
        let fn: JSValue

        if case .member(let object, let property, _) = callee {
            thisValue = try evaluateExpression(object)
            fn = try evaluateMember(object: object, property: property, computed: false)
        } else {
            fn = try evaluateExpression(callee)
        }

        guard case .function(let jsFunc) = fn else {
            throw JSError.typeError("\(fn.typeOf) is not a function")
        }

        return try callFunction(jsFunc, args: args, thisValue: thisValue)
    }

    private func callFunction(_ fn: JSFunction, args: [JSValue], thisValue: JSValue) throws -> JSValue {
        callDepth += 1
        defer { callDepth -= 1 }

        // Native function
        if fn.isNative {
            return fn.nativeImpl!(args, thisValue)
        }

        // Create function scope
        let funcScope = (fn.closure ?? globalScope).createFunctionScope()
        funcScope.thisBinding = fn.isArrow ? (fn.closure?.thisBinding ?? .undefined) : thisValue

        // Bind parameters
        for (index, param) in fn.params.enumerated() {
            let value = index < args.count ? args[index] : .undefined
            try funcScope.declare(param, value: value, kind: .var)
        }

        // Execute function body
        let previousScope = currentScope
        currentScope = funcScope
        defer { currentScope = previousScope }

        // Handle arrow function with expression body
        if fn.isArrow, let arrowBody = fn.arrowBody {
            switch arrowBody {
            case .expression(let expr):
                return try evaluateExpression(expr)
            case .block(let statements):
                return try execute(statements)
            }
        }

        // Regular function body
        for statement in fn.body {
            let (_, flow) = try executeStatement(statement)
            if case .return(let value) = flow {
                return value
            }
        }

        return .undefined
    }

    // MARK: - new Expression

    private func evaluateNew(callee: Expression, arguments: [Expression]) throws -> JSValue {
        let fn = try evaluateExpression(callee)

        guard case .function(let jsFunc) = fn else {
            throw JSError.typeError("\(fn.typeOf) is not a constructor")
        }

        // Create new object
        let newObj = JSObject()
        let args = try arguments.map { try evaluateExpression($0) }

        // Call constructor with new object as this
        let result = try callFunction(jsFunc, args: args, thisValue: .object(newObj))

        // Return result if it's an object, otherwise return the new object
        if case .object = result {
            return result
        }
        return .object(newObj)
    }

    // MARK: - Equality Helpers

    private func strictEquals(_ a: JSValue, _ b: JSValue) -> Bool {
        return a == b
    }

    private func looseEquals(_ a: JSValue, _ b: JSValue) -> Bool {
        // Same type - use strict equality
        switch (a, b) {
        case (.undefined, .undefined), (.null, .null):
            return true
        case (.undefined, .null), (.null, .undefined):
            return true
        case (.boolean(let ab), .boolean(let bb)):
            return ab == bb
        case (.number(let an), .number(let bn)):
            if an.isNaN || bn.isNaN { return false }
            return an == bn
        case (.string(let aStr), .string(let bStr)):
            return aStr == bStr

        // Type coercion cases
        case (.number, .string):
            return a.toNumber == b.toNumber
        case (.string, .number):
            return a.toNumber == b.toNumber
        case (.boolean, _):
            return looseEquals(.number(a.toNumber), b)
        case (_, .boolean):
            return looseEquals(a, .number(b.toNumber))

        // Object to primitive
        case (.object, .string), (.object, .number):
            return looseEquals(.string(a.toString), b)
        case (.string, .object), (.number, .object):
            return looseEquals(a, .string(b.toString))

        default:
            return false
        }
    }
}
