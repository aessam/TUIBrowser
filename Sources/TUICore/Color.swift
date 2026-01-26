// TUICore - Color representation

import Foundation

/// RGB color representation
public struct Color: Equatable, Hashable, Sendable {
    public var r: UInt8
    public var g: UInt8
    public var b: UInt8
    public var a: UInt8

    public init(r: UInt8, g: UInt8, b: UInt8, a: UInt8 = 255) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    // Common colors
    public static let black = Color(r: 0, g: 0, b: 0)
    public static let white = Color(r: 255, g: 255, b: 255)
    public static let red = Color(r: 255, g: 0, b: 0)
    public static let green = Color(r: 0, g: 128, b: 0)
    public static let blue = Color(r: 0, g: 0, b: 255)
    public static let yellow = Color(r: 255, g: 255, b: 0)
    public static let cyan = Color(r: 0, g: 255, b: 255)
    public static let magenta = Color(r: 255, g: 0, b: 255)
    public static let gray = Color(r: 128, g: 128, b: 128)
    public static let darkGray = Color(r: 64, g: 64, b: 64)
    public static let lightGray = Color(r: 192, g: 192, b: 192)
    public static let orange = Color(r: 255, g: 165, b: 0)
    public static let purple = Color(r: 128, g: 0, b: 128)
    public static let brown = Color(r: 165, g: 42, b: 42)
    public static let transparent = Color(r: 0, g: 0, b: 0, a: 0)

    /// Parse hex color string like "#FF0000" or "FF0000"
    public static func fromHex(_ hex: String) -> Color? {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexString.hasPrefix("#") {
            hexString.removeFirst()
        }

        guard hexString.count == 3 || hexString.count == 6 || hexString.count == 8 else {
            return nil
        }

        // Expand 3-char hex to 6-char
        if hexString.count == 3 {
            hexString = hexString.map { "\($0)\($0)" }.joined()
        }

        var rgbValue: UInt64 = 0
        guard Scanner(string: hexString).scanHexInt64(&rgbValue) else { return nil }

        if hexString.count == 6 {
            return Color(
                r: UInt8((rgbValue & 0xFF0000) >> 16),
                g: UInt8((rgbValue & 0x00FF00) >> 8),
                b: UInt8(rgbValue & 0x0000FF)
            )
        } else {
            return Color(
                r: UInt8((rgbValue & 0xFF000000) >> 24),
                g: UInt8((rgbValue & 0x00FF0000) >> 16),
                b: UInt8((rgbValue & 0x0000FF00) >> 8),
                a: UInt8(rgbValue & 0x000000FF)
            )
        }
    }

    /// Parse CSS color name
    public static func fromName(_ name: String) -> Color? {
        switch name.lowercased() {
        case "black": return .black
        case "white": return .white
        case "red": return .red
        case "green": return .green
        case "blue": return .blue
        case "yellow": return .yellow
        case "cyan", "aqua": return .cyan
        case "magenta", "fuchsia": return .magenta
        case "gray", "grey": return .gray
        case "darkgray", "darkgrey": return .darkGray
        case "lightgray", "lightgrey": return .lightGray
        case "orange": return .orange
        case "purple": return .purple
        case "brown": return .brown
        case "transparent": return .transparent
        case "silver": return Color(r: 192, g: 192, b: 192)
        case "maroon": return Color(r: 128, g: 0, b: 0)
        case "olive": return Color(r: 128, g: 128, b: 0)
        case "lime": return Color(r: 0, g: 255, b: 0)
        case "teal": return Color(r: 0, g: 128, b: 128)
        case "navy": return Color(r: 0, g: 0, b: 128)
        default: return nil
        }
    }

    /// Convert to hex string
    public func toHex(includeAlpha: Bool = false) -> String {
        if includeAlpha {
            return String(format: "#%02X%02X%02X%02X", r, g, b, a)
        } else {
            return String(format: "#%02X%02X%02X", r, g, b)
        }
    }

    /// Blend with another color
    public func blend(with other: Color, ratio: Double) -> Color {
        let ratio = max(0, min(1, ratio))
        let inverse = 1 - ratio
        return Color(
            r: UInt8(Double(r) * inverse + Double(other.r) * ratio),
            g: UInt8(Double(g) * inverse + Double(other.g) * ratio),
            b: UInt8(Double(b) * inverse + Double(other.b) * ratio),
            a: UInt8(Double(a) * inverse + Double(other.a) * ratio)
        )
    }

    /// Lighten the color
    public func lightened(by amount: Double = 0.2) -> Color {
        blend(with: .white, ratio: amount)
    }

    /// Darken the color
    public func darkened(by amount: Double = 0.2) -> Color {
        blend(with: .black, ratio: amount)
    }
}
