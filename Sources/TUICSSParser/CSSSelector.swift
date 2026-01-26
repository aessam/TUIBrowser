// TUICSSParser - CSS Selector Types

/// Attribute selector match type
public enum AttributeMatchType: Equatable, Hashable, Sendable {
    /// [attr] - has attribute
    case exists
    /// [attr=value] - exact match
    case exact
    /// [attr^=value] - starts with
    case prefix
    /// [attr$=value] - ends with
    case suffix
    /// [attr*=value] - contains
    case contains
    /// [attr~=value] - word match (space-separated)
    case word
    /// [attr|=value] - starts with or exactly equals (for lang attributes)
    case hyphen
}

/// Attribute selector
public struct AttributeSelector: Equatable, Hashable, Sendable {
    public var name: String
    public var matchType: AttributeMatchType
    public var value: String?
    public var caseSensitive: Bool

    public init(name: String, matchType: AttributeMatchType = .exists, value: String? = nil, caseSensitive: Bool = true) {
        self.name = name
        self.matchType = matchType
        self.value = value
        self.caseSensitive = caseSensitive
    }
}

/// Pseudo-class selector
public enum PseudoClass: Equatable, Hashable, Sendable {
    case firstChild
    case lastChild
    case nthChild(Int) // simplified: just the n value
    case nthLastChild(Int)
    case onlyChild
    case firstOfType
    case lastOfType
    case empty
    case not(SimpleSelector)
    case hover
    case focus
    case active
    case visited
    case link
    case enabled
    case disabled
    case checked
    case root
}

/// Represents a simple selector component (tag, class, id, attributes, pseudo-classes)
public struct SimpleSelector: Equatable, Hashable, Sendable {
    /// The tag name (e.g., "div", "p", "*" for universal)
    public var tagName: String?

    /// The ID (without the # prefix)
    public var id: String?

    /// The classes (without the . prefix)
    public var classes: [String]

    /// Attribute selectors
    public var attributes: [AttributeSelector]

    /// Pseudo-classes
    public var pseudoClasses: [PseudoClass]

    public init(
        tagName: String? = nil,
        id: String? = nil,
        classes: [String] = [],
        attributes: [AttributeSelector] = [],
        pseudoClasses: [PseudoClass] = []
    ) {
        self.tagName = tagName
        self.id = id
        self.classes = classes
        self.attributes = attributes
        self.pseudoClasses = pseudoClasses
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
        b += attributes.count
        b += pseudoClasses.count

        if let tag = tagName, tag != "*" {
            c += 1
        }

        return Specificity(a: a, b: b, c: c)
    }

    /// Check if this selector matches nothing specific
    public var isEmpty: Bool {
        tagName == nil && id == nil && classes.isEmpty && attributes.isEmpty && pseudoClasses.isEmpty
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
