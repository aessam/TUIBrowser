// TUIHTMLParser - CSS Selector Matcher
// Basic CSS selector matching for querySelector/querySelectorAll

import TUICore

/// Simple CSS selector matcher
/// Supports: tag, #id, .class, tag.class, tag#id, descendant selectors
internal final class SelectorMatcher {
    private let selectors: [SimpleSelector]

    init(selector: String) {
        self.selectors = SelectorMatcher.parse(selector)
    }

    /// Find the first matching element
    func findFirst(in root: Node) -> Element? {
        var result: Element?
        traverse(root) { element in
            if matches(element) {
                result = element
                return false // Stop traversal
            }
            return true // Continue
        }
        return result
    }

    /// Find all matching elements
    func findAll(in root: Node) -> [Element] {
        var results: [Element] = []
        traverse(root) { element in
            if matches(element) {
                results.append(element)
            }
            return true // Continue
        }
        return results
    }

    /// Check if an element matches the selector
    private func matches(_ element: Element) -> Bool {
        // For descendant selectors, check each part
        if selectors.isEmpty { return false }

        // Simple case: single selector
        if selectors.count == 1 {
            return selectors[0].matches(element)
        }

        // Descendant combinator: last selector must match, then ancestors
        guard selectors.last?.matches(element) == true else {
            return false
        }

        // Check ancestors for remaining selectors
        var selectorIndex = selectors.count - 2
        var currentAncestor = element.parentNode as? Element

        while selectorIndex >= 0 && currentAncestor != nil {
            if selectors[selectorIndex].matches(currentAncestor!) {
                selectorIndex -= 1
            }
            currentAncestor = currentAncestor?.parentNode as? Element
        }

        return selectorIndex < 0
    }

    /// Traverse the DOM tree
    private func traverse(_ node: Node, visitor: (Element) -> Bool) {
        for child in node.childNodes {
            if let element = child as? Element {
                if !visitor(element) {
                    return
                }
                traverse(element, visitor: visitor)
            }
        }
    }

    /// Parse a selector string into simple selectors
    private static func parse(_ selector: String) -> [SimpleSelector] {
        // Split by whitespace for descendant combinator
        let parts = selector.split(separator: " ")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        return parts.map { SimpleSelector(from: $0) }
    }
}

/// Represents a simple selector (tag, id, class, or combination)
private struct SimpleSelector {
    var tagName: String?
    var id: String?
    var classes: [String] = []

    init(from selector: String) {
        var remaining = selector
        var currentPart = ""
        var partType: PartType = .tag

        enum PartType {
            case tag, id, `class`
        }

        func flushPart() {
            guard !currentPart.isEmpty else { return }
            switch partType {
            case .tag:
                tagName = currentPart.lowercased()
            case .id:
                id = currentPart
            case .class:
                classes.append(currentPart)
            }
            currentPart = ""
        }

        for char in remaining {
            switch char {
            case "#":
                flushPart()
                partType = .id
            case ".":
                flushPart()
                partType = .class
            default:
                currentPart.append(char)
            }
        }
        flushPart()
    }

    func matches(_ element: Element) -> Bool {
        // Check tag name
        if let tag = tagName, element.tagName != tag {
            return false
        }

        // Check id
        if let id = id, element.id != id {
            return false
        }

        // Check classes
        for cls in classes {
            if !element.classList.contains(cls) {
                return false
            }
        }

        return tagName != nil || id != nil || !classes.isEmpty
    }
}
