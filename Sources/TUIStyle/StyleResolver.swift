// TUIStyle - Style Resolver
//
// Main API for resolving computed styles for all elements in a document.

import TUICore
import TUIHTMLParser
import TUICSSParser

/// Maps element identifiers to computed styles
public typealias StyleMap = [ObjectIdentifier: ComputedStyle]

/// Resolves computed styles for DOM elements
public struct StyleResolver: Sendable {
    private let cascadeEngine: CascadeEngine
    private let defaultStyles: Stylesheet
    private let maxElements: Int = 6000  // safety cap to avoid pathological trees

    public init(defaultStyles: Stylesheet? = nil) {
        self.cascadeEngine = CascadeEngine()
        self.defaultStyles = defaultStyles ?? DefaultStyles.create()
    }

    // MARK: - Main Resolution API

    /// Resolve styles for all elements in a document
    /// - Parameters:
    ///   - document: The DOM document
    ///   - stylesheets: Author stylesheets to apply
    /// - Returns: Map from element ObjectIdentifier to ComputedStyle
    public func resolve(
        document: Document,
        stylesheets: [Stylesheet],
        skipInlineStyles: Bool = false
    ) -> StyleMap {
        var styleMap = StyleMap()

        guard let root = document.documentElement else {
            return styleMap
        }

        // Inline style parsing budget (characters) and element count to prevent runaway work
        var inlineStyleCharBudget = 20_000
        var inlineStyleElementBudget = 2_000

        // Resolve styles recursively from root
        var processed = 0
        resolveRecursive(
            element: root,
            parentStyle: nil,
            stylesheets: stylesheets,
            styleMap: &styleMap,
            processed: &processed,
            skipInlineStyles: skipInlineStyles,
            inlineCharBudget: &inlineStyleCharBudget,
            inlineElementBudget: &inlineStyleElementBudget
        )

        return styleMap
    }

    /// Resolve style for a single element (without children)
    /// - Parameters:
    ///   - element: The element to style
    ///   - parentStyle: Parent's computed style (for inheritance)
    ///   - stylesheets: Author stylesheets
    /// - Returns: Computed style for the element
    public func resolveElement(
        _ element: Element,
        parentStyle: ComputedStyle?,
        stylesheets: [Stylesheet],
        skipInline: Bool = false,
        inlineCharBudget: inout Int,
        inlineElementBudget: inout Int
    ) -> ComputedStyle {
        // Collect matching rules
        var matchedRules = cascadeEngine.collectMatchingRules(
            for: element,
            from: stylesheets,
            defaultStyles: defaultStyles
        )

        // Inline styles (style="" attribute) have the highest author priority
        if !skipInline,
           inlineElementBudget > 0,
           let inlineStyle = element.getAttribute("style"),
           !inlineStyle.isEmpty {

            var cappedInline = inlineStyle
            if cappedInline.count > inlineCharBudget {
                cappedInline = String(cappedInline.prefix(max(0, inlineCharBudget)))
            }
            // Update budgets
            inlineCharBudget = max(0, inlineCharBudget - cappedInline.count)
            inlineElementBudget -= 1

            // Hard cap inline style length to avoid pathological parsing
            let inlineDeclarations = CSSParser.parseDeclarations(cappedInline)
            if !inlineDeclarations.isEmpty {
                // Give inline styles a very high specificity so they win over ID selectors
                let inlineSpecificity = Specificity(a: 1000, b: 0, c: 0)
                matchedRules.append(
                    MatchedRule(
                        declarations: inlineDeclarations,
                        specificity: inlineSpecificity,
                        sourceOrder: Int.max
                    )
                )
            }
        }

        // Apply cascade
        var cascadedValues = cascadeEngine.cascade(matchedRules: matchedRules)

        // Apply inheritance
        cascadedValues = cascadeEngine.applyInheritance(
            cascadedValues: cascadedValues,
            parentStyle: parentStyle
        )

        // Compute final style
        return cascadeEngine.computeStyle(
            from: cascadedValues,
            parentStyle: parentStyle,
            elementTagName: element.tagName
        )
    }

    // MARK: - Private Implementation

    private func resolveRecursive(
        element: Element,
        parentStyle: ComputedStyle?,
        stylesheets: [Stylesheet],
        styleMap: inout StyleMap,
        processed: inout Int,
        skipInlineStyles: Bool,
        inlineCharBudget: inout Int,
        inlineElementBudget: inout Int
    ) {
        guard processed < maxElements else { return }

        // Resolve this element's style
        let style = resolveElement(
            element,
            parentStyle: parentStyle,
            stylesheets: stylesheets,
            skipInline: skipInlineStyles,
            inlineCharBudget: &inlineCharBudget,
            inlineElementBudget: &inlineElementBudget
        )

        // Store in map using ObjectIdentifier
        let id = ObjectIdentifier(element)
        styleMap[id] = style

        processed += 1
        if processed >= maxElements { return }

        // Recursively resolve children
        for child in element.children {
            resolveRecursive(
                element: child,
                parentStyle: style,
                stylesheets: stylesheets,
                styleMap: &styleMap,
                processed: &processed,
                skipInlineStyles: skipInlineStyles,
                inlineCharBudget: &inlineCharBudget,
                inlineElementBudget: &inlineElementBudget
            )
        }
    }

    // MARK: - Utility Methods

    /// Get computed style for an element from a style map
    public static func getStyle(for element: Element, from styleMap: StyleMap) -> ComputedStyle {
        let id = ObjectIdentifier(element)
        return styleMap[id] ?? ComputedStyle.default
    }

    /// Check if an element should be displayed
    public static func isVisible(_ element: Element, in styleMap: StyleMap) -> Bool {
        let style = getStyle(for: element, from: styleMap)
        return style.display != .none
    }

    /// Check if an element is block-level
    public static func isBlock(_ element: Element, in styleMap: StyleMap) -> Bool {
        let style = getStyle(for: element, from: styleMap)
        return style.display == .block || style.display == .listItem
    }

    /// Check if an element is inline
    public static func isInline(_ element: Element, in styleMap: StyleMap) -> Bool {
        let style = getStyle(for: element, from: styleMap)
        return style.display == .inline || style.display == .inlineBlock
    }
}

// MARK: - Static Convenience API

extension StyleResolver {
    /// Resolve styles using default configuration
    public static func resolve(
        document: Document,
        stylesheets: [Stylesheet],
        defaultStyles: Stylesheet = DefaultStyles.create(),
        skipInlineStyles: Bool = false
    ) -> StyleMap {
        let resolver = StyleResolver(defaultStyles: defaultStyles)
        return resolver.resolve(
            document: document,
            stylesheets: stylesheets,
            skipInlineStyles: skipInlineStyles
        )
    }
}
