// TUICore - Text styling attributes

/// Text style attributes for rendering
public struct TextStyle: Equatable, Hashable, Sendable {
    public var bold: Bool
    public var italic: Bool
    public var underline: Bool
    public var strikethrough: Bool
    public var inverse: Bool
    public var dim: Bool
    public var foreground: Color?
    public var background: Color?

    public init(
        bold: Bool = false,
        italic: Bool = false,
        underline: Bool = false,
        strikethrough: Bool = false,
        inverse: Bool = false,
        dim: Bool = false,
        foreground: Color? = nil,
        background: Color? = nil
    ) {
        self.bold = bold
        self.italic = italic
        self.underline = underline
        self.strikethrough = strikethrough
        self.inverse = inverse
        self.dim = dim
        self.foreground = foreground
        self.background = background
    }

    public static let `default` = TextStyle()

    public static let bold = TextStyle(bold: true)
    public static let italic = TextStyle(italic: true)
    public static let underline = TextStyle(underline: true)

    /// Merge with another style (other takes precedence for colors)
    public func merging(with other: TextStyle) -> TextStyle {
        TextStyle(
            bold: other.bold || self.bold,
            italic: other.italic || self.italic,
            underline: other.underline || self.underline,
            strikethrough: other.strikethrough || self.strikethrough,
            inverse: other.inverse || self.inverse,
            dim: other.dim || self.dim,
            foreground: other.foreground ?? self.foreground,
            background: other.background ?? self.background
        )
    }

    /// Create style with foreground color
    public static func foreground(_ color: Color) -> TextStyle {
        TextStyle(foreground: color)
    }

    /// Create style with background color
    public static func background(_ color: Color) -> TextStyle {
        TextStyle(background: color)
    }
}
