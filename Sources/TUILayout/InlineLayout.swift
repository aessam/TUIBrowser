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
            } else if child.boxType == .inlineBlock {
                // Inline-block is atomic - don't flatten, treat as single unit
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
                let boxHeight = calculateInlineHeight(box)

                if currentLine.width + boxWidth > maxWidth && currentLine.width > 0 {
                    lines.append(currentLine)
                    currentLine = Line()
                }

                box.dimensions.setContentWidth(boxWidth)
                box.dimensions.setContentHeight(boxHeight)
                currentLine.boxes.append(box)
                currentLine.width += boxWidth
                currentLine.height = max(currentLine.height, boxHeight)
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

        // Check for special elements with intrinsic sizes
        if let element = box.element {
            switch element.tagName {
            case "input":
                let inputType = element.getAttribute("type")?.lowercased() ?? "text"
                switch inputType {
                case "checkbox", "radio":
                    return 1  // Single character
                case "submit", "button", "reset":
                    let value = element.getAttribute("value") ?? inputType.capitalized
                    return value.count + 4  // "┃ text ┃"
                case "hidden":
                    return 0
                default:
                    // Text inputs - use size attribute or default 20
                    let size = Int(element.getAttribute("size") ?? "20") ?? 20
                    return min(size + 2, 42)  // +2 for borders
                }
            case "button":
                let text = element.textContent.trimmingCharacters(in: .whitespacesAndNewlines)
                return max(text.count + 4, 8)  // Minimum 8 chars
            case "select":
                return 15  // Default dropdown width
            case "textarea":
                let cols = Int(element.getAttribute("cols") ?? "40") ?? 40
                return cols + 2  // +2 for borders
            case "img":
                // Use width attribute or default
                let width = Int(element.getAttribute("width") ?? "20") ?? 20
                return min(width, 60)
            case "br":
                return 0  // Line break has no width
            default:
                break
            }
        }

        // For other inline elements, sum children widths (only inline children)
        var width = box.style.padding.horizontal
        for child in box.children {
            // Skip block children (like <br>) when calculating inline width
            if child.isBlock && child.element?.tagName != "br" {
                continue
            }
            width += calculateInlineWidth(child)
        }

        // Ensure minimum width for elements with content
        if width == 0 && !box.children.isEmpty {
            // Estimate based on text content
            var textWidth = 0
            box.traverse { descendant in
                if let text = descendant.textContent {
                    textWidth += text.count
                }
            }
            width = max(width, textWidth + box.style.padding.horizontal)
        }

        return max(width, 0)
    }

    /// Calculate height of an inline box
    private func calculateInlineHeight(_ box: LayoutBox) -> Int {
        // Check for special elements with intrinsic heights
        if let element = box.element {
            switch element.tagName {
            case "input":
                let inputType = element.getAttribute("type")?.lowercased() ?? "text"
                switch inputType {
                case "checkbox", "radio", "hidden":
                    return 1
                case "submit", "button", "reset":
                    return 3  // Button with borders
                default:
                    return 3  // Text input with borders
                }
            case "button":
                return 3  // Button with borders
            case "select":
                return 3  // Dropdown with borders
            case "textarea":
                let rows = Int(element.getAttribute("rows") ?? "4") ?? 4
                return rows + 2  // +2 for borders
            case "img":
                let height = Int(element.getAttribute("height") ?? "10") ?? 10
                return min(height / 2, 20)  // Divide by 2 for terminal chars
            case "br":
                return 1
            default:
                break
            }
        }
        return 1  // Default single line height
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
