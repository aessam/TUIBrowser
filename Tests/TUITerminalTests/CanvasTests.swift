import Testing
@testable import TUITerminal
import TUICore

@Suite("Canvas Tests")
struct CanvasTests {

    // MARK: - Cell Tests

    @Test func testCellEquality() {
        let cell1 = Cell(character: "A", style: .default)
        let cell2 = Cell(character: "A", style: .default)
        let cell3 = Cell(character: "B", style: .default)

        #expect(cell1 == cell2)
        #expect(cell1 != cell3)
    }

    @Test func testEmptyCell() {
        let empty = Cell.empty
        #expect(empty.character == " ")
        #expect(empty.style == .default)
    }

    @Test func testCellWithStyle() {
        let style = TextStyle(bold: true, foreground: .red)
        let cell = Cell(character: "X", style: style)

        #expect(cell.character == "X")
        #expect(cell.style.bold == true)
        #expect(cell.style.foreground == .red)
    }

    // MARK: - Canvas Creation

    @Test func testCanvasCreation() {
        let canvas = Canvas(width: 80, height: 24)

        #expect(canvas.width == 80)
        #expect(canvas.height == 24)
    }

    @Test func testCanvasDefaultCells() {
        let canvas = Canvas(width: 10, height: 5)

        // All cells should be empty by default
        for x in 0..<10 {
            for y in 0..<5 {
                let cell = canvas[x, y]
                #expect(cell == Cell.empty)
            }
        }
    }

    // MARK: - Cell Access

    @Test func testSetAndGetCell() {
        let canvas = Canvas(width: 80, height: 24)
        let style = TextStyle(bold: true)

        canvas.setCell(x: 5, y: 10, char: "H", style: style)

        let cell = canvas[5, 10]
        #expect(cell.character == "H")
        #expect(cell.style.bold == true)
    }

    @Test func testSubscriptSet() {
        let canvas = Canvas(width: 80, height: 24)
        let cell = Cell(character: "Z", style: TextStyle(underline: true))

        canvas[10, 5] = cell

        #expect(canvas[10, 5] == cell)
    }

    @Test func testOutOfBoundsAccessReturnsEmpty() {
        let canvas = Canvas(width: 10, height: 10)

        // Out of bounds should return empty cell
        #expect(canvas[-1, 0] == Cell.empty)
        #expect(canvas[0, -1] == Cell.empty)
        #expect(canvas[10, 0] == Cell.empty)
        #expect(canvas[0, 10] == Cell.empty)
        #expect(canvas[100, 100] == Cell.empty)
    }

    // MARK: - Draw Text

    @Test func testDrawText() {
        let canvas = Canvas(width: 80, height: 24)
        let style = TextStyle(foreground: .blue)

        canvas.drawText("Hello", at: Point(x: 0, y: 0), style: style)

        #expect(canvas[0, 0].character == "H")
        #expect(canvas[1, 0].character == "e")
        #expect(canvas[2, 0].character == "l")
        #expect(canvas[3, 0].character == "l")
        #expect(canvas[4, 0].character == "o")

        // Verify style was applied
        #expect(canvas[0, 0].style.foreground == .blue)
    }

    @Test func testDrawTextAtPosition() {
        let canvas = Canvas(width: 80, height: 24)

        canvas.drawText("Test", at: Point(x: 10, y: 5), style: .default)

        #expect(canvas[10, 5].character == "T")
        #expect(canvas[11, 5].character == "e")
        #expect(canvas[12, 5].character == "s")
        #expect(canvas[13, 5].character == "t")
    }

    @Test func testDrawTextClipsAtBoundary() {
        let canvas = Canvas(width: 10, height: 5)

        // Text that would extend past the right edge
        canvas.drawText("Hello World!", at: Point(x: 5, y: 0), style: .default)

        #expect(canvas[5, 0].character == "H")
        #expect(canvas[6, 0].character == "e")
        #expect(canvas[7, 0].character == "l")
        #expect(canvas[8, 0].character == "l")
        #expect(canvas[9, 0].character == "o")
        // Beyond bounds should still be empty (or not crash)
    }

    // MARK: - Draw Rect

    @Test func testDrawRectOutline() {
        let canvas = Canvas(width: 20, height: 10)
        let rect = Rect(x: 0, y: 0, width: 5, height: 3)

        canvas.drawRect(rect, style: .default, fill: nil)

        // Top and bottom edges
        for x in 0..<5 {
            #expect(canvas[x, 0].character != " ") // Top edge
            #expect(canvas[x, 2].character != " ") // Bottom edge
        }

        // Left and right edges
        for y in 0..<3 {
            #expect(canvas[0, y].character != " ") // Left edge
            #expect(canvas[4, y].character != " ") // Right edge
        }
    }

    @Test func testDrawRectFilled() {
        let canvas = Canvas(width: 20, height: 10)
        let rect = Rect(x: 2, y: 2, width: 4, height: 3)

        canvas.drawRect(rect, style: .default, fill: "#")

        // Interior should be filled
        for x in 2..<6 {
            for y in 2..<5 {
                #expect(canvas[x, y].character == "#" || canvas[x, y].character != " ")
            }
        }
    }

    // MARK: - Clear

    @Test func testClear() {
        let canvas = Canvas(width: 10, height: 5)

        // Draw some content
        canvas.drawText("Test", at: Point(x: 0, y: 0), style: .default)
        #expect(canvas[0, 0].character == "T")

        // Clear
        canvas.clear()

        // All cells should be empty
        for x in 0..<10 {
            for y in 0..<5 {
                #expect(canvas[x, y] == Cell.empty)
            }
        }
    }

    // MARK: - Resize

    @Test func testResize() {
        let canvas = Canvas(width: 10, height: 5)
        canvas.drawText("Test", at: Point(x: 0, y: 0), style: .default)

        canvas.resize(width: 20, height: 10)

        #expect(canvas.width == 20)
        #expect(canvas.height == 10)

        // Old content should be preserved where possible
        #expect(canvas[0, 0].character == "T")
    }

    @Test func testResizeSmaller() {
        let canvas = Canvas(width: 20, height: 10)
        canvas.drawText("Hello World", at: Point(x: 0, y: 0), style: .default)

        canvas.resize(width: 5, height: 3)

        #expect(canvas.width == 5)
        #expect(canvas.height == 3)

        // Content within new bounds should be preserved
        #expect(canvas[0, 0].character == "H")
        #expect(canvas[4, 0].character == "o")
    }

    // MARK: - Render

    @Test func testRenderToOutput() {
        let canvas = Canvas(width: 5, height: 2)
        let output = TerminalOutput()

        canvas.drawText("Hi", at: Point(x: 0, y: 0), style: .default)
        canvas.render(to: output, fullRedraw: true)

        // Output should contain something
        // We can't easily test the exact output, but we can verify it ran
        output.flush()
    }
}
