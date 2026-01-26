// TUITerminal - Terminal Size Detection

import Darwin
import TUICore

/// Terminal size detection utilities
public struct TerminalSize {
    /// Default terminal size if detection fails
    public static let defaultSize = Size(width: 80, height: 24)

    /// Get the current terminal size
    /// - Returns: Current terminal dimensions, or default size if unavailable
    public static func current() -> Size {
        var winsize = winsize()

        // Try to get window size using ioctl
        let result = ioctl(STDOUT_FILENO, TIOCGWINSZ, &winsize)

        if result == 0 && winsize.ws_col > 0 && winsize.ws_row > 0 {
            return Size(
                width: Int(winsize.ws_col),
                height: Int(winsize.ws_row)
            )
        }

        // Try environment variables as fallback
        if let columns = getEnvironmentVariable("COLUMNS"),
           let lines = getEnvironmentVariable("LINES"),
           let width = Int(columns),
           let height = Int(lines),
           width > 0 && height > 0 {
            return Size(width: width, height: height)
        }

        // Return default size
        return defaultSize
    }

    /// Get environment variable value
    private static func getEnvironmentVariable(_ name: String) -> String? {
        guard let value = getenv(name) else { return nil }
        return String(cString: value)
    }
}
