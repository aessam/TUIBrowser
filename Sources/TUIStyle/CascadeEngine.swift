// TUIStyle - Cascade Engine
//
// Implements CSS cascade: !important > specificity > source order

import TUICore
import TUIHTMLParser
import TUICSSParser

/// A matched CSS rule with its specificity and source order
public struct MatchedRule: Sendable {
    public let declarations: [CSSDeclaration]
    public let specificity: Specificity
    public let sourceOrder: Int

    public init(declarations: [CSSDeclaration], specificity: Specificity, sourceOrder: Int) {
        self.declarations = declarations
        self.specificity = specificity
        self.sourceOrder = sourceOrder
    }
}

/// Cascade origin (browser defaults < user agent < author < author !important)
public enum CascadeOrigin: Int, Comparable, Sendable {
    case userAgent = 0      // Browser defaults
    case author = 1         // Page stylesheets
    case authorImportant = 2

    public static func < (lhs: CascadeOrigin, rhs: CascadeOrigin) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// CSS cascade engine
public struct CascadeEngine: Sendable {
    private let matcher: SelectorMatcher

    public init() {
        self.matcher = SelectorMatcher()
    }

    // MARK: - Property Classification

    /// Properties that inherit by default
    public static let inheritedProperties: Set<String> = [
        "color",
        "font-weight",
        "font-style",
        "font-family",
        "font-size",
        "text-align",
        "text-decoration",
        "white-space",
        "list-style-type",
        "line-height",
        "letter-spacing",
        "word-spacing",
        "visibility",
        "cursor"
    ]

    /// Check if a property inherits by default
    public static func isInherited(_ property: String) -> Bool {
        inheritedProperties.contains(property.lowercased())
    }

    // MARK: - Cascade Resolution

    /// Collect all rules matching an element
    public func collectMatchingRules(
        for element: Element,
        from stylesheets: [Stylesheet],
        defaultStyles: Stylesheet
    ) -> [MatchedRule] {
        var rules: [MatchedRule] = []
        var sourceOrder = 0

        // Add user agent (default) styles
        for rule in defaultStyles.rules {
            for selector in rule.selectors {
                if matcher.matches(selector, element: element) {
                    rules.append(MatchedRule(
                        declarations: rule.declarations,
                        specificity: selector.specificity,
                        sourceOrder: sourceOrder
                    ))
                    sourceOrder += 1
                    break  // Only add rule once per element
                }
            }
        }

        // Add author styles
        for stylesheet in stylesheets {
            for rule in stylesheet.rules {
                for selector in rule.selectors {
                    if matcher.matches(selector, element: element) {
                        rules.append(MatchedRule(
                            declarations: rule.declarations,
                            specificity: selector.specificity,
                            sourceOrder: sourceOrder
                        ))
                        sourceOrder += 1
                        break
                    }
                }
            }
        }

        return rules
    }

    /// Resolve cascaded values for all properties
    public func cascade(matchedRules: [MatchedRule]) -> [String: CSSValue] {
        var propertyValues: [String: (value: CSSValue, specificity: Specificity, sourceOrder: Int, important: Bool)] = [:]

        for rule in matchedRules {
            for declaration in rule.declarations {
                let property = declaration.property

                if let existing = propertyValues[property] {
                    // Cascade priority:
                    // 1. !important beats non-important
                    // 2. Higher specificity wins
                    // 3. Later source order wins (equal specificity)

                    let shouldReplace: Bool

                    if declaration.important && !existing.important {
                        // !important always wins over non-important
                        shouldReplace = true
                    } else if !declaration.important && existing.important {
                        // Non-important never beats !important
                        shouldReplace = false
                    } else if rule.specificity > existing.specificity {
                        // Higher specificity wins (same importance)
                        shouldReplace = true
                    } else if rule.specificity == existing.specificity && rule.sourceOrder > existing.sourceOrder {
                        // Later source order wins (same specificity and importance)
                        shouldReplace = true
                    } else {
                        shouldReplace = false
                    }

                    if shouldReplace {
                        propertyValues[property] = (declaration.value, rule.specificity, rule.sourceOrder, declaration.important)
                    }
                } else {
                    propertyValues[property] = (declaration.value, rule.specificity, rule.sourceOrder, declaration.important)
                }
            }
        }

        return propertyValues.mapValues { $0.value }
    }

    /// Apply inheritance for properties that inherit
    public func applyInheritance(
        cascadedValues: [String: CSSValue],
        parentStyle: ComputedStyle?
    ) -> [String: CSSValue] {
        guard let parent = parentStyle else {
            return cascadedValues
        }

        var values = cascadedValues

        // Apply inheritance for properties not explicitly set
        for property in Self.inheritedProperties {
            if values[property] == nil {
                // Inherit from parent
                if let inheritedValue = getPropertyValue(property, from: parent) {
                    values[property] = inheritedValue
                }
            } else if values[property] == .inherit {
                // Explicit inherit keyword
                if let inheritedValue = getPropertyValue(property, from: parent) {
                    values[property] = inheritedValue
                }
            }
        }

        return values
    }

    /// Get a CSS value from a computed style
    private func getPropertyValue(_ property: String, from style: ComputedStyle) -> CSSValue? {
        switch property {
        case "color":
            return .color(style.color)
        case "background-color":
            if let bg = style.backgroundColor {
                return .color(bg)
            }
            return nil
        case "font-weight":
            return .keyword(style.fontWeight == .bold ? "bold" : "normal")
        case "font-style":
            return .keyword(style.fontStyle.rawValue)
        case "text-decoration":
            switch style.textDecoration {
            case .none: return .keyword("none")
            case .underline: return .keyword("underline")
            case .lineThrough: return .keyword("line-through")
            case .overline: return .keyword("overline")
            }
        case "text-align":
            return .keyword(style.textAlign.rawValue)
        case "white-space":
            return .keyword(style.whiteSpace.rawValue)
        case "list-style-type":
            return .keyword(style.listStyleType.rawValue)
        case "display":
            return .keyword(style.display.rawValue)
        default:
            return nil
        }
    }

    // MARK: - Value Resolution

    /// Convert cascaded CSS values to a computed style
    public func computeStyle(
        from cascadedValues: [String: CSSValue],
        parentStyle: ComputedStyle?,
        elementTagName: String
    ) -> ComputedStyle {
        var style = ComputedStyle.default

        // Start with inherited values from parent if applicable
        if let parent = parentStyle {
            style = style.inherit(from: parent)
        }

        // Apply cascaded values
        for (property, value) in cascadedValues {
            applyProperty(property, value: value, to: &style)
        }

        return style
    }

    /// Apply a single property value to a computed style
    private func applyProperty(_ property: String, value: CSSValue, to style: inout ComputedStyle) {
        switch property {
        case "display":
            if let keyword = value.keywordValue,
               let display = Display(keyword: keyword) {
                style.display = display
            }

        case "color":
            if let color = value.colorValue {
                style.color = color
            } else if let keyword = value.keywordValue,
                      let color = Color.fromName(keyword) {
                style.color = color
            }

        case "background-color", "background":
            if let color = value.colorValue {
                style.backgroundColor = color
            } else if let keyword = value.keywordValue {
                if keyword == "transparent" {
                    style.backgroundColor = nil
                } else if let color = Color.fromName(keyword) {
                    style.backgroundColor = color
                }
            }

        case "font-weight":
            if let keyword = value.keywordValue,
               let weight = FontWeight(keyword: keyword) {
                style.fontWeight = weight
            } else if let num = value.numericValue {
                style.fontWeight = .weight(Int(num))
            }

        case "font-style":
            if let keyword = value.keywordValue,
               let fontStyle = FontStyle(keyword: keyword) {
                style.fontStyle = fontStyle
            }

        case "text-decoration":
            if let keyword = value.keywordValue,
               let decoration = TextDecoration(keyword: keyword) {
                style.textDecoration = decoration
            }

        case "text-align":
            if let keyword = value.keywordValue,
               let align = TextAlign(keyword: keyword) {
                style.textAlign = align
            }

        case "white-space":
            if let keyword = value.keywordValue,
               let ws = WhiteSpace(keyword: keyword) {
                style.whiteSpace = ws
            }

        case "list-style-type":
            if let keyword = value.keywordValue,
               let listType = ListStyleType(keyword: keyword) {
                style.listStyleType = listType
            }

        case "margin":
            if let px = resolveLength(value) {
                style.margin = EdgeInsets(all: px)
            }

        case "margin-top":
            if let px = resolveLength(value) {
                style.margin = EdgeInsets(top: px, right: style.margin.right, bottom: style.margin.bottom, left: style.margin.left)
            }

        case "margin-right":
            if let px = resolveLength(value) {
                style.margin = EdgeInsets(top: style.margin.top, right: px, bottom: style.margin.bottom, left: style.margin.left)
            }

        case "margin-bottom":
            if let px = resolveLength(value) {
                style.margin = EdgeInsets(top: style.margin.top, right: style.margin.right, bottom: px, left: style.margin.left)
            }

        case "margin-left":
            if let keyword = value.keywordValue, keyword.lowercased() == "auto" {
                style.marginLeftAuto = true
            } else if let px = resolveLength(value) {
                style.margin = EdgeInsets(top: style.margin.top, right: style.margin.right, bottom: style.margin.bottom, left: px)
                style.marginLeftAuto = false
            }

        case "margin-right":
            if let keyword = value.keywordValue, keyword.lowercased() == "auto" {
                style.marginRightAuto = true
            } else if let px = resolveLength(value) {
                style.margin = EdgeInsets(top: style.margin.top, right: px, bottom: style.margin.bottom, left: style.margin.left)
                style.marginRightAuto = false
            }

        case "padding":
            if let px = resolveLength(value) {
                style.padding = EdgeInsets(all: px)
            }

        case "padding-top":
            if let px = resolveLength(value) {
                style.padding = EdgeInsets(top: px, right: style.padding.right, bottom: style.padding.bottom, left: style.padding.left)
            }

        case "padding-right":
            if let px = resolveLength(value) {
                style.padding = EdgeInsets(top: style.padding.top, right: px, bottom: style.padding.bottom, left: style.padding.left)
            }

        case "padding-bottom":
            if let px = resolveLength(value) {
                style.padding = EdgeInsets(top: style.padding.top, right: style.padding.right, bottom: px, left: style.padding.left)
            }

        case "padding-left":
            if let px = resolveLength(value) {
                style.padding = EdgeInsets(top: style.padding.top, right: style.padding.right, bottom: style.padding.bottom, left: px)
            }

        // Width/Height sizing
        case "width":
            style.width = resolveCSSLength(value)

        case "height":
            style.height = resolveCSSLength(value)

        case "min-width":
            style.minWidth = resolveCSSLength(value)

        case "max-width":
            style.maxWidth = resolveCSSLength(value)

        case "min-height":
            style.minHeight = resolveCSSLength(value)

        case "max-height":
            style.maxHeight = resolveCSSLength(value)

        // Flexbox properties
        case "flex-direction":
            if let keyword = value.keywordValue,
               let dir = FlexDirection(keyword: keyword) {
                style.flexDirection = dir
            }

        case "justify-content":
            if let keyword = value.keywordValue,
               let jc = JustifyContent(keyword: keyword) {
                style.justifyContent = jc
            }

        case "align-items":
            if let keyword = value.keywordValue,
               let ai = AlignItems(keyword: keyword) {
                style.alignItems = ai
            }

        case "flex-wrap":
            if let keyword = value.keywordValue,
               let fw = FlexWrap(keyword: keyword) {
                style.flexWrap = fw
            }

        case "gap":
            if let px = resolveLength(value) {
                style.gap = px
            }

        case "flex-grow":
            if let num = value.numericValue {
                style.flexGrow = num
            }

        case "flex-shrink":
            if let num = value.numericValue {
                style.flexShrink = num
            }

        case "flex-basis":
            style.flexBasis = resolveCSSLength(value)

        case "flex":
            // Shorthand: flex-grow [flex-shrink] [flex-basis]
            // Simple handling: just extract grow value
            if let num = value.numericValue {
                style.flexGrow = num
            } else if let keyword = value.keywordValue {
                switch keyword.lowercased() {
                case "auto":
                    style.flexGrow = 1
                    style.flexShrink = 1
                    style.flexBasis = .auto
                case "none":
                    style.flexGrow = 0
                    style.flexShrink = 0
                    style.flexBasis = .auto
                case "initial":
                    style.flexGrow = 0
                    style.flexShrink = 1
                    style.flexBasis = .auto
                default:
                    break
                }
            }

        default:
            break  // Unsupported property
        }
    }

    /// Resolve a CSS length value to a CSSLength type
    private func resolveCSSLength(_ value: CSSValue) -> CSSLength? {
        switch value {
        case .keyword(let kw) where kw.lowercased() == "auto":
            return .auto
        case .length(let num, let unit):
            switch unit {
            case .px:
                return .px(Int(num / 8))  // ~8px per character cell
            case .em, .rem:
                return .px(Int(num))  // 1em = 1 character
            case .ch:
                return .px(Int(num))  // 1ch = 1 character exactly
            case .percent:
                return .percent(num)
            default:
                return .px(Int(num / 8))
            }
        case .percentage(let pct):
            return .percent(pct)
        case .number(let num):
            if num == 0 {
                return .px(0)
            }
            return .px(Int(num))
        default:
            return nil
        }
    }

    /// Resolve a length value to integer pixels (for terminal, 1 character = ~8px)
    private func resolveLength(_ value: CSSValue) -> Int? {
        switch value {
        case .length(let num, let unit):
            switch unit {
            case .px:
                return Int(num / 8)  // ~8px per character cell
            case .em, .rem:
                return Int(num)  // 1em = 1 character
            case .ch:
                return Int(num)  // 1ch = 1 character exactly
            default:
                return Int(num / 8)
            }
        case .number(let num):
            return Int(num)
        case .keyword(let kw) where kw == "0":
            return 0
        default:
            return nil
        }
    }
}
