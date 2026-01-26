// TUITerminal - ANSI Escape Code Builder

/// ANSI escape sequence constants and builders
public enum ANSICode {
    /// The escape sequence prefix
    public static let escape = "\u{1B}["

    /// Reset all attributes to default
    public static let reset = "\u{1B}[0m"

    // MARK: - Cursor Movement

    /// Move cursor to position (1-based coordinates, ANSI standard)
    /// - Parameters:
    ///   - x: Column (1-based)
    ///   - y: Row (1-based)
    /// - Returns: ANSI escape sequence
    public static func moveTo(x: Int, y: Int) -> String {
        "\u{1B}[\(y);\(x)H"
    }

    /// Move cursor up by n rows
    public static func moveUp(_ n: Int) -> String {
        "\u{1B}[\(n)A"
    }

    /// Move cursor down by n rows
    public static func moveDown(_ n: Int) -> String {
        "\u{1B}[\(n)B"
    }

    /// Move cursor right by n columns
    public static func moveRight(_ n: Int) -> String {
        "\u{1B}[\(n)C"
    }

    /// Move cursor left by n columns
    public static func moveLeft(_ n: Int) -> String {
        "\u{1B}[\(n)D"
    }

    /// Move cursor to home position (top-left)
    public static let home = "\u{1B}[H"

    /// Save current cursor position
    public static let saveCursor = "\u{1B}[s"

    /// Restore saved cursor position
    public static let restoreCursor = "\u{1B}[u"

    /// Hide the cursor
    public static let hideCursor = "\u{1B}[?25l"

    /// Show the cursor
    public static let showCursor = "\u{1B}[?25h"

    // MARK: - Screen Clearing

    /// Clear entire screen
    public static let clearScreen = "\u{1B}[2J"

    /// Clear entire line
    public static let clearLine = "\u{1B}[2K"

    /// Clear from cursor to end of line
    public static let clearToEndOfLine = "\u{1B}[K"

    /// Clear from cursor to end of screen
    public static let clearToEndOfScreen = "\u{1B}[J"

    // MARK: - Alternate Screen Buffer

    /// Enter alternate screen buffer (preserves original terminal content)
    public static let enterAlternateScreen = "\u{1B}[?1049h"

    /// Exit alternate screen buffer (restores original terminal content)
    public static let exitAlternateScreen = "\u{1B}[?1049l"

    // MARK: - 16 Color Mode

    /// Set foreground color (16 color)
    public static func foreground(_ color: ANSIColor) -> String {
        "\u{1B}[\(color.rawValue)m"
    }

    /// Set background color (16 color)
    public static func background(_ color: ANSIColor) -> String {
        // Background codes are foreground + 10, except for bright colors
        let code: UInt8
        if color.rawValue >= 90 && color.rawValue <= 97 {
            // Bright colors: 90-97 -> 100-107
            code = color.rawValue + 10
        } else if color.rawValue == 39 {
            // Default: 39 -> 49
            code = 49
        } else {
            // Normal colors: 30-37 -> 40-47
            code = color.rawValue + 10
        }
        return "\u{1B}[\(code)m"
    }

    // MARK: - 256 Color Mode

    /// Set foreground color (256 color)
    public static func foreground256(_ code: UInt8) -> String {
        "\u{1B}[38;5;\(code)m"
    }

    /// Set background color (256 color)
    public static func background256(_ code: UInt8) -> String {
        "\u{1B}[48;5;\(code)m"
    }

    // MARK: - True Color (24-bit RGB)

    /// Set foreground color (true color RGB)
    public static func foregroundRGB(_ r: UInt8, _ g: UInt8, _ b: UInt8) -> String {
        "\u{1B}[38;2;\(r);\(g);\(b)m"
    }

    /// Set background color (true color RGB)
    public static func backgroundRGB(_ r: UInt8, _ g: UInt8, _ b: UInt8) -> String {
        "\u{1B}[48;2;\(r);\(g);\(b)m"
    }

    // MARK: - Text Attributes

    /// Bold text
    public static let bold = "\u{1B}[1m"

    /// Dim/faint text
    public static let dim = "\u{1B}[2m"

    /// Italic text
    public static let italic = "\u{1B}[3m"

    /// Underlined text
    public static let underline = "\u{1B}[4m"

    /// Inverse/reverse video
    public static let inverse = "\u{1B}[7m"

    /// Strikethrough text
    public static let strikethrough = "\u{1B}[9m"
}

/// Standard ANSI 16 colors
public enum ANSIColor: UInt8, Sendable, Equatable, Hashable {
    // Normal colors (foreground 30-37)
    case black = 30
    case red = 31
    case green = 32
    case yellow = 33
    case blue = 34
    case magenta = 35
    case cyan = 36
    case white = 37

    // Default color
    case `default` = 39

    // Bright/bold colors (foreground 90-97)
    case brightBlack = 90
    case brightRed = 91
    case brightGreen = 92
    case brightYellow = 93
    case brightBlue = 94
    case brightMagenta = 95
    case brightCyan = 96
    case brightWhite = 97
}
