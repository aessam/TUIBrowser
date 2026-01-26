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
        stylesheets: [Stylesheet]
    ) -> StyleMap {
        var styleMap = StyleMap()

        guard let root = document.documentElement else {
            return styleMap
        }

        // Resolve styles recursively from root
        resolveRecursive(element: root, parentStyle: nil, stylesheets: stylesheets, styleMap: &styleMap)

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
        stylesheets: [Stylesheet]
    ) -> ComputedStyle {
        // Collect matching rules
        let matchedRules = cascadeEngine.collectMatchingRules(
            for: element,
            from: stylesheets,
            defaultStyles: defaultStyles
        )

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
        styleMap: inout StyleMap
    ) {
        // Resolve this element's style
        let style = resolveElement(element, parentStyle: parentStyle, stylesheets: stylesheets)

        // Store in map using ObjectIdentifier
        let id = ObjectIdentifier(element)
        styleMap[id] = style

        // Recursively resolve children
        for child in element.children {
            resolveRecursive(
                element: child,
                parentStyle: style,
                stylesheets: stylesheets,
                styleMap: &styleMap
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
        defaultStyles: Stylesheet = DefaultStyles.create()
    ) -> StyleMap {
        let resolver = StyleResolver(defaultStyles: defaultStyles)
        return resolver.resolve(document: document, stylesheets: stylesheets)
    }
}
