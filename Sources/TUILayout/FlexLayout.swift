// TUILayout - Flexbox Layout
//
// Implements CSS Flexbox layout algorithm for terminal rendering.
// Supports flex-direction, justify-content, align-items, and basic wrapping.

import TUICore
import TUIStyle

/// Flexbox layout algorithm
public struct FlexLayout: Sendable {

    public init() {}

    // MARK: - Main Layout

    /// Perform flex layout on a container and its children
    /// - Parameters:
    ///   - box: The flex container box
    ///   - containingWidth: Width of the containing block
    public func layout(_ box: LayoutBox, containingWidth: Int) {
        let style = box.style

        // Calculate container dimensions
        calculateContainerSize(box, containingWidth: containingWidth)

        // Get layout direction
        let isHorizontal = style.flexDirection.isHorizontal
        let isReversed = style.flexDirection.isReversed

        // Get children (excluding display:none)
        var children = box.children.filter { $0.style.display != .none }

        // Reverse if needed
        if isReversed {
            children.reverse()
        }

        // Measure children to get their natural sizes
        measureChildren(children, isHorizontal: isHorizontal, containerWidth: box.dimensions.content.width)

        // Check if we need to wrap
        let shouldWrap = style.flexWrap != .nowrap
        let lines = shouldWrap
            ? wrapChildren(children, isHorizontal: isHorizontal, container: box)
            : [children]

        // Layout each line
        if isHorizontal {
            layoutHorizontalLines(lines, container: box)
        } else {
            layoutVerticalLines(lines, container: box)
        }

        // Calculate final container height based on children
        calculateFinalHeight(box, lines: lines, isHorizontal: isHorizontal)
    }

    // MARK: - Container Size

    private func calculateContainerSize(_ box: LayoutBox, containingWidth: Int) {
        let style = box.style

        // Available width = containing width - margins - padding
        let availableWidth = containingWidth
            - style.margin.horizontal
            - style.padding.horizontal

        box.dimensions.margin = style.margin
        box.dimensions.padding = style.padding
        box.dimensions.setContentWidth(max(0, availableWidth))
    }

    // MARK: - Measure Children

    private func measureChildren(_ children: [LayoutBox], isHorizontal: Bool, containerWidth: Int) {
        for child in children {
            // Determine base size from flex-basis, explicit width, or content
            let baseSize: Int

            if let flexBasis = child.style.flexBasis, !flexBasis.isAuto {
                // Use explicit flex-basis
                baseSize = flexBasis.resolve(against: containerWidth)
            } else if let explicitWidth = child.style.width, !explicitWidth.isAuto {
                // Use explicit CSS width (from width property or HTML width attribute)
                baseSize = explicitWidth.resolve(against: containerWidth)
            } else if child.boxType == .text {
                // Text nodes get their natural width
                baseSize = child.textContent?.count ?? 0
            } else if child.isBlock {
                // Block children: estimate content width
                baseSize = estimateContentWidth(child)
            } else {
                baseSize = estimateContentWidth(child)
            }

            if child.boxType == .text {
                child.dimensions.setContentWidth(min(baseSize, containerWidth))
                child.dimensions.setContentHeight(1)
            } else if child.boxType == .inlineBlock {
                // Inline-block elements: set their width first, then layout
                let inlineBlockWidth = min(baseSize, containerWidth)
                child.dimensions.setContentWidth(inlineBlockWidth)

                // Layout children using InlineLayout to get content height
                InlineLayout().layout(child, containingWidth: inlineBlockWidth)
            } else if child.isBlock {
                // Block children take full width in column flex, or natural width in row flex
                if isHorizontal {
                    child.dimensions.setContentWidth(min(baseSize, containerWidth))
                } else {
                    child.dimensions.setContentWidth(containerWidth)
                }

                // Recursively layout to get height
                BlockLayout().layout(child, containingWidth: child.dimensions.content.width)
            } else {
                // Other inline elements
                InlineLayout().layout(child, containingWidth: containerWidth)
            }
        }
    }

    /// Distribute remaining space among flex items based on flex-grow
    private func distributeSpace(_ children: [LayoutBox], remainingSpace: Int, isHorizontal: Bool) {
        guard remainingSpace > 0 else { return }

        // Calculate total flex-grow
        let totalGrow = children.reduce(0.0) { $0 + $1.style.flexGrow }
        guard totalGrow > 0 else { return }

        // Distribute space proportionally
        var spaceDistributed = 0
        for (index, child) in children.enumerated() {
            if child.style.flexGrow > 0 {
                let share: Int
                if index == children.count - 1 {
                    // Give remaining space to last item to avoid rounding errors
                    share = remainingSpace - spaceDistributed
                } else {
                    share = Int(Double(remainingSpace) * (child.style.flexGrow / totalGrow))
                }

                if isHorizontal {
                    child.dimensions.setContentWidth(child.dimensions.content.width + share)
                } else {
                    child.dimensions.setContentHeight(child.dimensions.content.height + share)
                }
                spaceDistributed += share
            }
        }
    }

    private func estimateContentWidth(_ box: LayoutBox) -> Int {
        // Simple content width estimation
        if let text = box.textContent {
            return text.count
        }

        // For block-level children, take max width
        // For inline/inline-block children, sum their widths
        var sumWidth = 0
        var maxWidth = 0

        for child in box.children {
            let childWidth = estimateContentWidth(child)
            if child.isBlock && child.boxType != .inlineBlock {
                maxWidth = max(maxWidth, childWidth)
            } else {
                // Inline content - sum widths (with 1 char spacing)
                if sumWidth > 0 {
                    sumWidth += 1  // Space between inline elements
                }
                sumWidth += childWidth
            }
        }

        // Return whichever is larger plus padding
        return max(maxWidth, sumWidth) + box.style.padding.horizontal
    }

    // MARK: - Wrapping

    private func wrapChildren(_ children: [LayoutBox], isHorizontal: Bool, container: LayoutBox) -> [[LayoutBox]] {
        let mainSize = isHorizontal
            ? container.dimensions.content.width
            : container.dimensions.content.height

        let gap = container.style.gap

        var lines: [[LayoutBox]] = [[]]
        var currentLineSize = 0

        for child in children {
            let childMainSize = isHorizontal
                ? child.dimensions.totalWidth
                : child.dimensions.totalHeight

            // Check if adding this child would overflow
            let sizeWithGap = currentLineSize > 0 ? childMainSize + gap : childMainSize

            if currentLineSize + sizeWithGap > mainSize && !lines[lines.count - 1].isEmpty {
                // Start a new line
                lines.append([child])
                currentLineSize = childMainSize
            } else {
                lines[lines.count - 1].append(child)
                currentLineSize += sizeWithGap
            }
        }

        return lines
    }

    // MARK: - Horizontal (Row) Layout

    private func layoutHorizontalLines(_ lines: [[LayoutBox]], container: LayoutBox) {
        let style = container.style
        let contentRect = container.dimensions.content
        let gap = style.gap

        var currentY = contentRect.y

        for line in lines {
            guard !line.isEmpty else { continue }

            // Calculate total children width and remaining space
            let totalChildWidth = line.reduce(0) { $0 + $1.dimensions.totalWidth }
            let totalGaps = (line.count - 1) * gap
            var remainingSpace = max(0, contentRect.width - totalChildWidth - totalGaps)

            // Distribute remaining space using flex-grow
            let hasFlexGrow = line.contains { $0.style.flexGrow > 0 }
            if hasFlexGrow && remainingSpace > 0 {
                distributeSpace(line, remainingSpace: remainingSpace, isHorizontal: true)
                // Recalculate remaining space after distribution
                let newTotalWidth = line.reduce(0) { $0 + $1.dimensions.totalWidth }
                remainingSpace = max(0, contentRect.width - newTotalWidth - totalGaps)
            }

            // Position children based on justify-content
            var currentX = contentRect.x

            switch style.justifyContent {
            case .flexStart:
                // Start from left (already positioned)
                break
            case .flexEnd:
                currentX = contentRect.x + remainingSpace
            case .center:
                currentX = contentRect.x + remainingSpace / 2
            case .spaceBetween:
                // First item at start, last at end, others evenly distributed
                break // Handle in loop
            case .spaceAround:
                let itemSpace = remainingSpace / line.count
                currentX = contentRect.x + itemSpace / 2
            case .spaceEvenly:
                let itemSpace = remainingSpace / (line.count + 1)
                currentX = contentRect.x + itemSpace
            }

            // Calculate line height (for alignment)
            let lineHeight = line.reduce(0) { max($0, $1.dimensions.totalHeight) }

            // Position each child
            for (index, child) in line.enumerated() {
                // Calculate Y position based on align-items
                let childY: Int
                switch style.alignItems {
                case .flexStart:
                    childY = currentY
                case .flexEnd:
                    childY = currentY + lineHeight - child.dimensions.totalHeight
                case .center:
                    childY = currentY + (lineHeight - child.dimensions.totalHeight) / 2
                case .baseline, .stretch:
                    childY = currentY
                }

                child.dimensions.positionAt(x: currentX, y: childY)

                // Move X for next child
                currentX += child.dimensions.totalWidth

                // Add gap or space
                if index < line.count - 1 {
                    switch style.justifyContent {
                    case .spaceBetween:
                        currentX += remainingSpace / max(1, line.count - 1)
                    case .spaceAround:
                        currentX += gap + remainingSpace / line.count
                    case .spaceEvenly:
                        currentX += remainingSpace / (line.count + 1)
                    default:
                        currentX += gap
                    }
                }
            }

            // Move Y for next line
            currentY += lineHeight + gap
        }
    }

    // MARK: - Vertical (Column) Layout

    private func layoutVerticalLines(_ lines: [[LayoutBox]], container: LayoutBox) {
        let style = container.style
        let contentRect = container.dimensions.content
        let gap = style.gap

        var currentX = contentRect.x

        for line in lines {
            guard !line.isEmpty else { continue }

            // Calculate total children height and remaining space
            let totalChildHeight = line.reduce(0) { $0 + $1.dimensions.totalHeight }
            let totalGaps = (line.count - 1) * gap
            let remainingSpace = max(0, contentRect.height - totalChildHeight - totalGaps)

            // Position children based on justify-content
            var currentY = contentRect.y

            switch style.justifyContent {
            case .flexStart:
                break
            case .flexEnd:
                currentY = contentRect.y + remainingSpace
            case .center:
                currentY = contentRect.y + remainingSpace / 2
            case .spaceBetween, .spaceAround, .spaceEvenly:
                break // Handle in loop
            }

            // Calculate line width (for alignment) - use container width, not max item width
            let alignmentWidth = contentRect.width

            // Position each child
            for (index, child) in line.enumerated() {
                // Calculate X position based on align-items
                let childX: Int
                switch style.alignItems {
                case .flexStart:
                    childX = currentX
                case .flexEnd:
                    childX = currentX + alignmentWidth - child.dimensions.totalWidth
                case .center:
                    childX = currentX + (alignmentWidth - child.dimensions.totalWidth) / 2
                case .baseline, .stretch:
                    childX = currentX
                }

                child.dimensions.positionAt(x: childX, y: currentY)

                // Move Y for next child
                currentY += child.dimensions.totalHeight

                // Add gap or space
                if index < line.count - 1 {
                    switch style.justifyContent {
                    case .spaceBetween:
                        currentY += remainingSpace / max(1, line.count - 1)
                    case .spaceAround:
                        currentY += gap + remainingSpace / line.count
                    case .spaceEvenly:
                        currentY += remainingSpace / (line.count + 1)
                    default:
                        currentY += gap
                    }
                }
            }

            // Move X for next column (line)
            let lineWidth = line.reduce(0) { max($0, $1.dimensions.totalWidth) }
            currentX += lineWidth + gap
        }
    }

    // MARK: - Final Height Calculation

    private func calculateFinalHeight(_ box: LayoutBox, lines: [[LayoutBox]], isHorizontal: Bool) {
        let gap = box.style.gap

        if isHorizontal {
            // Height is sum of line heights + gaps
            var totalHeight = 0
            for (index, line) in lines.enumerated() {
                let lineHeight = line.reduce(0) { max($0, $1.dimensions.totalHeight) }
                totalHeight += lineHeight
                if index < lines.count - 1 {
                    totalHeight += gap
                }
            }
            box.dimensions.setContentHeight(totalHeight)
        } else {
            // Height in column direction depends on tallest column
            var maxHeight = 0
            for line in lines {
                let lineHeight = line.reduce(0) { $0 + $1.dimensions.totalHeight }
                    + max(0, line.count - 1) * gap
                maxHeight = max(maxHeight, lineHeight)
            }
            box.dimensions.setContentHeight(maxHeight)
        }
    }
}
