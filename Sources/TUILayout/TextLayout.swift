// TUILayout - Text Layout
//
// Text word wrapping and measurement for terminal display.

import TUICore
import TUIStyle

/// Text layout utilities
public struct TextLayout: Sendable {

    public init() {}

    // MARK: - Text Measurement

    /// Measure the width of a string in terminal columns
    public func measureWidth(_ text: String) -> Int {
        var width = 0
        for char in text {
            width += characterWidth(char)
        }
        return width
    }

    /// Get the display width of a character
    /// Note: In a real implementation, this would handle Unicode width (CJK, emoji, etc.)
    public func characterWidth(_ char: Character) -> Int {
        // Simple implementation: most chars are 1 wide
        // Full implementation would use Unicode East Asian Width
        if char.isNewline {
            return 0
        }
        // Emoji and CJK would be 2 wide
        if let scalar = char.unicodeScalars.first {
            // Basic detection for wide characters
            let value = scalar.value
            if (0x1100...0x115F).contains(value) ||  // Hangul Jamo
               (0x2E80...0x9FFF).contains(value) ||  // CJK
               (0xAC00...0xD7AF).contains(value) ||  // Hangul Syllables
               (0xF900...0xFAFF).contains(value) ||  // CJK Compatibility
               (0xFE10...0xFE1F).contains(value) ||  // CJK Punctuation
               (0x1F300...0x1F9FF).contains(value) { // Emoji
                return 2
            }
        }
        return 1
    }

    // MARK: - Word Wrapping

    /// Word wrap result
    public struct WrapResult {
        public var lines: [String]
        public var lineWidths: [Int]

        public init(lines: [String] = [], lineWidths: [Int] = []) {
            self.lines = lines
            self.lineWidths = lineWidths
        }
    }

    /// Wrap text to fit within a given width
    public func wrap(_ text: String, maxWidth: Int, style: WhiteSpace = .normal) -> WrapResult {
        switch style {
        case .pre, .preLine:
            return wrapPreformatted(text, maxWidth: maxWidth)
        case .nowrap:
            return wrapNoWrap(text)
        case .normal, .preWrap:
            return wrapNormal(text, maxWidth: maxWidth)
        }
    }

    /// Normal wrapping: collapse whitespace, wrap at word boundaries
    private func wrapNormal(_ text: String, maxWidth: Int) -> WrapResult {
        var result = WrapResult()

        // Collapse whitespace and split into words
        let normalized = collapseWhitespace(text)
        let words = normalized.split(separator: " ", omittingEmptySubsequences: true).map(String.init)

        var currentLine = ""
        var currentWidth = 0

        for word in words {
            let wordWidth = measureWidth(word)

            if currentWidth == 0 {
                // First word on line
                currentLine = word
                currentWidth = wordWidth
            } else if currentWidth + 1 + wordWidth <= maxWidth {
                // Word fits on current line
                currentLine += " " + word
                currentWidth += 1 + wordWidth
            } else {
                // Start new line
                result.lines.append(currentLine)
                result.lineWidths.append(currentWidth)
                currentLine = word
                currentWidth = wordWidth
            }
        }

        // Add final line
        if !currentLine.isEmpty {
            result.lines.append(currentLine)
            result.lineWidths.append(currentWidth)
        }

        // Ensure at least one line
        if result.lines.isEmpty {
            result.lines.append("")
            result.lineWidths.append(0)
        }

        return result
    }

    /// No-wrap: single line, collapse whitespace
    private func wrapNoWrap(_ text: String) -> WrapResult {
        let normalized = collapseWhitespace(text)
        return WrapResult(
            lines: [normalized],
            lineWidths: [measureWidth(normalized)]
        )
    }

    /// Preformatted: preserve whitespace and newlines
    private func wrapPreformatted(_ text: String, maxWidth: Int) -> WrapResult {
        var result = WrapResult()

        let paragraphs = text.split(separator: "\n", omittingEmptySubsequences: false)

        for paragraph in paragraphs {
            let line = String(paragraph)
            let width = measureWidth(line)

            if width <= maxWidth {
                result.lines.append(line)
                result.lineWidths.append(width)
            } else {
                // Hard wrap long lines
                let wrapped = hardWrap(line, maxWidth: maxWidth)
                result.lines.append(contentsOf: wrapped.lines)
                result.lineWidths.append(contentsOf: wrapped.lineWidths)
            }
        }

        if result.lines.isEmpty {
            result.lines.append("")
            result.lineWidths.append(0)
        }

        return result
    }

    /// Hard wrap a single line at character boundaries
    private func hardWrap(_ text: String, maxWidth: Int) -> WrapResult {
        var result = WrapResult()
        var currentLine = ""
        var currentWidth = 0

        for char in text {
            let charWidth = characterWidth(char)

            if currentWidth + charWidth > maxWidth && !currentLine.isEmpty {
                result.lines.append(currentLine)
                result.lineWidths.append(currentWidth)
                currentLine = ""
                currentWidth = 0
            }

            currentLine.append(char)
            currentWidth += charWidth
        }

        if !currentLine.isEmpty {
            result.lines.append(currentLine)
            result.lineWidths.append(currentWidth)
        }

        return result
    }

    // MARK: - Whitespace Handling

    /// Collapse whitespace (multiple spaces/tabs/newlines to single space)
    public func collapseWhitespace(_ text: String) -> String {
        var result = ""
        var lastWasWhitespace = false

        for char in text {
            if char.isWhitespace {
                if !lastWasWhitespace {
                    result.append(" ")
                    lastWasWhitespace = true
                }
            } else {
                result.append(char)
                lastWasWhitespace = false
            }
        }

        return result.trimmingCharacters(in: .whitespaces)
    }

    /// Check if text is only whitespace
    public func isWhitespaceOnly(_ text: String) -> Bool {
        text.allSatisfy { $0.isWhitespace }
    }
}

// MARK: - Text Segmentation

extension TextLayout {
    /// Segment text for styled rendering
    public struct TextSegment {
        public var text: String
        public var width: Int
        public var style: TextStyle

        public init(text: String, width: Int, style: TextStyle) {
            self.text = text
            self.width = width
            self.style = style
        }
    }

    /// Create segments from styled text
    public func segment(_ text: String, style: ComputedStyle) -> [TextSegment] {
        let textStyle = style.toTextStyle()
        let width = measureWidth(text)
        return [TextSegment(text: text, width: width, style: textStyle)]
    }
}
