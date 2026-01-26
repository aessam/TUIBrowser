// TUIHTMLParser - Element Node
// Represents an HTML element in the DOM

import TUICore

/// Represents an HTML element
public final class Element: BaseNode {
    /// The tag name (lowercase)
    public let tagName: String

    /// Element attributes
    private var _attributes: [String: String] = [:]

    public override var nodeType: NodeType { .element }
    public override var nodeName: String { tagName.uppercased() }

    /// Create an element with the given tag name
    public init(tagName: String) {
        self.tagName = tagName.lowercased()
        super.init()
    }

    /// Create an element with tag name and attributes
    public init(tagName: String, attributes: [HTMLAttribute]) {
        self.tagName = tagName.lowercased()
        super.init()
        for attr in attributes {
            _attributes[attr.name.lowercased()] = attr.value
        }
    }

    // MARK: - Attributes

    /// Get an attribute value
    public func getAttribute(_ name: String) -> String? {
        _attributes[name.lowercased()]
    }

    /// Set an attribute value
    public func setAttribute(_ name: String, _ value: String) {
        _attributes[name.lowercased()] = value
    }

    /// Remove an attribute
    public func removeAttribute(_ name: String) {
        _attributes.removeValue(forKey: name.lowercased())
    }

    /// Check if an attribute exists
    public func hasAttribute(_ name: String) -> Bool {
        _attributes[name.lowercased()] != nil
    }

    /// All attribute names
    public var attributeNames: [String] {
        Array(_attributes.keys)
    }

    /// All attributes as a dictionary
    public var attributes: [String: String] {
        _attributes
    }

    // MARK: - Common Attributes

    /// The id attribute
    public var id: String {
        get { getAttribute("id") ?? "" }
        set { setAttribute("id", newValue) }
    }

    /// The class attribute as a set of class names
    public var classList: Set<String> {
        get {
            let classAttr = getAttribute("class") ?? ""
            let classes = classAttr.split(separator: " ")
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            return Set(classes)
        }
        set {
            setAttribute("class", newValue.joined(separator: " "))
        }
    }

    /// The class attribute as a string
    public var className: String {
        get { getAttribute("class") ?? "" }
        set { setAttribute("class", newValue) }
    }

    // MARK: - innerHTML

    /// The inner HTML of this element
    public var innerHTML: String {
        get {
            var result = ""
            for child in childNodes {
                result += serializeNode(child)
            }
            return result
        }
        set {
            // Remove all children
            _childNodes.removeAll()
            // For now, just add as text content (full HTML parsing requires HTMLParser)
            if !newValue.isEmpty {
                let textNode = Text(data: newValue)
                appendChild(textNode)
            }
        }
    }

    /// The outer HTML of this element (including the element itself)
    public var outerHTML: String {
        serializeNode(self)
    }

    // MARK: - Query Methods

    /// Find elements by tag name within this element
    public func getElementsByTagName(_ name: String) -> [Element] {
        var results: [Element] = []
        let lowercaseName = name.lowercased()
        collectElementsByTagName(lowercaseName, into: &results)
        return results
    }

    private func collectElementsByTagName(_ name: String, into results: inout [Element]) {
        for child in childNodes {
            if let element = child as? Element {
                if element.tagName == name || name == "*" {
                    results.append(element)
                }
                element.collectElementsByTagName(name, into: &results)
            }
        }
    }

    /// Find elements by class name within this element
    public func getElementsByClassName(_ name: String) -> [Element] {
        var results: [Element] = []
        collectElementsByClassName(name, into: &results)
        return results
    }

    private func collectElementsByClassName(_ name: String, into results: inout [Element]) {
        for child in childNodes {
            if let element = child as? Element {
                if element.classList.contains(name) {
                    results.append(element)
                }
                element.collectElementsByClassName(name, into: &results)
            }
        }
    }

    /// Query selector - find first matching element
    public func querySelector(_ selector: String) -> Element? {
        let matcher = SelectorMatcher(selector: selector)
        return matcher.findFirst(in: self)
    }

    /// Query selector all - find all matching elements
    public func querySelectorAll(_ selector: String) -> [Element] {
        let matcher = SelectorMatcher(selector: selector)
        return matcher.findAll(in: self)
    }

    // MARK: - Cloning

    public override func cloneNode(deep: Bool) -> Node {
        let clone = Element(tagName: tagName)
        clone._attributes = _attributes

        if deep {
            for child in childNodes {
                clone.appendChild(child.cloneNode(deep: true))
            }
        }

        return clone
    }

    // MARK: - Text Content

    public override var textContent: String {
        get {
            var result = ""
            collectTextContent(into: &result)
            return result
        }
        set {
            _childNodes.removeAll()
            if !newValue.isEmpty {
                let textNode = Text(data: newValue)
                appendChild(textNode)
            }
        }
    }

    private func collectTextContent(into result: inout String) {
        for child in childNodes {
            if let text = child as? Text {
                result += text.data
            } else if let element = child as? Element {
                element.collectTextContent(into: &result)
            }
        }
    }

    // MARK: - Serialization

    private func serializeNode(_ node: Node) -> String {
        if let text = node as? Text {
            return escapeHTML(text.data)
        } else if let comment = node as? Comment {
            return "<!--\(comment.data)-->"
        } else if let element = node as? Element {
            var result = "<\(element.tagName)"

            for (name, value) in element._attributes {
                result += " \(name)=\"\(escapeAttribute(value))\""
            }

            // Void elements
            let voidElements: Set<String> = [
                "area", "base", "br", "col", "embed", "hr", "img", "input",
                "link", "meta", "param", "source", "track", "wbr"
            ]

            if voidElements.contains(element.tagName) {
                result += ">"
            } else {
                result += ">"
                for child in element.childNodes {
                    result += serializeNode(child)
                }
                result += "</\(element.tagName)>"
            }

            return result
        }

        return ""
    }

    private func escapeHTML(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "&", with: "&amp;")
        result = result.replacingOccurrences(of: "<", with: "&lt;")
        result = result.replacingOccurrences(of: ">", with: "&gt;")
        return result
    }

    private func escapeAttribute(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "&", with: "&amp;")
        result = result.replacingOccurrences(of: "\"", with: "&quot;")
        return result
    }
}

// MARK: - Element Extensions for Tree Traversal

extension Element {
    /// Get all child elements (excluding text nodes, comments, etc.)
    public var children: [Element] {
        childNodes.compactMap { $0 as? Element }
    }

    /// Get the first child element
    public var firstElementChild: Element? {
        children.first
    }

    /// Get the last child element
    public var lastElementChild: Element? {
        children.last
    }

    /// Get the number of child elements
    public var childElementCount: Int {
        children.count
    }

    /// Get the parent element
    public var parentElement: Element? {
        parentNode as? Element
    }

    /// Get the next sibling element
    public var nextElementSibling: Element? {
        var sibling = nextSibling
        while let current = sibling {
            if let element = current as? Element {
                return element
            }
            sibling = current.nextSibling
        }
        return nil
    }

    /// Get the previous sibling element
    public var previousElementSibling: Element? {
        var sibling = previousSibling
        while let current = sibling {
            if let element = current as? Element {
                return element
            }
            sibling = current.previousSibling
        }
        return nil
    }
}
