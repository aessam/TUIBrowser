// TUIRender - Main Renderer
//
// Orchestrates rendering of layout boxes to a terminal canvas.

import TUICore
import TUITerminal
import TUILayout
import TUIStyle
import TUIHTMLParser

/// Main renderer that converts a layout tree to canvas output
public struct Renderer: Sendable {
    private let textRenderer: TextRenderer
    private let boxRenderer: BoxRenderer

    public init() {
        self.textRenderer = TextRenderer()
        self.boxRenderer = BoxRenderer()
    }

    // MARK: - Main Render API

    /// Render a layout tree to a canvas
    /// - Parameters:
    ///   - layout: Root layout box
    ///   - canvas: Target canvas (will be cleared first)
    ///   - scrollY: Vertical scroll offset (default 0)
    public func render(layout: LayoutBox, to canvas: Canvas, scrollY: Int = 0) {
        // Clear canvas
        canvas.clear()

        // Render layout tree recursively
        renderBox(layout, to: canvas, scrollY: scrollY)
    }

    /// Render layout tree and return as string
    public func renderToString(layout: LayoutBox, width: Int, height: Int) -> String {
        let canvas = Canvas(width: width, height: height)
        render(layout: layout, to: canvas)
        return canvasToString(canvas)
    }

    // MARK: - Box Rendering

    /// Render a single layout box and its children
    private func renderBox(_ box: LayoutBox, to canvas: Canvas, scrollY: Int) {
        let content = box.dimensions.content

        // Apply scroll offset
        let renderY = content.y - scrollY

        // Skip if entirely above viewport
        if renderY + content.height < 0 {
            return
        }

        // Skip if entirely below viewport
        if renderY >= canvas.height {
            return
        }

        // Skip hidden boxes
        if box.style.display == .none {
            return
        }

        // Render box background
        boxRenderer.renderBackground(box, to: canvas)

        // Render based on box type
        switch box.boxType {
        case .text:
            renderTextContent(box, to: canvas, scrollY: scrollY)

        case .block, .inline, .inlineBlock, .anonymous:
            // Render list marker if present
            if let marker = box.layoutInfo.listMarker {
                let markerX = max(0, content.x - marker.count - 1)
                let style = box.style.toTextStyle()
                textRenderer.renderText(
                    marker,
                    at: Point(x: markerX, y: renderY),
                    style: style,
                    to: canvas
                )
            }

            // Check for special elements
            if let element = box.element {
                renderSpecialElement(element, box: box, to: canvas, scrollY: scrollY)
            }

            // Render children
            for child in box.children {
                renderBox(child, to: canvas, scrollY: scrollY)
            }
        }
    }

    // MARK: - Text Content

    private func renderTextContent(_ box: LayoutBox, to canvas: Canvas, scrollY: Int) {
        guard let text = box.textContent else { return }

        let content = box.dimensions.content
        let renderY = content.y - scrollY

        // Skip if outside viewport
        if renderY < 0 || renderY >= canvas.height {
            return
        }

        let style = box.style.toTextStyle()
        textRenderer.renderText(
            text,
            at: Point(x: content.x, y: renderY),
            style: style,
            to: canvas
        )
    }

    // MARK: - Special Elements

    private func renderSpecialElement(
        _ element: Element,
        box: LayoutBox,
        to canvas: Canvas,
        scrollY: Int
    ) {
        let content = box.dimensions.content
        let renderY = content.y - scrollY

        switch element.tagName {
        case "hr":
            // Horizontal rule
            if renderY >= 0 && renderY < canvas.height {
                boxRenderer.drawHorizontalRule(
                    y: renderY,
                    x: content.x,
                    width: content.width,
                    to: canvas
                )
            }

        case "br":
            // Line break (handled by layout, nothing to render)
            break

        case "img":
            // Image placeholder
            let alt = element.getAttribute("alt") ?? "[IMG]"
            if renderY >= 0 && renderY < canvas.height {
                let style = TextStyle(foreground: .gray)
                textRenderer.renderText(
                    "[\(alt)]",
                    at: Point(x: content.x, y: renderY),
                    style: style,
                    to: canvas
                )
            }

        case "a":
            // Links are rendered by their text children with link styling
            break

        case "input":
            // Form input placeholder
            let inputType = element.getAttribute("type") ?? "text"
            let placeholder = element.getAttribute("placeholder") ?? ""
            if renderY >= 0 && renderY < canvas.height {
                let style = TextStyle(
                    foreground: .gray,
                    background: Color(r: 30, g: 30, b: 30)
                )
                let display = placeholder.isEmpty ? "[\(inputType)]" : "[\(placeholder)]"
                textRenderer.renderText(
                    display,
                    at: Point(x: content.x, y: renderY),
                    style: style,
                    to: canvas
                )
            }

        case "button":
            // Button with border
            if renderY >= 0 && renderY < canvas.height {
                let buttonText = element.textContent
                let style = TextStyle(
                    bold: true,
                    foreground: .white,
                    background: Color(r: 60, g: 60, b: 60)
                )
                textRenderer.renderText(
                    "[ \(buttonText) ]",
                    at: Point(x: content.x, y: renderY),
                    style: style,
                    to: canvas
                )
            }

        case "blockquote":
            // Blockquote with left bar
            boxRenderer.drawBlockquoteBar(
                x: content.x,
                y: renderY,
                height: content.height,
                to: canvas
            )

        case "pre", "code":
            // Handled by text content with code styling
            break

        default:
            break
        }
    }

    // MARK: - Canvas to String

    private func canvasToString(_ canvas: Canvas) -> String {
        var result = ""

        for y in 0..<canvas.height {
            for x in 0..<canvas.width {
                let cell = canvas[x, y]
                result.append(cell.character)
            }
            result.append("\n")
        }

        return result
    }

    // MARK: - Static API

    /// Render a layout to a new canvas and return it
    public static func render(layout: LayoutBox, width: Int, height: Int, scrollY: Int = 0) -> Canvas {
        let canvas = Canvas(width: width, height: height)
        let renderer = Renderer()
        renderer.render(layout: layout, to: canvas, scrollY: scrollY)
        return canvas
    }

    /// Render layout directly to terminal output
    public static func render(
        layout: LayoutBox,
        to output: TerminalOutput,
        width: Int,
        height: Int,
        scrollY: Int = 0
    ) {
        let canvas = render(layout: layout, width: width, height: height, scrollY: scrollY)
        canvas.render(to: output, fullRedraw: true)
    }
}

// MARK: - Rendering Options

/// Options for customizing rendering
public struct RenderOptions: Sendable {
    /// Whether to use color
    public var useColor: Bool

    /// Whether to use bold/italic/underline
    public var useTextStyles: Bool

    /// Whether to show images (as ASCII)
    public var showImages: Bool

    /// Whether to show form elements
    public var showForms: Bool

    /// Link display mode
    public var linkMode: LinkDisplayMode

    public init(
        useColor: Bool = true,
        useTextStyles: Bool = true,
        showImages: Bool = true,
        showForms: Bool = true,
        linkMode: LinkDisplayMode = .inline
    ) {
        self.useColor = useColor
        self.useTextStyles = useTextStyles
        self.showImages = showImages
        self.showForms = showForms
        self.linkMode = linkMode
    }

    public static let `default` = RenderOptions()
}

/// How to display links
public enum LinkDisplayMode: Sendable {
    case inline      // Show link text with styling
    case numbered    // Show [N] after links, list URLs at bottom
    case hidden      // Don't indicate links at all
}
