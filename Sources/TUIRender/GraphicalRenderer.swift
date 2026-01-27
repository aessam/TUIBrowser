// TUIRender - Graphical PNG Renderer
//
// Renders a LayoutBox tree directly to a PNG image using CoreGraphics and CoreText.
// This produces much better quality output than the bitmap font approach.

import Foundation
import TUICore
import TUILayout
import TUIStyle
import TUIHTMLParser

#if canImport(CoreGraphics) && canImport(CoreText) && canImport(ImageIO)
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

/// Renders a layout tree directly to a PNG image using CoreGraphics
public struct GraphicalRenderer: Sendable {
    /// Pixels per character cell width
    public let cellWidth: CGFloat

    /// Pixels per character cell height
    public let cellHeight: CGFloat

    /// Output width in pixels
    public let width: Int

    /// Output height in pixels
    public let height: Int

    /// Base font size in points
    public let baseFontSize: CGFloat

    /// Image cache for rendering images
    public let imageCache: (any ImageCacheProtocol)?

    public init(
        cellWidth: CGFloat = 16.0,
        cellHeight: CGFloat = 20.0,
        width: Int,
        height: Int,
        baseFontSize: CGFloat = 16.0,
        imageCache: (any ImageCacheProtocol)? = nil
    ) {
        self.cellWidth = cellWidth
        self.cellHeight = cellHeight
        self.width = width
        self.height = height
        self.baseFontSize = baseFontSize
        self.imageCache = imageCache
    }

    // MARK: - Main Render API

    /// Render a layout tree to a CGImage
    /// - Parameter layout: Root layout box
    /// - Returns: CGImage if successful, nil otherwise
    public func render(_ layout: LayoutBox) -> CGImage? {
        // Create RGBA context
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }

        // CoreGraphics has origin at bottom-left, flip to top-left
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)

        // Fill white background
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))

        // Render the layout tree
        renderBox(layout, context: context)

        return context.makeImage()
    }

    /// Render to a PNG file
    /// - Parameters:
    ///   - layout: Root layout box
    ///   - path: Output file path
    /// - Returns: true if successful
    public func renderToFile(_ layout: LayoutBox, path: String) -> Bool {
        guard let image = render(layout) else {
            return false
        }
        return writePNG(image, to: path)
    }

    // MARK: - Box Rendering

    private func renderBox(_ box: LayoutBox, context: CGContext) {
        // Skip hidden boxes
        if box.style.display == .none {
            return
        }

        // Convert layout coords (character cells) to pixel coords
        let rect = CGRect(
            x: CGFloat(box.dimensions.content.x) * cellWidth,
            y: CGFloat(box.dimensions.content.y) * cellHeight,
            width: CGFloat(box.dimensions.content.width) * cellWidth,
            height: CGFloat(box.dimensions.content.height) * cellHeight
        )

        // Render background if set
        if let bgColor = box.style.backgroundColor {
            context.setFillColor(bgColor.cgColor)
            context.fill(rect)
        }

        // Check for special elements
        if let element = box.element {
            renderSpecialElement(element, box: box, rect: rect, context: context)
        }

        // Render based on box type
        switch box.boxType {
        case .text:
            renderText(box, in: rect, context: context)

        case .block, .inline, .inlineBlock, .anonymous:
            // Render list marker if present
            if let marker = box.layoutInfo.listMarker {
                let markerX = CGFloat(max(0, box.dimensions.content.x - marker.count - 1)) * cellWidth
                renderTextString(
                    marker,
                    at: CGPoint(x: markerX, y: rect.origin.y),
                    style: box.style,
                    context: context
                )
            }

            // Render children
            for child in box.children {
                renderBox(child, context: context)
            }
        }
    }

    // MARK: - Text Rendering

    private func renderText(_ box: LayoutBox, in rect: CGRect, context: CGContext) {
        guard let text = box.textContent, !text.isEmpty else { return }
        renderTextString(text, at: rect.origin, style: box.style, context: context)
    }

    private func renderTextString(
        _ text: String,
        at origin: CGPoint,
        style: ComputedStyle,
        context: CGContext
    ) {
        // Determine font - use baseFontSize directly, scaled to fit cell height
        let fontSize = baseFontSize
        let fontName: CFString

        if style.fontWeight.isBold && style.fontStyle == .italic {
            fontName = "Helvetica-BoldOblique" as CFString
        } else if style.fontWeight.isBold {
            fontName = "Helvetica-Bold" as CFString
        } else if style.fontStyle == .italic {
            fontName = "Helvetica-Oblique" as CFString
        } else {
            fontName = "Helvetica" as CFString
        }

        let font = CTFontCreateWithName(fontName, fontSize, nil)

        // Build attributes using CoreText keys (not AppKit)
        let attributes: [CFString: Any] = [
            kCTFontAttributeName: font,
            kCTForegroundColorAttributeName: style.color.cgColor
        ]

        // Create attributed string
        let attrString = CFAttributedStringCreate(
            kCFAllocatorDefault,
            text as CFString,
            attributes as CFDictionary
        )!
        let line = CTLineCreateWithAttributedString(attrString)

        // Get text metrics for baseline positioning
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        CTLineGetTypographicBounds(line, &ascent, &descent, &leading)

        // Save context state before text-specific transforms
        context.saveGState()

        // CoreText draws text with y-axis going up, but we've flipped the coordinate system
        // We need to flip again locally for text, then position at baseline
        context.translateBy(x: origin.x, y: origin.y + ascent + descent)
        context.scaleBy(x: 1, y: -1)

        // Position text at origin (baseline is at y=descent after our flip)
        context.textPosition = CGPoint(x: 0, y: descent)

        // Draw the text
        CTLineDraw(line, context)

        // Restore context state
        context.restoreGState()

        // Draw underline manually if needed
        if style.textDecoration == .underline {
            let textWidth = CTLineGetTypographicBounds(line, nil, nil, nil)
            let underlineY = origin.y + ascent + descent * 0.3
            context.setStrokeColor(style.color.cgColor)
            context.setLineWidth(1)
            context.move(to: CGPoint(x: origin.x, y: underlineY))
            context.addLine(to: CGPoint(x: origin.x + textWidth, y: underlineY))
            context.strokePath()
        } else if style.textDecoration == .lineThrough {
            let textWidth = CTLineGetTypographicBounds(line, nil, nil, nil)
            let strikeY = origin.y + (ascent + descent) * 0.5
            context.setStrokeColor(style.color.cgColor)
            context.setLineWidth(1)
            context.move(to: CGPoint(x: origin.x, y: strikeY))
            context.addLine(to: CGPoint(x: origin.x + textWidth, y: strikeY))
            context.strokePath()
        }
    }

    // MARK: - Special Element Rendering

    private func renderSpecialElement(
        _ element: Element,
        box: LayoutBox,
        rect: CGRect,
        context: CGContext
    ) {
        switch element.tagName {
        case "hr":
            // Horizontal rule
            let lineY = rect.origin.y + rect.height / 2
            context.setStrokeColor(CGColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 1))
            context.setLineWidth(1)
            context.move(to: CGPoint(x: rect.origin.x, y: lineY))
            context.addLine(to: CGPoint(x: rect.origin.x + rect.width, y: lineY))
            context.strokePath()

        case "img":
            renderImage(element, in: rect, context: context)

        case "a":
            // Links get rendered with underline in text, but we could add special styling here
            break

        case "input":
            renderInputElement(element, in: rect, context: context)

        case "button":
            renderButtonElement(element, box: box, in: rect, context: context)

        case "blockquote":
            // Draw left border bar
            context.setFillColor(CGColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1))
            let barWidth: CGFloat = 4
            context.fill(CGRect(x: rect.origin.x - barWidth - 4, y: rect.origin.y, width: barWidth, height: rect.height))

        default:
            break
        }
    }

    // MARK: - Image Rendering

    private func renderImage(_ element: Element, in rect: CGRect, context: CGContext) {
        guard let src = element.getAttribute("src"),
              let cache = imageCache,
              let pixelBuffer = cache.get(src) else {
            // Render placeholder
            let alt = element.getAttribute("alt") ?? "IMG"
            let placeholder = "[\(alt)]"

            context.setFillColor(CGColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1))
            context.fill(rect)

            context.setStrokeColor(CGColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 1))
            context.setLineWidth(1)
            context.stroke(rect)

            // Draw placeholder text
            let placeholderStyle = ComputedStyle(color: .gray)
            let textX = rect.origin.x + 4
            let textY = rect.origin.y + 4
            renderTextString(placeholder, at: CGPoint(x: textX, y: textY), style: placeholderStyle, context: context)
            return
        }

        // Convert PixelBuffer to CGImage
        guard let cgImage = createCGImage(from: pixelBuffer) else { return }

        // Draw image scaled to fit the rect
        context.draw(cgImage, in: rect)
    }

    private func createCGImage(from pixelBuffer: PixelBuffer) -> CGImage? {
        let width = pixelBuffer.width
        let height = pixelBuffer.height

        // Create RGBA pixel data
        var pixels = [UInt8](repeating: 0, count: width * height * 4)

        for y in 0..<height {
            for x in 0..<width {
                let color = pixelBuffer[x, y]
                let offset = (y * width + x) * 4
                pixels[offset] = color.r
                pixels[offset + 1] = color.g
                pixels[offset + 2] = color.b
                pixels[offset + 3] = 255
            }
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else {
            return nil
        }

        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }

    // MARK: - Form Element Rendering

    private func renderInputElement(_ element: Element, in rect: CGRect, context: CGContext) {
        let inputType = element.getAttribute("type")?.lowercased() ?? "text"
        let value = element.getAttribute("value") ?? ""
        let placeholder = element.getAttribute("placeholder") ?? ""
        let checked = element.hasAttribute("checked")

        switch inputType {
        case "checkbox":
            // Draw checkbox
            let boxSize: CGFloat = min(rect.width, rect.height) * 0.8
            let boxRect = CGRect(
                x: rect.origin.x + (rect.width - boxSize) / 2,
                y: rect.origin.y + (rect.height - boxSize) / 2,
                width: boxSize,
                height: boxSize
            )

            context.setStrokeColor(CGColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1))
            context.setLineWidth(1)
            context.stroke(boxRect)

            if checked {
                // Draw checkmark
                context.setStrokeColor(CGColor(red: 0.2, green: 0.6, blue: 0.2, alpha: 1))
                context.setLineWidth(2)
                context.move(to: CGPoint(x: boxRect.minX + boxSize * 0.2, y: boxRect.midY))
                context.addLine(to: CGPoint(x: boxRect.midX, y: boxRect.maxY - boxSize * 0.2))
                context.addLine(to: CGPoint(x: boxRect.maxX - boxSize * 0.2, y: boxRect.minY + boxSize * 0.2))
                context.strokePath()
            }

        case "radio":
            // Draw radio button
            let radius: CGFloat = min(rect.width, rect.height) * 0.35
            let center = CGPoint(x: rect.midX, y: rect.midY)

            context.setStrokeColor(CGColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1))
            context.setLineWidth(1)
            context.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            context.strokePath()

            if checked {
                context.setFillColor(CGColor(red: 0.2, green: 0.6, blue: 0.2, alpha: 1))
                context.addArc(center: center, radius: radius * 0.5, startAngle: 0, endAngle: .pi * 2, clockwise: true)
                context.fillPath()
            }

        case "submit", "button", "reset":
            // Draw button
            let buttonText = value.isEmpty ? inputType.capitalized : value

            // Button background
            context.setFillColor(CGColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1))
            let cornerRadius: CGFloat = 4
            let buttonPath = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
            context.addPath(buttonPath)
            context.fillPath()

            // Button border
            context.setStrokeColor(CGColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 1))
            context.setLineWidth(1)
            context.addPath(buttonPath)
            context.strokePath()

            // Button text
            let buttonStyle = ComputedStyle(color: .black, fontWeight: .bold)
            let textX = rect.origin.x + 8
            let textY = rect.origin.y + 4
            renderTextString(buttonText, at: CGPoint(x: textX, y: textY), style: buttonStyle, context: context)

        case "hidden":
            break

        default:
            // Text input
            // Background
            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            context.fill(rect)

            // Border
            context.setStrokeColor(CGColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 1))
            context.setLineWidth(1)
            context.stroke(rect)

            // Text content
            let displayText = value.isEmpty ? placeholder : value
            let textColor: Color = value.isEmpty ? .gray : .black
            let textStyle = ComputedStyle(color: textColor)
            let textX = rect.origin.x + 4
            let textY = rect.origin.y + 4
            renderTextString(displayText, at: CGPoint(x: textX, y: textY), style: textStyle, context: context)
        }
    }

    private func renderButtonElement(_ element: Element, box: LayoutBox, in rect: CGRect, context: CGContext) {
        let buttonText = element.textContent.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = buttonText.isEmpty ? "Button" : buttonText

        // Button background with gradient-like effect
        context.setFillColor(CGColor(red: 0.92, green: 0.92, blue: 0.95, alpha: 1))
        let cornerRadius: CGFloat = 4
        let buttonPath = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        context.addPath(buttonPath)
        context.fillPath()

        // Button border
        context.setStrokeColor(CGColor(red: 0.6, green: 0.6, blue: 0.7, alpha: 1))
        context.setLineWidth(1)
        context.addPath(buttonPath)
        context.strokePath()

        // Button text (centered)
        let buttonStyle = ComputedStyle(color: .black, fontWeight: .bold)
        let textX = rect.origin.x + 8
        let textY = rect.origin.y + 6
        renderTextString(text, at: CGPoint(x: textX, y: textY), style: buttonStyle, context: context)
    }

    // MARK: - PNG Writing

    private func writePNG(_ image: CGImage, to path: String) -> Bool {
        let url = URL(fileURLWithPath: path)

        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            return false
        }

        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination)
    }
}

#else
// Fallback for non-Apple platforms
public struct GraphicalRenderer: Sendable {
    public let cellWidth: CGFloat = 16.0
    public let cellHeight: CGFloat = 20.0
    public let width: Int
    public let height: Int
    public let baseFontSize: CGFloat = 16.0
    public let imageCache: (any ImageCacheProtocol)?

    public init(
        cellWidth: CGFloat = 16.0,
        cellHeight: CGFloat = 20.0,
        width: Int,
        height: Int,
        baseFontSize: CGFloat = 16.0,
        imageCache: (any ImageCacheProtocol)? = nil
    ) {
        self.width = width
        self.height = height
        self.imageCache = imageCache
    }

    public func render(_ layout: LayoutBox) -> Any? {
        print("Graphical rendering is only available on macOS")
        return nil
    }

    public func renderToFile(_ layout: LayoutBox, path: String) -> Bool {
        print("Graphical rendering is only available on macOS")
        return false
    }
}
#endif
