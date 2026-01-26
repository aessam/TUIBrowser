// TUIHTMLParser - Comment Node
// Represents an HTML comment in the DOM

import TUICore

/// Represents a comment node in the DOM
public typealias Comment = HTMLComment

public final class HTMLComment: BaseNode {
    /// The comment content
    public var data: String

    public override var nodeType: NodeType { .comment }
    public override var nodeName: String { "#comment" }

    public override var nodeValue: String? {
        get { data }
        set { data = newValue ?? "" }
    }

    /// Create a comment node with the given content
    public init(data: String) {
        self.data = data
        super.init()
    }

    /// The length of the comment content
    public var length: Int {
        data.count
    }

    // MARK: - Text Content

    public override var textContent: String {
        get { "" }
        set { /* Comments don't have text content */ }
    }

    // MARK: - Cloning

    public override func cloneNode(deep: Bool) -> Node {
        HTMLComment(data: data)
    }
}
