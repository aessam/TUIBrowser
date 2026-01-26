// TUILayout - Inline Layout
//
// Inline layout algorithm: horizontal flow with line breaking.

import TUICore
import TUIStyle

/// Inline layout algorithm
public struct InlineLayout: Sendable {

    public init() {}

    // MARK: - Main Layout

    /// Perform inline layout on a box containing inline content
    /// - Parameters:
    ///   - box: The box to lay out (should contain inline children)
    ///   - containingWidth: Width of the containing block
    public func layout(_ box: LayoutBox, containingWidth: Int) {
        // Flatten all inline content into a sequence of inline boxes
        let inlineBoxes = flattenInlineContent(box)

        // Break into lines
        let lines = breakIntoLines(inlineBoxes, maxWidth: containingWidth)

        // Position boxes on lines
        positionLines(lines, in: box, containingWidth: containingWidth)
    }

    // MARK: - Content Flattening

    /// Flatten nested inline boxes into a sequence
    private func flattenInlineContent(_ box: LayoutBox) -> [LayoutBox] {
        var result: [LayoutBox] = []

        for child in box.children {
            if child.boxType == .text {
                // Text nodes stay as-is
                result.append(child)
            } else if child.isInline {
                // Inline boxes: include box start, flatten children, include box end
                if child.children.isEmpty {
                    // Atomic inline (like <br> or empty inline)
                    result.append(child)
                } else {
                    // Flatten children but keep style
                    for inner in flattenInlineContent(child) {
                        // Apply parent style
                        inner.style = mergeStyles(parent: child.style, child: inner.style)
                        result.append(inner)
                    }
                }
            } else {
                // Block inside inline - should not happen after wrapping
                result.append(child)
            }
        }

        return result
    }

    /// Merge parent and child styles for inline inheritance
    private func mergeStyles(parent: ComputedStyle, child: ComputedStyle) -> ComputedStyle {
        var merged = child
        // Apply parent color if child doesn't override
        if merged.color == .white && parent.color != .white {
            merged.color = parent.color
        }
        // Combine font styles
        if parent.fontWeight.isBold {
            merged.fontWeight = .bold
        }
        if parent.fontStyle == .italic {
            merged.fontStyle = .italic
        }
        if parent.textDecoration != .none && merged.textDecoration == .none {
            merged.textDecoration = parent.textDecoration
        }
        return merged
    }

    // MARK: - Line Breaking

    /// A line of inline boxes
    public struct Line {
        public var boxes: [LayoutBox]
        public var width: Int
        public var height: Int

        public init() {
            boxes = []
            width = 0
            height = 1  // Minimum height of 1 line
        }
    }

    /// Break inline boxes into lines
    private func breakIntoLines(_ boxes: [LayoutBox], maxWidth: Int) -> [Line] {
        var lines: [Line] = []
        var currentLine = Line()

        for box in boxes {
            if box.boxType == .text, let text = box.textContent {
                // Break text into words and wrap
                let words = splitIntoWords(text)

                for (wordIndex, word) in words.enumerated() {
                    let wordWidth = word.count

                    if currentLine.width + wordWidth > maxWidth && currentLine.width > 0 {
                        // Line is full, start new line
                        lines.append(currentLine)
                        currentLine = Line()
                    }

                    // Create box for this word
                    let wordBox = LayoutBox.text(word, style: box.style)
                    wordBox.dimensions.setContentWidth(wordWidth)
                    wordBox.dimensions.setContentHeight(1)

                    currentLine.boxes.append(wordBox)
                    currentLine.width += wordWidth

                    // Add space after word (except last word)
                    if wordIndex < words.count - 1 && !word.hasSuffix("\n") {
                        currentLine.width += 1  // Space between words
                    }
                }
            } else {
                // Atomic inline box
                let boxWidth = calculateInlineWidth(box)

                if currentLine.width + boxWidth > maxWidth && currentLine.width > 0 {
                    lines.append(currentLine)
                    currentLine = Line()
                }

                box.dimensions.setContentWidth(boxWidth)
                box.dimensions.setContentHeight(1)
                currentLine.boxes.append(box)
                currentLine.width += boxWidth
            }
        }

        // Add final line if non-empty
        if !currentLine.boxes.isEmpty {
            lines.append(currentLine)
        }

        // Ensure at least one empty line if no content
        if lines.isEmpty {
            lines.append(Line())
        }

        return lines
    }

    /// Split text into words for wrapping
    private func splitIntoWords(_ text: String) -> [String] {
        var words: [String] = []
        var currentWord = ""

        for char in text {
            if char.isWhitespace {
                if !currentWord.isEmpty {
                    words.append(currentWord)
                    currentWord = ""
                }
                if char == "\n" {
                    words.append("\n")
                }
            } else {
                currentWord.append(char)
            }
        }

        if !currentWord.isEmpty {
            words.append(currentWord)
        }

        return words
    }

    /// Calculate width of an inline box
    private func calculateInlineWidth(_ box: LayoutBox) -> Int {
        if let text = box.textContent {
            return text.count
        }
        // For other inline elements, sum children widths
        var width = box.style.padding.horizontal
        for child in box.children {
            width += calculateInlineWidth(child)
        }
        return width
    }

    // MARK: - Line Positioning

    /// Position lines within the containing box
    private func positionLines(_ lines: [Line], in box: LayoutBox, containingWidth: Int) {
        box.removeAllChildren()

        var currentY = box.dimensions.content.y
        let startX = box.dimensions.content.x

        for (lineIndex, line) in lines.enumerated() {
            var currentX = startX

            // Apply text-align
            switch box.style.textAlign {
            case .center:
                currentX = startX + (containingWidth - line.width) / 2
            case .right:
                currentX = startX + containingWidth - line.width
            case .left, .justify:
                break  // Default left align
            }

            for (boxIndex, lineBox) in line.boxes.enumerated() {
                lineBox.dimensions.positionAt(x: currentX, y: currentY)
                lineBox.layoutInfo.lineNumber = lineIndex

                box.appendChild(lineBox)

                currentX += lineBox.dimensions.content.width

                // Add space between words (except for newlines)
                if boxIndex < line.boxes.count - 1 {
                    if lineBox.textContent != "\n" {
                        currentX += 1
                    }
                }
            }

            currentY += line.height
        }

        // Set box height based on number of lines
        box.dimensions.setContentHeight(lines.count)
        box.dimensions.setContentWidth(containingWidth)
    }
}
