// TUICore Tests

import Testing
@testable import TUICore

@Suite("Point Tests")
struct PointTests {
    @Test func testPointCreation() {
        let point = Point(x: 10, y: 20)
        #expect(point.x == 10)
        #expect(point.y == 20)
    }

    @Test func testPointZero() {
        let point = Point.zero
        #expect(point.x == 0)
        #expect(point.y == 0)
    }

    @Test func testPointEquality() {
        let p1 = Point(x: 5, y: 10)
        let p2 = Point(x: 5, y: 10)
        let p3 = Point(x: 5, y: 11)
        #expect(p1 == p2)
        #expect(p1 != p3)
    }
}

@Suite("Size Tests")
struct SizeTests {
    @Test func testSizeCreation() {
        let size = Size(width: 100, height: 50)
        #expect(size.width == 100)
        #expect(size.height == 50)
    }

    @Test func testSizeZero() {
        let size = Size.zero
        #expect(size.width == 0)
        #expect(size.height == 0)
    }
}

@Suite("Rect Tests")
struct RectTests {
    @Test func testRectCreation() {
        let rect = Rect(x: 10, y: 20, width: 100, height: 50)
        #expect(rect.x == 10)
        #expect(rect.y == 20)
        #expect(rect.width == 100)
        #expect(rect.height == 50)
    }

    @Test func testRectBounds() {
        let rect = Rect(x: 10, y: 20, width: 100, height: 50)
        #expect(rect.minX == 10)
        #expect(rect.minY == 20)
        #expect(rect.maxX == 110)
        #expect(rect.maxY == 70)
    }

    @Test func testRectContains() {
        let rect = Rect(x: 0, y: 0, width: 100, height: 100)
        #expect(rect.contains(Point(x: 50, y: 50)))
        #expect(rect.contains(Point(x: 0, y: 0)))
        #expect(!rect.contains(Point(x: 100, y: 100)))  // exclusive
        #expect(!rect.contains(Point(x: -1, y: 50)))
    }

    @Test func testRectInset() {
        let rect = Rect(x: 0, y: 0, width: 100, height: 100)
        let inset = rect.inset(by: EdgeInsets(all: 10))
        #expect(inset.x == 10)
        #expect(inset.y == 10)
        #expect(inset.width == 80)
        #expect(inset.height == 80)
    }
}

@Suite("EdgeInsets Tests")
struct EdgeInsetsTests {
    @Test func testEdgeInsetsCreation() {
        let insets = EdgeInsets(top: 1, right: 2, bottom: 3, left: 4)
        #expect(insets.top == 1)
        #expect(insets.right == 2)
        #expect(insets.bottom == 3)
        #expect(insets.left == 4)
    }

    @Test func testEdgeInsetsAll() {
        let insets = EdgeInsets(all: 10)
        #expect(insets.top == 10)
        #expect(insets.right == 10)
        #expect(insets.bottom == 10)
        #expect(insets.left == 10)
    }

    @Test func testEdgeInsetsHorizontalVertical() {
        let insets = EdgeInsets(horizontal: 5, vertical: 10)
        #expect(insets.horizontal == 10)  // left + right
        #expect(insets.vertical == 20)    // top + bottom
    }
}
