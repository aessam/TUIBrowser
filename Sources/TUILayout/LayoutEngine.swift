// TUILayout - Layout Engine
//
// Main entry point for building and computing layout.

import TUICore
import TUIHTMLParser
import TUIStyle

/// Main layout engine
public struct LayoutEngine: Sendable {
    private let textLayout: TextLayout

    public init() {
        self.textLayout = TextLayout()
    }

    // MARK: - Main Layout API

    /// Build a layout tree from a document and compute layout
    /// - Parameters:
    ///   - document: The DOM document
    ///   - styles: Computed styles for elements
    ///   - width: Available width for layout
    /// - Returns: Root layout box
    public func layout(
        document: Document,
        styles: StyleMap,
        width: Int
    ) -> LayoutBox {
        // Create root box
        let root = LayoutBox(boxType: .block, style: .block)
        root.dimensions.setContentWidth(width)

        // Build layout tree from document body (or root)
        if let body = document.body ?? document.documentElement {
            let bodyStyle = StyleResolver.getStyle(for: body, from: styles)
            let bodyBox = buildLayoutTree(for: body, styles: styles, parentStyle: bodyStyle)

            if let bodyBox = bodyBox {
                root.appendChild(bodyBox)
            }
        }

        // Compute layout
        computeLayout(root, containingWidth: width)

        return root
    }

    // MARK: - Layout Tree Building

    /// Build a layout box tree from a DOM element
    private func buildLayoutTree(
        for element: Element,
        styles: StyleMap,
        parentStyle: ComputedStyle
    ) -> LayoutBox? {
        var style = StyleResolver.getStyle(for: element, from: styles)

        // Skip hidden elements
        if style.display == .none {
            return nil
        }

        // Handle special tags
        let tagName = element.tagName
        switch tagName {
        case "center":
            // <center> tag centers its content
            style.textAlign = .center
        case "table", "tbody", "thead", "tfoot":
            // Tables are block-level
            style.display = .block
        case "tr":
            // Table rows are block-level, children flow horizontally
            style.display = .block
        case "td", "th":
            // Table cells are inline-block
            style.display = .inlineBlock
        case "input", "select", "button", "textarea":
            // Form elements are inline-block
            style.display = .inlineBlock
        case "img":
            // Images are inline-block
            style.display = .inlineBlock
        default:
            break
        }

        // Create box for element
        let boxType: BoxType
        switch style.display {
        case .block, .listItem, .flex:
            boxType = .block
        case .inline, .inlineFlex:
            boxType = style.display == .inlineFlex ? .inlineBlock : .inline
        case .inlineBlock:
            boxType = .inlineBlock
        case .none:
            return nil
        }

        let box = LayoutBox(boxType: boxType, style: style, element: element)

        // Handle list items
        if style.display == .listItem {
            box.layoutInfo.listMarker = style.listStyleType.marker
        }

        // Process children
        var listIndex = 1
        for child in element.childNodes {
            if let childElement = child as? Element {
                // Recurse for element children
                if let childBox = buildLayoutTree(for: childElement, styles: styles, parentStyle: style) {
                    // Set list index for list items
                    if childBox.style.display == .listItem {
                        childBox.layoutInfo.listIndex = listIndex
                        if style.listStyleType == .decimal {
                            childBox.layoutInfo.listMarker = "\(listIndex)."
                        }
                        listIndex += 1
                    }
                    box.appendChild(childBox)
                }
            } else if let textNode = child as? Text {
                // Create text box for text nodes
                let text = textNode.data
                if !text.allSatisfy({ $0.isWhitespace }) || style.whiteSpace == .pre {
                    let textBox = LayoutBox.text(text, style: style)
                    box.appendChild(textBox)
                }
            }
        }

        return box
    }

    // MARK: - Layout Computation

    /// Compute layout for a layout tree
    private func computeLayout(_ box: LayoutBox, containingWidth: Int) {
        box.dimensions.positionAt(x: 0, y: 0)

        // Check if this is a flex container
        if box.style.display.isFlex {
            FlexLayout().layout(box, containingWidth: containingWidth)
        } else if box.isBlock || box.boxType == .anonymous {
            BlockLayout().layout(box, containingWidth: containingWidth)
        } else {
            InlineLayout().layout(box, containingWidth: containingWidth)
        }
    }

    // MARK: - Static API

    /// Static convenience method
    public static func layout(
        document: Document,
        styles: StyleMap,
        width: Int
    ) -> LayoutBox {
        let engine = LayoutEngine()
        return engine.layout(document: document, styles: styles, width: width)
    }
}

// MARK: - Layout Debugging

extension LayoutEngine {
    /// Print layout tree for debugging
    public static func debugPrint(_ box: LayoutBox) {
        box.traverseWithDepth { box, depth in
            let indent = String(repeating: "  ", count: depth)
            let content = box.dimensions.content
            print("\(indent)\(box.debugDescription)")
            print("\(indent)  pos:(\(content.x),\(content.y)) size:(\(content.width)x\(content.height))")
        }
    }
}

// MARK: - Layout Queries

extension LayoutEngine {
    /// Find the box at a given position
    public static func hitTest(_ box: LayoutBox, x: Int, y: Int) -> LayoutBox? {
        let content = box.dimensions.content

        // Check if point is in this box
        if x >= content.x && x < content.x + content.width &&
           y >= content.y && y < content.y + content.height {

            // Check children first (they're on top)
            for child in box.children.reversed() {
                if let hit = hitTest(child, x: x, y: y) {
                    return hit
                }
            }

            return box
        }

        return nil
    }

    /// Get all boxes that intersect a rectangle
    public static func findIntersecting(_ box: LayoutBox, rect: Rect) -> [LayoutBox] {
        var results: [LayoutBox] = []

        let boxRect = box.dimensions.content
        if boxRect.intersects(rect) {
            results.append(box)
            for child in box.children {
                results.append(contentsOf: findIntersecting(child, rect: rect))
            }
        }

        return results
    }
}

// MARK: - Rect Extension

extension Rect {
    /// Check if this rect intersects another
    func intersects(_ other: Rect) -> Bool {
        !(other.x >= x + width ||
          other.x + other.width <= x ||
          other.y >= y + height ||
          other.y + other.height <= y)
    }
}
