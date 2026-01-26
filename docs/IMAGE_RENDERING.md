# Terminal Image Rendering Techniques

This document details research findings on terminal image rendering techniques, drawing from established projects like notcurses, chafa, and dotmatrix. It provides an implementation plan for `ImageRenderer.swift` in the TUIRender module.

## Table of Contents

1. [Overview](#overview)
2. [Rendering Modes](#rendering-modes)
3. [Braille Rendering](#braille-rendering)
4. [Half-Block Rendering](#half-block-rendering)
5. [Dithering Algorithms](#dithering-algorithms)
6. [Color Quantization](#color-quantization)
7. [Implementation Plan](#implementation-plan)
8. [Data Structures](#data-structures)
9. [Algorithm Pseudocode](#algorithm-pseudocode)
10. [Swift Implementation](#swift-implementation)

---

## Overview

Terminal image rendering converts raster images (pixels) into character-based representations suitable for display in text terminals. The key challenges are:

1. **Resolution**: Terminal cells are larger than pixels; each cell can represent multiple pixels
2. **Color depth**: Terminals support limited color palettes (16, 256, or true color)
3. **Aspect ratio**: Terminal cells are typically taller than wide (roughly 2:1)
4. **Character selection**: Choosing optimal Unicode characters to represent pixel patterns

### Reference Projects

| Project | Focus | Key Techniques |
|---------|-------|----------------|
| **notcurses** | Full TUI library | Blitters (half-block, sextant, octant, braille), graceful degradation |
| **chafa** | Image-to-terminal CLI | Multiple symbol sets, dithering, color quantization |
| **dotmatrix** | Braille rendering | Floyd-Steinberg dithering, 2x4 pixel-to-braille mapping |

---

## Rendering Modes

Based on notcurses blitter architecture, terminals support these rendering modes in order of quality:

| Mode | Resolution | Characters | Unicode Requirement |
|------|------------|------------|---------------------|
| **1x1** | 1 pixel/cell | Space only | ASCII |
| **Half-block (2x1)** | 2 pixels/cell | `▀▄` | Basic Unicode |
| **Quadrant (2x2)** | 4 pixels/cell | `▖▗▘▙▚▛▜▝▞▟` | Unicode 1.0 |
| **Sextant (3x2)** | 6 pixels/cell | Sextant characters | Unicode 13 |
| **Octant (4x2)** | 8 pixels/cell | Octant characters | Unicode 16 |
| **Braille (4x2)** | 8 pixels/cell | `⠀-⣿` (U+2800-U+28FF) | Unicode 1.0 |
| **Pixel** | Native pixels | Sixel/Kitty protocol | Terminal-specific |

### Graceful Degradation

Notcurses implements automatic fallback: `Pixel > Sextant > Quadrant > Half > ASCII`

---

## Braille Rendering

### Unicode Braille Block (U+2800-U+28FF)

Braille patterns encode 8 dots in a 2x4 grid, yielding 256 (2^8) possible patterns per character.

#### Dot Position Layout

```
Position:   Bit Value:
[1] [4]     0x01  0x08
[2] [5]     0x02  0x10
[3] [6]     0x04  0x20
[7] [8]     0x40  0x80
```

#### Encoding Formula

```
codepoint = 0x2800 + (dot1 * 0x01) + (dot2 * 0x02) + (dot3 * 0x04) +
            (dot4 * 0x08) + (dot5 * 0x10) + (dot6 * 0x20) +
            (dot7 * 0x40) + (dot8 * 0x80)
```

Example: Dots 1, 2, and 5 raised:
```
codepoint = 0x2800 + 0x01 + 0x02 + 0x10 = 0x2813 = '⠓'
```

#### Pixel-to-Braille Mapping

For a 2x4 pixel block at position (bx, by) in the image:

```
pixel_positions = [
    (bx,   by),   (bx+1, by),    // dots 1, 4
    (bx,   by+1), (bx+1, by+1),  // dots 2, 5
    (bx,   by+2), (bx+1, by+2),  // dots 3, 6
    (bx,   by+3), (bx+1, by+3)   // dots 7, 8
]

bit_values = [0x01, 0x08, 0x02, 0x10, 0x04, 0x20, 0x40, 0x80]
```

### Braille Rendering Pipeline (from dotmatrix)

1. **Decode**: Load image (JPEG, PNG, GIF, BMP)
2. **Filter**: Apply brightness, contrast, gamma adjustments
3. **Scale**: Resize to terminal dimensions (accounting for 2:4 ratio)
4. **Dither**: Convert to monochrome using Floyd-Steinberg
5. **Encode**: Map each 2x4 block to braille character
6. **Render**: Output with newlines

---

## Half-Block Rendering

Half-block rendering uses two characters to represent 2 vertical pixels per cell:
- `▀` (U+2580) Upper half block
- `▄` (U+2584) Lower half block
- Space or full block for solid colors

### Color Selection

Each cell can have two colors (foreground and background), representing top and bottom halves:

```
For pixels (top_pixel, bottom_pixel):
  if top_pixel == bottom_pixel:
    output = ' ' with background = top_pixel
  else:
    output = '▀' with fg = top_pixel, bg = bottom_pixel
```

### Aspect Ratio Preservation

Half-block (2x1) preserves aspect ratio because terminal cells are approximately 2:1 (twice as tall as wide). Other blitters may distort:

| Blitter | Vertical Stretch Factor |
|---------|------------------------|
| 1x1 | 2x (doubled height) |
| 2x1 | 1x (preserved) |
| 3x2 | 1.5x |
| 4x2 | 1x (preserved) |

---

## Dithering Algorithms

Dithering simulates colors/shades not available in the target palette by distributing quantization errors.

### Floyd-Steinberg Dithering (Error Diffusion)

The most common dithering algorithm, distributes quantization error to neighboring pixels.

#### Error Distribution Pattern

```
         *    7/16
  3/16  5/16  1/16
```

Where `*` is the current pixel.

#### Algorithm

```
for y = 0 to height-1:
    for x = 0 to width-1:
        old_pixel = image[x][y]
        new_pixel = find_closest_palette_color(old_pixel)
        image[x][y] = new_pixel
        quant_error = old_pixel - new_pixel

        image[x+1][y  ] += quant_error * 7/16
        image[x-1][y+1] += quant_error * 3/16
        image[x  ][y+1] += quant_error * 5/16
        image[x+1][y+1] += quant_error * 1/16
```

#### Serpentine Scanning (Enhancement)

Process even rows left-to-right, odd rows right-to-left. This reduces directional artifacts.

### Ordered (Bayer) Dithering

Uses a threshold matrix tiled across the image. Faster but produces visible patterns.

#### 4x4 Bayer Matrix

```
M4 = [
    [ 0,  8,  2, 10],
    [12,  4, 14,  6],
    [ 3, 11,  1,  9],
    [15,  7, 13,  5]
]
```

Normalized (divide by 16): values 0.0 to 0.9375

#### 8x8 Bayer Matrix (Recursive Generation)

```
M(2n) = (1/4n^2) * [
    4*M(n) + 0    4*M(n) + 2
    4*M(n) + 3    4*M(n) + 1
]
```

#### Algorithm

```
for y = 0 to height-1:
    for x = 0 to width-1:
        threshold = matrix[y % matrix_size][x % matrix_size] / matrix_max
        if image[x][y] > threshold:
            output[x][y] = white
        else:
            output[x][y] = black
```

### Dithering Comparison (from chafa)

| Type | Pros | Cons |
|------|------|------|
| **None** | Sharp edges | Banding in gradients |
| **Ordered** | Fast, predictable | Cross-hatch artifacts |
| **Diffusion (F-S)** | Smooth gradients | Slower, can blur edges |
| **Noise** | Good for sixel | Random pattern |

---

## Color Quantization

### ANSI 256-Color Palette Structure

```
Colors 0-15:    System colors (terminal-dependent)
Colors 16-231:  6x6x6 RGB color cube (216 colors)
Colors 232-255: 24-level grayscale ramp
```

#### RGB Cube Formula

```
index = 16 + (36 * r) + (6 * g) + b
where r, g, b in [0, 5]
```

#### Cube Level Values

```
level:  0     1     2     3     4     5
value:  0x00  0x5F  0x87  0xAF  0xD7  0xFF
        (0)   (95)  (135) (175) (215) (255)
```

#### Grayscale Ramp Formula

```
For index 232-255:
gray_value = 8 + (index - 232) * 10
```

### RGB to ANSI 256 Conversion

```swift
func toANSI256(r: UInt8, g: UInt8, b: UInt8) -> UInt8 {
    // Check for grayscale
    if isGrayscale(r, g, b) {
        let avg = (Int(r) + Int(g) + Int(b)) / 3
        if avg < 8 { return 16 }        // Black
        if avg > 248 { return 231 }     // White
        return UInt8(232 + (avg - 8) / 10)
    }

    // Map to 6x6x6 cube
    let levels = [0, 95, 135, 175, 215, 255]
    let ri = nearestLevel(Int(r), levels)
    let gi = nearestLevel(Int(g), levels)
    let bi = nearestLevel(Int(b), levels)

    return UInt8(16 + 36 * ri + 6 * gi + bi)
}
```

### Perceptual Color Distance

Simple RGB Euclidean distance is not perceptually uniform. Better alternatives:

#### Weighted RGB Distance

```swift
func colorDistance(_ c1: Color, _ c2: Color) -> Double {
    let rMean = (Double(c1.r) + Double(c2.r)) / 2
    let dR = Double(c1.r) - Double(c2.r)
    let dG = Double(c1.g) - Double(c2.g)
    let dB = Double(c1.b) - Double(c2.b)

    // Redmean color difference formula
    let rWeight = 2 + rMean / 256
    let gWeight = 4.0
    let bWeight = 2 + (255 - rMean) / 256

    return sqrt(rWeight * dR * dR + gWeight * dG * dG + bWeight * dB * dB)
}
```

#### OkLab Color Space (Modern Approach)

Convert to OkLab for perceptually uniform distances. OkLab is designed for perceptual uniformity.

### Median Cut Algorithm

For adaptive palette generation:

1. Create bounding box around all colors in RGB space
2. Find the longest axis (R, G, or B)
3. Sort colors along that axis
4. Split at median into two boxes
5. Repeat until desired palette size reached
6. Average colors in each box for final palette

---

## Implementation Plan

### File Structure

```
Sources/TUIRender/
├── TUIRender.swift          (existing module entry)
├── ImageRenderer.swift      (main renderer)
├── Blitters/
│   ├── Blitter.swift        (protocol)
│   ├── BrailleBlitter.swift
│   ├── HalfBlockBlitter.swift
│   ├── QuadrantBlitter.swift
│   └── AsciiBlitter.swift
├── Dithering/
│   ├── Ditherer.swift       (protocol)
│   ├── FloydSteinberg.swift
│   ├── OrderedDither.swift
│   └── NoDither.swift
└── ColorQuantizer.swift
```

### Dependencies

- **TUICore**: Color type (already exists)
- **TUITerminal**: ColorConverter, ANSICode (already exists)
- **Foundation**: Image loading (via CGImage/NSImage or external library)

---

## Data Structures

### Pixel Buffer

```swift
/// Raw pixel data for image processing
public struct PixelBuffer {
    public let width: Int
    public let height: Int
    public private(set) var pixels: [Color]

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.pixels = Array(repeating: .black, count: width * height)
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
}
```

### Blitter Output

```swift
/// A single rendered cell with character and colors
public struct RenderedCell {
    public let character: Character
    public let foreground: Color
    public let background: Color
}

/// Result of blitting an image region
public struct BlitResult {
    public let cells: [[RenderedCell]]
    public let width: Int   // in cells
    public let height: Int  // in cells
}
```

### Render Options

```swift
/// Configuration for image rendering
public struct ImageRenderOptions {
    /// Target width in terminal columns (nil = auto)
    public var targetWidth: Int?

    /// Target height in terminal rows (nil = auto)
    public var targetHeight: Int?

    /// Rendering mode
    public var blitMode: BlitMode = .auto

    /// Dithering algorithm
    public var dithering: DitheringMode = .floydSteinberg

    /// Color support level
    public var colorSupport: ColorSupport = .trueColor

    /// Preserve aspect ratio
    public var preserveAspectRatio: Bool = true
}

public enum BlitMode {
    case auto           // Best available
    case ascii          // 1x1, spaces only
    case halfBlock      // 2x1, ▀▄
    case quadrant       // 2x2, quadrant chars
    case braille        // 4x2, braille patterns
}

public enum DitheringMode {
    case none
    case ordered(size: Int)  // 2, 4, or 8
    case floydSteinberg
}
```

---

## Algorithm Pseudocode

### Main Rendering Pipeline

```
function renderImage(image, options):
    // 1. Calculate target dimensions
    (targetW, targetH) = calculateDimensions(image, options)

    // 2. Get pixel dimensions based on blitter
    blitter = selectBlitter(options.blitMode)
    pixelW = targetW * blitter.pixelsPerCellX
    pixelH = targetH * blitter.pixelsPerCellY

    // 3. Scale image
    scaled = scaleImage(image, pixelW, pixelH)

    // 4. Apply dithering if needed
    if options.dithering != .none:
        scaled = applyDithering(scaled, options)

    // 5. Quantize colors for target palette
    quantized = quantizeColors(scaled, options.colorSupport)

    // 6. Blit to character cells
    cells = blitter.blit(quantized)

    return cells
```

### Braille Blitting

```
function blitBraille(pixels):
    cellsW = pixels.width / 2
    cellsH = pixels.height / 4
    cells = new array[cellsH][cellsW]

    for cy = 0 to cellsH-1:
        for cx = 0 to cellsW-1:
            // Get 2x4 pixel block
            px = cx * 2
            py = cy * 4

            // Calculate braille codepoint
            codepoint = 0x2800
            if pixel_is_on(px,   py):   codepoint |= 0x01
            if pixel_is_on(px,   py+1): codepoint |= 0x02
            if pixel_is_on(px,   py+2): codepoint |= 0x04
            if pixel_is_on(px,   py+3): codepoint |= 0x40
            if pixel_is_on(px+1, py):   codepoint |= 0x08
            if pixel_is_on(px+1, py+1): codepoint |= 0x10
            if pixel_is_on(px+1, py+2): codepoint |= 0x20
            if pixel_is_on(px+1, py+3): codepoint |= 0x80

            cells[cy][cx] = Character(codepoint)

    return cells
```

### Half-Block Blitting

```
function blitHalfBlock(pixels):
    cellsW = pixels.width
    cellsH = pixels.height / 2
    cells = new array[cellsH][cellsW]

    for cy = 0 to cellsH-1:
        for cx = 0 to cellsW-1:
            topColor = pixels[cx, cy * 2]
            botColor = pixels[cx, cy * 2 + 1]

            if topColor == botColor:
                // Solid color - use space with background
                cells[cy][cx] = RenderedCell(' ', topColor, topColor)
            else:
                // Mixed - use upper half block
                cells[cy][cx] = RenderedCell('▀', topColor, botColor)

    return cells
```

### Floyd-Steinberg Implementation

```
function floydSteinbergDither(pixels, palette):
    for y = 0 to height-1:
        for x = 0 to width-1:
            oldPixel = pixels[x, y]
            newPixel = findClosestColor(oldPixel, palette)
            pixels[x, y] = newPixel

            error = oldPixel - newPixel  // per channel

            if x+1 < width:
                pixels[x+1, y] += error * 7/16
            if y+1 < height:
                if x > 0:
                    pixels[x-1, y+1] += error * 3/16
                pixels[x, y+1] += error * 5/16
                if x+1 < width:
                    pixels[x+1, y+1] += error * 1/16

    return pixels
```

---

## Swift Implementation

### Blitter Protocol

```swift
/// Protocol for image-to-character blitters
public protocol Blitter {
    /// Pixels consumed per cell horizontally
    var pixelsPerCellX: Int { get }

    /// Pixels consumed per cell vertically
    var pixelsPerCellY: Int { get }

    /// Convert pixel buffer to rendered cells
    func blit(_ pixels: PixelBuffer) -> BlitResult
}
```

### Braille Blitter

```swift
public struct BrailleBlitter: Blitter {
    public let pixelsPerCellX = 2
    public let pixelsPerCellY = 4

    /// Threshold for considering a pixel "on" (0-255)
    public var threshold: UInt8 = 128

    /// Foreground color for braille dots
    public var foregroundColor: Color = .white

    /// Background color
    public var backgroundColor: Color = .black

    public init() {}

    public func blit(_ pixels: PixelBuffer) -> BlitResult {
        let cellsW = pixels.width / pixelsPerCellX
        let cellsH = pixels.height / pixelsPerCellY

        var cells: [[RenderedCell]] = []

        for cy in 0..<cellsH {
            var row: [RenderedCell] = []
            for cx in 0..<cellsW {
                let px = cx * 2
                let py = cy * 4

                var codepoint: UInt32 = 0x2800

                // Map pixels to braille dots
                // Dot positions and their bit values:
                // [1][4]  -> 0x01, 0x08
                // [2][5]  -> 0x02, 0x10
                // [3][6]  -> 0x04, 0x20
                // [7][8]  -> 0x40, 0x80

                if isPixelOn(pixels[px, py])     { codepoint |= 0x01 }
                if isPixelOn(pixels[px, py + 1]) { codepoint |= 0x02 }
                if isPixelOn(pixels[px, py + 2]) { codepoint |= 0x04 }
                if isPixelOn(pixels[px, py + 3]) { codepoint |= 0x40 }
                if isPixelOn(pixels[px + 1, py])     { codepoint |= 0x08 }
                if isPixelOn(pixels[px + 1, py + 1]) { codepoint |= 0x10 }
                if isPixelOn(pixels[px + 1, py + 2]) { codepoint |= 0x20 }
                if isPixelOn(pixels[px + 1, py + 3]) { codepoint |= 0x80 }

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

    private func isPixelOn(_ color: Color) -> Bool {
        // Convert to grayscale and threshold
        let gray = (Int(color.r) + Int(color.g) + Int(color.b)) / 3
        return gray >= Int(threshold)
    }
}
```

### Half-Block Blitter

```swift
public struct HalfBlockBlitter: Blitter {
    public let pixelsPerCellX = 1
    public let pixelsPerCellY = 2

    /// Upper half block character
    private let upperHalf: Character = "\u{2580}"  // ▀

    /// Lower half block character
    private let lowerHalf: Character = "\u{2584}"  // ▄

    /// Full block character
    private let fullBlock: Character = "\u{2588}"  // █

    public init() {}

    public func blit(_ pixels: PixelBuffer) -> BlitResult {
        let cellsW = pixels.width / pixelsPerCellX
        let cellsH = pixels.height / pixelsPerCellY

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
                        character: upperHalf,
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
        // Allow small tolerance for near-identical colors
        let tolerance: Int = 8
        return abs(Int(a.r) - Int(b.r)) < tolerance &&
               abs(Int(a.g) - Int(b.g)) < tolerance &&
               abs(Int(a.b) - Int(b.b)) < tolerance
    }
}
```

### Floyd-Steinberg Ditherer

```swift
public struct FloydSteinbergDitherer {
    /// The target palette to quantize to
    public let palette: [Color]

    /// Enable serpentine (bidirectional) scanning
    public var serpentine: Bool = true

    public init(palette: [Color]) {
        self.palette = palette
    }

    /// Create ditherer for monochrome output
    public static var monochrome: FloydSteinbergDitherer {
        FloydSteinbergDitherer(palette: [.black, .white])
    }

    public func dither(_ pixels: inout PixelBuffer) {
        for y in 0..<pixels.height {
            let leftToRight = !serpentine || (y % 2 == 0)
            let xRange = leftToRight ?
                Array(0..<pixels.width) :
                Array((0..<pixels.width).reversed())

            for x in xRange {
                let oldPixel = pixels[x, y]
                let newPixel = findClosestColor(oldPixel)
                pixels[x, y] = newPixel

                let errorR = Int(oldPixel.r) - Int(newPixel.r)
                let errorG = Int(oldPixel.g) - Int(newPixel.g)
                let errorB = Int(oldPixel.b) - Int(newPixel.b)

                // Distribute error to neighbors
                let xDir = leftToRight ? 1 : -1

                distributeError(&pixels, x: x + xDir, y: y,
                              errorR: errorR, errorG: errorG, errorB: errorB,
                              factor: 7.0 / 16.0)
                distributeError(&pixels, x: x - xDir, y: y + 1,
                              errorR: errorR, errorG: errorG, errorB: errorB,
                              factor: 3.0 / 16.0)
                distributeError(&pixels, x: x, y: y + 1,
                              errorR: errorR, errorG: errorG, errorB: errorB,
                              factor: 5.0 / 16.0)
                distributeError(&pixels, x: x + xDir, y: y + 1,
                              errorR: errorR, errorG: errorG, errorB: errorB,
                              factor: 1.0 / 16.0)
            }
        }
    }

    private func distributeError(_ pixels: inout PixelBuffer,
                                  x: Int, y: Int,
                                  errorR: Int, errorG: Int, errorB: Int,
                                  factor: Double) {
        guard x >= 0, x < pixels.width, y >= 0, y < pixels.height else { return }

        let current = pixels[x, y]
        pixels[x, y] = Color(
            r: clampToByte(Int(current.r) + Int(Double(errorR) * factor)),
            g: clampToByte(Int(current.g) + Int(Double(errorG) * factor)),
            b: clampToByte(Int(current.b) + Int(Double(errorB) * factor))
        )
    }

    private func findClosestColor(_ color: Color) -> Color {
        var minDist = Double.infinity
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

    private func colorDistance(_ a: Color, _ b: Color) -> Double {
        // Weighted Euclidean distance (Redmean formula)
        let rMean = (Double(a.r) + Double(b.r)) / 2.0
        let dR = Double(a.r) - Double(b.r)
        let dG = Double(a.g) - Double(b.g)
        let dB = Double(a.b) - Double(b.b)

        let rWeight = 2.0 + rMean / 256.0
        let gWeight = 4.0
        let bWeight = 2.0 + (255.0 - rMean) / 256.0

        return sqrt(rWeight * dR * dR + gWeight * dG * dG + bWeight * dB * dB)
    }

    private func clampToByte(_ value: Int) -> UInt8 {
        UInt8(max(0, min(255, value)))
    }
}
```

### Ordered Ditherer

```swift
public struct OrderedDitherer {
    /// The Bayer matrix for threshold values
    private let matrix: [[Double]]
    private let matrixSize: Int

    /// Target palette
    public let palette: [Color]

    public init(size: Int, palette: [Color]) {
        self.matrixSize = size
        self.palette = palette
        self.matrix = Self.generateBayerMatrix(size: size)
    }

    /// Generate Bayer matrix of given size (must be power of 2)
    private static func generateBayerMatrix(size: Int) -> [[Double]] {
        guard size >= 2 else {
            return [[0]]
        }

        if size == 2 {
            return [
                [0.0 / 4.0, 2.0 / 4.0],
                [3.0 / 4.0, 1.0 / 4.0]
            ]
        }

        // Recursive generation
        let half = size / 2
        let smaller = generateBayerMatrix(size: half)
        var result = Array(repeating: Array(repeating: 0.0, count: size), count: size)
        let scale = Double(size * size)

        for y in 0..<size {
            for x in 0..<size {
                let baseValue = smaller[y % half][x % half] * 4.0 * Double(half * half)
                let offset: Double
                if y < half && x < half { offset = 0 }
                else if y < half && x >= half { offset = 2 }
                else if y >= half && x < half { offset = 3 }
                else { offset = 1 }

                result[y][x] = (baseValue + offset) / scale
            }
        }

        return result
    }

    /// 4x4 Bayer matrix (commonly used)
    public static let bayer4x4: [[Double]] = [
        [ 0.0/16,  8.0/16,  2.0/16, 10.0/16],
        [12.0/16,  4.0/16, 14.0/16,  6.0/16],
        [ 3.0/16, 11.0/16,  1.0/16,  9.0/16],
        [15.0/16,  7.0/16, 13.0/16,  5.0/16]
    ]

    public func dither(_ pixels: inout PixelBuffer) {
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

    private func applyThreshold(value: UInt8, threshold: Double) -> UInt8 {
        let normalized = Double(value) / 255.0
        let adjusted = normalized + (threshold - 0.5) * 0.5
        return adjusted > 0.5 ? 255 : 0
    }

    private func findClosestColor(_ color: Color) -> Color {
        // Same as Floyd-Steinberg implementation
        var minDist = Double.infinity
        var closest = palette[0]

        for paletteColor in palette {
            let dR = Double(color.r) - Double(paletteColor.r)
            let dG = Double(color.g) - Double(paletteColor.g)
            let dB = Double(color.b) - Double(paletteColor.b)
            let dist = dR * dR + dG * dG + dB * dB

            if dist < minDist {
                minDist = dist
                closest = paletteColor
            }
        }

        return closest
    }
}
```

### Main Image Renderer

```swift
import TUICore
import TUITerminal

/// Renders images to terminal character cells
public struct ImageRenderer {

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
            let palette = buildPalette(for: options.colorSupport)
            var ditherer = FloydSteinbergDitherer(palette: palette)
            ditherer.dither(&workingPixels)
        case .ordered(let size):
            let palette = buildPalette(for: options.colorSupport)
            let ditherer = OrderedDitherer(size: size, palette: palette)
            ditherer.dither(&workingPixels)
        }

        // 2. Select and apply blitter
        let blitter = selectBlitter()
        return blitter.blit(workingPixels)
    }

    /// Select appropriate blitter based on options
    private func selectBlitter() -> Blitter {
        switch options.blitMode {
        case .braille:
            return BrailleBlitter()
        case .halfBlock:
            return HalfBlockBlitter()
        case .quadrant:
            return QuadrantBlitter()
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
                return BrailleBlitter()
            }
        }
    }

    /// Build color palette for given support level
    private func buildPalette(for colorSupport: ColorSupport) -> [Color] {
        switch colorSupport {
        case .trueColor:
            // For true color, no quantization needed
            return []
        case .ansi256:
            return build256ColorPalette()
        case .ansi16:
            return build16ColorPalette()
        case .none:
            return [.black, .white]
        }
    }

    private func build16ColorPalette() -> [Color] {
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

    private func build256ColorPalette() -> [Color] {
        var palette: [Color] = []

        // Add 16 system colors
        palette.append(contentsOf: build16ColorPalette())

        // Add 6x6x6 color cube (216 colors)
        let levels: [UInt8] = [0, 95, 135, 175, 215, 255]
        for r in levels {
            for g in levels {
                for b in levels {
                    palette.append(Color(r: r, g: g, b: b))
                }
            }
        }

        // Add 24 grayscale colors
        for i in 0..<24 {
            let gray = UInt8(8 + i * 10)
            palette.append(Color(r: gray, g: gray, b: gray))
        }

        return palette
    }
}
```

---

## References

### Projects Studied

- [notcurses](https://github.com/dankamongmen/notcurses) - Comprehensive TUI library with multiple blitter modes
- [chafa](https://hpjansson.org/chafa/) - Terminal image viewer with extensive symbol and dithering options
- [dotmatrix](https://github.com/kevin-cantwell/dotmatrix) - Focused braille rendering implementation
- [drawille](https://github.com/asciimoo/drawille) - Python braille graphics library

### Technical References

- [Unicode Braille Patterns](https://en.wikipedia.org/wiki/Braille_Patterns) - U+2800-U+28FF character encoding
- [Floyd-Steinberg Dithering](https://en.wikipedia.org/wiki/Floyd%E2%80%93Steinberg_dithering) - Error diffusion algorithm
- [Ordered Dithering](https://en.wikipedia.org/wiki/Ordered_dithering) - Bayer matrix threshold dithering
- [Color Quantization](https://en.wikipedia.org/wiki/Color_quantization) - Palette reduction algorithms
- [256 Colors Cheat Sheet](https://www.ditig.com/256-colors-cheat-sheet) - ANSI 256 color palette reference

### Implementation Notes

- The existing `TUICore.Color` type already provides RGB color representation suitable for this implementation
- The `TUITerminal.ColorConverter` already implements ANSI 16 and 256 color conversion
- The `TUITerminal.Canvas` provides the character cell abstraction that image rendering will output to
