// TUITerminal - Terminal Input Handling

import Darwin
import TUICore

/// Terminal input handling for keyboard events
public struct TerminalInput {

    /// Read a key from terminal (non-blocking)
    /// - Returns: The key code if available, nil if no input
    public static func readKey() -> KeyCode? {
        var buffer = [UInt8](repeating: 0, count: 8)
        let bytesRead = read(STDIN_FILENO, &buffer, buffer.count)

        if bytesRead <= 0 {
            return nil
        }

        return parseKeySequence(Array(buffer.prefix(bytesRead)))
    }

    /// Read a key from terminal (blocking)
    /// - Returns: The key code
    public static func readKeyBlocking() -> KeyCode {
        // Set up for blocking read
        var oldTermios = termios()
        tcgetattr(STDIN_FILENO, &oldTermios)

        var newTermios = oldTermios
        // VMIN = 1: block until at least 1 byte available
        // VTIME = 0: no timeout
        newTermios.c_cc.16 = 1  // VMIN
        newTermios.c_cc.17 = 0  // VTIME
        tcsetattr(STDIN_FILENO, TCSANOW, &newTermios)

        defer {
            // Restore original settings
            tcsetattr(STDIN_FILENO, TCSANOW, &oldTermios)
        }

        var buffer = [UInt8](repeating: 0, count: 8)
        let bytesRead = read(STDIN_FILENO, &buffer, buffer.count)

        if bytesRead <= 0 {
            return .unknown(0)
        }

        return parseKeySequence(Array(buffer.prefix(bytesRead)))
    }

    /// Parse a byte sequence into a key code
    private static func parseKeySequence(_ bytes: [UInt8]) -> KeyCode {
        guard !bytes.isEmpty else {
            return .unknown(0)
        }

        let first = bytes[0]

        // Check for control characters (0-31)
        if first < 32 {
            switch first {
            case 0:
                return .unknown(0) // Ctrl+@
            case 1:
                return .ctrlA
            case 3:
                return .ctrlC
            case 4:
                return .ctrlD
            case 5:
                return .ctrlE
            case 9:
                return .tab
            case 10, 13:
                return .enter
            case 11:
                return .ctrlK
            case 12:
                return .ctrlL
            case 21:
                return .ctrlU
            case 23:
                return .ctrlW
            case 26:
                return .ctrlZ
            case 27:
                // Escape sequence
                return parseEscapeSequence(bytes)
            case 127:
                return .backspace
            default:
                return .unknown(first)
            }
        }

        // Backspace (some terminals)
        if first == 127 {
            return .backspace
        }

        // Space
        if first == 32 {
            return .space
        }

        // Printable ASCII character
        if first >= 32 && first < 127 {
            return .char(Character(UnicodeScalar(first)))
        }

        // UTF-8 multi-byte character
        if let string = String(bytes: bytes, encoding: .utf8),
           let char = string.first {
            return .char(char)
        }

        return .unknown(first)
    }

    /// Parse escape sequences (arrow keys, function keys, etc.)
    private static func parseEscapeSequence(_ bytes: [UInt8]) -> KeyCode {
        // Just escape
        if bytes.count == 1 {
            return .escape
        }

        // Check for CSI sequences (ESC [)
        if bytes.count >= 2 && bytes[1] == 91 { // '['
            if bytes.count >= 3 {
                let code = bytes[2]

                // Arrow keys and navigation
                switch code {
                case 65: return .up      // ESC [ A
                case 66: return .down    // ESC [ B
                case 67: return .right   // ESC [ C
                case 68: return .left    // ESC [ D
                case 72: return .home    // ESC [ H
                case 70: return .end     // ESC [ F
                default: break
                }

                // Extended sequences (ESC [ n ~)
                if bytes.count >= 4 && bytes[3] == 126 { // '~'
                    switch code {
                    case 49: return .home     // ESC [ 1 ~
                    case 50: return .insert   // ESC [ 2 ~
                    case 51: return .delete   // ESC [ 3 ~
                    case 52: return .end      // ESC [ 4 ~
                    case 53: return .pageUp   // ESC [ 5 ~
                    case 54: return .pageDown // ESC [ 6 ~
                    default: break
                    }
                }

                // Function keys (ESC [ 1 n ~)
                if bytes.count >= 5 && bytes[2] == 49 && bytes[4] == 126 {
                    switch bytes[3] {
                    case 53: return .f5  // ESC [ 1 5 ~
                    case 55: return .f6  // ESC [ 1 7 ~
                    case 56: return .f7  // ESC [ 1 8 ~
                    case 57: return .f8  // ESC [ 1 9 ~
                    default: break
                    }
                }

                // More function keys (ESC [ 2 n ~)
                if bytes.count >= 5 && bytes[2] == 50 && bytes[4] == 126 {
                    switch bytes[3] {
                    case 48: return .f9   // ESC [ 2 0 ~
                    case 49: return .f10  // ESC [ 2 1 ~
                    case 51: return .f11  // ESC [ 2 3 ~
                    case 52: return .f12  // ESC [ 2 4 ~
                    default: break
                    }
                }
            }
        }

        // SS3 sequences (ESC O) - alternative function keys
        if bytes.count >= 3 && bytes[1] == 79 { // 'O'
            switch bytes[2] {
            case 80: return .f1  // ESC O P
            case 81: return .f2  // ESC O Q
            case 82: return .f3  // ESC O R
            case 83: return .f4  // ESC O S
            case 72: return .home // ESC O H
            case 70: return .end  // ESC O F
            default: break
            }
        }

        return .escape
    }
}
