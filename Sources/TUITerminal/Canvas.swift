// TUITerminal - Character Cell Canvas

import TUICore
import Foundation

/// A single character cell with styling
public struct Cell: Equatable, Sendable {
    /// The character displayed in this cell
    public var character: Character

    /// The style applied to this cell
    public var style: TextStyle

    /// Initialize a cell with character and style
    public init(character: Character, style: TextStyle) {
        self.character = character
        self.style = style
    }

    /// An empty cell (space with default style)
    public static let empty = Cell(character: " ", style: .default)
}

/// A 2D grid of character cells for terminal rendering
public final class Canvas: @unchecked Sendable {
    /// Canvas width in columns
    public private(set) var width: Int

    /// Canvas height in rows
    public private(set) var height: Int

    /// Current cell grid
    private var cells: [[Cell]]

    /// Previous cell grid for differential updates
    private var previousCells: [[Cell]]?

    /// Lock for thread safety
    private let lock = NSLock()

    /// Initialize a canvas with specified dimensions
    /// - Parameters:
    ///   - width: Width in columns
    ///   - height: Height in rows
    public init(width: Int, height: Int) {
        self.width = max(1, width)
        self.height = max(1, height)
        self.cells = Self.createEmptyGrid(width: self.width, height: self.height)
    }

    /// Create an empty grid of cells
    private static func createEmptyGrid(width: Int, height: Int) -> [[Cell]] {
        Array(repeating: Array(repeating: Cell.empty, count: width), count: height)
    }

    /// Access a cell by coordinates
    /// - Parameters:
    ///   - x: Column (0-based)
    ///   - y: Row (0-based)
    /// - Returns: The cell at the position, or empty cell if out of bounds
    public subscript(x: Int, y: Int) -> Cell {
        get {
            lock.lock()
            defer { lock.unlock() }
            guard x >= 0 && x < width && y >= 0 && y < height else {
                return .empty
            }
            return cells[y][x]
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            guard x >= 0 && x < width && y >= 0 && y < height else {
                return
            }
            cells[y][x] = newValue
        }
    }

    /// Set a cell at the specified position
    /// - Parameters:
    ///   - x: Column (0-based)
    ///   - y: Row (0-based)
    ///   - char: Character to display
    ///   - style: Style to apply
    public func setCell(x: Int, y: Int, char: Character, style: TextStyle) {
        self[x, y] = Cell(character: char, style: style)
    }

    /// Draw text at a position
    /// - Parameters:
    ///   - text: The text to draw
    ///   - point: Starting position
    ///   - style: Style to apply to all characters
    public func drawText(_ text: String, at point: Point, style: TextStyle) {
        lock.lock()
        defer { lock.unlock() }

        var x = point.x
        let y = point.y

        guard y >= 0 && y < height else { return }

        for char in text {
            guard x >= 0 && x < width else { break }
            cells[y][x] = Cell(character: char, style: style)
            x += 1
        }
    }

    /// Draw a rectangle
    /// - Parameters:
    ///   - rect: The rectangle bounds
    ///   - style: Style to apply
    ///   - fill: Optional fill character (nil for outline only)
    public func drawRect(_ rect: Rect, style: TextStyle, fill: Character?) {
        lock.lock()
        defer { lock.unlock() }

        let minX = max(0, rect.minX)
        let minY = max(0, rect.minY)
        let maxX = min(width, rect.maxX)
        let maxY = min(height, rect.maxY)

        guard minX < maxX && minY < maxY else { return }

        if let fillChar = fill {
            // Filled rectangle
            for y in minY..<maxY {
                for x in minX..<maxX {
                    cells[y][x] = Cell(character: fillChar, style: style)
                }
            }
        } else {
            // Outline only using box drawing characters
            let horizontal: Character = "\u{2500}" // ─
            let vertical: Character = "\u{2502}"   // │
            let topLeft: Character = "\u{250C}"    // ┌
            let topRight: Character = "\u{2510}"   // ┐
            let bottomLeft: Character = "\u{2514}" // └
            let bottomRight: Character = "\u{2518}"// ┘

            // Top edge
            for x in minX..<maxX {
                if x == minX {
                    cells[minY][x] = Cell(character: topLeft, style: style)
                } else if x == maxX - 1 {
                    cells[minY][x] = Cell(character: topRight, style: style)
                } else {
                    cells[minY][x] = Cell(character: horizontal, style: style)
                }
            }

            // Bottom edge
            if maxY - 1 > minY {
                for x in minX..<maxX {
                    if x == minX {
                        cells[maxY - 1][x] = Cell(character: bottomLeft, style: style)
                    } else if x == maxX - 1 {
                        cells[maxY - 1][x] = Cell(character: bottomRight, style: style)
                    } else {
                        cells[maxY - 1][x] = Cell(character: horizontal, style: style)
                    }
                }
            }

            // Left and right edges
            for y in (minY + 1)..<(maxY - 1) {
                cells[y][minX] = Cell(character: vertical, style: style)
                if maxX - 1 > minX {
                    cells[y][maxX - 1] = Cell(character: vertical, style: style)
                }
            }
        }
    }

    /// Clear the canvas to empty cells
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        cells = Self.createEmptyGrid(width: width, height: height)
    }

    /// Resize the canvas
    /// - Parameters:
    ///   - width: New width
    ///   - height: New height
    public func resize(width newWidth: Int, height newHeight: Int) {
        lock.lock()
        defer { lock.unlock() }

        let newWidth = max(1, newWidth)
        let newHeight = max(1, newHeight)

        var newCells = Self.createEmptyGrid(width: newWidth, height: newHeight)

        // Copy existing content that fits
        let copyWidth = min(width, newWidth)
        let copyHeight = min(height, newHeight)

        for y in 0..<copyHeight {
            for x in 0..<copyWidth {
                newCells[y][x] = cells[y][x]
            }
        }

        width = newWidth
        height = newHeight
        cells = newCells
        previousCells = nil // Force full redraw after resize
    }

    /// Render the canvas to terminal output
    /// - Parameters:
    ///   - output: The terminal output buffer
    ///   - fullRedraw: If true, redraw everything; if false, only changed cells
    public func render(to output: TerminalOutput, fullRedraw: Bool) {
        lock.lock()
        let currentCells = cells
        let prevCells = previousCells
        self.previousCells = currentCells
        lock.unlock()

        var lastStyle: TextStyle?

        // Start with cursor at home and clear
        if fullRedraw {
            output.write(ANSICode.hideCursor)
            output.write(ANSICode.home)
        }

        for y in 0..<height {
            for x in 0..<width {
                let cell = currentCells[y][x]

                // Skip unchanged cells in differential mode
                if !fullRedraw, let prev = prevCells, y < prev.count && x < prev[y].count {
                    if prev[y][x] == cell {
                        continue
                    }
                }

                // Move cursor to position (1-based)
                output.write(ANSICode.moveTo(x: x + 1, y: y + 1))

                // Apply style if changed
                if lastStyle != cell.style {
                    output.write(buildStyleSequence(cell.style))
                    lastStyle = cell.style
                }

                // Write character
                output.write(String(cell.character))
            }
        }

        // Reset style and show cursor
        output.write(ANSICode.reset)
        output.write(ANSICode.showCursor)
    }

    /// Build ANSI escape sequence for a style
    private func buildStyleSequence(_ style: TextStyle) -> String {
        var codes: [String] = [ANSICode.reset]

        if style.bold { codes.append(ANSICode.bold) }
        if style.dim { codes.append(ANSICode.dim) }
        if style.italic { codes.append(ANSICode.italic) }
        if style.underline { codes.append(ANSICode.underline) }
        if style.inverse { codes.append(ANSICode.inverse) }
        if style.strikethrough { codes.append(ANSICode.strikethrough) }

        if let fg = style.foreground {
            codes.append(ANSICode.foregroundRGB(fg.r, fg.g, fg.b))
        }

        if let bg = style.background {
            codes.append(ANSICode.backgroundRGB(bg.r, bg.g, bg.b))
        }

        return codes.joined()
    }
}
