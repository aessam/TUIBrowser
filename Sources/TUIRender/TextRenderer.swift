// TUIRender - Text Renderer
//
// Renders styled text content to the terminal canvas.

import TUICore
import TUITerminal
import TUILayout
import TUIStyle

/// Renders text content with styling to a canvas
public struct TextRenderer: Sendable {

    public init() {}

    // MARK: - Text Rendering

    /// Render text at a position with style
    public func renderText(
        _ text: String,
        at point: Point,
        style: TextStyle,
        to canvas: Canvas
    ) {
        var x = point.x
        let y = point.y

        for char in text {
            if char.isNewline {
                continue  // Newlines handled by layout
            }

            if x >= 0 && x < canvas.width && y >= 0 && y < canvas.height {
                canvas.setCell(x: x, y: y, char: char, style: style)
            }

            x += 1
        }
    }

    /// Render a layout box containing text
    public func renderTextBox(_ box: LayoutBox, to canvas: Canvas) {
        guard let text = box.textContent else { return }

        let style = box.style.toTextStyle()
        let origin = Point(x: box.dimensions.content.x, y: box.dimensions.content.y)

        renderText(text, at: origin, style: style, to: canvas)
    }

    // MARK: - Styled Segments

    /// Render multiple styled segments on a single line
    public func renderSegments(
        _ segments: [(text: String, style: TextStyle)],
        at point: Point,
        to canvas: Canvas
    ) {
        var x = point.x

        for (text, style) in segments {
            renderText(text, at: Point(x: x, y: point.y), style: style, to: canvas)
            x += text.count
        }
    }

    // MARK: - Link Rendering

    /// Render a hyperlink with appropriate styling
    public func renderLink(
        _ text: String,
        href: String,
        at point: Point,
        to canvas: Canvas
    ) {
        let linkStyle = TextStyle(
            underline: true,
            foreground: .cyan
        )

        renderText(text, at: point, style: linkStyle, to: canvas)
    }

    // MARK: - List Marker Rendering

    /// Render a list marker (bullet or number)
    public func renderListMarker(
        _ marker: String,
        at point: Point,
        style: TextStyle,
        to canvas: Canvas
    ) {
        // Position marker to the left of content
        let markerPoint = Point(x: max(0, point.x - marker.count - 1), y: point.y)
        renderText(marker, at: markerPoint, style: style, to: canvas)
    }

    // MARK: - Code Block Rendering

    /// Render text as code (with background)
    public func renderCode(
        _ text: String,
        at point: Point,
        to canvas: Canvas
    ) {
        let codeStyle = TextStyle(
            foreground: .white,
            background: Color(r: 40, g: 40, b: 40)
        )

        renderText(text, at: point, style: codeStyle, to: canvas)
    }

    // MARK: - Heading Rendering

    /// Render heading text (bold, with optional underline)
    public func renderHeading(
        _ text: String,
        level: Int,
        at point: Point,
        width: Int,
        to canvas: Canvas
    ) {
        let headingStyle = TextStyle(bold: true, foreground: .white)

        renderText(text, at: point, style: headingStyle, to: canvas)

        // For h1, add underline
        if level == 1 && point.y + 1 < canvas.height {
            let underline = String(repeating: "═", count: min(text.count, width))
            renderText(underline, at: Point(x: point.x, y: point.y + 1), style: .default, to: canvas)
        }
    }
}
