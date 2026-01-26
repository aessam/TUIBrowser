// TUIJSEngine - Built-in Functions
//
// Provides JavaScript built-in objects and functions like console, JSON, etc.

import Foundation

// MARK: - Builtins Setup

/// Sets up built-in objects and functions in the interpreter
public struct Builtins {

    /// Install all built-in objects into the interpreter's global scope
    public static func install(into interpreter: Interpreter) {
        installConsole(into: interpreter)
        installJSON(into: interpreter)
        installMath(into: interpreter)
        installGlobalFunctions(into: interpreter)
        installStringPrototype(into: interpreter)
        installArrayPrototype(into: interpreter)
    }

    // MARK: - Console

    /// Install console object
    private static func installConsole(into interpreter: Interpreter) {
        let console = JSObject(className: "Console")

        // console.log
        console.set("log", .function(JSFunction(name: "log") { args, _ in
            let output = args.map { $0.toString }.joined(separator: " ")
            interpreter.consoleOutput?(output)
            return .undefined
        }))

        // console.error
        console.set("error", .function(JSFunction(name: "error") { args, _ in
            let output = "Error: " + args.map { $0.toString }.joined(separator: " ")
            interpreter.consoleOutput?(output)
            return .undefined
        }))

        // console.warn
        console.set("warn", .function(JSFunction(name: "warn") { args, _ in
            let output = "Warning: " + args.map { $0.toString }.joined(separator: " ")
            interpreter.consoleOutput?(output)
            return .undefined
        }))

        // console.info
        console.set("info", .function(JSFunction(name: "info") { args, _ in
            let output = args.map { $0.toString }.joined(separator: " ")
            interpreter.consoleOutput?(output)
            return .undefined
        }))

        // console.debug
        console.set("debug", .function(JSFunction(name: "debug") { args, _ in
            let output = "[DEBUG] " + args.map { $0.toString }.joined(separator: " ")
            interpreter.consoleOutput?(output)
            return .undefined
        }))

        interpreter.setGlobal("console", value: .object(console))
    }

    // MARK: - JSON

    /// Install JSON object
    private static func installJSON(into interpreter: Interpreter) {
        let json = JSObject(className: "JSON")

        // JSON.parse
        json.set("parse", .function(JSFunction(name: "parse") { args, _ in
            guard let str = args.first?.stringValue else {
                return .undefined
            }

            guard let data = str.data(using: .utf8) else {
                return .undefined
            }

            do {
                let jsonObj = try JSONSerialization.jsonObject(with: data, options: [])
                return convertJSONToJSValue(jsonObj)
            } catch {
                return .undefined
            }
        }))

        // JSON.stringify
        json.set("stringify", .function(JSFunction(name: "stringify") { args, _ in
            guard let value = args.first else {
                return .undefined
            }

            let jsonObj = convertJSValueToJSON(value)

            do {
                let data = try JSONSerialization.data(withJSONObject: jsonObj, options: [.fragmentsAllowed])
                if let str = String(data: data, encoding: .utf8) {
                    return .string(str)
                }
            } catch {
                return .undefined
            }

            return .undefined
        }))

        interpreter.setGlobal("JSON", value: .object(json))
    }

    // MARK: - Math

    /// Install Math object
    private static func installMath(into interpreter: Interpreter) {
        let math = JSObject(className: "Math")

        // Constants
        math.set("PI", .number(.pi))
        math.set("E", .number(Darwin.M_E))
        math.set("LN2", .number(Darwin.M_LN2))
        math.set("LN10", .number(Darwin.M_LN10))
        math.set("LOG2E", .number(Darwin.M_LOG2E))
        math.set("LOG10E", .number(Darwin.M_LOG10E))
        math.set("SQRT2", .number(Darwin.M_SQRT2))
        math.set("SQRT1_2", .number(Darwin.M_SQRT1_2))

        // Methods
        math.set("abs", .function(JSFunction(name: "abs") { args, _ in
            .number(abs(args.first?.toNumber ?? 0))
        }))

        math.set("ceil", .function(JSFunction(name: "ceil") { args, _ in
            .number(ceil(args.first?.toNumber ?? 0))
        }))

        math.set("floor", .function(JSFunction(name: "floor") { args, _ in
            .number(floor(args.first?.toNumber ?? 0))
        }))

        math.set("round", .function(JSFunction(name: "round") { args, _ in
            .number((args.first?.toNumber ?? 0).rounded())
        }))

        math.set("max", .function(JSFunction(name: "max") { args, _ in
            if args.isEmpty { return .number(-.infinity) }
            let nums = args.map { $0.toNumber }
            return .number(nums.max() ?? -.infinity)
        }))

        math.set("min", .function(JSFunction(name: "min") { args, _ in
            if args.isEmpty { return .number(.infinity) }
            let nums = args.map { $0.toNumber }
            return .number(nums.min() ?? .infinity)
        }))

        math.set("pow", .function(JSFunction(name: "pow") { args, _ in
            let base = args.first?.toNumber ?? 0
            let exp = args.count > 1 ? args[1].toNumber : 0
            return .number(pow(base, exp))
        }))

        math.set("sqrt", .function(JSFunction(name: "sqrt") { args, _ in
            .number(sqrt(args.first?.toNumber ?? 0))
        }))

        math.set("random", .function(JSFunction(name: "random") { _, _ in
            .number(Double.random(in: 0..<1))
        }))

        math.set("sin", .function(JSFunction(name: "sin") { args, _ in
            .number(sin(args.first?.toNumber ?? 0))
        }))

        math.set("cos", .function(JSFunction(name: "cos") { args, _ in
            .number(cos(args.first?.toNumber ?? 0))
        }))

        math.set("tan", .function(JSFunction(name: "tan") { args, _ in
            .number(tan(args.first?.toNumber ?? 0))
        }))

        math.set("log", .function(JSFunction(name: "log") { args, _ in
            .number(log(args.first?.toNumber ?? 0))
        }))

        math.set("exp", .function(JSFunction(name: "exp") { args, _ in
            .number(exp(args.first?.toNumber ?? 0))
        }))

        math.set("trunc", .function(JSFunction(name: "trunc") { args, _ in
            .number(trunc(args.first?.toNumber ?? 0))
        }))

        math.set("sign", .function(JSFunction(name: "sign") { args, _ in
            let n = args.first?.toNumber ?? 0
            if n > 0 { return .number(1) }
            if n < 0 { return .number(-1) }
            return .number(0)
        }))

        interpreter.setGlobal("Math", value: .object(math))
    }

    // MARK: - Global Functions

    /// Install global functions
    private static func installGlobalFunctions(into interpreter: Interpreter) {
        // parseInt
        interpreter.setGlobal("parseInt", value: .function(JSFunction(name: "parseInt") { args, _ in
            let str = args.first?.toString ?? ""
            let radix = args.count > 1 ? Int(args[1].toNumber) : 10

            guard radix >= 2 && radix <= 36 else {
                return .number(.nan)
            }

            let trimmed = str.trimmingCharacters(in: .whitespaces)
            if let n = Int(trimmed, radix: radix) {
                return .number(Double(n))
            }
            return .number(.nan)
        }))

        // parseFloat
        interpreter.setGlobal("parseFloat", value: .function(JSFunction(name: "parseFloat") { args, _ in
            let str = args.first?.toString ?? ""
            let trimmed = str.trimmingCharacters(in: .whitespaces)
            if let n = Double(trimmed) {
                return .number(n)
            }
            return .number(.nan)
        }))

        // isNaN
        interpreter.setGlobal("isNaN", value: .function(JSFunction(name: "isNaN") { args, _ in
            .boolean(args.first?.toNumber.isNaN ?? true)
        }))

        // isFinite
        interpreter.setGlobal("isFinite", value: .function(JSFunction(name: "isFinite") { args, _ in
            .boolean(args.first?.toNumber.isFinite ?? false)
        }))

        // Number
        interpreter.setGlobal("Number", value: .function(JSFunction(name: "Number") { args, _ in
            .number(args.first?.toNumber ?? 0)
        }))

        // String
        interpreter.setGlobal("String", value: .function(JSFunction(name: "String") { args, _ in
            .string(args.first?.toString ?? "")
        }))

        // Boolean
        interpreter.setGlobal("Boolean", value: .function(JSFunction(name: "Boolean") { args, _ in
            .boolean(args.first?.toBoolean ?? false)
        }))

        // Array.isArray
        let arrayObj = JSObject(className: "Array")
        arrayObj.set("isArray", .function(JSFunction(name: "isArray") { args, _ in
            if case .array = args.first {
                return .boolean(true)
            }
            return .boolean(false)
        }))
        interpreter.setGlobal("Array", value: .object(arrayObj))

        // Object
        let objectObj = JSObject(className: "Object")
        objectObj.set("keys", .function(JSFunction(name: "keys") { args, _ in
            guard case .object(let obj) = args.first else {
                return .array(JSArray())
            }
            let keys = obj.keys.map { JSValue.string($0) }
            return .array(JSArray(elements: keys))
        }))

        objectObj.set("values", .function(JSFunction(name: "values") { args, _ in
            guard case .object(let obj) = args.first else {
                return .array(JSArray())
            }
            let values = obj.keys.compactMap { obj.properties[$0] }
            return .array(JSArray(elements: values))
        }))

        objectObj.set("entries", .function(JSFunction(name: "entries") { args, _ in
            guard case .object(let obj) = args.first else {
                return .array(JSArray())
            }
            let entries = obj.keys.map { key -> JSValue in
                let value = obj.properties[key] ?? .undefined
                return .array(JSArray(elements: [.string(key), value]))
            }
            return .array(JSArray(elements: entries))
        }))

        interpreter.setGlobal("Object", value: .object(objectObj))

        // undefined and null
        interpreter.setGlobal("undefined", value: .undefined)
        interpreter.setGlobal("null", value: .null)
        interpreter.setGlobal("NaN", value: .number(.nan))
        interpreter.setGlobal("Infinity", value: .number(.infinity))
    }

    // MARK: - String Prototype Methods

    private static func installStringPrototype(into interpreter: Interpreter) {
        // These would be installed as prototype methods
        // For now, we provide them as global helpers that work with string values
    }

    // MARK: - Array Prototype Methods

    private static func installArrayPrototype(into interpreter: Interpreter) {
        // These would be installed as prototype methods
        // For now, arrays support basic operations through JSArray class
    }

    // MARK: - JSON Helpers

    private static func convertJSONToJSValue(_ json: Any) -> JSValue {
        switch json {
        case let str as String:
            return .string(str)
        case let num as NSNumber:
            // Check for boolean
            if CFGetTypeID(num) == CFBooleanGetTypeID() {
                return .boolean(num.boolValue)
            }
            return .number(num.doubleValue)
        case let arr as [Any]:
            let elements = arr.map { convertJSONToJSValue($0) }
            return .array(JSArray(elements: elements))
        case let dict as [String: Any]:
            let obj = JSObject()
            for (key, value) in dict {
                obj.set(key, convertJSONToJSValue(value))
            }
            return .object(obj)
        case is NSNull:
            return .null
        default:
            return .undefined
        }
    }

    private static func convertJSValueToJSON(_ value: JSValue) -> Any {
        switch value {
        case .undefined, .null:
            return NSNull()
        case .boolean(let b):
            return b
        case .number(let n):
            if n.isNaN || n.isInfinite {
                return NSNull()
            }
            return n
        case .string(let s):
            return s
        case .array(let arr):
            return arr.elements.map { convertJSValueToJSON($0) }
        case .object(let obj):
            var dict: [String: Any] = [:]
            for (key, val) in obj.properties {
                dict[key] = convertJSValueToJSON(val)
            }
            return dict
        case .function:
            return NSNull()
        }
    }
}

// MARK: - Timer Support (Simplified)

/// Simple timer manager for setTimeout/setInterval
public final class TimerManager: @unchecked Sendable {
    private var timers: [Int: Timer] = [:]
    private var nextId: Int = 1
    private let lock = NSLock()

    public static let shared = TimerManager()

    private init() {}

    /// Schedule a timeout
    public func setTimeout(callback: @escaping () -> Void, delay: TimeInterval) -> Int {
        lock.lock()
        let id = nextId
        nextId += 1
        lock.unlock()

        let timer = Timer(fire: Date().addingTimeInterval(delay), interval: 0, repeats: false) { [weak self] _ in
            callback()
            self?.clearTimer(id)
        }

        lock.lock()
        timers[id] = timer
        lock.unlock()

        RunLoop.main.add(timer, forMode: .common)
        return id
    }

    /// Schedule an interval
    public func setInterval(callback: @escaping () -> Void, interval: TimeInterval) -> Int {
        lock.lock()
        let id = nextId
        nextId += 1

        let timer = Timer(fire: Date().addingTimeInterval(interval), interval: interval, repeats: true) { _ in
            callback()
        }

        timers[id] = timer
        lock.unlock()

        RunLoop.main.add(timer, forMode: .common)
        return id
    }

    /// Clear a timer
    public func clearTimer(_ id: Int) {
        lock.lock()
        if let timer = timers.removeValue(forKey: id) {
            timer.invalidate()
        }
        lock.unlock()
    }
}
