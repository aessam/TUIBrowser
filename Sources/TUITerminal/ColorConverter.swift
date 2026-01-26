// TUITerminal - Color Conversion Utilities

import TUICore
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Terminal color support levels
public enum ColorSupport: Sendable, Equatable {
    case none
    case ansi16
    case ansi256
    case trueColor
}

/// Converts TUICore.Color to ANSI color codes
public struct ColorConverter {

    /// Convert RGB color to nearest ANSI 16 color
    /// - Parameter color: The RGB color to convert
    /// - Returns: The nearest ANSIColor
    public static func toANSI16(_ color: Color) -> ANSIColor {
        let r = Int(color.r)
        let g = Int(color.g)
        let b = Int(color.b)

        // Check for grayscale
        let isGray = abs(r - g) < 30 && abs(g - b) < 30 && abs(r - b) < 30

        if isGray {
            let avg = (r + g + b) / 3
            if avg < 40 {
                return .black
            } else if avg < 140 {
                return .brightBlack // Dark to mid-gray
            } else if avg < 220 {
                return .white // Light gray
            } else {
                return .brightWhite // Very light/white
            }
        }

        // Determine which color channel is dominant
        let isBright = r > 170 || g > 170 || b > 170

        // Determine the color
        let hasRed = r > 100
        let hasGreen = g > 100
        let hasBlue = b > 100

        if hasRed && hasGreen && hasBlue {
            return isBright ? .brightWhite : .white
        } else if hasRed && hasGreen {
            return isBright ? .brightYellow : .yellow
        } else if hasRed && hasBlue {
            return isBright ? .brightMagenta : .magenta
        } else if hasGreen && hasBlue {
            return isBright ? .brightCyan : .cyan
        } else if hasRed {
            return isBright ? .brightRed : .red
        } else if hasGreen {
            return isBright ? .brightGreen : .green
        } else if hasBlue {
            return isBright ? .brightBlue : .blue
        }

        return .black
    }

    /// Convert RGB color to ANSI 256 color code
    /// - Parameter color: The RGB color to convert
    /// - Returns: The ANSI 256 color code (0-255)
    public static func toANSI256(_ color: Color) -> UInt8 {
        let r = Int(color.r)
        let g = Int(color.g)
        let b = Int(color.b)

        // Check if it's a grayscale color
        let isGray = abs(r - g) < 10 && abs(g - b) < 10 && abs(r - b) < 10

        if isGray {
            let avg = (r + g + b) / 3
            if avg < 8 {
                return 16 // Black
            } else if avg > 248 {
                return 231 // White
            }
            // Grayscale ramp: 232-255 (24 shades)
            // Each step is approximately 10 units (256/24 ≈ 10.67)
            let grayIndex = (avg - 8) / 10
            return UInt8(min(255, 232 + grayIndex))
        }

        // Convert to 6x6x6 color cube (codes 16-231)
        // Each axis has 6 values: 0, 95, 135, 175, 215, 255
        let levels: [Int] = [0, 95, 135, 175, 215, 255]

        func nearest(_ value: Int) -> Int {
            var minDist = Int.max
            var nearest = 0
            for (i, level) in levels.enumerated() {
                let dist = abs(value - level)
                if dist < minDist {
                    minDist = dist
                    nearest = i
                }
            }
            return nearest
        }

        let ri = nearest(r)
        let gi = nearest(g)
        let bi = nearest(b)

        // Formula: 16 + 36*r + 6*g + b
        return UInt8(16 + 36 * ri + 6 * gi + bi)
    }

    /// Detect terminal color support from environment
    /// - Returns: The detected color support level
    public static func detectColorSupport() -> ColorSupport {
        // Check COLORTERM environment variable first
        if let colorterm = getEnvironmentVariable("COLORTERM") {
            if colorterm == "truecolor" || colorterm == "24bit" {
                return .trueColor
            }
        }

        // Check TERM environment variable
        if let term = getEnvironmentVariable("TERM") {
            if term.contains("256color") || term.contains("256-color") {
                return .ansi256
            }
            if term.contains("color") || term == "xterm" || term == "screen" {
                return .ansi16
            }
            if term == "dumb" {
                return .none
            }
        }

        // Check for common terminal emulators that support true color
        if let termProgram = getEnvironmentVariable("TERM_PROGRAM") {
            let trueColorTerminals = ["iTerm.app", "Hyper", "Apple_Terminal", "vscode"]
            if trueColorTerminals.contains(where: { termProgram.contains($0) }) {
                return .trueColor
            }
        }

        // Default to 16 colors if we have a terminal
        if isatty(1) != 0 {
            return .ansi16
        }

        return .none
    }

    /// Get environment variable value
    private static func getEnvironmentVariable(_ name: String) -> String? {
        guard let value = getenv(name) else { return nil }
        return String(cString: value)
    }
}
