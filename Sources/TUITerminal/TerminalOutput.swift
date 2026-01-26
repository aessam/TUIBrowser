// TUITerminal - Buffered Terminal Output

import Darwin
import Foundation

/// Buffered output writer for efficient terminal rendering
public final class TerminalOutput: @unchecked Sendable {
    /// Internal buffer for accumulating output
    private var buffer: String = ""

    /// Lock for thread safety
    private let lock = NSLock()

    /// Initialize a new terminal output buffer
    public init() {}

    /// Write a string to the buffer
    /// - Parameter string: The string to append
    public func write(_ string: String) {
        lock.lock()
        defer { lock.unlock() }
        buffer.append(string)
    }

    /// Flush the buffer to stdout
    public func flush() {
        lock.lock()
        let output = buffer
        buffer = ""
        lock.unlock()

        guard !output.isEmpty else { return }

        // Write to stdout
        output.withCString { cString in
            _ = Darwin.write(STDOUT_FILENO, cString, strlen(cString))
        }

        // Ensure output is flushed
        fflush(stdout)
    }

    /// Clear the buffer without writing
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        buffer = ""
    }

    /// Get the current buffer content (for testing)
    public var content: String {
        lock.lock()
        defer { lock.unlock() }
        return buffer
    }
}
