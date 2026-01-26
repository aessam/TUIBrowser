// TUIRender - Box Renderer
//
// Renders box borders and backgrounds to the terminal canvas.

import TUICore
import TUITerminal
import TUILayout
import TUIStyle

/// Box border characters
public struct BoxChars: Sendable {
    public let topLeft: Character
    public let topRight: Character
    public let bottomLeft: Character
    public let bottomRight: Character
    public let horizontal: Character
    public let vertical: Character

    public static let single = BoxChars(
        topLeft: "┌",
        topRight: "┐",
        bottomLeft: "└",
        bottomRight: "┘",
        horizontal: "─",
        vertical: "│"
    )

    public static let double = BoxChars(
        topLeft: "╔",
        topRight: "╗",
        bottomLeft: "╚",
        bottomRight: "╝",
        horizontal: "═",
        vertical: "║"
    )

    public static let rounded = BoxChars(
        topLeft: "╭",
        topRight: "╮",
        bottomLeft: "╰",
        bottomRight: "╯",
        horizontal: "─",
        vertical: "│"
    )

    public static let heavy = BoxChars(
        topLeft: "┏",
        topRight: "┓",
        bottomLeft: "┗",
        bottomRight: "┛",
        horizontal: "━",
        vertical: "┃"
    )

    public static let ascii = BoxChars(
        topLeft: "+",
        topRight: "+",
        bottomLeft: "+",
        bottomRight: "+",
        horizontal: "-",
        vertical: "|"
    )

    public init(
        topLeft: Character,
        topRight: Character,
        bottomLeft: Character,
        bottomRight: Character,
        horizontal: Character,
        vertical: Character
    ) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
        self.horizontal = horizontal
        self.vertical = vertical
    }
}

/// Renders boxes, borders, and backgrounds
public struct BoxRenderer: Sendable {

    public init() {}

    // MARK: - Background Rendering

    /// Fill a rectangular area with a background color
    public func fillBackground(
        rect: Rect,
        color: Color,
        to canvas: Canvas
    ) {
        let style = TextStyle(background: color)

        for y in rect.y..<(rect.y + rect.height) {
            for x in rect.x..<(rect.x + rect.width) {
                if x >= 0 && x < canvas.width && y >= 0 && y < canvas.height {
                    canvas.setCell(x: x, y: y, char: " ", style: style)
                }
            }
        }
    }

    /// Render background for a layout box
    public func renderBackground(_ box: LayoutBox, to canvas: Canvas) {
        guard let bgColor = box.style.backgroundColor else { return }

        let rect = box.dimensions.paddingBox()
        fillBackground(rect: rect, color: bgColor, to: canvas)
    }

    // MARK: - Border Rendering

    /// Draw a border around a rectangle
    public func drawBorder(
        rect: Rect,
        chars: BoxChars = .single,
        style: TextStyle = .default,
        to canvas: Canvas
    ) {
        guard rect.width >= 2 && rect.height >= 2 else { return }

        let x1 = rect.x
        let y1 = rect.y
        let x2 = rect.x + rect.width - 1
        let y2 = rect.y + rect.height - 1

        // Corners
        setCell(x: x1, y: y1, char: chars.topLeft, style: style, canvas: canvas)
        setCell(x: x2, y: y1, char: chars.topRight, style: style, canvas: canvas)
        setCell(x: x1, y: y2, char: chars.bottomLeft, style: style, canvas: canvas)
        setCell(x: x2, y: y2, char: chars.bottomRight, style: style, canvas: canvas)

        // Top and bottom edges
        for x in (x1 + 1)..<x2 {
            setCell(x: x, y: y1, char: chars.horizontal, style: style, canvas: canvas)
            setCell(x: x, y: y2, char: chars.horizontal, style: style, canvas: canvas)
        }

        // Left and right edges
        for y in (y1 + 1)..<y2 {
            setCell(x: x1, y: y, char: chars.vertical, style: style, canvas: canvas)
            setCell(x: x2, y: y, char: chars.vertical, style: style, canvas: canvas)
        }
    }

    /// Draw a horizontal rule (HR element)
    public func drawHorizontalRule(
        y: Int,
        x: Int,
        width: Int,
        style: TextStyle = .default,
        to canvas: Canvas
    ) {
        for xi in x..<(x + width) {
            if xi >= 0 && xi < canvas.width && y >= 0 && y < canvas.height {
                canvas.setCell(x: xi, y: y, char: "─", style: style)
            }
        }
    }

    // MARK: - Table Rendering

    /// Draw a table grid
    public func drawTableGrid(
        rect: Rect,
        columns: [Int],  // column widths
        rows: Int,
        chars: BoxChars = .single,
        style: TextStyle = .default,
        to canvas: Canvas
    ) {
        // Draw outer border
        drawBorder(rect: rect, chars: chars, style: style, to: canvas)

        // Draw column separators
        var x = rect.x
        for (index, width) in columns.dropLast().enumerated() {
            x += width
            // Draw vertical line
            for y in rect.y..<(rect.y + rect.height) {
                let char: Character = (y == rect.y) ? "┬" :
                                      (y == rect.y + rect.height - 1) ? "┴" : chars.vertical
                setCell(x: x, y: y, char: char, style: style, canvas: canvas)
            }
            x += 1
        }

        // Draw row separators (header row only for simplicity)
        if rows > 1 {
            let headerY = rect.y + 1
            for xi in rect.x..<(rect.x + rect.width) {
                if xi >= 0 && xi < canvas.width && headerY >= 0 && headerY < canvas.height {
                    let existing = canvas[xi, headerY]
                    let char: Character = (existing.character == chars.vertical) ? "┼" : chars.horizontal
                    canvas.setCell(x: xi, y: headerY, char: char, style: style)
                }
            }
        }
    }

    // MARK: - Blockquote Rendering

    /// Draw a blockquote indicator (vertical bar on left)
    public func drawBlockquoteBar(
        x: Int,
        y: Int,
        height: Int,
        style: TextStyle = TextStyle(foreground: .gray),
        to canvas: Canvas
    ) {
        for yi in y..<(y + height) {
            setCell(x: x, y: yi, char: "│", style: style, canvas: canvas)
        }
    }

    // MARK: - Helpers

    private func setCell(x: Int, y: Int, char: Character, style: TextStyle, canvas: Canvas) {
        if x >= 0 && x < canvas.width && y >= 0 && y < canvas.height {
            canvas.setCell(x: x, y: y, char: char, style: style)
        }
    }
}

// MARK: - Layout Box Rendering Helpers

extension BoxRenderer {
    /// Render all box decorations (background, border) for a layout box
    public func renderBoxDecorations(_ box: LayoutBox, to canvas: Canvas) {
        // Render background first
        renderBackground(box, to: canvas)

        // Render border if the box has border styling
        // (In terminal, we typically skip borders unless explicitly styled)
    }
}
