// TUILayout - Block Layout
//
// Block layout algorithm: vertical stacking with width from parent.

import TUICore
import TUIStyle

/// Block layout algorithm
public struct BlockLayout: Sendable {

    public init() {}

    // MARK: - Main Layout

    /// Perform block layout on a box and its children
    /// - Parameters:
    ///   - box: The box to lay out
    ///   - containingWidth: Width of the containing block
    public func layout(_ box: LayoutBox, containingWidth: Int) {
        // Calculate width: block boxes take full container width (minus margins/padding)
        calculateWidth(box, containingWidth: containingWidth)

        // Position is set by parent; we just need to lay out children
        layoutChildren(box)

        // Calculate height based on children
        calculateHeight(box)
    }

    // MARK: - Width Calculation

    private func calculateWidth(_ box: LayoutBox, containingWidth: Int) {
        let style = box.style

        // Available width = containing width - margins - padding
        let availableWidth = containingWidth
            - style.margin.horizontal
            - style.padding.horizontal

        box.dimensions.margin = style.margin
        box.dimensions.padding = style.padding
        box.dimensions.setContentWidth(max(0, availableWidth))
    }

    // MARK: - Child Layout

    private func layoutChildren(_ box: LayoutBox) {
        // Only wrap inline children if this is not already an anonymous box
        // (to prevent infinite recursion)
        if box.boxType != .anonymous {
            let hasInlineContent = box.children.contains { $0.isInline }
            let hasMixedContent = box.hasBlockChildren && hasInlineContent

            if hasMixedContent || (hasInlineContent && !box.children.isEmpty) {
                wrapInlineChildren(box)
            }
        }

        // Layout children
        var currentY = box.dimensions.content.y

        for child in box.children {
            // Position child
            let childX = box.dimensions.content.x
            child.dimensions.positionAt(x: childX, y: currentY)

            // Layout the child based on its type
            if child.style.display.isFlex {
                FlexLayout().layout(child, containingWidth: box.dimensions.content.width)
            } else if child.isBlock {
                BlockLayout().layout(child, containingWidth: box.dimensions.content.width)
            } else if child.boxType == .anonymous {
                // Anonymous box with inline content - use InlineLayout
                InlineLayout().layout(child, containingWidth: box.dimensions.content.width)
            } else {
                // Single inline element in a block - wrap in anonymous for proper inline layout
                InlineLayout().layout(child, containingWidth: box.dimensions.content.width)
            }

            // Move Y position for next child (including margin collapsing)
            currentY += child.dimensions.totalHeight
        }
    }

    // MARK: - Height Calculation

    private func calculateHeight(_ box: LayoutBox) {
        // Height is sum of children heights
        var totalHeight = 0

        for child in box.children {
            totalHeight += child.dimensions.totalHeight
        }

        box.dimensions.setContentHeight(totalHeight)
    }

    // MARK: - Anonymous Box Creation

    /// Wrap consecutive inline children in anonymous block boxes
    private func wrapInlineChildren(_ box: LayoutBox) {
        var newChildren: [LayoutBox] = []
        var currentInlineGroup: [LayoutBox] = []

        func flushInlineGroup() {
            if !currentInlineGroup.isEmpty {
                let anonymous = LayoutBox.anonymous(style: box.style)
                for inline in currentInlineGroup {
                    anonymous.appendChild(inline)
                }
                newChildren.append(anonymous)
                currentInlineGroup.removeAll()
            }
        }

        for child in box.children {
            if child.isBlock {
                flushInlineGroup()
                newChildren.append(child)
            } else {
                currentInlineGroup.append(child)
            }
        }

        flushInlineGroup()
        box.children = newChildren
    }
}

// MARK: - Margin Collapsing

extension BlockLayout {
    /// Calculate collapsed margin between two adjacent boxes
    public static func collapseMargins(topMargin: Int, bottomMargin: Int) -> Int {
        // In CSS, adjacent vertical margins collapse to the larger value
        // Positive margins collapse to the maximum
        // Negative margins collapse to the minimum (most negative)
        // Mixed: take the maximum positive minus the absolute of minimum negative

        if topMargin >= 0 && bottomMargin >= 0 {
            return max(topMargin, bottomMargin)
        } else if topMargin < 0 && bottomMargin < 0 {
            return min(topMargin, bottomMargin)
        } else {
            return topMargin + bottomMargin
        }
    }
}
