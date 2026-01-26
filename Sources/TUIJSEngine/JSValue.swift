// TUIJSEngine - JavaScript Value Types
//
// Represents JavaScript values for the interpreter runtime.

import Foundation

// MARK: - JSValue

/// JavaScript value type
public enum JSValue: Sendable, CustomStringConvertible {
    case undefined
    case null
    case boolean(Bool)
    case number(Double)
    case string(String)
    case object(JSObject)
    case array(JSArray)
    case function(JSFunction)

    // MARK: - Description

    public var description: String {
        switch self {
        case .undefined:
            return "undefined"
        case .null:
            return "null"
        case .boolean(let b):
            return b ? "true" : "false"
        case .number(let n):
            if n.isNaN { return "NaN" }
            if n.isInfinite { return n > 0 ? "Infinity" : "-Infinity" }
            if n == n.rounded() && abs(n) < Double(Int.max) {
                return String(Int(n))
            }
            return String(n)
        case .string(let s):
            return s
        case .object(let obj):
            return obj.description
        case .array(let arr):
            return arr.description
        case .function(let fn):
            return fn.description
        }
    }

    // MARK: - Type Checking

    public var isUndefined: Bool {
        if case .undefined = self { return true }
        return false
    }

    public var isNull: Bool {
        if case .null = self { return true }
        return false
    }

    public var isNullOrUndefined: Bool {
        isNull || isUndefined
    }

    public var isBoolean: Bool {
        if case .boolean = self { return true }
        return false
    }

    public var isNumber: Bool {
        if case .number = self { return true }
        return false
    }

    public var isString: Bool {
        if case .string = self { return true }
        return false
    }

    public var isObject: Bool {
        if case .object = self { return true }
        return false
    }

    public var isArray: Bool {
        if case .array = self { return true }
        return false
    }

    public var isFunction: Bool {
        if case .function = self { return true }
        return false
    }

    public var isPrimitive: Bool {
        switch self {
        case .undefined, .null, .boolean, .number, .string:
            return true
        default:
            return false
        }
    }

    // MARK: - Type Coercion

    /// Convert to boolean (JavaScript truthiness)
    public var toBoolean: Bool {
        switch self {
        case .undefined, .null:
            return false
        case .boolean(let b):
            return b
        case .number(let n):
            return n != 0 && !n.isNaN
        case .string(let s):
            return !s.isEmpty
        case .object, .array, .function:
            return true
        }
    }

    /// Convert to number
    public var toNumber: Double {
        switch self {
        case .undefined:
            return .nan
        case .null:
            return 0
        case .boolean(let b):
            return b ? 1 : 0
        case .number(let n):
            return n
        case .string(let s):
            if s.isEmpty { return 0 }
            return Double(s) ?? .nan
        case .object, .array, .function:
            // Try to convert via toString
            return Double(self.toString) ?? .nan
        }
    }

    /// Convert to string
    public var toString: String {
        description
    }

    /// Get the typeof value
    public var typeOf: String {
        switch self {
        case .undefined:
            return "undefined"
        case .null:
            return "object" // JavaScript quirk
        case .boolean:
            return "boolean"
        case .number:
            return "number"
        case .string:
            return "string"
        case .object:
            return "object"
        case .array:
            return "object"
        case .function:
            return "function"
        }
    }

    // MARK: - Unwrap helpers

    public var boolValue: Bool? {
        if case .boolean(let b) = self { return b }
        return nil
    }

    public var numberValue: Double? {
        if case .number(let n) = self { return n }
        return nil
    }

    public var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    public var objectValue: JSObject? {
        if case .object(let o) = self { return o }
        return nil
    }

    public var arrayValue: JSArray? {
        if case .array(let a) = self { return a }
        return nil
    }

    public var functionValue: JSFunction? {
        if case .function(let f) = self { return f }
        return nil
    }
}

// MARK: - JSObject

/// JavaScript object implementation
public final class JSObject: @unchecked Sendable, CustomStringConvertible {
    /// Object properties
    public var properties: [String: JSValue]

    /// Prototype (for prototype chain)
    public var prototype: JSObject?

    /// Internal class name
    public let className: String

    public init(className: String = "Object", prototype: JSObject? = nil) {
        self.properties = [:]
        self.className = className
        self.prototype = prototype
    }

    public convenience init(properties: [String: JSValue]) {
        self.init()
        self.properties = properties
    }

    /// Get a property, checking prototype chain
    public func get(_ key: String) -> JSValue {
        if let value = properties[key] {
            return value
        }
        if let proto = prototype {
            return proto.get(key)
        }
        return .undefined
    }

    /// Set a property
    public func set(_ key: String, _ value: JSValue) {
        properties[key] = value
    }

    /// Check if property exists (own or inherited)
    public func hasProperty(_ key: String) -> Bool {
        if properties[key] != nil {
            return true
        }
        if let proto = prototype {
            return proto.hasProperty(key)
        }
        return false
    }

    /// Check if object has own property
    public func hasOwnProperty(_ key: String) -> Bool {
        return properties[key] != nil
    }

    /// Get all own property keys
    public var keys: [String] {
        Array(properties.keys)
    }

    public var description: String {
        if className == "Object" {
            let pairs = properties.map { "\($0.key): \($0.value)" }
            return "{ \(pairs.joined(separator: ", ")) }"
        }
        return "[\(className)]"
    }
}

// MARK: - JSArray

/// JavaScript array implementation
public final class JSArray: @unchecked Sendable, CustomStringConvertible {
    /// Array elements
    public var elements: [JSValue]

    public init(elements: [JSValue] = []) {
        self.elements = elements
    }

    /// Get element at index
    public func get(_ index: Int) -> JSValue {
        guard index >= 0 && index < elements.count else {
            return .undefined
        }
        return elements[index]
    }

    /// Set element at index
    public func set(_ index: Int, _ value: JSValue) {
        // Expand array if needed
        while elements.count <= index {
            elements.append(.undefined)
        }
        elements[index] = value
    }

    /// Array length
    public var length: Int {
        elements.count
    }

    /// Push an element
    public func push(_ value: JSValue) {
        elements.append(value)
    }

    /// Pop an element
    public func pop() -> JSValue {
        guard !elements.isEmpty else { return .undefined }
        return elements.removeLast()
    }

    /// Shift (remove first element)
    public func shift() -> JSValue {
        guard !elements.isEmpty else { return .undefined }
        return elements.removeFirst()
    }

    /// Unshift (add to beginning)
    public func unshift(_ value: JSValue) {
        elements.insert(value, at: 0)
    }

    public var description: String {
        let items = elements.map { $0.description }
        return "[\(items.joined(separator: ", "))]"
    }
}

// MARK: - JSFunction

/// Native function type - uses @unchecked Sendable wrapper for DOM integration
public typealias JSNativeFunction = ([JSValue], JSValue?) -> JSValue

/// JavaScript function implementation
public final class JSFunction: @unchecked Sendable, CustomStringConvertible {
    /// Function name (empty for anonymous)
    public let name: String

    /// Parameter names
    public let params: [String]

    /// Function body (AST statements)
    public let body: [Statement]

    /// Closure scope (captured environment)
    public var closure: Scope?

    /// Whether this is a native function
    public let isNative: Bool

    /// Native function implementation (not Sendable to allow DOM captures)
    private let _nativeImpl: JSNativeFunction?

    /// Arrow function body (expression form)
    public let arrowBody: ArrowBody?

    /// Whether this is an arrow function
    public let isArrow: Bool

    /// Access native implementation
    public var nativeImpl: JSNativeFunction? { _nativeImpl }

    // Regular function
    public init(name: String, params: [String], body: [Statement], closure: Scope?) {
        self.name = name
        self.params = params
        self.body = body
        self.closure = closure
        self.isNative = false
        self._nativeImpl = nil
        self.arrowBody = nil
        self.isArrow = false
    }

    // Arrow function with expression body
    public init(params: [String], arrowBody: ArrowBody, closure: Scope?) {
        self.name = ""
        self.params = params
        self.body = []
        self.closure = closure
        self.isNative = false
        self._nativeImpl = nil
        self.arrowBody = arrowBody
        self.isArrow = true
    }

    // Native function
    public init(name: String, nativeImpl: @escaping JSNativeFunction) {
        self.name = name
        self.params = []
        self.body = []
        self.closure = nil
        self.isNative = true
        self._nativeImpl = nativeImpl
        self.arrowBody = nil
        self.isArrow = false
    }

    public var description: String {
        if isNative {
            return "[native function: \(name)]"
        }
        let nameStr = name.isEmpty ? "anonymous" : name
        return "[function: \(nameStr)]"
    }
}

// MARK: - JSValue Equatable

extension JSValue: Equatable {
    public static func == (lhs: JSValue, rhs: JSValue) -> Bool {
        switch (lhs, rhs) {
        case (.undefined, .undefined):
            return true
        case (.null, .null):
            return true
        case (.boolean(let a), .boolean(let b)):
            return a == b
        case (.number(let a), .number(let b)):
            // Handle NaN
            if a.isNaN && b.isNaN { return false }
            return a == b
        case (.string(let a), .string(let b)):
            return a == b
        case (.object(let a), .object(let b)):
            return a === b // Reference equality
        case (.array(let a), .array(let b)):
            return a === b
        case (.function(let a), .function(let b)):
            return a === b
        default:
            return false
        }
    }
}

// MARK: - Convenience Initializers

extension JSValue {
    /// Create from literal value
    public static func from(_ literal: LiteralValue) -> JSValue {
        switch literal {
        case .number(let n):
            return .number(n)
        case .string(let s):
            return .string(s)
        case .boolean(let b):
            return .boolean(b)
        case .null:
            return .null
        case .undefined:
            return .undefined
        }
    }
}

// MARK: - JSError

/// JavaScript error
public final class JSError: @unchecked Sendable, Error, CustomStringConvertible {
    public let name: String
    public let message: String
    public var stack: String?

    public init(name: String = "Error", message: String) {
        self.name = name
        self.message = message
    }

    public static func typeError(_ message: String) -> JSError {
        JSError(name: "TypeError", message: message)
    }

    public static func referenceError(_ message: String) -> JSError {
        JSError(name: "ReferenceError", message: message)
    }

    public static func syntaxError(_ message: String) -> JSError {
        JSError(name: "SyntaxError", message: message)
    }

    public static func rangeError(_ message: String) -> JSError {
        JSError(name: "RangeError", message: message)
    }

    public var description: String {
        "\(name): \(message)"
    }
}
