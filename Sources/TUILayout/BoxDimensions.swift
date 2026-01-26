// TUILayout - Box Dimensions
//
// CSS box model dimensions (content, padding, border, margin).

import TUICore
import TUIStyle

/// CSS box model dimensions
public struct BoxDimensions: Equatable, Sendable {
    /// Content area rectangle
    public var content: Rect

    /// Padding (inside border)
    public var padding: EdgeInsets

    /// Border widths
    public var border: EdgeInsets

    /// Margin (outside border)
    public var margin: EdgeInsets

    // MARK: - Initialization

    public init(
        content: Rect = .zero,
        padding: EdgeInsets = .zero,
        border: EdgeInsets = .zero,
        margin: EdgeInsets = .zero
    ) {
        self.content = content
        self.padding = padding
        self.border = border
        self.margin = margin
    }

    // MARK: - Box Calculations

    /// Padding box = content + padding
    public func paddingBox() -> Rect {
        Rect(
            x: content.x - padding.left,
            y: content.y - padding.top,
            width: content.width + padding.horizontal,
            height: content.height + padding.vertical
        )
    }

    /// Border box = content + padding + border
    public func borderBox() -> Rect {
        let padBox = paddingBox()
        return Rect(
            x: padBox.x - border.left,
            y: padBox.y - border.top,
            width: padBox.width + border.horizontal,
            height: padBox.height + border.vertical
        )
    }

    /// Margin box = content + padding + border + margin
    public func marginBox() -> Rect {
        let bordBox = borderBox()
        return Rect(
            x: bordBox.x - margin.left,
            y: bordBox.y - margin.top,
            width: bordBox.width + margin.horizontal,
            height: bordBox.height + margin.vertical
        )
    }

    // MARK: - Dimension Helpers

    /// Total width including padding, border, and margin
    public var totalWidth: Int {
        content.width + padding.horizontal + border.horizontal + margin.horizontal
    }

    /// Total height including padding, border, and margin
    public var totalHeight: Int {
        content.height + padding.vertical + border.vertical + margin.vertical
    }

    /// Set content width (adjusts box size)
    public mutating func setContentWidth(_ width: Int) {
        content = Rect(
            x: content.x,
            y: content.y,
            width: max(0, width),
            height: content.height
        )
    }

    /// Set content height (adjusts box size)
    public mutating func setContentHeight(_ height: Int) {
        content = Rect(
            x: content.x,
            y: content.y,
            width: content.width,
            height: max(0, height)
        )
    }

    /// Position the box at a specific origin
    public mutating func positionAt(x: Int, y: Int) {
        let offsetX = x + margin.left + border.left + padding.left
        let offsetY = y + margin.top + border.top + padding.top
        content = Rect(
            x: offsetX,
            y: offsetY,
            width: content.width,
            height: content.height
        )
    }

    // MARK: - Static Factory

    /// Create box dimensions from computed style
    public static func from(
        style: ComputedStyle,
        contentWidth: Int,
        contentHeight: Int
    ) -> BoxDimensions {
        BoxDimensions(
            content: Rect(x: 0, y: 0, width: contentWidth, height: contentHeight),
            padding: style.padding,
            border: .zero,  // Terminal doesn't have pixel borders
            margin: style.margin
        )
    }
}

// MARK: - EdgeInsets Extension for Box Model

extension EdgeInsets {
    /// Create edge insets that collapse margins (CSS margin collapsing)
    public func collapsingWith(_ other: EdgeInsets) -> EdgeInsets {
        EdgeInsets(
            top: max(top, other.top),
            right: max(right, other.right),
            bottom: max(bottom, other.bottom),
            left: max(left, other.left)
        )
    }
}
