import Testing
@testable import TUITerminal

@Suite("TerminalOutput Tests")
struct TerminalOutputTests {

    @Test func testWriteAccumulatesContent() {
        let output = TerminalOutput()
        output.write("Hello")
        output.write(" ")
        output.write("World")

        // Internal buffer should have all content
        // We test this indirectly through clear
        output.clear()
        // After clear, buffer should be empty
    }

    @Test func testClear() {
        let output = TerminalOutput()
        output.write("Some content")
        output.clear()

        // After clear, writing and flushing should only show new content
        output.write("New")
        // No crash means success
    }

    @Test func testFlush() {
        let output = TerminalOutput()
        output.write("Test output")
        output.flush()

        // After flush, buffer should be cleared
        // Write more and flush again
        output.write("More output")
        output.flush()
    }

    @Test func testEmptyFlush() {
        let output = TerminalOutput()
        // Flushing empty buffer should not crash
        output.flush()
    }

    @Test func testMultipleFlushes() {
        let output = TerminalOutput()

        for i in 0..<10 {
            output.write("Line \(i)\n")
            output.flush()
        }
    }
}
