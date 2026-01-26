// TUICSSParser - CSS Rule and Stylesheet

/// Represents a CSS rule (selectors + declarations)
public struct CSSRule: Sendable {
    /// The selectors for this rule
    public let selectors: [Selector]

    /// The declarations in this rule
    public let declarations: [CSSDeclaration]

    public init(selectors: [Selector], declarations: [CSSDeclaration]) {
        self.selectors = selectors
        self.declarations = declarations
    }
}

extension CSSRule: CustomStringConvertible {
    public var description: String {
        let selectorStr = selectors.map { $0.description }.joined(separator: ", ")
        let declStr = declarations.map { "  \($0);" }.joined(separator: "\n")
        return "\(selectorStr) {\n\(declStr)\n}"
    }
}

/// Represents a complete CSS stylesheet
public struct Stylesheet: Sendable {
    /// The rules in this stylesheet
    public var rules: [CSSRule]

    public init(rules: [CSSRule] = []) {
        self.rules = rules
    }

    /// Add a rule to the stylesheet
    public mutating func addRule(_ rule: CSSRule) {
        rules.append(rule)
    }

    /// Get all rules that match a given simple selector
    /// This is a simplified matching - full matching would require DOM context
    public func rulesMatching(tagName: String?, id: String?, classes: [String]) -> [CSSRule] {
        rules.filter { rule in
            rule.selectors.contains { selector in
                guard let first = selector.components.first else { return false }
                let simple = first.0

                // Check tag match
                if let selectorTag = simple.tagName {
                    if selectorTag != "*" && selectorTag.lowercased() != tagName?.lowercased() {
                        return false
                    }
                }

                // Check ID match
                if let selectorId = simple.id {
                    if selectorId != id {
                        return false
                    }
                }

                // Check classes match
                for cls in simple.classes {
                    if !classes.contains(cls) {
                        return false
                    }
                }

                return true
            }
        }
    }
}

extension Stylesheet: CustomStringConvertible {
    public var description: String {
        rules.map { $0.description }.joined(separator: "\n\n")
    }
}
