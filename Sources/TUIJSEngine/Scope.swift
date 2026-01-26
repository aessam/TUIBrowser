// TUIJSEngine - Variable Scope
//
// Implements lexical scoping for JavaScript variable bindings.

import Foundation

// MARK: - Variable Info

/// Information about a variable binding
public struct VariableInfo: Sendable {
    /// The variable's value
    public var value: JSValue

    /// Declaration kind (var, let, const)
    public let kind: VarKind

    /// Whether the variable has been initialized
    public var initialized: Bool

    public init(value: JSValue, kind: VarKind, initialized: Bool = true) {
        self.value = value
        self.kind = kind
        self.initialized = initialized
    }
}

// MARK: - Scope

/// JavaScript lexical scope
public final class Scope: @unchecked Sendable {
    /// Variables in this scope
    private var variables: [String: VariableInfo]

    /// Parent scope (for scope chain lookup)
    public weak var parent: Scope?

    /// The "this" binding for this scope
    public var thisBinding: JSValue

    /// Whether this is a function scope (for var hoisting)
    public let isFunction: Bool

    /// Whether this is the global scope
    public var isGlobal: Bool {
        parent == nil
    }

    private let lock = NSLock()

    // MARK: - Initialization

    public init(parent: Scope? = nil, isFunction: Bool = false) {
        self.variables = [:]
        self.parent = parent
        self.thisBinding = parent?.thisBinding ?? .undefined
        self.isFunction = isFunction
    }

    /// Create a global scope
    public static func createGlobal() -> Scope {
        let scope = Scope(parent: nil, isFunction: true)
        scope.thisBinding = .object(JSObject(className: "Window"))
        return scope
    }

    /// Create a function scope
    public func createFunctionScope() -> Scope {
        return Scope(parent: self, isFunction: true)
    }

    /// Create a block scope
    public func createBlockScope() -> Scope {
        return Scope(parent: self, isFunction: false)
    }

    // MARK: - Variable Operations

    /// Declare a variable in this scope
    /// - Parameters:
    ///   - name: Variable name
    ///   - value: Initial value
    ///   - kind: Declaration kind (var, let, const)
    /// - Throws: JSError if redeclaration is not allowed
    public func declare(_ name: String, value: JSValue = .undefined, kind: VarKind) throws {
        lock.lock()
        defer { lock.unlock() }

        // Check for redeclaration
        if let existing = variables[name] {
            // var can be redeclared
            if kind == .var && existing.kind == .var {
                variables[name] = VariableInfo(value: value, kind: kind)
                return
            }
            // let/const cannot be redeclared
            throw JSError.syntaxError("Identifier '\(name)' has already been declared")
        }

        // For var declarations in non-function scope, hoist to function scope
        if kind == .var && !isFunction {
            if let funcScope = findFunctionScope() {
                try funcScope.declare(name, value: value, kind: kind)
                return
            }
        }

        variables[name] = VariableInfo(value: value, kind: kind)
    }

    /// Get a variable's value, searching up the scope chain
    /// - Parameter name: Variable name
    /// - Returns: The variable's value
    /// - Throws: JSError if variable is not defined
    public func get(_ name: String) throws -> JSValue {
        lock.lock()
        defer { lock.unlock() }

        if let info = variables[name] {
            if !info.initialized {
                throw JSError.referenceError("Cannot access '\(name)' before initialization")
            }
            return info.value
        }

        if let parent = parent {
            return try parent.get(name)
        }

        throw JSError.referenceError("'\(name)' is not defined")
    }

    /// Set a variable's value, searching up the scope chain
    /// - Parameters:
    ///   - name: Variable name
    ///   - value: New value
    /// - Throws: JSError if variable is not defined or is const
    public func set(_ name: String, value: JSValue) throws {
        lock.lock()
        defer { lock.unlock() }

        if var info = variables[name] {
            if info.kind == .const && info.initialized {
                throw JSError.typeError("Assignment to constant variable '\(name)'")
            }
            info.value = value
            info.initialized = true
            variables[name] = info
            return
        }

        if let parent = parent {
            try parent.set(name, value: value)
            return
        }

        // In non-strict mode, create global variable
        // In strict mode, this would throw an error
        variables[name] = VariableInfo(value: value, kind: .var)
    }

    /// Check if a variable exists in this scope (not searching parent)
    public func hasOwn(_ name: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return variables[name] != nil
    }

    /// Check if a variable exists in the scope chain
    public func has(_ name: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        if variables[name] != nil {
            return true
        }
        return parent?.has(name) ?? false
    }

    /// Delete a variable (only works for non-configurable vars in global scope)
    public func delete(_ name: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        if let info = variables[name] {
            // Cannot delete let/const
            if info.kind != .var {
                return false
            }
            variables.removeValue(forKey: name)
            return true
        }
        return parent?.delete(name) ?? false
    }

    /// Get all variable names in this scope
    public var localNames: [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(variables.keys)
    }

    // MARK: - Helpers

    /// Find the nearest function scope
    private func findFunctionScope() -> Scope? {
        if isFunction {
            return self
        }
        return parent?.findFunctionScope()
    }

    /// Create a child scope with initial variables
    public func child(withVariables vars: [String: JSValue] = [:]) -> Scope {
        let child = createBlockScope()
        for (name, value) in vars {
            try? child.declare(name, value: value, kind: .let)
        }
        return child
    }
}

// MARK: - Debug Support

extension Scope: CustomStringConvertible {
    public var description: String {
        lock.lock()
        defer { lock.unlock() }

        var parts: [String] = []
        for (name, info) in variables {
            let kindStr = info.kind.rawValue
            let valueStr = info.value.description.prefix(50)
            parts.append("  \(kindStr) \(name) = \(valueStr)")
        }

        let scopeType = isFunction ? "function" : "block"
        let header = "Scope(\(scopeType)):"
        return ([header] + parts).joined(separator: "\n")
    }
}
