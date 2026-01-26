// TUIRender - Image Decoding
//
// Uses CoreGraphics/ImageIO to decode PNG, JPEG, GIF, BMP, and other image formats
// into PixelBuffer for terminal rendering.

import Foundation
import CoreGraphics
import ImageIO
import TUICore

// MARK: - Image Decoder

/// Decodes image data (PNG, JPEG, GIF, etc.) into PixelBuffer using CoreGraphics
public struct ImageDecoder: Sendable {

    /// Supported image formats
    public enum ImageFormat: String, Sendable {
        case png = "image/png"
        case jpeg = "image/jpeg"
        case gif = "image/gif"
        case bmp = "image/bmp"
        case webp = "image/webp"
        case tiff = "image/tiff"
        case unknown

        public init(mimeType: String) {
            switch mimeType.lowercased() {
            case "image/png":
                self = .png
            case "image/jpeg", "image/jpg":
                self = .jpeg
            case "image/gif":
                self = .gif
            case "image/bmp":
                self = .bmp
            case "image/webp":
                self = .webp
            case "image/tiff":
                self = .tiff
            default:
                self = .unknown
            }
        }

        public init(fileExtension: String) {
            switch fileExtension.lowercased() {
            case "png":
                self = .png
            case "jpg", "jpeg":
                self = .jpeg
            case "gif":
                self = .gif
            case "bmp":
                self = .bmp
            case "webp":
                self = .webp
            case "tiff", "tif":
                self = .tiff
            default:
                self = .unknown
            }
        }
    }

    /// Decoding errors
    public enum DecodingError: Error, Sendable {
        case invalidData
        case unsupportedFormat
        case failedToCreateImageSource
        case failedToCreateImage
        case failedToGetImageInfo
        case failedToCreateContext
        case failedToRenderImage
    }

    /// Decoded image info
    public struct ImageInfo: Sendable {
        public let width: Int
        public let height: Int
        public let hasAlpha: Bool
        public let colorSpace: String
        public let bitsPerComponent: Int
    }

    public init() {}

    // MARK: - Public API

    /// Decode image data into PixelBuffer
    /// - Parameter data: Raw image data (PNG, JPEG, GIF, etc.)
    /// - Returns: PixelBuffer if decoding succeeds, nil otherwise
    public func decode(_ data: Data) -> PixelBuffer? {
        do {
            return try decodeOrThrow(data)
        } catch {
            return nil
        }
    }

    /// Decode image data with detailed error information
    /// - Parameter data: Raw image data
    /// - Returns: PixelBuffer
    /// - Throws: DecodingError if decoding fails
    public func decodeOrThrow(_ data: Data) throws -> PixelBuffer {
        // Create image source from data
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw DecodingError.failedToCreateImageSource
        }

        // Get the first image (for animated GIFs, we only get the first frame)
        guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw DecodingError.failedToCreateImage
        }

        return try convertCGImageToPixelBuffer(cgImage)
    }

    /// Decode image from file URL
    /// - Parameter fileURL: URL to image file
    /// - Returns: PixelBuffer if decoding succeeds, nil otherwise
    public func decode(fileURL: URL) -> PixelBuffer? {
        do {
            return try decodeOrThrow(fileURL: fileURL)
        } catch {
            return nil
        }
    }

    /// Decode image from file URL with detailed error information
    /// - Parameter fileURL: URL to image file
    /// - Returns: PixelBuffer
    /// - Throws: DecodingError if decoding fails
    public func decodeOrThrow(fileURL: URL) throws -> PixelBuffer {
        guard let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else {
            throw DecodingError.failedToCreateImageSource
        }

        guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw DecodingError.failedToCreateImage
        }

        return try convertCGImageToPixelBuffer(cgImage)
    }

    /// Get image info without fully decoding
    /// - Parameter data: Raw image data
    /// - Returns: ImageInfo if available
    public func getImageInfo(_ data: Data) -> ImageInfo? {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }

        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] else {
            return nil
        }

        guard let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            return nil
        }

        let hasAlpha = (properties[kCGImagePropertyHasAlpha] as? Bool) ?? false
        let colorSpace = (properties[kCGImagePropertyColorModel] as? String) ?? "Unknown"
        let bitsPerComponent = (properties[kCGImagePropertyDepth] as? Int) ?? 8

        return ImageInfo(
            width: width,
            height: height,
            hasAlpha: hasAlpha,
            colorSpace: colorSpace,
            bitsPerComponent: bitsPerComponent
        )
    }

    /// Detect image format from data
    /// - Parameter data: Raw image data
    /// - Returns: Detected format
    public func detectFormat(_ data: Data) -> ImageFormat {
        guard data.count >= 4 else { return .unknown }

        let bytes = [UInt8](data.prefix(8))

        // PNG: 89 50 4E 47
        if bytes.count >= 4 && bytes[0] == 0x89 && bytes[1] == 0x50 &&
           bytes[2] == 0x4E && bytes[3] == 0x47 {
            return .png
        }

        // JPEG: FF D8 FF
        if bytes.count >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF {
            return .jpeg
        }

        // GIF: 47 49 46 38
        if bytes.count >= 4 && bytes[0] == 0x47 && bytes[1] == 0x49 &&
           bytes[2] == 0x46 && bytes[3] == 0x38 {
            return .gif
        }

        // BMP: 42 4D
        if bytes.count >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4D {
            return .bmp
        }

        // WebP: RIFF....WEBP
        if bytes.count >= 8 && bytes[0] == 0x52 && bytes[1] == 0x49 &&
           bytes[2] == 0x46 && bytes[3] == 0x46 {
            // Check for WEBP at offset 8
            if data.count >= 12 {
                let webpBytes = [UInt8](data[8..<12])
                if webpBytes[0] == 0x57 && webpBytes[1] == 0x45 &&
                   webpBytes[2] == 0x42 && webpBytes[3] == 0x50 {
                    return .webp
                }
            }
        }

        // TIFF: 49 49 2A 00 or 4D 4D 00 2A
        if bytes.count >= 4 {
            if (bytes[0] == 0x49 && bytes[1] == 0x49 && bytes[2] == 0x2A && bytes[3] == 0x00) ||
               (bytes[0] == 0x4D && bytes[1] == 0x4D && bytes[2] == 0x00 && bytes[3] == 0x2A) {
                return .tiff
            }
        }

        return .unknown
    }

    // MARK: - Private Helpers

    /// Convert CGImage to PixelBuffer
    private func convertCGImageToPixelBuffer(_ cgImage: CGImage) throws -> PixelBuffer {
        let width = cgImage.width
        let height = cgImage.height

        guard width > 0 && height > 0 else {
            throw DecodingError.failedToGetImageInfo
        }

        // Create RGBA context
        let bitsPerComponent = 8
        let bytesPerRow = width * 4
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            throw DecodingError.failedToCreateContext
        }

        // Draw image into context
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context.draw(cgImage, in: rect)

        // Get pixel data
        guard let data = context.data else {
            throw DecodingError.failedToRenderImage
        }

        // Convert to Color array
        let pixelData = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        var pixels: [Color] = []
        pixels.reserveCapacity(width * height)

        for i in 0..<(width * height) {
            let offset = i * 4
            let r = pixelData[offset]
            let g = pixelData[offset + 1]
            let b = pixelData[offset + 2]
            // Alpha is at offset + 3, but we ignore it for now

            // Handle premultiplied alpha
            let a = pixelData[offset + 3]
            if a > 0 && a < 255 {
                // Un-premultiply alpha
                let rUnpremult = UInt8(min(255, Int(r) * 255 / Int(a)))
                let gUnpremult = UInt8(min(255, Int(g) * 255 / Int(a)))
                let bUnpremult = UInt8(min(255, Int(b) * 255 / Int(a)))
                pixels.append(Color(r: rUnpremult, g: gUnpremult, b: bUnpremult))
            } else {
                pixels.append(Color(r: r, g: g, b: b))
            }
        }

        return PixelBuffer(width: width, height: height, pixels: pixels)
    }
}

// MARK: - Static Convenience Methods

extension ImageDecoder {

    /// Decode image data (static convenience method)
    public static func decode(_ data: Data) -> PixelBuffer? {
        ImageDecoder().decode(data)
    }

    /// Decode image from file URL (static convenience method)
    public static func decode(fileURL: URL) -> PixelBuffer? {
        ImageDecoder().decode(fileURL: fileURL)
    }

    /// Decode and scale image to fit within specified dimensions
    /// - Parameters:
    ///   - data: Raw image data
    ///   - maxWidth: Maximum width in terminal columns
    ///   - maxHeight: Maximum height in terminal rows
    ///   - blitMode: The blitting mode to use for pixel-to-cell ratio
    /// - Returns: Scaled PixelBuffer, or nil if decoding fails
    public static func decodeAndScale(
        _ data: Data,
        maxWidth: Int,
        maxHeight: Int,
        blitMode: BlitMode = .halfBlock
    ) -> PixelBuffer? {
        guard let original = decode(data) else {
            return nil
        }

        return scaleToFit(original, maxWidth: maxWidth, maxHeight: maxHeight, blitMode: blitMode)
    }

    /// Scale PixelBuffer to fit within terminal dimensions
    /// - Parameters:
    ///   - pixels: Original pixel buffer
    ///   - maxWidth: Maximum width in terminal columns
    ///   - maxHeight: Maximum height in terminal rows
    ///   - blitMode: The blitting mode for pixel-to-cell ratio calculation
    /// - Returns: Scaled PixelBuffer
    public static func scaleToFit(
        _ pixels: PixelBuffer,
        maxWidth: Int,
        maxHeight: Int,
        blitMode: BlitMode = .halfBlock
    ) -> PixelBuffer {
        // Get pixels per cell based on blit mode
        let (pixelsPerCellX, pixelsPerCellY) = pixelsPerCell(for: blitMode)

        // Target pixel dimensions
        let targetPixelWidth = maxWidth * pixelsPerCellX
        let targetPixelHeight = maxHeight * pixelsPerCellY

        // Calculate scale to fit while preserving aspect ratio
        let scaleX = Float(targetPixelWidth) / Float(pixels.width)
        let scaleY = Float(targetPixelHeight) / Float(pixels.height)
        let scale = min(scaleX, scaleY, 1.0) // Don't upscale

        let newWidth = max(1, Int(Float(pixels.width) * scale))
        let newHeight = max(1, Int(Float(pixels.height) * scale))

        // Use bilinear scaling for better quality
        let renderer = ImageRenderer()
        return renderer.scaleBilinear(pixels, toWidth: newWidth, toHeight: newHeight)
    }

    /// Get pixels per cell for a blitting mode
    private static func pixelsPerCell(for blitMode: BlitMode) -> (x: Int, y: Int) {
        switch blitMode {
        case .braille:
            return (2, 4)
        case .halfBlock:
            return (1, 2)
        case .quadrant:
            return (2, 2)
        case .ascii:
            return (1, 1)
        case .auto:
            return (1, 2) // Default to half-block
        }
    }
}
