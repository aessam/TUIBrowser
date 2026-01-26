// TUIBrowser - Focus Manager
//
// Manages focusable elements and keyboard navigation.

import TUIHTMLParser
import TUILayout

/// Manages focusable elements in the document
public struct FocusManager {

    public init() {}

    // MARK: - Focusable Element Collection

    /// Collect all focusable elements from a document in DOM order
    /// - Parameter document: The document to scan
    /// - Returns: Array of focusable elements in tab order
    public func collectFocusableElements(from document: Document) -> [Element] {
        var focusable: [Element] = []

        func traverse(_ node: Node) {
            if let element = node as? Element {
                if isFocusable(element) {
                    focusable.append(element)
                }
                for child in element.children {
                    traverse(child)
                }
            }
        }

        if let body = document.body {
            traverse(body)
        }

        // Sort by tabindex (elements with positive tabindex come first, then 0/no tabindex)
        return focusable.sorted { e1, e2 in
            let tab1 = tabIndex(e1)
            let tab2 = tabIndex(e2)

            // Negative tabindex elements are not in the tab order
            if tab1 < 0 && tab2 >= 0 { return false }
            if tab1 >= 0 && tab2 < 0 { return true }
            if tab1 < 0 && tab2 < 0 { return false }  // Both negative, keep DOM order

            // Positive tabindex comes before 0
            if tab1 > 0 && tab2 == 0 { return true }
            if tab1 == 0 && tab2 > 0 { return false }

            // Both positive: lower number comes first
            if tab1 > 0 && tab2 > 0 { return tab1 < tab2 }

            // Both are 0: DOM order (already sorted)
            return false
        }
    }

    /// Check if an element is focusable
    /// - Parameter element: The element to check
    /// - Returns: true if the element can receive focus
    public func isFocusable(_ element: Element) -> Bool {
        // Check for explicit tabindex=-1 (programmatically focusable only)
        if let tabStr = element.getAttribute("tabindex"),
           let tab = Int(tabStr), tab < 0 {
            return false
        }

        // Check disabled state
        if element.hasAttribute("disabled") {
            return false
        }

        switch element.tagName.lowercased() {
        case "a":
            // Links are focusable if they have an href
            return element.hasAttribute("href")

        case "button":
            return true

        case "input":
            // Most input types are focusable except hidden
            let inputType = element.getAttribute("type")?.lowercased() ?? "text"
            return inputType != "hidden"

        case "select", "textarea":
            return true

        case "area":
            return element.hasAttribute("href")

        default:
            // Elements with explicit tabindex >= 0 are focusable
            if let tabStr = element.getAttribute("tabindex"),
               let tab = Int(tabStr), tab >= 0 {
                return true
            }
            return false
        }
    }

    /// Get the tabindex of an element
    /// - Parameter element: The element
    /// - Returns: The tabindex value (0 for naturally focusable elements without explicit tabindex)
    public func tabIndex(_ element: Element) -> Int {
        if let tabStr = element.getAttribute("tabindex"),
           let tab = Int(tabStr) {
            return tab
        }
        // Naturally focusable elements default to 0
        return 0
    }

    // MARK: - Focus Navigation

    /// Find the next focusable element after the given index
    /// - Parameters:
    ///   - currentIndex: Current focus index (nil if nothing focused)
    ///   - elements: Array of focusable elements
    /// - Returns: Index of the next focusable element
    public func nextFocusIndex(from currentIndex: Int?, in elements: [Element]) -> Int? {
        guard !elements.isEmpty else { return nil }

        if let current = currentIndex {
            let next = current + 1
            return next < elements.count ? next : 0  // Wrap around
        } else {
            return 0  // Start at first element
        }
    }

    /// Find the previous focusable element before the given index
    /// - Parameters:
    ///   - currentIndex: Current focus index (nil if nothing focused)
    ///   - elements: Array of focusable elements
    /// - Returns: Index of the previous focusable element
    public func previousFocusIndex(from currentIndex: Int?, in elements: [Element]) -> Int? {
        guard !elements.isEmpty else { return nil }

        if let current = currentIndex {
            let prev = current - 1
            return prev >= 0 ? prev : elements.count - 1  // Wrap around
        } else {
            return elements.count - 1  // Start at last element
        }
    }

    // MARK: - Layout Box Lookup

    /// Find the layout box corresponding to a focused element
    /// - Parameters:
    ///   - element: The focused element
    ///   - layout: The root layout box
    /// - Returns: The layout box for the element, if found
    public func findLayoutBox(for element: Element, in layout: LayoutBox) -> LayoutBox? {
        var result: LayoutBox?

        layout.traverse { box in
            if box.element === element {
                result = box
            }
        }

        return result
    }
}
