// TUITerminal - Terminal Raw Mode Management

import Darwin
import Foundation

/// Error types for raw mode operations
public enum RawModeError: Error, Sendable {
    case failedToGetTerminalAttributes
    case failedToSetTerminalAttributes
    case notATerminal
}

/// Manages terminal raw mode for direct input handling
public final class RawMode: @unchecked Sendable {
    /// Original terminal settings to restore
    private var originalTermios: termios

    /// Whether raw mode is currently enabled
    private var isRaw: Bool = false

    /// Lock for thread safety
    private let lock = NSLock()

    /// Initialize raw mode manager
    public init() {
        self.originalTermios = termios()
    }

    /// Enable raw mode on the terminal
    /// - Throws: RawModeError if terminal attributes cannot be modified
    public func enable() throws {
        lock.lock()
        defer { lock.unlock() }

        guard isatty(STDIN_FILENO) != 0 else {
            throw RawModeError.notATerminal
        }

        guard isRaw == false else { return }

        // Get current terminal attributes
        var raw = termios()
        guard tcgetattr(STDIN_FILENO, &raw) == 0 else {
            throw RawModeError.failedToGetTerminalAttributes
        }

        // Save original settings for restoration
        originalTermios = raw

        // Modify terminal flags for raw mode
        // Input flags: disable break, CR to NL, parity check, strip, XON/XOFF
        raw.c_iflag &= ~(UInt(BRKINT) | UInt(ICRNL) | UInt(INPCK) | UInt(ISTRIP) | UInt(IXON))

        // Output flags: disable post-processing
        raw.c_oflag &= ~UInt(OPOST)

        // Control flags: set 8-bit characters
        raw.c_cflag |= UInt(CS8)

        // Local flags: disable echo, canonical mode, signals, extended input
        raw.c_lflag &= ~(UInt(ECHO) | UInt(ICANON) | UInt(ISIG) | UInt(IEXTEN))

        // Control characters:
        // VMIN = 0: read returns immediately
        // VTIME = 1: 100ms timeout (in tenths of seconds)
        raw.c_cc.16 = 0  // VMIN
        raw.c_cc.17 = 1  // VTIME

        // Apply the new settings
        guard tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw) == 0 else {
            throw RawModeError.failedToSetTerminalAttributes
        }

        isRaw = true
    }

    /// Disable raw mode and restore original terminal settings
    public func disable() {
        lock.lock()
        defer { lock.unlock() }

        guard isRaw else { return }

        // Restore original terminal settings
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &originalTermios)
        isRaw = false
    }

    /// Restore terminal on deinitialization
    deinit {
        disable()
    }

    /// Check if raw mode is currently enabled
    public var isEnabled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isRaw
    }
}
