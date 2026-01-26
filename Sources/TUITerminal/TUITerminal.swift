// TUITerminal - Terminal I/O module
// Raw mode, input handling, ANSI escape codes
//
// This module provides:
// - RawMode: Terminal raw mode management
// - TerminalSize: Terminal dimension detection
// - ANSICode: ANSI escape sequence builder
// - ColorConverter: RGB to ANSI color conversion
// - TerminalInput: Keyboard input handling
// - TerminalOutput: Buffered terminal output
// - SignalHandler: Terminal signal handling
// - Canvas: Character cell grid for rendering

import TUICore

/// Terminal module version and re-exports
public enum TUITerminal {
    public static let version = "0.1.0"
}

// Re-export TUICore types for convenience
public typealias Point = TUICore.Point
public typealias Size = TUICore.Size
public typealias Rect = TUICore.Rect
public typealias Color = TUICore.Color
public typealias TextStyle = TUICore.TextStyle
public typealias KeyCode = TUICore.KeyCode
