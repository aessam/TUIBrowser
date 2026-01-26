// TUILayout - Layout Box
//
// A box in the layout tree, corresponding to a DOM element or anonymous box.

import TUICore
import TUIHTMLParser
import TUIStyle

/// Type of layout box
public enum BoxType: Equatable, Sendable {
    case block          // Block-level box
    case inline         // Inline-level box
    case inlineBlock    // Inline-block box
    case anonymous      // Anonymous box (for text or grouping)
    case text           // Text content box
}

/// A box in the layout tree
public final class LayoutBox {
    /// Type of this box
    public var boxType: BoxType

    /// Box dimensions (content, padding, border, margin)
    public var dimensions: BoxDimensions

    /// Child boxes
    public var children: [LayoutBox]

    /// Reference to source element (nil for anonymous/text boxes)
    public weak var element: Element?

    /// Computed style for this box
    public var style: ComputedStyle

    /// Text content (for text boxes)
    public var textContent: String?

    /// Additional layout information
    public var layoutInfo: LayoutInfo

    // MARK: - Initialization

    public init(
        boxType: BoxType,
        style: ComputedStyle = .default,
        element: Element? = nil
    ) {
        self.boxType = boxType
        self.dimensions = BoxDimensions()
        self.children = []
        self.element = element
        self.style = style
        self.textContent = nil
        self.layoutInfo = LayoutInfo()
    }

    /// Create a text box
    public static func text(_ content: String, style: ComputedStyle) -> LayoutBox {
        let box = LayoutBox(boxType: .text, style: style)
        box.textContent = content
        return box
    }

    /// Create an anonymous box for grouping
    public static func anonymous(style: ComputedStyle = .default) -> LayoutBox {
        LayoutBox(boxType: .anonymous, style: style)
    }

    // MARK: - Child Management

    /// Add a child box
    public func appendChild(_ child: LayoutBox) {
        children.append(child)
    }

    /// Insert child at index
    public func insertChild(_ child: LayoutBox, at index: Int) {
        children.insert(child, at: min(index, children.count))
    }

    /// Remove all children
    public func removeAllChildren() {
        children.removeAll()
    }

    // MARK: - Box Type Queries

    /// Whether this is a block-level box
    public var isBlock: Bool {
        boxType == .block
    }

    /// Whether this is inline-level
    public var isInline: Bool {
        boxType == .inline || boxType == .inlineBlock || boxType == .text
    }

    /// Whether this contains only inline children
    public var hasOnlyInlineChildren: Bool {
        children.allSatisfy { $0.isInline }
    }

    /// Whether this contains any block children
    public var hasBlockChildren: Bool {
        children.contains { $0.isBlock }
    }

    // MARK: - Layout Queries

    /// Get the containing block width
    public var containingBlockWidth: Int {
        dimensions.content.width
    }

    /// Get the height after layout
    public var layoutHeight: Int {
        dimensions.totalHeight
    }

    /// Get the width after layout
    public var layoutWidth: Int {
        dimensions.totalWidth
    }

    // MARK: - Debug

    /// Debug description
    public var debugDescription: String {
        let typeStr: String
        switch boxType {
        case .block: typeStr = "BLOCK"
        case .inline: typeStr = "INLINE"
        case .inlineBlock: typeStr = "INLINE-BLOCK"
        case .anonymous: typeStr = "ANON"
        case .text: typeStr = "TEXT"
        }

        let elementStr = element?.tagName ?? "(none)"
        let textStr = textContent.map { "'\($0.prefix(20))'" } ?? ""

        return "[\(typeStr)] <\(elementStr)> \(textStr) dim=\(dimensions.content)"
    }
}

// MARK: - Layout Info

/// Additional layout information for a box
public struct LayoutInfo: Equatable, Sendable {
    /// Index in list (for list items)
    public var listIndex: Int?

    /// Marker string (for list items)
    public var listMarker: String?

    /// Whether this box starts a new line
    public var startsNewLine: Bool = false

    /// Whether this box ends the current line
    public var endsLine: Bool = false

    /// Line number within parent (for inline layout)
    public var lineNumber: Int = 0

    public init(
        listIndex: Int? = nil,
        listMarker: String? = nil,
        startsNewLine: Bool = false,
        endsLine: Bool = false,
        lineNumber: Int = 0
    ) {
        self.listIndex = listIndex
        self.listMarker = listMarker
        self.startsNewLine = startsNewLine
        self.endsLine = endsLine
        self.lineNumber = lineNumber
    }
}

// MARK: - Tree Traversal

extension LayoutBox {
    /// Traverse the layout tree in pre-order
    public func traverse(_ visitor: (LayoutBox) -> Void) {
        visitor(self)
        for child in children {
            child.traverse(visitor)
        }
    }

    /// Traverse with depth information
    public func traverseWithDepth(_ visitor: (LayoutBox, Int) -> Void, depth: Int = 0) {
        visitor(self, depth)
        for child in children {
            child.traverseWithDepth(visitor, depth: depth + 1)
        }
    }

    /// Find all boxes matching a predicate
    public func findAll(where predicate: (LayoutBox) -> Bool) -> [LayoutBox] {
        var results: [LayoutBox] = []
        traverse { box in
            if predicate(box) {
                results.append(box)
            }
        }
        return results
    }
}
