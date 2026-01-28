// TUIRender - Main Renderer
//
// Orchestrates rendering of layout boxes to a terminal canvas.

import TUICore
import TUITerminal
import TUILayout
import TUIStyle
import TUIHTMLParser

/// Image cache protocol for providing decoded images
public protocol ImageCacheProtocol: Sendable {
    func get(_ url: String) -> PixelBuffer?
}

/// Main renderer that converts a layout tree to canvas output
public struct Renderer: Sendable {
    private let textRenderer: TextRenderer
    private let boxRenderer: BoxRenderer

    /// Image cache for fetched images
    private let imageCache: (any ImageCacheProtocol)?

    /// Image render options
    public var imageOptions: ImageRenderOptions

    /// Object ID of currently focused element (for rendering focus indicators)
    public var focusedElementId: ObjectIdentifier?

    /// Whether the browser is in text input mode
    public var isInTextInputMode: Bool

    /// Cursor position for text input (if in text input mode)
    public var textInputCursor: Int

    public init(
        imageCache: (any ImageCacheProtocol)? = nil,
        imageOptions: ImageRenderOptions = .init(),
        focusedElement: Element? = nil,
        isInTextInputMode: Bool = false,
        textInputCursor: Int = 0
    ) {
        self.textRenderer = TextRenderer()
        self.boxRenderer = BoxRenderer()
        self.imageCache = imageCache
        self.imageOptions = imageOptions
        self.focusedElementId = focusedElement.map { ObjectIdentifier($0) }
        self.isInTextInputMode = isInTextInputMode
        self.textInputCursor = textInputCursor
    }

    /// Check if an element is the focused element
    private func isFocused(_ element: Element) -> Bool {
        guard let focusedId = focusedElementId else { return false }
        return ObjectIdentifier(element) == focusedId
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
            // Try to render actual image from cache
            if let src = element.getAttribute("src"),
               let cache = imageCache,
               let pixelBuffer = cache.get(src) {
                renderImage(
                    pixelBuffer,
                    at: Point(x: content.x, y: renderY),
                    maxWidth: content.width,
                    maxHeight: max(1, content.height),
                    to: canvas
                )
            } else {
                // Fall back to placeholder
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
            }

        case "a":
            // Render link focus indicator
            if isFocused(element) {
                // Draw focus brackets around the link
                let focusStyle = TextStyle(bold: true, foreground: .cyan)
                if renderY >= 0 && renderY < canvas.height {
                    if content.x > 0 {
                        canvas.setCell(x: content.x - 1, y: renderY, char: "›", style: focusStyle)
                    }
                    let endX = content.x + content.width
                    if endX < canvas.width {
                        canvas.setCell(x: endX, y: renderY, char: "‹", style: focusStyle)
                    }
                }
            }

        case "input":
            renderInput(element, at: Point(x: content.x, y: renderY), width: content.width, to: canvas)

        case "button":
            renderButton(element, at: Point(x: content.x, y: renderY), to: canvas)

        case "select":
            renderSelect(element, at: Point(x: content.x, y: renderY), width: content.width, to: canvas)

        case "textarea":
            renderTextarea(element, at: Point(x: content.x, y: renderY), width: content.width, height: content.height, to: canvas)

        case "label":
            // Labels are handled by their text content
            break

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

    // MARK: - Image Rendering

    /// Render an image to the canvas using terminal graphics
    private func renderImage(
        _ pixels: PixelBuffer,
        at position: Point,
        maxWidth: Int,
        maxHeight: Int,
        to canvas: Canvas
    ) {
        // Skip if position is outside canvas
        guard position.y >= 0 && position.y < canvas.height else { return }
        guard position.x >= 0 && position.x < canvas.width else { return }

        // Calculate available space
        let availableWidth = min(maxWidth, canvas.width - position.x)
        let availableHeight = min(maxHeight, canvas.height - position.y)

        guard availableWidth > 0 && availableHeight > 0 else { return }

        // Scale image to fit available space
        let scaledPixels = ImageDecoder.scaleToFit(
            pixels,
            maxWidth: availableWidth,
            maxHeight: availableHeight,
            blitMode: imageOptions.blitMode
        )

        // Create renderer with options
        let imageRenderer = ImageRenderer(options: imageOptions)

        // Render using configured blitter
        let blitResult = imageRenderer.render(scaledPixels)

        // Draw blitted cells to canvas
        for (rowIndex, row) in blitResult.cells.enumerated() {
            let y = position.y + rowIndex
            guard y >= 0 && y < canvas.height else { continue }

            for (colIndex, cell) in row.enumerated() {
                let x = position.x + colIndex
                guard x >= 0 && x < canvas.width else { continue }

                let textStyle = TextStyle(
                    foreground: cell.foreground,
                    background: cell.background
                )
                canvas.setCell(x: x, y: y, char: cell.character, style: textStyle)
            }
        }
    }

    // MARK: - Form Element Rendering

    /// Render an input element
    private func renderInput(_ element: Element, at position: Point, width: Int, to canvas: Canvas) {
        guard position.y >= 0 && position.y < canvas.height else { return }

        let inputType = element.getAttribute("type")?.lowercased() ?? "text"
        let value = element.getAttribute("value") ?? ""
        let placeholder = element.getAttribute("placeholder") ?? ""
        let checked = element.hasAttribute("checked")
        let disabled = element.hasAttribute("disabled")
        let isFocused = self.isFocused(element)

        let fgColor: Color = disabled ? .gray : (isFocused ? .cyan : .white)
        let bgColor = isFocused ? Color(r: 40, g: 40, b: 50) : Color(r: 30, g: 30, b: 30)

        switch inputType {
        case "checkbox":
            // Render checkbox: ☐ or ☑
            let checkChar: Character = checked ? "☑" : "☐"
            let style = TextStyle(foreground: fgColor)
            canvas.setCell(x: position.x, y: position.y, char: checkChar, style: style)

        case "radio":
            // Render radio button: ○ or ●
            let radioChar: Character = checked ? "●" : "○"
            let style = TextStyle(foreground: fgColor)
            canvas.setCell(x: position.x, y: position.y, char: radioChar, style: style)

        case "submit", "button", "reset":
            // Render as button
            let buttonText = value.isEmpty ? inputType.capitalized : value
            let style = TextStyle(bold: true, foreground: fgColor, background: Color(r: 50, g: 50, b: 50))
            let display = "┃ \(buttonText) ┃"
            textRenderer.renderText(display, at: position, style: style, to: canvas)

        case "hidden":
            // Don't render hidden inputs
            break

        default:
            // Text-like inputs: text, password, email, number, search, etc.
            renderTextInput(
                placeholder: placeholder,
                value: value,
                inputType: inputType,
                at: position,
                width: max(10, min(width, 40)),
                fgColor: fgColor,
                bgColor: bgColor,
                isFocused: isFocused,
                cursorPosition: isInTextInputMode && isFocused ? textInputCursor : nil,
                to: canvas
            )
        }
    }

    /// Render a text input field with box border
    private func renderTextInput(
        placeholder: String,
        value: String,
        inputType: String,
        at position: Point,
        width: Int,
        fgColor: Color,
        bgColor: Color,
        isFocused: Bool,
        cursorPosition: Int?,
        to canvas: Canvas
    ) {
        guard position.y >= 0 && position.y < canvas.height else { return }

        let fieldWidth = max(10, width)
        let borderColor = isFocused ? Color(r: 100, g: 150, b: 200) : Color(r: 80, g: 80, b: 80)
        let borderStyle = TextStyle(foreground: borderColor)
        let textStyle = TextStyle(foreground: fgColor, background: bgColor)
        let placeholderStyle = TextStyle(foreground: .gray, background: bgColor)
        let cursorStyle = TextStyle(foreground: .cyan, background: bgColor)

        // Draw top border: ┌─────┐
        var topBorder = "┌"
        topBorder += String(repeating: "─", count: fieldWidth - 2)
        topBorder += "┐"

        for (i, char) in topBorder.enumerated() {
            let x = position.x + i
            guard x >= 0 && x < canvas.width else { continue }
            canvas.setCell(x: x, y: position.y, char: char, style: borderStyle)
        }

        // Draw content row: │ text │
        let contentY = position.y + 1
        if contentY >= 0 && contentY < canvas.height {
            // Left border
            if position.x >= 0 && position.x < canvas.width {
                canvas.setCell(x: position.x, y: contentY, char: "│", style: borderStyle)
            }

            // Content area
            let contentWidth = fieldWidth - 2
            let displayText: String
            let useStyle: TextStyle

            if !value.isEmpty {
                // Show value (masked for password)
                if inputType == "password" {
                    displayText = String(repeating: "•", count: min(value.count, contentWidth))
                } else {
                    displayText = String(value.prefix(contentWidth))
                }
                useStyle = textStyle
            } else if !placeholder.isEmpty {
                displayText = String(placeholder.prefix(contentWidth))
                useStyle = placeholderStyle
            } else {
                displayText = ""
                useStyle = textStyle
            }

            // Draw content background and text
            for i in 0..<contentWidth {
                let x = position.x + 1 + i
                guard x >= 0 && x < canvas.width else { continue }

                // Determine if cursor is at this position
                let isCursorHere = cursorPosition != nil && i == cursorPosition

                let char: Character
                let charStyle: TextStyle
                if isCursorHere {
                    // Draw cursor
                    char = i < displayText.count ? Array(displayText)[i] : "▎"
                    charStyle = cursorStyle
                } else if i < displayText.count {
                    char = Array(displayText)[i]
                    charStyle = useStyle
                } else {
                    char = " "
                    charStyle = useStyle
                }
                canvas.setCell(x: x, y: contentY, char: char, style: charStyle)
            }

            // Right border
            let rightX = position.x + fieldWidth - 1
            if rightX >= 0 && rightX < canvas.width {
                canvas.setCell(x: rightX, y: contentY, char: "│", style: borderStyle)
            }
        }

        // Draw bottom border: └─────┘
        let bottomY = position.y + 2
        if bottomY >= 0 && bottomY < canvas.height {
            var bottomBorder = "└"
            bottomBorder += String(repeating: "─", count: fieldWidth - 2)
            bottomBorder += "┘"

            for (i, char) in bottomBorder.enumerated() {
                let x = position.x + i
                guard x >= 0 && x < canvas.width else { continue }
                canvas.setCell(x: x, y: bottomY, char: char, style: borderStyle)
            }
        }
    }

    /// Render a button element with bold border
    private func renderButton(_ element: Element, at position: Point, to canvas: Canvas) {
        guard position.y >= 0 && position.y < canvas.height else { return }

        let buttonText = element.textContent.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = buttonText.isEmpty ? "Button" : buttonText
        let disabled = element.hasAttribute("disabled")
        let isFocused = self.isFocused(element)

        let fgColor: Color = disabled ? .gray : (isFocused ? .cyan : .white)
        let bgColor = isFocused ? Color(r: 60, g: 60, b: 80) : Color(r: 50, g: 50, b: 60)
        let borderColor = isFocused ? Color(r: 120, g: 160, b: 200) : Color(r: 100, g: 100, b: 120)

        let contentWidth = text.count + 2  // padding on each side
        let buttonWidth = contentWidth + 2  // borders

        let borderStyle = TextStyle(foreground: borderColor)
        let textStyle = TextStyle(bold: true, foreground: fgColor, background: bgColor)

        // Draw top border: ┏━━━━━┓
        var topBorder = "┏"
        topBorder += String(repeating: "━", count: contentWidth)
        topBorder += "┓"

        for (i, char) in topBorder.enumerated() {
            let x = position.x + i
            guard x >= 0 && x < canvas.width else { continue }
            canvas.setCell(x: x, y: position.y, char: char, style: borderStyle)
        }

        // Draw content row: ┃ text ┃
        let contentY = position.y + 1
        if contentY >= 0 && contentY < canvas.height {
            if position.x >= 0 && position.x < canvas.width {
                canvas.setCell(x: position.x, y: contentY, char: "┃", style: borderStyle)
            }

            // Draw text with background
            let paddedText = " \(text) "
            for (i, char) in paddedText.enumerated() {
                let x = position.x + 1 + i
                guard x >= 0 && x < canvas.width else { continue }
                canvas.setCell(x: x, y: contentY, char: char, style: textStyle)
            }

            let rightX = position.x + buttonWidth - 1
            if rightX >= 0 && rightX < canvas.width {
                canvas.setCell(x: rightX, y: contentY, char: "┃", style: borderStyle)
            }
        }

        // Draw bottom border: ┗━━━━━┛
        let bottomY = position.y + 2
        if bottomY >= 0 && bottomY < canvas.height {
            var bottomBorder = "┗"
            bottomBorder += String(repeating: "━", count: contentWidth)
            bottomBorder += "┛"

            for (i, char) in bottomBorder.enumerated() {
                let x = position.x + i
                guard x >= 0 && x < canvas.width else { continue }
                canvas.setCell(x: x, y: bottomY, char: char, style: borderStyle)
            }
        }
    }

    /// Render a select dropdown
    private func renderSelect(_ element: Element, at position: Point, width: Int, to canvas: Canvas) {
        guard position.y >= 0 && position.y < canvas.height else { return }

        // Find selected option
        var selectedText = ""
        let options = element.children.filter { $0.tagName == "option" }
        for option in options {
            if option.hasAttribute("selected") {
                selectedText = option.textContent.trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }
        if selectedText.isEmpty && !options.isEmpty {
            selectedText = options[0].textContent.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let fieldWidth = max(10, min(width, 30))
        let borderStyle = TextStyle(foreground: Color(r: 80, g: 80, b: 80))
        let textStyle = TextStyle(foreground: .white, background: Color(r: 30, g: 30, b: 30))
        let arrowStyle = TextStyle(foreground: .cyan)

        // Draw border and content similar to text input
        // Top border
        var topBorder = "┌"
        topBorder += String(repeating: "─", count: fieldWidth - 2)
        topBorder += "┐"

        for (i, char) in topBorder.enumerated() {
            let x = position.x + i
            guard x >= 0 && x < canvas.width else { continue }
            canvas.setCell(x: x, y: position.y, char: char, style: borderStyle)
        }

        // Content row with dropdown arrow
        let contentY = position.y + 1
        if contentY >= 0 && contentY < canvas.height {
            if position.x >= 0 && position.x < canvas.width {
                canvas.setCell(x: position.x, y: contentY, char: "│", style: borderStyle)
            }

            // Content (leave 2 chars for arrow)
            let contentWidth = fieldWidth - 4
            let displayText = String(selectedText.prefix(contentWidth))
            let paddedText = displayText.padding(toLength: contentWidth, withPad: " ", startingAt: 0)

            for (i, char) in paddedText.enumerated() {
                let x = position.x + 1 + i
                guard x >= 0 && x < canvas.width else { continue }
                canvas.setCell(x: x, y: contentY, char: char, style: textStyle)
            }

            // Dropdown arrow
            let arrowX = position.x + fieldWidth - 3
            if arrowX >= 0 && arrowX < canvas.width {
                canvas.setCell(x: arrowX, y: contentY, char: " ", style: textStyle)
            }
            if arrowX + 1 >= 0 && arrowX + 1 < canvas.width {
                canvas.setCell(x: arrowX + 1, y: contentY, char: "▼", style: arrowStyle)
            }

            let rightX = position.x + fieldWidth - 1
            if rightX >= 0 && rightX < canvas.width {
                canvas.setCell(x: rightX, y: contentY, char: "│", style: borderStyle)
            }
        }

        // Bottom border
        let bottomY = position.y + 2
        if bottomY >= 0 && bottomY < canvas.height {
            var bottomBorder = "└"
            bottomBorder += String(repeating: "─", count: fieldWidth - 2)
            bottomBorder += "┘"

            for (i, char) in bottomBorder.enumerated() {
                let x = position.x + i
                guard x >= 0 && x < canvas.width else { continue }
                canvas.setCell(x: x, y: bottomY, char: char, style: borderStyle)
            }
        }
    }

    /// Render a textarea element
    private func renderTextarea(_ element: Element, at position: Point, width: Int, height: Int, to canvas: Canvas) {
        guard position.y >= 0 && position.y < canvas.height else { return }

        let text = element.textContent
        let placeholder = element.getAttribute("placeholder") ?? ""

        let fieldWidth = max(10, min(width, 60))
        let fieldHeight = max(3, min(height, 10))

        let borderStyle = TextStyle(foreground: Color(r: 80, g: 80, b: 80))
        let textStyle = TextStyle(foreground: .white, background: Color(r: 30, g: 30, b: 30))
        let placeholderStyle = TextStyle(foreground: .gray, background: Color(r: 30, g: 30, b: 30))

        // Top border
        var topBorder = "┌"
        topBorder += String(repeating: "─", count: fieldWidth - 2)
        topBorder += "┐"

        for (i, char) in topBorder.enumerated() {
            let x = position.x + i
            guard x >= 0 && x < canvas.width else { continue }
            canvas.setCell(x: x, y: position.y, char: char, style: borderStyle)
        }

        // Content rows
        let displayText = text.isEmpty ? placeholder : text
        let useStyle = text.isEmpty ? placeholderStyle : textStyle
        let lines = displayText.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        for row in 0..<(fieldHeight - 2) {
            let contentY = position.y + 1 + row
            guard contentY >= 0 && contentY < canvas.height else { continue }

            // Left border
            if position.x >= 0 && position.x < canvas.width {
                canvas.setCell(x: position.x, y: contentY, char: "│", style: borderStyle)
            }

            // Content
            let lineText = row < lines.count ? String(lines[row].prefix(fieldWidth - 2)) : ""
            for i in 0..<(fieldWidth - 2) {
                let x = position.x + 1 + i
                guard x >= 0 && x < canvas.width else { continue }
                let char: Character = i < lineText.count ? Array(lineText)[i] : " "
                canvas.setCell(x: x, y: contentY, char: char, style: useStyle)
            }

            // Right border
            let rightX = position.x + fieldWidth - 1
            if rightX >= 0 && rightX < canvas.width {
                canvas.setCell(x: rightX, y: contentY, char: "│", style: borderStyle)
            }
        }

        // Bottom border
        let bottomY = position.y + fieldHeight - 1
        if bottomY >= 0 && bottomY < canvas.height {
            var bottomBorder = "└"
            bottomBorder += String(repeating: "─", count: fieldWidth - 2)
            bottomBorder += "┘"

            for (i, char) in bottomBorder.enumerated() {
                let x = position.x + i
                guard x >= 0 && x < canvas.width else { continue }
                canvas.setCell(x: x, y: bottomY, char: char, style: borderStyle)
            }
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
