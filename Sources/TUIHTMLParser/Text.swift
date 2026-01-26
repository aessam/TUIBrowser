// TUIHTMLParser - Text Node
// Represents text content in the DOM

import TUICore

/// Represents a text node in the DOM
public final class Text: BaseNode {
    /// The text content
    public var data: String

    public override var nodeType: NodeType { .text }
    public override var nodeName: String { "#text" }

    public override var nodeValue: String? {
        get { data }
        set { data = newValue ?? "" }
    }

    /// Create a text node with the given content
    public init(data: String) {
        self.data = data
        super.init()
    }

    /// The length of the text content
    public var length: Int {
        data.count
    }

    /// Check if this text node contains only whitespace
    public var isWhitespace: Bool {
        data.allSatisfy { $0.isWhitespace }
    }

    // MARK: - Text Manipulation

    /// Append data to this text node
    public func appendData(_ text: String) {
        data += text
    }

    /// Insert data at the given offset
    public func insertData(_ offset: Int, _ text: String) {
        let index = data.index(data.startIndex, offsetBy: min(offset, data.count))
        data.insert(contentsOf: text, at: index)
    }

    /// Delete data from the given offset
    public func deleteData(_ offset: Int, _ count: Int) {
        let startIndex = data.index(data.startIndex, offsetBy: min(offset, data.count))
        let endIndex = data.index(startIndex, offsetBy: min(count, data.count - offset))
        data.removeSubrange(startIndex..<endIndex)
    }

    /// Get a substring of the text content
    public func substringData(_ offset: Int, _ count: Int) -> String {
        let startIndex = data.index(data.startIndex, offsetBy: min(offset, data.count))
        let endIndex = data.index(startIndex, offsetBy: min(count, data.count - offset))
        return String(data[startIndex..<endIndex])
    }

    // MARK: - Text Content

    public override var textContent: String {
        get { data }
        set { data = newValue }
    }

    // MARK: - Cloning

    public override func cloneNode(deep: Bool) -> Node {
        Text(data: data)
    }

    /// Split this text node at the given offset
    public func splitText(_ offset: Int) -> Text {
        let newData = substringData(offset, length - offset)
        deleteData(offset, length - offset)

        let newNode = Text(data: newData)

        // Insert the new node after this one
        if let parent = parentNode as? BaseNode {
            if let nextNode = nextSibling {
                parent.insertBefore(newNode, nextNode)
            } else {
                parent.appendChild(newNode)
            }
        }

        return newNode
    }
}
