// TUIHTMLParser - Document Node
// Represents the root of the DOM tree

import TUICore

/// Represents an HTML document
public final class Document: BaseNode {
    public override var nodeType: NodeType { .document }
    public override var nodeName: String { "#document" }

    /// The document type (DOCTYPE)
    public private(set) var doctype: DocumentType?

    /// Create an empty document
    public override init() {
        super.init()
        self.ownerDocument = self
    }

    // MARK: - Document Properties

    /// The document element (<html>)
    public var documentElement: Element? {
        childNodes.first { ($0 as? Element)?.tagName == "html" } as? Element
    }

    /// The head element
    public var head: Element? {
        documentElement?.childNodes.first { ($0 as? Element)?.tagName == "head" } as? Element
    }

    /// The body element
    public var body: Element? {
        documentElement?.childNodes.first { ($0 as? Element)?.tagName == "body" } as? Element
    }

    /// The document title
    public var title: String {
        get {
            guard let head = head else { return "" }
            guard let titleElement = head.childNodes.first(where: {
                ($0 as? Element)?.tagName == "title"
            }) as? Element else { return "" }
            return titleElement.textContent
        }
        set {
            // Find or create title element
            guard let head = head else { return }
            if let titleElement = head.childNodes.first(where: {
                ($0 as? Element)?.tagName == "title"
            }) as? Element {
                titleElement.textContent = newValue
            } else {
                let titleElement = Element(tagName: "title")
                titleElement.textContent = newValue
                head.appendChild(titleElement)
            }
        }
    }

    // MARK: - Element Creation

    /// Create a new element
    public func createElement(_ tagName: String) -> Element {
        let element = Element(tagName: tagName)
        element.ownerDocument = self
        return element
    }

    /// Create a new text node
    public func createTextNode(_ data: String) -> Text {
        let text = Text(data: data)
        text.ownerDocument = self
        return text
    }

    /// Create a new comment node
    public func createComment(_ data: String) -> Comment {
        let comment = Comment(data: data)
        comment.ownerDocument = self
        return comment
    }

    // MARK: - Document Type

    /// Set the document type
    internal func setDoctype(_ doctype: DocumentType) {
        self.doctype = doctype
        doctype.ownerDocument = self
    }

    // MARK: - Query Methods

    /// Get an element by its id
    public func getElementById(_ id: String) -> Element? {
        return findElementById(id, in: self)
    }

    private func findElementById(_ id: String, in node: Node) -> Element? {
        for child in node.childNodes {
            if let element = child as? Element {
                if element.id == id {
                    return element
                }
                if let found = findElementById(id, in: element) {
                    return found
                }
            }
        }
        return nil
    }

    /// Get elements by tag name
    public func getElementsByTagName(_ name: String) -> [Element] {
        var results: [Element] = []
        let lowercaseName = name.lowercased()
        collectElementsByTagName(lowercaseName, from: self, into: &results)
        return results
    }

    private func collectElementsByTagName(_ name: String, from node: Node, into results: inout [Element]) {
        for child in node.childNodes {
            if let element = child as? Element {
                if element.tagName == name || name == "*" {
                    results.append(element)
                }
                collectElementsByTagName(name, from: element, into: &results)
            }
        }
    }

    /// Get elements by class name
    public func getElementsByClassName(_ name: String) -> [Element] {
        var results: [Element] = []
        collectElementsByClassName(name, from: self, into: &results)
        return results
    }

    private func collectElementsByClassName(_ name: String, from node: Node, into results: inout [Element]) {
        for child in node.childNodes {
            if let element = child as? Element {
                if element.classList.contains(name) {
                    results.append(element)
                }
                collectElementsByClassName(name, from: element, into: &results)
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
        let clone = Document()

        if deep {
            if let doctype = doctype {
                clone.setDoctype(doctype.cloneNode(deep: true) as! DocumentType)
            }
            for child in childNodes {
                clone.appendChild(child.cloneNode(deep: true))
            }
        }

        return clone
    }

    // MARK: - Text Content

    public override var textContent: String {
        get { "" }
        set { /* Documents don't have text content */ }
    }

    /// Count elements up to a limit to avoid expensive full traversals
    public func countElements(limit: Int) -> Int {
        var count = 0
        var stack: [Node] = childNodes

        while let node = stack.popLast() {
            if let element = node as? Element {
                count += 1
                if count >= limit { return count }
                stack.append(contentsOf: element.childNodes)
            }
        }
        return count
    }
}
