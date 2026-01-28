// TUILayout - Block Layout
//
// Block layout algorithm: vertical stacking with width from parent.

import TUICore
import TUIStyle

/// Block layout algorithm
public struct BlockLayout: Sendable {

    /// When true, ignore CSS width/max-width constraints (useful for PNG rendering)
    private let ignoreWidthConstraints: Bool

    public init(ignoreWidthConstraints: Bool = false) {
        self.ignoreWidthConstraints = ignoreWidthConstraints
    }

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

        // Start with containing width minus margins and padding
        let availableWidth = containingWidth
            - style.margin.horizontal
            - style.padding.horizontal

        // Apply explicit width if set (skip in PNG mode)
        var resolvedWidth = availableWidth
        if !ignoreWidthConstraints, let explicitWidth = style.width {
            if !explicitWidth.isAuto {
                resolvedWidth = explicitWidth.resolve(against: containingWidth)
            }
        }

        // Apply max-width constraint (skip in PNG mode)
        if !ignoreWidthConstraints, let maxW = style.maxWidth {
            let maxResolved = maxW.resolve(against: containingWidth)
            resolvedWidth = min(resolvedWidth, maxResolved)
        }

        // Apply min-width constraint (still applies for minimum readable width)
        if let minW = style.minWidth {
            let minResolved = minW.resolve(against: containingWidth)
            resolvedWidth = max(resolvedWidth, minResolved)
        }

        // Store old content position (before padding was set)
        let oldX = box.dimensions.content.x
        let oldY = box.dimensions.content.y

        // Set dimensions
        box.dimensions.margin = style.margin
        box.dimensions.padding = style.padding
        var contentWidth = max(0, resolvedWidth)

        // If border-box sizing, the resolved width includes padding; subtract to get content width
        if style.boxSizing == .borderBox {
            contentWidth = max(0, resolvedWidth - style.padding.horizontal)
        }

        box.dimensions.setContentWidth(contentWidth)

        // Update content position to account for padding
        // The content area should be offset by padding from the box origin
        box.dimensions.content = Rect(
            x: oldX + style.padding.left,
            y: oldY + style.padding.top,
            width: box.dimensions.content.width,
            height: box.dimensions.content.height
        )

        // Handle margin:auto for horizontal centering
        if style.marginLeftAuto && style.marginRightAuto {
            let totalContentWidth = resolvedWidth + style.padding.horizontal
            let remainingSpace = containingWidth - totalContentWidth
            if remainingSpace > 0 {
                let autoMargin = remainingSpace / 2
                box.dimensions.margin = EdgeInsets(
                    top: style.margin.top,
                    right: autoMargin,
                    bottom: style.margin.bottom,
                    left: autoMargin
                )
            }
        } else if style.marginLeftAuto {
            let totalContentWidth = resolvedWidth + style.padding.horizontal + style.margin.right
            let remainingSpace = containingWidth - totalContentWidth
            if remainingSpace > 0 {
                box.dimensions.margin = EdgeInsets(
                    top: style.margin.top,
                    right: style.margin.right,
                    bottom: style.margin.bottom,
                    left: remainingSpace
                )
            }
        } else if style.marginRightAuto {
            let totalContentWidth = resolvedWidth + style.padding.horizontal + style.margin.left
            let remainingSpace = containingWidth - totalContentWidth
            if remainingSpace > 0 {
                box.dimensions.margin = EdgeInsets(
                    top: style.margin.top,
                    right: remainingSpace,
                    bottom: style.margin.bottom,
                    left: style.margin.left
                )
            }
        }
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
                FlexLayout(ignoreWidthConstraints: ignoreWidthConstraints).layout(child, containingWidth: box.dimensions.content.width)
            } else if child.isBlock {
                BlockLayout(ignoreWidthConstraints: ignoreWidthConstraints).layout(child, containingWidth: box.dimensions.content.width)
            } else if child.boxType == .anonymous {
                // Anonymous box - check if it has block children
                if child.hasBlockChildren {
                    // Anonymous box with block children - use BlockLayout
                    BlockLayout(ignoreWidthConstraints: ignoreWidthConstraints).layout(child, containingWidth: box.dimensions.content.width)
                } else {
                    // Anonymous box with only inline content - use InlineLayout
                    InlineLayout().layout(child, containingWidth: box.dimensions.content.width)
                }
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
