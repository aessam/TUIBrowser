// TUICSSParser - CSS Declaration

/// Represents a CSS property declaration (property: value)
public struct CSSDeclaration: Equatable, Hashable, Sendable {
    /// The property name (e.g., "color", "background-color")
    public let property: String

    /// The property value
    public let value: CSSValue

    /// Whether this declaration has !important
    public let important: Bool

    public init(property: String, value: CSSValue, important: Bool = false) {
        self.property = property.lowercased()
        self.value = value
        self.important = important
    }
}

extension CSSDeclaration: CustomStringConvertible {
    public var description: String {
        if important {
            return "\(property): \(value) !important"
        } else {
            return "\(property): \(value)"
        }
    }
}
