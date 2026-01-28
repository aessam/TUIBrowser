// TUICSSParser - CSS Value Types

import TUICore

/// Represents a CSS length unit
public enum LengthUnit: String, Equatable, Hashable, Sendable, CaseIterable {
    case px
    case em
    case rem
    case percent
    case ch
    case vw
    case vh
    case vmin
    case vmax
    case pt
    case cm
    case mm
    case `in`

    /// Create a LengthUnit from a string
    public init?(from string: String) {
        switch string.lowercased() {
        case "px": self = .px
        case "em": self = .em
        case "rem": self = .rem
        case "%": self = .percent
        case "ch": self = .ch
        case "vw": self = .vw
        case "vh": self = .vh
        case "vmin": self = .vmin
        case "vmax": self = .vmax
        case "pt": self = .pt
        case "cm": self = .cm
        case "mm": self = .mm
        case "in": self = .in
        default: return nil
        }
    }
}

/// Represents a CSS value
public enum CSSValue: Equatable, Hashable, Sendable {
    /// A keyword value (e.g., "bold", "block", "red")
    case keyword(String)

    /// A length value with unit (e.g., 10px, 1.5em)
    case length(Double, LengthUnit)

    /// A percentage value (e.g., 50%)
    case percentage(Double)

    /// A color value
    case color(Color)

    /// A numeric value without unit
    case number(Double)

    /// A string value
    case string(String)

    /// The inherit keyword
    case inherit

    /// The initial keyword
    case initial

    /// The unset keyword
    case unset

    /// A list of values (e.g. "10px 20px" or "Arial, sans-serif")
    case list([CSSValue])

    /// Check if this value is a keyword with the given name
    public func isKeyword(_ name: String) -> Bool {
        if case .keyword(let value) = self {
            return value.lowercased() == name.lowercased()
        }
        return false
    }

    /// Try to get the keyword value
    public var keywordValue: String? {
        if case .keyword(let value) = self {
            return value
        }
        return nil
    }

    /// Try to get the color value
    public var colorValue: Color? {
        if case .color(let c) = self {
            return c
        }
        return nil
    }

    /// Try to get the numeric value (from number, length, or percentage)
    public var numericValue: Double? {
        switch self {
        case .number(let n): return n
        case .length(let n, _): return n
        case .percentage(let n): return n
        default: return nil
        }
    }
}

extension CSSValue: CustomStringConvertible {
    public var description: String {
        switch self {
        case .keyword(let value):
            return value
        case .length(let value, let unit):
            return "\(value)\(unit.rawValue)"
        case .percentage(let value):
            return "\(value)%"
        case .color(let color):
            return color.toHex()
        case .number(let value):
            return "\(value)"
        case .string(let value):
            return "\"\(value)\""
        case .inherit:
            return "inherit"
        case .initial:
            return "initial"
        case .unset:
            return "unset"
        case .list(let values):
            return values.map { $0.description }.joined(separator: " ")
        }
    }
}
