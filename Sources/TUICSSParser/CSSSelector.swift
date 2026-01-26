// TUICSSParser - CSS Selector Types

/// Represents a simple selector component (tag, class, id)
public struct SimpleSelector: Equatable, Hashable, Sendable {
    /// The tag name (e.g., "div", "p", "*" for universal)
    public var tagName: String?

    /// The ID (without the # prefix)
    public var id: String?

    /// The classes (without the . prefix)
    public var classes: [String]

    public init(tagName: String? = nil, id: String? = nil, classes: [String] = []) {
        self.tagName = tagName
        self.id = id
        self.classes = classes
    }

    /// Calculate the specificity of this simple selector
    public var specificity: Specificity {
        var a = 0
        var b = 0
        var c = 0

        if id != nil {
            a += 1
        }

        b += classes.count

        if let tag = tagName, tag != "*" {
            c += 1
        }

        return Specificity(a: a, b: b, c: c)
    }

    /// Check if this selector matches nothing specific
    public var isEmpty: Bool {
        tagName == nil && id == nil && classes.isEmpty
    }
}

/// Represents a combinator between selector components
public enum Combinator: Equatable, Hashable, Sendable {
    /// Descendant combinator (space): `div p` - matches p inside div
    case descendant

    /// Child combinator (>): `div > p` - matches p that is direct child of div
    case child

    /// Adjacent sibling combinator (+): `h1 + p` - matches p immediately after h1
    case adjacentSibling

    /// General sibling combinator (~): `h1 ~ p` - matches p after h1 at same level
    case generalSibling
}

extension Combinator: CustomStringConvertible {
    public var description: String {
        switch self {
        case .descendant: return " "
        case .child: return " > "
        case .adjacentSibling: return " + "
        case .generalSibling: return " ~ "
        }
    }
}

/// Represents a complete CSS selector
public struct Selector: Equatable, Hashable, Sendable {
    /// The selector components with their combinators
    /// The combinator is what follows the simple selector (nil for the last component)
    public var components: [(SimpleSelector, Combinator?)]

    /// The calculated specificity of this selector
    public var specificity: Specificity

    public init(components: [(SimpleSelector, Combinator?)], specificity: Specificity) {
        self.components = components
        self.specificity = specificity
    }

    /// Calculate specificity from components
    public static func calculateSpecificity(from components: [(SimpleSelector, Combinator?)]) -> Specificity {
        components.reduce(Specificity.zero) { result, component in
            result + component.0.specificity
        }
    }

    /// Make Selector conform to Hashable
    public func hash(into hasher: inout Hasher) {
        for (selector, combinator) in components {
            hasher.combine(selector)
            hasher.combine(combinator)
        }
        hasher.combine(specificity)
    }

    /// Make Selector conform to Equatable
    public static func == (lhs: Selector, rhs: Selector) -> Bool {
        guard lhs.components.count == rhs.components.count else { return false }
        guard lhs.specificity == rhs.specificity else { return false }

        for i in 0..<lhs.components.count {
            if lhs.components[i].0 != rhs.components[i].0 ||
               lhs.components[i].1 != rhs.components[i].1 {
                return false
            }
        }

        return true
    }
}

extension Selector: CustomStringConvertible {
    public var description: String {
        var result = ""
        for (simple, combinator) in components {
            if let tag = simple.tagName {
                result += tag
            }
            if let id = simple.id {
                result += "#\(id)"
            }
            for cls in simple.classes {
                result += ".\(cls)"
            }
            if let comb = combinator {
                result += comb.description
            }
        }
        return result
    }
}
