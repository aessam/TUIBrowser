// TUICore - Keyboard key codes

/// Keyboard key codes for terminal input handling
public enum KeyCode: Equatable, Hashable, Sendable {
    // Printable characters
    case char(Character)

    // Special keys
    case enter
    case tab
    case backspace
    case escape
    case space
    case delete

    // Arrow keys
    case up
    case down
    case left
    case right

    // Navigation keys
    case home
    case end
    case pageUp
    case pageDown
    case insert

    // Function keys
    case f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12

    // Modifier combinations
    case ctrlC
    case ctrlD
    case ctrlZ
    case ctrlA
    case ctrlE
    case ctrlK
    case ctrlU
    case ctrlW
    case ctrlL

    // Unknown or unhandled
    case unknown(UInt8)
}
