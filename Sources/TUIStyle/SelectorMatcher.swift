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

        // Check attribute selectors
        for attr in selector.attributes {
            if !matchesAttribute(attr, element: element) {
                return false
            }
        }

        // Check pseudo-classes
        for pseudo in selector.pseudoClasses {
            if !matchesPseudoClass(pseudo, element: element) {
                return false
            }
        }

        return true
    }

    // MARK: - Attribute Selector Matching

    /// Check if an attribute selector matches an element
    private func matchesAttribute(_ selector: AttributeSelector, element: Element) -> Bool {
        let attrValue = element.getAttribute(selector.name)

        switch selector.matchType {
        case .exists:
            // [attr] - just check if attribute exists
            return attrValue != nil

        case .exact:
            // [attr=value] - exact match
            guard let value = attrValue, let expected = selector.value else {
                return false
            }
            if selector.caseSensitive {
                return value == expected
            } else {
                return value.lowercased() == expected.lowercased()
            }

        case .prefix:
            // [attr^=value] - starts with
            guard let value = attrValue, let expected = selector.value else {
                return false
            }
            if selector.caseSensitive {
                return value.hasPrefix(expected)
            } else {
                return value.lowercased().hasPrefix(expected.lowercased())
            }

        case .suffix:
            // [attr$=value] - ends with
            guard let value = attrValue, let expected = selector.value else {
                return false
            }
            if selector.caseSensitive {
                return value.hasSuffix(expected)
            } else {
                return value.lowercased().hasSuffix(expected.lowercased())
            }

        case .contains:
            // [attr*=value] - contains
            guard let value = attrValue, let expected = selector.value else {
                return false
            }
            if selector.caseSensitive {
                return value.contains(expected)
            } else {
                return value.lowercased().contains(expected.lowercased())
            }

        case .word:
            // [attr~=value] - space-separated word match
            guard let value = attrValue, let expected = selector.value else {
                return false
            }
            let words = value.split(separator: " ").map(String.init)
            if selector.caseSensitive {
                return words.contains(expected)
            } else {
                return words.contains { $0.lowercased() == expected.lowercased() }
            }

        case .hyphen:
            // [attr|=value] - exact or prefix with hyphen
            guard let value = attrValue, let expected = selector.value else {
                return false
            }
            let compare = selector.caseSensitive ? value : value.lowercased()
            let exp = selector.caseSensitive ? expected : expected.lowercased()
            return compare == exp || compare.hasPrefix("\(exp)-")
        }
    }

    // MARK: - Pseudo-Class Matching

    /// Check if a pseudo-class matches an element
    private func matchesPseudoClass(_ pseudo: PseudoClass, element: Element) -> Bool {
        switch pseudo {
        case .firstChild:
            return isFirstChild(element)

        case .lastChild:
            return isLastChild(element)

        case .nthChild(let n):
            return getNthChildIndex(element) == n

        case .nthLastChild(let n):
            return getNthLastChildIndex(element) == n

        case .onlyChild:
            return isFirstChild(element) && isLastChild(element)

        case .firstOfType:
            return isFirstOfType(element)

        case .lastOfType:
            return isLastOfType(element)

        case .empty:
            return element.childNodes.isEmpty

        case .not(let selector):
            return !matchesSimple(selector, element: element)

        case .root:
            // Root element (html)
            return element.parentElement == nil || element.tagName == "html"

        case .enabled:
            // Form elements that are not disabled
            let formTags = ["input", "button", "select", "textarea"]
            return formTags.contains(element.tagName) && !element.hasAttribute("disabled")

        case .disabled:
            return element.hasAttribute("disabled")

        case .checked:
            return element.hasAttribute("checked")

        case .hover, .focus, .active, .visited, .link:
            // These require state tracking which we don't have in static rendering
            // For now, return false (not in that state)
            return false
        }
    }

    // MARK: - Position Helpers

    private func isFirstChild(_ element: Element) -> Bool {
        guard let parent = element.parentElement else { return true }
        return parent.children.first === element
    }

    private func isLastChild(_ element: Element) -> Bool {
        guard let parent = element.parentElement else { return true }
        return parent.children.last === element
    }

    private func getNthChildIndex(_ element: Element) -> Int {
        guard let parent = element.parentElement else { return 1 }
        for (index, child) in parent.children.enumerated() {
            if child === element {
                return index + 1 // 1-indexed
            }
        }
        return 0
    }

    private func getNthLastChildIndex(_ element: Element) -> Int {
        guard let parent = element.parentElement else { return 1 }
        let children = parent.children
        for (index, child) in children.reversed().enumerated() {
            if child === element {
                return index + 1 // 1-indexed from end
            }
        }
        return 0
    }

    private func isFirstOfType(_ element: Element) -> Bool {
        guard let parent = element.parentElement else { return true }
        for child in parent.children {
            if child.tagName == element.tagName {
                return child === element
            }
        }
        return false
    }

    private func isLastOfType(_ element: Element) -> Bool {
        guard let parent = element.parentElement else { return true }
        var lastOfType: Element?
        for child in parent.children {
            if child.tagName == element.tagName {
                lastOfType = child
            }
        }
        return lastOfType === element
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
