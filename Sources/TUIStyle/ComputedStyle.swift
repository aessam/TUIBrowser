// TUIStyle - Computed Style Types
//
// Defines the computed style values after CSS cascade resolution.

import TUICore

// MARK: - Display Mode

/// CSS display property values
public enum Display: String, Equatable, Hashable, Sendable {
    case block
    case inline
    case inlineBlock = "inline-block"
    case none
    case listItem = "list-item"
    case flex
    case inlineFlex = "inline-flex"

    /// Initialize from CSS keyword
    public init?(keyword: String) {
        switch keyword.lowercased() {
        case "block": self = .block
        case "inline": self = .inline
        case "inline-block": self = .inlineBlock
        case "none": self = .none
        case "list-item": self = .listItem
        case "flex": self = .flex
        case "inline-flex": self = .inlineFlex
        default: return nil
        }
    }

    /// Whether this display type creates a flex container
    public var isFlex: Bool {
        self == .flex || self == .inlineFlex
    }
}

// MARK: - Flexbox Properties

/// CSS flex-direction values
public enum FlexDirection: String, Equatable, Hashable, Sendable {
    case row
    case rowReverse = "row-reverse"
    case column
    case columnReverse = "column-reverse"

    public init?(keyword: String) {
        switch keyword.lowercased() {
        case "row": self = .row
        case "row-reverse": self = .rowReverse
        case "column": self = .column
        case "column-reverse": self = .columnReverse
        default: return nil
        }
    }

    public var isHorizontal: Bool {
        self == .row || self == .rowReverse
    }

    public var isReversed: Bool {
        self == .rowReverse || self == .columnReverse
    }
}

/// CSS justify-content values
public enum JustifyContent: String, Equatable, Hashable, Sendable {
    case flexStart = "flex-start"
    case flexEnd = "flex-end"
    case center
    case spaceBetween = "space-between"
    case spaceAround = "space-around"
    case spaceEvenly = "space-evenly"

    public init?(keyword: String) {
        switch keyword.lowercased() {
        case "flex-start", "start": self = .flexStart
        case "flex-end", "end": self = .flexEnd
        case "center": self = .center
        case "space-between": self = .spaceBetween
        case "space-around": self = .spaceAround
        case "space-evenly": self = .spaceEvenly
        default: return nil
        }
    }
}

/// CSS align-items values
public enum AlignItems: String, Equatable, Hashable, Sendable {
    case flexStart = "flex-start"
    case flexEnd = "flex-end"
    case center
    case baseline
    case stretch

    public init?(keyword: String) {
        switch keyword.lowercased() {
        case "flex-start", "start": self = .flexStart
        case "flex-end", "end": self = .flexEnd
        case "center": self = .center
        case "baseline": self = .baseline
        case "stretch": self = .stretch
        default: return nil
        }
    }
}

/// CSS flex-wrap values
public enum FlexWrap: String, Equatable, Hashable, Sendable {
    case nowrap
    case wrap
    case wrapReverse = "wrap-reverse"

    public init?(keyword: String) {
        switch keyword.lowercased() {
        case "nowrap": self = .nowrap
        case "wrap": self = .wrap
        case "wrap-reverse": self = .wrapReverse
        default: return nil
        }
    }
}

// MARK: - Font Weight

/// CSS font-weight values
public enum FontWeight: Equatable, Hashable, Sendable {
    case normal     // 400
    case bold       // 700
    case lighter
    case bolder
    case weight(Int)

    /// Initialize from CSS value
    public init?(keyword: String) {
        switch keyword.lowercased() {
        case "normal": self = .normal
        case "bold": self = .bold
        case "lighter": self = .lighter
        case "bolder": self = .bolder
        default:
            if let value = Int(keyword) {
                self = .weight(value)
            } else {
                return nil
            }
        }
    }

    /// Numeric weight value
    public var numericValue: Int {
        switch self {
        case .normal: return 400
        case .bold: return 700
        case .lighter: return 100
        case .bolder: return 900
        case .weight(let w): return w
        }
    }

    /// Whether this weight should render as bold in terminal
    public var isBold: Bool {
        numericValue >= 600
    }
}

// MARK: - Text Decoration

/// CSS text-decoration values
public enum TextDecoration: Equatable, Hashable, Sendable {
    case none
    case underline
    case lineThrough
    case overline

    /// Initialize from CSS keyword
    public init?(keyword: String) {
        switch keyword.lowercased() {
        case "none": self = .none
        case "underline": self = .underline
        case "line-through": self = .lineThrough
        case "overline": self = .overline
        default: return nil
        }
    }
}

// MARK: - Font Style

/// CSS font-style values
public enum FontStyle: String, Equatable, Hashable, Sendable {
    case normal
    case italic
    case oblique

    public init?(keyword: String) {
        switch keyword.lowercased() {
        case "normal": self = .normal
        case "italic": self = .italic
        case "oblique": self = .oblique
        default: return nil
        }
    }
}

// MARK: - Text Align

/// CSS text-align values
public enum TextAlign: String, Equatable, Hashable, Sendable {
    case left
    case right
    case center
    case justify

    public init?(keyword: String) {
        switch keyword.lowercased() {
        case "left": self = .left
        case "right": self = .right
        case "center": self = .center
        case "justify": self = .justify
        default: return nil
        }
    }
}

// MARK: - White Space

/// CSS white-space values
public enum WhiteSpace: String, Equatable, Hashable, Sendable {
    case normal
    case nowrap
    case pre
    case preWrap = "pre-wrap"
    case preLine = "pre-line"

    public init?(keyword: String) {
        switch keyword.lowercased() {
        case "normal": self = .normal
        case "nowrap": self = .nowrap
        case "pre": self = .pre
        case "pre-wrap": self = .preWrap
        case "pre-line": self = .preLine
        default: return nil
        }
    }
}

// MARK: - List Style Type

/// CSS list-style-type values
public enum ListStyleType: String, Equatable, Hashable, Sendable {
    case disc
    case circle
    case square
    case decimal
    case none

    public init?(keyword: String) {
        switch keyword.lowercased() {
        case "disc": self = .disc
        case "circle": self = .circle
        case "square": self = .square
        case "decimal": self = .decimal
        case "none": self = .none
        default: return nil
        }
    }

    /// Character representation for terminal
    public var marker: String {
        switch self {
        case .disc: return "•"
        case .circle: return "○"
        case .square: return "▪"
        case .decimal: return ""  // Needs index
        case .none: return ""
        }
    }
}

// MARK: - Computed Style

/// Fully resolved style for a DOM element
public struct ComputedStyle: Equatable, Sendable {
    // Display
    public var display: Display

    // Colors
    public var color: Color
    public var backgroundColor: Color?

    // Font
    public var fontWeight: FontWeight
    public var fontStyle: FontStyle

    // Text
    public var textDecoration: TextDecoration
    public var textAlign: TextAlign
    public var whiteSpace: WhiteSpace

    // Box model
    public var margin: EdgeInsets
    public var padding: EdgeInsets

    // List
    public var listStyleType: ListStyleType

    // Flexbox (only relevant when display is flex/inline-flex)
    public var flexDirection: FlexDirection
    public var justifyContent: JustifyContent
    public var alignItems: AlignItems
    public var flexWrap: FlexWrap
    public var gap: Int  // Simplified: single gap value for both row and column

    // MARK: - Initialization

    public init(
        display: Display = .inline,
        color: Color = .white,
        backgroundColor: Color? = nil,
        fontWeight: FontWeight = .normal,
        fontStyle: FontStyle = .normal,
        textDecoration: TextDecoration = .none,
        textAlign: TextAlign = .left,
        whiteSpace: WhiteSpace = .normal,
        margin: EdgeInsets = .zero,
        padding: EdgeInsets = .zero,
        listStyleType: ListStyleType = .disc,
        flexDirection: FlexDirection = .row,
        justifyContent: JustifyContent = .flexStart,
        alignItems: AlignItems = .stretch,
        flexWrap: FlexWrap = .nowrap,
        gap: Int = 0
    ) {
        self.display = display
        self.color = color
        self.backgroundColor = backgroundColor
        self.fontWeight = fontWeight
        self.fontStyle = fontStyle
        self.textDecoration = textDecoration
        self.textAlign = textAlign
        self.whiteSpace = whiteSpace
        self.margin = margin
        self.padding = padding
        self.listStyleType = listStyleType
        self.flexDirection = flexDirection
        self.justifyContent = justifyContent
        self.alignItems = alignItems
        self.flexWrap = flexWrap
        self.gap = gap
    }

    // MARK: - Default Styles

    /// Default computed style (inline element)
    public static let `default` = ComputedStyle()

    /// Default style for block elements
    public static let block = ComputedStyle(display: .block)

    // MARK: - Style Conversion

    /// Convert to TextStyle for terminal rendering
    public func toTextStyle() -> TextStyle {
        TextStyle(
            bold: fontWeight.isBold,
            italic: fontStyle == .italic,
            underline: textDecoration == .underline,
            strikethrough: textDecoration == .lineThrough,
            inverse: false,
            dim: false,
            foreground: color,
            background: backgroundColor
        )
    }

    /// Create a style inheriting inheritable properties from parent
    public func inherit(from parent: ComputedStyle) -> ComputedStyle {
        var style = self
        // These properties inherit by default in CSS
        style.color = parent.color
        style.fontWeight = parent.fontWeight
        style.fontStyle = parent.fontStyle
        style.textAlign = parent.textAlign
        style.whiteSpace = parent.whiteSpace
        style.listStyleType = parent.listStyleType
        return style
    }
}
