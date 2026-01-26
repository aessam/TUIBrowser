// TUIHTMLParser - DocumentType Node
// Represents the DOCTYPE declaration

import TUICore

/// Represents a document type node (DOCTYPE)
public final class DocumentType: BaseNode {
    /// The name of the document type (e.g., "html")
    public let name: String

    /// The public identifier
    public let publicId: String

    /// The system identifier
    public let systemId: String

    public override var nodeType: NodeType { .documentType }
    public override var nodeName: String { name }

    /// Create a document type node
    public init(name: String, publicId: String = "", systemId: String = "") {
        self.name = name
        self.publicId = publicId
        self.systemId = systemId
        super.init()
    }

    // MARK: - Text Content

    public override var textContent: String {
        get { "" }
        set { /* DocumentType nodes don't have text content */ }
    }

    // MARK: - Cloning

    public override func cloneNode(deep: Bool) -> Node {
        DocumentType(name: name, publicId: publicId, systemId: systemId)
    }
}
