// TUIRender - Terminal Image Rendering
//
// Implements terminal image rendering techniques based on notcurses, chafa, and dotmatrix.
// Supports braille patterns, half-block characters, dithering, and color quantization.

import TUICore
import TUITerminal
import Darwin

// MARK: - Pixel Buffer

/// Raw pixel data for image processing
public struct PixelBuffer: Sendable {
    public let width: Int
    public let height: Int
    public var pixels: [Color]

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.pixels = Array(repeating: .black, count: width * height)
    }

    public init(width: Int, height: Int, pixels: [Color]) {
        precondition(pixels.count == width * height, "Pixel count must match dimensions")
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    public subscript(x: Int, y: Int) -> Color {
        get {
            guard x >= 0, x < width, y >= 0, y < height else { return .black }
            return pixels[y * width + x]
        }
        set {
            guard x >= 0, x < width, y >= 0, y < height else { return }
            pixels[y * width + x] = newValue
        }
    }

    /// Get grayscale value at position (0-255)
    public func grayscale(x: Int, y: Int) -> UInt8 {
        let color = self[x, y]
        let gray = (Int(color.r) + Int(color.g) + Int(color.b)) / 3
        return UInt8(gray)
    }

    /// Create a grayscale copy of the buffer
    public func toGrayscale() -> PixelBuffer {
        var result = PixelBuffer(width: width, height: height)
        for y in 0..<height {
            for x in 0..<width {
                let gray = grayscale(x: x, y: y)
                result[x, y] = Color(r: gray, g: gray, b: gray)
            }
        }
        return result
    }
}

// MARK: - Rendered Cell

/// A single rendered cell with character and colors
public struct RenderedCell: Sendable, Equatable {
    public let character: Character
    public let foreground: Color
    public let background: Color

    public init(character: Character, foreground: Color, background: Color) {
        self.character = character
        self.foreground = foreground
        self.background = background
    }
}

// MARK: - Blit Result

/// Result of blitting an image region
public struct BlitResult: Sendable {
    public let cells: [[RenderedCell]]
    public let width: Int   // in cells
    public let height: Int  // in cells

    public init(cells: [[RenderedCell]], width: Int, height: Int) {
        self.cells = cells
        self.width = width
        self.height = height
    }

    /// Convert to ANSI string for terminal output
    public func toANSIString(colorSupport: ColorSupport = .trueColor) -> String {
        var result = ""
        for row in cells {
            for cell in row {
                result += formatCell(cell, colorSupport: colorSupport)
            }
            result += ANSICode.reset + "\n"
        }
        return result
    }

    private func formatCell(_ cell: RenderedCell, colorSupport: ColorSupport) -> String {
        var codes: [String] = []

        switch colorSupport {
        case .trueColor:
            codes.append(ANSICode.foregroundRGB(cell.foreground.r, cell.foreground.g, cell.foreground.b))
            codes.append(ANSICode.backgroundRGB(cell.background.r, cell.background.g, cell.background.b))
        case .ansi256:
            let fg = ColorConverter.toANSI256(cell.foreground)
            let bg = ColorConverter.toANSI256(cell.background)
            codes.append(ANSICode.foreground256(fg))
            codes.append(ANSICode.background256(bg))
        case .ansi16:
            let fg = ColorConverter.toANSI16(cell.foreground)
            let bg = ColorConverter.toANSI16(cell.background)
            codes.append(ANSICode.foreground(fg))
            codes.append(ANSICode.background(bg))
        case .none:
            break
        }

        return codes.joined() + String(cell.character)
    }
}

// MARK: - Blitter Protocol

/// Protocol for image-to-character blitters
public protocol Blitter: Sendable {
    /// Pixels consumed per cell horizontally
    var pixelsPerCellX: Int { get }

    /// Pixels consumed per cell vertically
    var pixelsPerCellY: Int { get }

    /// Convert pixel buffer to rendered cells
    func blit(_ pixels: PixelBuffer) -> BlitResult
}

// MARK: - Braille Blitter

/// Renders images using braille patterns (U+2800-U+28FF)
/// Each character represents 8 pixels in a 2x4 grid
public struct BrailleBlitter: Blitter {
    public let pixelsPerCellX = 2
    public let pixelsPerCellY = 4

    /// Threshold for considering a pixel "on" (0-255)
    public var threshold: UInt8

    /// Foreground color for braille dots
    public var foregroundColor: Color

    /// Background color
    public var backgroundColor: Color

    public init(
        threshold: UInt8 = 128,
        foregroundColor: Color = .white,
        backgroundColor: Color = .black
    ) {
        self.threshold = threshold
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
    }

    public func blit(_ pixels: PixelBuffer) -> BlitResult {
        let cellsW = max(1, pixels.width / pixelsPerCellX)
        let cellsH = max(1, pixels.height / pixelsPerCellY)

        var cells: [[RenderedCell]] = []

        for cy in 0..<cellsH {
            var row: [RenderedCell] = []
            for cx in 0..<cellsW {
                let px = cx * 2
                let py = cy * 4

                // Calculate braille codepoint
                // Dot positions and their bit values:
                // [1][4]  -> 0x01, 0x08
                // [2][5]  -> 0x02, 0x10
                // [3][6]  -> 0x04, 0x20
                // [7][8]  -> 0x40, 0x80
                var codepoint: UInt32 = 0x2800

                if isPixelOn(pixels, x: px, y: py)     { codepoint |= 0x01 }
                if isPixelOn(pixels, x: px, y: py + 1) { codepoint |= 0x02 }
                if isPixelOn(pixels, x: px, y: py + 2) { codepoint |= 0x04 }
                if isPixelOn(pixels, x: px, y: py + 3) { codepoint |= 0x40 }
                if isPixelOn(pixels, x: px + 1, y: py)     { codepoint |= 0x08 }
                if isPixelOn(pixels, x: px + 1, y: py + 1) { codepoint |= 0x10 }
                if isPixelOn(pixels, x: px + 1, y: py + 2) { codepoint |= 0x20 }
                if isPixelOn(pixels, x: px + 1, y: py + 3) { codepoint |= 0x80 }

                let char = Character(UnicodeScalar(codepoint)!)
                row.append(RenderedCell(
                    character: char,
                    foreground: foregroundColor,
                    background: backgroundColor
                ))
            }
            cells.append(row)
        }

        return BlitResult(cells: cells, width: cellsW, height: cellsH)
    }

    /// Convert 2x4 pixel block to braille character
    public static func pixelsTobraille(
        _ p: [[Bool]]
    ) -> Character {
        precondition(p.count >= 4 && p[0].count >= 2, "Need 2x4 pixel block")

        var codepoint: UInt32 = 0x2800

        if p[0][0] { codepoint |= 0x01 }  // dot 1
        if p[1][0] { codepoint |= 0x02 }  // dot 2
        if p[2][0] { codepoint |= 0x04 }  // dot 3
        if p[3][0] { codepoint |= 0x40 }  // dot 7
        if p[0][1] { codepoint |= 0x08 }  // dot 4
        if p[1][1] { codepoint |= 0x10 }  // dot 5
        if p[2][1] { codepoint |= 0x20 }  // dot 6
        if p[3][1] { codepoint |= 0x80 }  // dot 8

        return Character(UnicodeScalar(codepoint)!)
    }

    /// Convert bit pattern to braille character
    /// Bits are ordered: [0]=dot1, [1]=dot2, ..., [7]=dot8
    public static func bitsTobraille(_ bits: UInt8) -> Character {
        // Reorder bits from sequential to braille encoding
        var codepoint: UInt32 = 0x2800
        if bits & 0x01 != 0 { codepoint |= 0x01 }  // dot 1
        if bits & 0x02 != 0 { codepoint |= 0x02 }  // dot 2
        if bits & 0x04 != 0 { codepoint |= 0x04 }  // dot 3
        if bits & 0x08 != 0 { codepoint |= 0x40 }  // dot 7
        if bits & 0x10 != 0 { codepoint |= 0x08 }  // dot 4
        if bits & 0x20 != 0 { codepoint |= 0x10 }  // dot 5
        if bits & 0x40 != 0 { codepoint |= 0x20 }  // dot 6
        if bits & 0x80 != 0 { codepoint |= 0x80 }  // dot 8
        return Character(UnicodeScalar(codepoint)!)
    }

    private func isPixelOn(_ pixels: PixelBuffer, x: Int, y: Int) -> Bool {
        guard x >= 0, x < pixels.width, y >= 0, y < pixels.height else { return false }
        let color = pixels[x, y]
        let gray = (Int(color.r) + Int(color.g) + Int(color.b)) / 3
        return gray >= Int(threshold)
    }
}

// MARK: - Half Block Blitter

/// Renders images using half-block characters with foreground/background colors
/// Each character represents 2 vertical pixels
public struct HalfBlockBlitter: Blitter {
    public let pixelsPerCellX = 1
    public let pixelsPerCellY = 2

    /// Upper half block character
    public static let upperHalf: Character = "\u{2580}"  // upper half block

    /// Lower half block character
    public static let lowerHalf: Character = "\u{2584}"  // lower half block

    /// Full block character
    public static let fullBlock: Character = "\u{2588}"  // full block

    /// Color tolerance for considering two colors equal
    public var colorTolerance: Int

    public init(colorTolerance: Int = 8) {
        self.colorTolerance = colorTolerance
    }

    public func blit(_ pixels: PixelBuffer) -> BlitResult {
        let cellsW = pixels.width / pixelsPerCellX
        let cellsH = max(1, pixels.height / pixelsPerCellY)

        var cells: [[RenderedCell]] = []

        for cy in 0..<cellsH {
            var row: [RenderedCell] = []
            for cx in 0..<cellsW {
                let topColor = pixels[cx, cy * 2]
                let botColor = pixels[cx, cy * 2 + 1]

                let cell: RenderedCell
                if colorsEqual(topColor, botColor) {
                    // Solid color - use space with background
                    cell = RenderedCell(
                        character: " ",
                        foreground: topColor,
                        background: topColor
                    )
                } else {
                    // Different colors - use upper half block
                    // FG = top color, BG = bottom color
                    cell = RenderedCell(
                        character: Self.upperHalf,
                        foreground: topColor,
                        background: botColor
                    )
                }
                row.append(cell)
            }
            cells.append(row)
        }

        return BlitResult(cells: cells, width: cellsW, height: cellsH)
    }

    private func colorsEqual(_ a: Color, _ b: Color) -> Bool {
        return abs(Int(a.r) - Int(b.r)) < colorTolerance &&
               abs(Int(a.g) - Int(b.g)) < colorTolerance &&
               abs(Int(a.b) - Int(b.b)) < colorTolerance
    }
}

// MARK: - Quadrant Blitter

/// Renders images using quadrant characters for 2x2 pixel resolution
public struct QuadrantBlitter: Blitter {
    public let pixelsPerCellX = 2
    public let pixelsPerCellY = 2

    /// Quadrant characters indexed by pattern
    /// Pattern bits: [top-left, top-right, bottom-left, bottom-right]
    private static let quadrantChars: [Character] = [
        " ",       // 0b0000 - empty
        "\u{2598}", // 0b0001 - top-left
        "\u{259D}", // 0b0010 - top-right
        "\u{2580}", // 0b0011 - top half
        "\u{2596}", // 0b0100 - bottom-left
        "\u{258C}", // 0b0101 - left half
        "\u{259E}", // 0b0110 - diagonal (top-right + bottom-left)
        "\u{259B}", // 0b0111 - all except bottom-right
        "\u{2597}", // 0b1000 - bottom-right
        "\u{259A}", // 0b1001 - diagonal (top-left + bottom-right)
        "\u{2590}", // 0b1010 - right half
        "\u{259C}", // 0b1011 - all except bottom-left
        "\u{2584}", // 0b1100 - bottom half
        "\u{2599}", // 0b1101 - all except top-right
        "\u{259F}", // 0b1110 - all except top-left
        "\u{2588}"  // 0b1111 - full block
    ]

    public var threshold: UInt8
    public var foregroundColor: Color
    public var backgroundColor: Color

    public init(
        threshold: UInt8 = 128,
        foregroundColor: Color = .white,
        backgroundColor: Color = .black
    ) {
        self.threshold = threshold
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
    }

    public func blit(_ pixels: PixelBuffer) -> BlitResult {
        let cellsW = max(1, pixels.width / pixelsPerCellX)
        let cellsH = max(1, pixels.height / pixelsPerCellY)

        var cells: [[RenderedCell]] = []

        for cy in 0..<cellsH {
            var row: [RenderedCell] = []
            for cx in 0..<cellsW {
                let px = cx * 2
                let py = cy * 2

                // Calculate quadrant pattern
                var pattern = 0
                if isPixelOn(pixels, x: px, y: py)         { pattern |= 0b0001 }  // top-left
                if isPixelOn(pixels, x: px + 1, y: py)     { pattern |= 0b0010 }  // top-right
                if isPixelOn(pixels, x: px, y: py + 1)     { pattern |= 0b0100 }  // bottom-left
                if isPixelOn(pixels, x: px + 1, y: py + 1) { pattern |= 0b1000 }  // bottom-right

                let char = Self.quadrantChars[pattern]
                row.append(RenderedCell(
                    character: char,
                    foreground: foregroundColor,
                    background: backgroundColor
                ))
            }
            cells.append(row)
        }

        return BlitResult(cells: cells, width: cellsW, height: cellsH)
    }

    private func isPixelOn(_ pixels: PixelBuffer, x: Int, y: Int) -> Bool {
        guard x >= 0, x < pixels.width, y >= 0, y < pixels.height else { return false }
        let color = pixels[x, y]
        let gray = (Int(color.r) + Int(color.g) + Int(color.b)) / 3
        return gray >= Int(threshold)
    }
}

// MARK: - ASCII Blitter

/// Simple ASCII art rendering using brightness characters
public struct AsciiBlitter: Blitter {
    public let pixelsPerCellX = 1
    public let pixelsPerCellY = 1

    /// Characters from darkest to brightest
    public var charset: String

    public init(charset: String = " .:-=+*#%@") {
        self.charset = charset
    }

    public func blit(_ pixels: PixelBuffer) -> BlitResult {
        let chars = Array(charset)
        guard !chars.isEmpty else {
            return BlitResult(cells: [], width: 0, height: 0)
        }

        var cells: [[RenderedCell]] = []

        for y in 0..<pixels.height {
            var row: [RenderedCell] = []
            for x in 0..<pixels.width {
                let color = pixels[x, y]
                let gray = (Int(color.r) + Int(color.g) + Int(color.b)) / 3
                let charIndex = gray * (chars.count - 1) / 255
                let char = chars[charIndex]

                row.append(RenderedCell(
                    character: char,
                    foreground: color,
                    background: .black
                ))
            }
            cells.append(row)
        }

        return BlitResult(cells: cells, width: pixels.width, height: pixels.height)
    }
}

// MARK: - Floyd-Steinberg Ditherer

/// Implements Floyd-Steinberg error diffusion dithering
public struct FloydSteinbergDitherer: Sendable {
    /// The target palette to quantize to
    public let palette: [Color]

    /// Enable serpentine (bidirectional) scanning
    public var serpentine: Bool

    public init(palette: [Color], serpentine: Bool = true) {
        self.palette = palette
        self.serpentine = serpentine
    }

    /// Create ditherer for monochrome output
    public static var monochrome: FloydSteinbergDitherer {
        FloydSteinbergDitherer(palette: [.black, .white])
    }

    /// Apply Floyd-Steinberg dithering to pixel buffer in place
    public func dither(_ pixels: inout PixelBuffer) {
        guard !palette.isEmpty else { return }

        // Use floating point buffer for error accumulation
        var floatPixels = pixels.pixels.map { FloatColor(color: $0) }

        for y in 0..<pixels.height {
            let leftToRight = !serpentine || (y % 2 == 0)
            let xRange: [Int] = leftToRight ?
                Array(0..<pixels.width) :
                Array((0..<pixels.width).reversed())

            for x in xRange {
                let index = y * pixels.width + x
                let oldPixel = floatPixels[index]
                let newPixel = findClosestColor(oldPixel)
                floatPixels[index] = newPixel

                let errorR = oldPixel.r - newPixel.r
                let errorG = oldPixel.g - newPixel.g
                let errorB = oldPixel.b - newPixel.b

                // Distribute error to neighbors
                // Pattern:       *    7/16
                //         3/16  5/16  1/16
                let xDir = leftToRight ? 1 : -1

                distributeError(&floatPixels, pixels: pixels,
                              x: x + xDir, y: y,
                              errorR: errorR, errorG: errorG, errorB: errorB,
                              factor: 7.0 / 16.0)
                distributeError(&floatPixels, pixels: pixels,
                              x: x - xDir, y: y + 1,
                              errorR: errorR, errorG: errorG, errorB: errorB,
                              factor: 3.0 / 16.0)
                distributeError(&floatPixels, pixels: pixels,
                              x: x, y: y + 1,
                              errorR: errorR, errorG: errorG, errorB: errorB,
                              factor: 5.0 / 16.0)
                distributeError(&floatPixels, pixels: pixels,
                              x: x + xDir, y: y + 1,
                              errorR: errorR, errorG: errorG, errorB: errorB,
                              factor: 1.0 / 16.0)
            }
        }

        // Convert back to Color
        for i in 0..<pixels.pixels.count {
            pixels.pixels[i] = floatPixels[i].toColor()
        }
    }

    /// Create a dithered copy of the pixel buffer
    public func dithered(_ pixels: PixelBuffer) -> PixelBuffer {
        var copy = pixels
        dither(&copy)
        return copy
    }

    private func distributeError(
        _ floatPixels: inout [FloatColor],
        pixels: PixelBuffer,
        x: Int, y: Int,
        errorR: Float, errorG: Float, errorB: Float,
        factor: Float
    ) {
        guard x >= 0, x < pixels.width, y >= 0, y < pixels.height else { return }

        let index = y * pixels.width + x
        floatPixels[index].r += errorR * factor
        floatPixels[index].g += errorG * factor
        floatPixels[index].b += errorB * factor
    }

    private func findClosestColor(_ color: FloatColor) -> FloatColor {
        var minDist = Float.infinity
        var closest = FloatColor(color: palette[0])

        for paletteColor in palette {
            let pc = FloatColor(color: paletteColor)
            let dist = colorDistance(color, pc)
            if dist < minDist {
                minDist = dist
                closest = pc
            }
        }

        return closest
    }

    /// Weighted Euclidean distance (Redmean formula) for perceptual accuracy
    private func colorDistance(_ a: FloatColor, _ b: FloatColor) -> Float {
        let rMean = (a.r + b.r) / 2.0
        let dR = a.r - b.r
        let dG = a.g - b.g
        let dB = a.b - b.b

        let rWeight = 2.0 + rMean / 256.0
        let gWeight: Float = 4.0
        let bWeight = 2.0 + (255.0 - rMean) / 256.0

        return sqrt(rWeight * dR * dR + gWeight * dG * dG + bWeight * dB * dB)
    }
}

/// Floating point color for error accumulation
private struct FloatColor: Sendable {
    var r: Float
    var g: Float
    var b: Float

    init(r: Float, g: Float, b: Float) {
        self.r = r
        self.g = g
        self.b = b
    }

    init(color: Color) {
        self.r = Float(color.r)
        self.g = Float(color.g)
        self.b = Float(color.b)
    }

    func toColor() -> Color {
        Color(
            r: UInt8(clamping: Int(r.rounded())),
            g: UInt8(clamping: Int(g.rounded())),
            b: UInt8(clamping: Int(b.rounded()))
        )
    }
}

// MARK: - Ordered Ditherer

/// Implements ordered (Bayer) dithering using threshold matrices
public struct OrderedDitherer: Sendable {
    /// The Bayer matrix for threshold values
    private let matrix: [[Float]]
    private let matrixSize: Int

    /// Target palette
    public let palette: [Color]

    public init(size: Int, palette: [Color]) {
        self.matrixSize = max(2, size)
        self.palette = palette
        self.matrix = Self.generateBayerMatrix(size: matrixSize)
    }

    /// 2x2 Bayer matrix
    public static let bayer2x2: [[Float]] = [
        [0.0 / 4.0, 2.0 / 4.0],
        [3.0 / 4.0, 1.0 / 4.0]
    ]

    /// 4x4 Bayer matrix
    public static let bayer4x4: [[Float]] = [
        [ 0.0/16,  8.0/16,  2.0/16, 10.0/16],
        [12.0/16,  4.0/16, 14.0/16,  6.0/16],
        [ 3.0/16, 11.0/16,  1.0/16,  9.0/16],
        [15.0/16,  7.0/16, 13.0/16,  5.0/16]
    ]

    /// 8x8 Bayer matrix
    public static let bayer8x8: [[Float]] = {
        var m = Array(repeating: Array(repeating: Float(0), count: 8), count: 8)
        let values: [[Int]] = [
            [ 0, 32,  8, 40,  2, 34, 10, 42],
            [48, 16, 56, 24, 50, 18, 58, 26],
            [12, 44,  4, 36, 14, 46,  6, 38],
            [60, 28, 52, 20, 62, 30, 54, 22],
            [ 3, 35, 11, 43,  1, 33,  9, 41],
            [51, 19, 59, 27, 49, 17, 57, 25],
            [15, 47,  7, 39, 13, 45,  5, 37],
            [63, 31, 55, 23, 61, 29, 53, 21]
        ]
        for y in 0..<8 {
            for x in 0..<8 {
                m[y][x] = Float(values[y][x]) / 64.0
            }
        }
        return m
    }()

    /// Generate Bayer matrix of given size (must be power of 2)
    public static func generateBayerMatrix(size: Int) -> [[Float]] {
        guard size >= 2 else {
            return [[0]]
        }

        if size == 2 {
            return bayer2x2
        }

        if size == 4 {
            return bayer4x4
        }

        if size == 8 {
            return bayer8x8
        }

        // Recursive generation for larger sizes
        let half = size / 2
        let smaller = generateBayerMatrix(size: half)
        var result = Array(repeating: Array(repeating: Float(0), count: size), count: size)
        let scale = Float(size * size)

        for y in 0..<size {
            for x in 0..<size {
                let baseValue = smaller[y % half][x % half] * 4.0 * Float(half * half)
                let offset: Float
                if y < half && x < half { offset = 0 }
                else if y < half && x >= half { offset = 2 }
                else if y >= half && x < half { offset = 3 }
                else { offset = 1 }

                result[y][x] = (baseValue + offset) / scale
            }
        }

        return result
    }

    /// Apply ordered dithering to pixel buffer in place
    public func dither(_ pixels: inout PixelBuffer) {
        guard !palette.isEmpty else { return }

        for y in 0..<pixels.height {
            for x in 0..<pixels.width {
                let threshold = matrix[y % matrixSize][x % matrixSize]
                let color = pixels[x, y]

                // Apply threshold-based dithering per channel
                let newR = applyThreshold(value: color.r, threshold: threshold)
                let newG = applyThreshold(value: color.g, threshold: threshold)
                let newB = applyThreshold(value: color.b, threshold: threshold)

                let newColor = Color(r: newR, g: newG, b: newB)
                pixels[x, y] = findClosestColor(newColor)
            }
        }
    }

    /// Create a dithered copy of the pixel buffer
    public func dithered(_ pixels: PixelBuffer) -> PixelBuffer {
        var copy = pixels
        dither(&copy)
        return copy
    }

    private func applyThreshold(value: UInt8, threshold: Float) -> UInt8 {
        let normalized = Float(value) / 255.0
        let adjusted = normalized + (threshold - 0.5) * 0.5
        return adjusted > 0.5 ? 255 : 0
    }

    private func findClosestColor(_ color: Color) -> Color {
        var minDist = Float.infinity
        var closest = palette[0]

        for paletteColor in palette {
            let dR = Float(color.r) - Float(paletteColor.r)
            let dG = Float(color.g) - Float(paletteColor.g)
            let dB = Float(color.b) - Float(paletteColor.b)
            let dist = dR * dR + dG * dG + dB * dB

            if dist < minDist {
                minDist = dist
                closest = paletteColor
            }
        }

        return closest
    }
}

// MARK: - Color Quantizer

/// Utilities for color quantization to terminal palettes
public struct ColorQuantizer: Sendable {

    /// Convert RGB to ANSI 256 color index
    /// Formula: index = 16 + 36*r + 6*g + b (where r,g,b are 0-5)
    public static func rgbToANSI256(r: UInt8, g: UInt8, b: UInt8) -> UInt8 {
        // Use the existing ColorConverter
        return ColorConverter.toANSI256(Color(r: r, g: g, b: b))
    }

    /// Convert ANSI 256 color index to RGB
    public static func ansi256ToRGB(_ index: UInt8) -> Color {
        if index < 16 {
            // System colors (terminal-dependent, using standard values)
            let systemColors: [Color] = [
                Color(r: 0, g: 0, b: 0),       // 0: Black
                Color(r: 128, g: 0, b: 0),     // 1: Red
                Color(r: 0, g: 128, b: 0),     // 2: Green
                Color(r: 128, g: 128, b: 0),   // 3: Yellow
                Color(r: 0, g: 0, b: 128),     // 4: Blue
                Color(r: 128, g: 0, b: 128),   // 5: Magenta
                Color(r: 0, g: 128, b: 128),   // 6: Cyan
                Color(r: 192, g: 192, b: 192), // 7: White
                Color(r: 128, g: 128, b: 128), // 8: Bright Black
                Color(r: 255, g: 0, b: 0),     // 9: Bright Red
                Color(r: 0, g: 255, b: 0),     // 10: Bright Green
                Color(r: 255, g: 255, b: 0),   // 11: Bright Yellow
                Color(r: 0, g: 0, b: 255),     // 12: Bright Blue
                Color(r: 255, g: 0, b: 255),   // 13: Bright Magenta
                Color(r: 0, g: 255, b: 255),   // 14: Bright Cyan
                Color(r: 255, g: 255, b: 255)  // 15: Bright White
            ]
            return systemColors[Int(index)]
        } else if index < 232 {
            // 6x6x6 color cube (16-231)
            let cubeIndex = Int(index) - 16
            let levels: [UInt8] = [0, 95, 135, 175, 215, 255]
            let r = levels[(cubeIndex / 36) % 6]
            let g = levels[(cubeIndex / 6) % 6]
            let b = levels[cubeIndex % 6]
            return Color(r: r, g: g, b: b)
        } else {
            // Grayscale ramp (232-255)
            let gray = UInt8(8 + (Int(index) - 232) * 10)
            return Color(r: gray, g: gray, b: gray)
        }
    }

    /// Build ANSI 16 color palette
    public static func palette16() -> [Color] {
        [
            Color(r: 0, g: 0, b: 0),       // Black
            Color(r: 128, g: 0, b: 0),     // Red
            Color(r: 0, g: 128, b: 0),     // Green
            Color(r: 128, g: 128, b: 0),   // Yellow
            Color(r: 0, g: 0, b: 128),     // Blue
            Color(r: 128, g: 0, b: 128),   // Magenta
            Color(r: 0, g: 128, b: 128),   // Cyan
            Color(r: 192, g: 192, b: 192), // White
            Color(r: 128, g: 128, b: 128), // Bright Black
            Color(r: 255, g: 0, b: 0),     // Bright Red
            Color(r: 0, g: 255, b: 0),     // Bright Green
            Color(r: 255, g: 255, b: 0),   // Bright Yellow
            Color(r: 0, g: 0, b: 255),     // Bright Blue
            Color(r: 255, g: 0, b: 255),   // Bright Magenta
            Color(r: 0, g: 255, b: 255),   // Bright Cyan
            Color(r: 255, g: 255, b: 255)  // Bright White
        ]
    }

    /// Build ANSI 256 color palette
    public static func palette256() -> [Color] {
        var palette: [Color] = []

        // Add all 256 colors
        for i: UInt8 in 0..<255 {
            palette.append(ansi256ToRGB(i))
        }
        palette.append(ansi256ToRGB(255))

        return palette
    }

    /// Build grayscale palette with specified number of levels
    public static func grayscalePalette(levels: Int) -> [Color] {
        var palette: [Color] = []
        for i in 0..<levels {
            let gray = UInt8(i * 255 / max(1, levels - 1))
            palette.append(Color(r: gray, g: gray, b: gray))
        }
        return palette
    }

    /// Find nearest color in palette using weighted RGB distance
    public static func findNearest(_ color: Color, in palette: [Color]) -> Color {
        guard !palette.isEmpty else { return color }

        var minDist = Float.infinity
        var closest = palette[0]

        for paletteColor in palette {
            let dist = colorDistance(color, paletteColor)
            if dist < minDist {
                minDist = dist
                closest = paletteColor
            }
        }

        return closest
    }

    /// Weighted Euclidean distance (Redmean formula) for perceptual accuracy
    public static func colorDistance(_ a: Color, _ b: Color) -> Float {
        let rMean = (Float(a.r) + Float(b.r)) / 2.0
        let dR = Float(a.r) - Float(b.r)
        let dG = Float(a.g) - Float(b.g)
        let dB = Float(a.b) - Float(b.b)

        let rWeight = 2.0 + rMean / 256.0
        let gWeight: Float = 4.0
        let bWeight = 2.0 + (255.0 - rMean) / 256.0

        return sqrt(rWeight * dR * dR + gWeight * dG * dG + bWeight * dB * dB)
    }
}

// MARK: - Render Options

/// Blitting mode for image rendering
public enum BlitMode: Sendable, Equatable {
    case auto           // Best available
    case ascii          // 1x1, brightness characters
    case halfBlock      // 2x1, upper/lower half blocks
    case quadrant       // 2x2, quadrant characters
    case braille        // 4x2, braille patterns
}

/// Dithering algorithm selection
public enum DitheringMode: Sendable, Equatable {
    case none
    case ordered(size: Int)  // 2, 4, or 8
    case floydSteinberg
}

/// Configuration for image rendering
public struct ImageRenderOptions: Sendable {
    /// Target width in terminal columns (nil = use image width)
    public var targetWidth: Int?

    /// Target height in terminal rows (nil = use image height)
    public var targetHeight: Int?

    /// Rendering mode
    public var blitMode: BlitMode

    /// Dithering algorithm
    public var dithering: DitheringMode

    /// Color support level
    public var colorSupport: ColorSupport

    /// Preserve aspect ratio when scaling
    public var preserveAspectRatio: Bool

    /// Threshold for binary rendering (braille, quadrant)
    public var threshold: UInt8

    /// Foreground color for monochrome modes
    public var foregroundColor: Color

    /// Background color
    public var backgroundColor: Color

    public init(
        targetWidth: Int? = nil,
        targetHeight: Int? = nil,
        blitMode: BlitMode = .auto,
        dithering: DitheringMode = .floydSteinberg,
        colorSupport: ColorSupport = .trueColor,
        preserveAspectRatio: Bool = true,
        threshold: UInt8 = 128,
        foregroundColor: Color = .white,
        backgroundColor: Color = .black
    ) {
        self.targetWidth = targetWidth
        self.targetHeight = targetHeight
        self.blitMode = blitMode
        self.dithering = dithering
        self.colorSupport = colorSupport
        self.preserveAspectRatio = preserveAspectRatio
        self.threshold = threshold
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
    }
}

// MARK: - Image Renderer

/// Main image renderer that combines blitting, dithering, and color quantization
public struct ImageRenderer: Sendable {

    public var options: ImageRenderOptions

    public init(options: ImageRenderOptions = ImageRenderOptions()) {
        self.options = options
    }

    /// Render pixel buffer to terminal cells
    public func render(_ pixels: PixelBuffer) -> BlitResult {
        var workingPixels = pixels

        // 1. Apply dithering if configured
        switch options.dithering {
        case .none:
            break
        case .floydSteinberg:
            let palette = buildPalette()
            if !palette.isEmpty {
                let ditherer = FloydSteinbergDitherer(palette: palette)
                ditherer.dither(&workingPixels)
            }
        case .ordered(let size):
            let palette = buildPalette()
            if !palette.isEmpty {
                let ditherer = OrderedDitherer(size: size, palette: palette)
                ditherer.dither(&workingPixels)
            }
        }

        // 2. Select and apply blitter
        let blitter = selectBlitter()
        return blitter.blit(workingPixels)
    }

    /// Render to ANSI string directly
    public func renderToString(_ pixels: PixelBuffer) -> String {
        let result = render(pixels)
        return result.toANSIString(colorSupport: options.colorSupport)
    }

    /// Render grayscale image with braille
    public func renderGrayscaleBraille(_ pixels: PixelBuffer) -> BlitResult {
        var workingPixels = pixels.toGrayscale()

        // Apply dithering for better quality
        if case .floydSteinberg = options.dithering {
            let ditherer = FloydSteinbergDitherer.monochrome
            ditherer.dither(&workingPixels)
        } else if case .ordered(let size) = options.dithering {
            let ditherer = OrderedDitherer(size: size, palette: [.black, .white])
            ditherer.dither(&workingPixels)
        }

        let blitter = BrailleBlitter(
            threshold: options.threshold,
            foregroundColor: options.foregroundColor,
            backgroundColor: options.backgroundColor
        )
        return blitter.blit(workingPixels)
    }

    /// Render color image with half-blocks
    public func renderColorHalfBlock(_ pixels: PixelBuffer) -> BlitResult {
        var workingPixels = pixels

        // Apply dithering if using limited palette
        if options.colorSupport != .trueColor {
            let palette = buildPalette()
            if !palette.isEmpty {
                switch options.dithering {
                case .floydSteinberg:
                    let ditherer = FloydSteinbergDitherer(palette: palette)
                    ditherer.dither(&workingPixels)
                case .ordered(let size):
                    let ditherer = OrderedDitherer(size: size, palette: palette)
                    ditherer.dither(&workingPixels)
                case .none:
                    break
                }
            }
        }

        let blitter = HalfBlockBlitter()
        return blitter.blit(workingPixels)
    }

    /// Scale pixel buffer to target dimensions
    public func scale(_ pixels: PixelBuffer, toWidth width: Int, toHeight height: Int) -> PixelBuffer {
        guard width > 0 && height > 0 else {
            return PixelBuffer(width: 1, height: 1)
        }

        var result = PixelBuffer(width: width, height: height)

        let scaleX = Float(pixels.width) / Float(width)
        let scaleY = Float(pixels.height) / Float(height)

        for y in 0..<height {
            for x in 0..<width {
                // Nearest neighbor sampling
                let srcX = Int(Float(x) * scaleX)
                let srcY = Int(Float(y) * scaleY)
                result[x, y] = pixels[min(srcX, pixels.width - 1), min(srcY, pixels.height - 1)]
            }
        }

        return result
    }

    /// Scale pixel buffer with bilinear interpolation
    public func scaleBilinear(_ pixels: PixelBuffer, toWidth width: Int, toHeight height: Int) -> PixelBuffer {
        guard width > 0 && height > 0 else {
            return PixelBuffer(width: 1, height: 1)
        }

        var result = PixelBuffer(width: width, height: height)

        let scaleX = Float(pixels.width - 1) / Float(max(1, width - 1))
        let scaleY = Float(pixels.height - 1) / Float(max(1, height - 1))

        for y in 0..<height {
            for x in 0..<width {
                let srcX = Float(x) * scaleX
                let srcY = Float(y) * scaleY

                let x0 = Int(srcX)
                let y0 = Int(srcY)
                let x1 = min(x0 + 1, pixels.width - 1)
                let y1 = min(y0 + 1, pixels.height - 1)

                let xFrac = srcX - Float(x0)
                let yFrac = srcY - Float(y0)

                let c00 = pixels[x0, y0]
                let c10 = pixels[x1, y0]
                let c01 = pixels[x0, y1]
                let c11 = pixels[x1, y1]

                // Bilinear interpolation
                let r = interpolate(
                    Float(c00.r), Float(c10.r), Float(c01.r), Float(c11.r),
                    xFrac, yFrac
                )
                let g = interpolate(
                    Float(c00.g), Float(c10.g), Float(c01.g), Float(c11.g),
                    xFrac, yFrac
                )
                let b = interpolate(
                    Float(c00.b), Float(c10.b), Float(c01.b), Float(c11.b),
                    xFrac, yFrac
                )

                result[x, y] = Color(
                    r: UInt8(clamping: Int(r.rounded())),
                    g: UInt8(clamping: Int(g.rounded())),
                    b: UInt8(clamping: Int(b.rounded()))
                )
            }
        }

        return result
    }

    private func interpolate(_ c00: Float, _ c10: Float, _ c01: Float, _ c11: Float,
                            _ xFrac: Float, _ yFrac: Float) -> Float {
        let top = c00 * (1 - xFrac) + c10 * xFrac
        let bottom = c01 * (1 - xFrac) + c11 * xFrac
        return top * (1 - yFrac) + bottom * yFrac
    }

    /// Select appropriate blitter based on options
    private func selectBlitter() -> any Blitter {
        switch options.blitMode {
        case .braille:
            return BrailleBlitter(
                threshold: options.threshold,
                foregroundColor: options.foregroundColor,
                backgroundColor: options.backgroundColor
            )
        case .halfBlock:
            return HalfBlockBlitter()
        case .quadrant:
            return QuadrantBlitter(
                threshold: options.threshold,
                foregroundColor: options.foregroundColor,
                backgroundColor: options.backgroundColor
            )
        case .ascii:
            return AsciiBlitter()
        case .auto:
            // Auto-select based on color support
            switch options.colorSupport {
            case .trueColor, .ansi256:
                return HalfBlockBlitter()
            case .ansi16:
                return HalfBlockBlitter()
            case .none:
                return BrailleBlitter(
                    threshold: options.threshold,
                    foregroundColor: options.foregroundColor,
                    backgroundColor: options.backgroundColor
                )
            }
        }
    }

    /// Build color palette for given support level
    private func buildPalette() -> [Color] {
        switch options.colorSupport {
        case .trueColor:
            // For true color, no palette needed (return empty)
            return []
        case .ansi256:
            return ColorQuantizer.palette256()
        case .ansi16:
            return ColorQuantizer.palette16()
        case .none:
            return [.black, .white]
        }
    }
}
