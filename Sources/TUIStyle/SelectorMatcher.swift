// TUIStyle - Selector Matcher
//
// Matches CSS selectors against DOM elements.

import TUICore
import TUIHTMLParser
import TUICSSParser

/// Matches CSS selectors to DOM elements
public struct SelectorMatcher: Sendable {

    public init() {}

    // MARK: - Main Matching

    /// Check if a selector matches an element
    public func matches(_ selector: Selector, element: Element) -> Bool {
        // A selector is a sequence of (SimpleSelector, Combinator?) pairs
        // We match right-to-left
        var components = selector.components
        guard !components.isEmpty else { return false }

        // Start with the rightmost simple selector
        let (lastSimple, _) = components.removeLast()
        guard matchesSimple(lastSimple, element: element) else { return false }

        if components.isEmpty {
            return true
        }

        // Process remaining components right-to-left
        var currentElement: Element? = element

        while !components.isEmpty {
            let (simple, combinator) = components.removeLast()

            switch combinator {
            case .descendant, nil:
                // Match any ancestor
                var matched = false
                var ancestor = currentElement?.parentElement
                while let parent = ancestor {
                    if matchesSimple(simple, element: parent) {
                        currentElement = parent
                        matched = true
                        break
                    }
                    ancestor = parent.parentElement
                }
                if !matched { return false }

            case .child:
                // Match direct parent only
                guard let parent = currentElement?.parentElement,
                      matchesSimple(simple, element: parent) else {
                    return false
                }
                currentElement = parent

            case .adjacentSibling:
                // Match immediate previous sibling
                guard let sibling = currentElement?.previousElementSibling,
                      matchesSimple(simple, element: sibling) else {
                    return false
                }
                currentElement = sibling

            case .generalSibling:
                // Match any previous sibling
                var matched = false
                var sibling = currentElement?.previousElementSibling
                while let sib = sibling {
                    if matchesSimple(simple, element: sib) {
                        currentElement = sib
                        matched = true
                        break
                    }
                    sibling = sib.previousElementSibling
                }
                if !matched { return false }
            }
        }

        return true
    }

    // MARK: - Simple Selector Matching

    /// Check if a simple selector matches an element
    public func matchesSimple(_ selector: SimpleSelector, element: Element) -> Bool {
        // Check tag name
        if let tagName = selector.tagName {
            if tagName != "*" && tagName.lowercased() != element.tagName {
                return false
            }
        }

        // Check ID
        if let id = selector.id {
            if element.id != id {
                return false
            }
        }

        // Check classes
        for className in selector.classes {
            if !element.classList.contains(className) {
                return false
            }
        }

        return true
    }

    // MARK: - Utility Methods

    /// Find all elements matching a selector in a document
    public func querySelectorAll(_ selector: Selector, in document: Document) -> [Element] {
        var results: [Element] = []

        func traverse(_ node: Node) {
            if let element = node as? Element {
                if matches(selector, element: element) {
                    results.append(element)
                }
                for child in element.children {
                    traverse(child)
                }
            }
        }

        if let root = document.documentElement {
            traverse(root)
        }

        return results
    }

    /// Find first element matching a selector
    public func querySelector(_ selector: Selector, in document: Document) -> Element? {
        func traverse(_ node: Node) -> Element? {
            if let element = node as? Element {
                if matches(selector, element: element) {
                    return element
                }
                for child in element.children {
                    if let found = traverse(child) {
                        return found
                    }
                }
            }
            return nil
        }

        if let root = document.documentElement {
            return traverse(root)
        }
        return nil
    }
}
