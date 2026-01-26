// TUIHTMLParser - DOM Node
// Base protocol for all DOM nodes

import TUICore

/// Node type enumeration
public enum NodeType: Int, Sendable {
    case element = 1
    case text = 3
    case comment = 8
    case document = 9
    case documentType = 10
}

/// Base protocol for all DOM nodes
public protocol Node: AnyObject {
    /// The type of this node
    var nodeType: NodeType { get }

    /// The name of this node (tag name for elements, #text for text nodes, etc.)
    var nodeName: String { get }

    /// The value of this node (text content for text/comment nodes, nil for elements)
    var nodeValue: String? { get set }

    /// The parent of this node
    var parentNode: Node? { get set }

    /// The children of this node
    var childNodes: [Node] { get }

    /// The first child of this node
    var firstChild: Node? { get }

    /// The last child of this node
    var lastChild: Node? { get }

    /// The next sibling of this node
    var nextSibling: Node? { get }

    /// The previous sibling of this node
    var previousSibling: Node? { get }

    /// The owner document of this node
    var ownerDocument: Document? { get set }

    /// Append a child node
    func appendChild(_ child: Node)

    /// Remove a child node
    func removeChild(_ child: Node)

    /// Insert a child before a reference node
    func insertBefore(_ newNode: Node, _ referenceNode: Node?)

    /// Clone this node
    func cloneNode(deep: Bool) -> Node

    /// The text content of this node and its descendants
    var textContent: String { get set }
}

/// Base implementation for Node
open class BaseNode: Node {
    public var nodeType: NodeType { fatalError("Subclasses must override") }
    public var nodeName: String { fatalError("Subclasses must override") }
    public var nodeValue: String?

    public weak var parentNode: Node?
    internal var _childNodes: [Node] = []
    public weak var ownerDocument: Document?

    public var childNodes: [Node] { _childNodes }

    public var firstChild: Node? { _childNodes.first }
    public var lastChild: Node? { _childNodes.last }

    public var nextSibling: Node? {
        guard let parent = parentNode as? BaseNode else { return nil }
        guard let index = parent._childNodes.firstIndex(where: { $0 === self }) else { return nil }
        let nextIndex = index + 1
        guard nextIndex < parent._childNodes.count else { return nil }
        return parent._childNodes[nextIndex]
    }

    public var previousSibling: Node? {
        guard let parent = parentNode as? BaseNode else { return nil }
        guard let index = parent._childNodes.firstIndex(where: { $0 === self }) else { return nil }
        guard index > 0 else { return nil }
        return parent._childNodes[index - 1]
    }

    public init() {}

    public func appendChild(_ child: Node) {
        // Remove from previous parent
        if let previousParent = child.parentNode as? BaseNode {
            previousParent.removeChild(child)
        }

        _childNodes.append(child)
        child.parentNode = self
        child.ownerDocument = ownerDocument
    }

    public func removeChild(_ child: Node) {
        if let index = _childNodes.firstIndex(where: { $0 === child }) {
            _childNodes.remove(at: index)
            child.parentNode = nil
        }
    }

    public func insertBefore(_ newNode: Node, _ referenceNode: Node?) {
        guard let refNode = referenceNode else {
            appendChild(newNode)
            return
        }

        // Remove from previous parent
        if let previousParent = newNode.parentNode as? BaseNode {
            previousParent.removeChild(newNode)
        }

        if let index = _childNodes.firstIndex(where: { $0 === refNode }) {
            _childNodes.insert(newNode, at: index)
            newNode.parentNode = self
            newNode.ownerDocument = ownerDocument
        }
    }

    open func cloneNode(deep: Bool) -> Node {
        fatalError("Subclasses must override")
    }

    open var textContent: String {
        get {
            var result = ""
            for child in _childNodes {
                result += child.textContent
            }
            return result
        }
        set {
            // Remove all children
            _childNodes.removeAll()
            // Add a text node with the new content
            if !newValue.isEmpty {
                let textNode = Text(data: newValue)
                appendChild(textNode)
            }
        }
    }
}
