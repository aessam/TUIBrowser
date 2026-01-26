// TUIHTMLParser - HTML Token Types
// Tokens emitted by the HTML tokenizer

import TUICore

/// Represents an attribute on an HTML tag
public struct HTMLAttribute: Equatable, Sendable {
    public let name: String
    public let value: String

    public init(name: String, value: String) {
        self.name = name
        self.value = value
    }
}

/// HTML tokens emitted by the tokenizer
public enum HTMLToken: Equatable, Sendable {
    /// DOCTYPE declaration
    case doctype(name: String, publicId: String?, systemId: String?)

    /// Start tag with name, attributes, and self-closing flag
    case startTag(name: String, attributes: [HTMLAttribute], selfClosing: Bool)

    /// End tag with name
    case endTag(name: String)

    /// Character data (text content)
    case character(String)

    /// Comment
    case comment(String)

    /// End of file
    case eof

    // MARK: - Convenience Properties

    /// Returns true if this is an EOF token
    public var isEOF: Bool {
        if case .eof = self { return true }
        return false
    }

    /// Returns the tag name if this is a start or end tag
    public var tagName: String? {
        switch self {
        case .startTag(let name, _, _), .endTag(let name):
            return name
        default:
            return nil
        }
    }

    /// Returns true if this is a start tag
    public var isStartTag: Bool {
        if case .startTag = self { return true }
        return false
    }

    /// Returns true if this is an end tag
    public var isEndTag: Bool {
        if case .endTag = self { return true }
        return false
    }
}
