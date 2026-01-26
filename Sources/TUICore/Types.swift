// TUICore - Core types used across all modules

/// A point in 2D space (terminal coordinates)
public struct Point: Equatable, Hashable, Sendable {
    public var x: Int
    public var y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }

    public static let zero = Point(x: 0, y: 0)
}

/// A size in 2D space
public struct Size: Equatable, Hashable, Sendable {
    public var width: Int
    public var height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    public static let zero = Size(width: 0, height: 0)
}

/// A rectangle in 2D space
public struct Rect: Equatable, Hashable, Sendable {
    public var origin: Point
    public var size: Size

    public init(origin: Point, size: Size) {
        self.origin = origin
        self.size = size
    }

    public init(x: Int, y: Int, width: Int, height: Int) {
        self.origin = Point(x: x, y: y)
        self.size = Size(width: width, height: height)
    }

    public var x: Int { origin.x }
    public var y: Int { origin.y }
    public var width: Int { size.width }
    public var height: Int { size.height }

    public var minX: Int { origin.x }
    public var minY: Int { origin.y }
    public var maxX: Int { origin.x + size.width }
    public var maxY: Int { origin.y + size.height }

    public static let zero = Rect(origin: .zero, size: .zero)

    public func contains(_ point: Point) -> Bool {
        point.x >= minX && point.x < maxX &&
        point.y >= minY && point.y < maxY
    }

    public func inset(by edges: EdgeInsets) -> Rect {
        Rect(
            x: x + edges.left,
            y: y + edges.top,
            width: max(0, width - edges.left - edges.right),
            height: max(0, height - edges.top - edges.bottom)
        )
    }
}

/// Edge insets (padding/margin)
public struct EdgeInsets: Equatable, Hashable, Sendable {
    public var top: Int
    public var right: Int
    public var bottom: Int
    public var left: Int

    public init(top: Int = 0, right: Int = 0, bottom: Int = 0, left: Int = 0) {
        self.top = top
        self.right = right
        self.bottom = bottom
        self.left = left
    }

    public init(all: Int) {
        self.top = all
        self.right = all
        self.bottom = all
        self.left = all
    }

    public init(horizontal: Int, vertical: Int) {
        self.top = vertical
        self.right = horizontal
        self.bottom = vertical
        self.left = horizontal
    }

    public static let zero = EdgeInsets()

    public var horizontal: Int { left + right }
    public var vertical: Int { top + bottom }
}
