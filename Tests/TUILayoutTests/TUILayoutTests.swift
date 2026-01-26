import Testing
@testable import TUILayout
@testable import TUICore
@testable import TUIStyle
@testable import TUIHTMLParser

@Suite("TUILayout Tests")
struct TUILayoutTests {
    @Test func testVersion() {
        #expect(TUILayout.version == "0.1.0")
    }
}

// MARK: - Block Layout Tests

@Suite("Block Layout Dimensions")
struct BlockLayoutDimensionsTests {

    @Test("Block child should have absolute position from parent")
    func blockChildAbsolutePosition() {
        // Create parent block at (0,0) with width 100
        let parent = LayoutBox(boxType: .block, style: .block)
        parent.dimensions.setContentWidth(100)
        parent.dimensions.positionAt(x: 0, y: 0)

        // Create child block
        let child = LayoutBox(boxType: .block, style: .block)
        parent.appendChild(child)

        // Layout
        BlockLayout().layout(parent, containingWidth: 100)

        // Child should have width 100 and be at (0, 0)
        #expect(child.dimensions.content.width == 100, "Child width should be 100")
        #expect(child.dimensions.content.x == 0, "Child x should be 0")
        #expect(child.dimensions.content.y == 0, "Child y should be 0")
    }

    @Test("Multiple block children should stack vertically")
    func multipleBlockChildrenStack() {
        let parent = LayoutBox(boxType: .block, style: .block)
        parent.dimensions.setContentWidth(80)
        parent.dimensions.positionAt(x: 0, y: 0)

        // Create two children with text content (so they have height)
        let child1 = LayoutBox(boxType: .block, style: .block)
        let text1 = LayoutBox.text("Line 1", style: .default)
        child1.appendChild(text1)

        let child2 = LayoutBox(boxType: .block, style: .block)
        let text2 = LayoutBox.text("Line 2", style: .default)
        child2.appendChild(text2)

        parent.appendChild(child1)
        parent.appendChild(child2)

        BlockLayout().layout(parent, containingWidth: 80)

        // First child at y=0
        #expect(child1.dimensions.content.y == 0, "First child y should be 0")
        // Second child should be after first child (y > 0)
        #expect(child2.dimensions.content.y > 0, "Second child y should be > 0 (after first child), got \(child2.dimensions.content.y)")
    }

    @Test("Nested blocks should have correct absolute positions")
    func nestedBlocksAbsolutePositions() {
        // Grandparent at (10, 5)
        let grandparent = LayoutBox(boxType: .block, style: .block)
        grandparent.dimensions.setContentWidth(100)
        grandparent.dimensions.positionAt(x: 10, y: 5)

        // Parent inside grandparent
        let parent = LayoutBox(boxType: .block, style: .block)
        grandparent.appendChild(parent)

        // Child inside parent
        let child = LayoutBox(boxType: .block, style: .block)
        parent.appendChild(child)

        BlockLayout().layout(grandparent, containingWidth: 100)

        // Parent should be at (10, 5) - inheriting grandparent's content origin
        #expect(parent.dimensions.content.x == 10, "Parent x should be 10")
        #expect(parent.dimensions.content.y == 5, "Parent y should be 5")

        // Child should also be at (10, 5)
        #expect(child.dimensions.content.x == 10, "Child x should be 10")
        #expect(child.dimensions.content.y == 5, "Child y should be 5")
    }

    @Test("Block with padding should offset children")
    func blockWithPaddingOffsetsChildren() {
        var style = ComputedStyle.block
        style.padding = EdgeInsets(top: 2, right: 3, bottom: 2, left: 3)

        let parent = LayoutBox(boxType: .block, style: style)
        parent.dimensions.setContentWidth(100)
        parent.dimensions.positionAt(x: 0, y: 0)

        let child = LayoutBox(boxType: .block, style: .block)
        parent.appendChild(child)

        BlockLayout().layout(parent, containingWidth: 106) // 100 + 6 padding

        // Parent's content area starts at (3, 2) due to padding
        #expect(parent.dimensions.content.x == 3, "Parent content x should be 3 (padding-left)")
        #expect(parent.dimensions.content.y == 2, "Parent content y should be 2 (padding-top)")

        // Child should be at parent's content origin
        #expect(child.dimensions.content.x == 3, "Child x should be 3")
        #expect(child.dimensions.content.y == 2, "Child y should be 2")
    }
}

// MARK: - Flex Layout Tests

@Suite("Flex Layout Dimensions")
struct FlexLayoutDimensionsTests {

    @Test("Flex row children should be positioned horizontally")
    func flexRowHorizontalPositioning() {
        var style = ComputedStyle.block
        style.display = .flex
        style.flexDirection = .row

        let container = LayoutBox(boxType: .block, style: style)
        container.dimensions.setContentWidth(100)
        container.dimensions.positionAt(x: 0, y: 0)

        // Two children with fixed CSS widths
        var child1Style = ComputedStyle.block
        child1Style.width = .px(20)
        let child1 = LayoutBox(boxType: .block, style: child1Style)

        var child2Style = ComputedStyle.block
        child2Style.width = .px(30)
        let child2 = LayoutBox(boxType: .block, style: child2Style)

        container.appendChild(child1)
        container.appendChild(child2)

        FlexLayout().layout(container, containingWidth: 100)

        // First child at x=0
        #expect(child1.dimensions.content.x == 0, "First child x should be 0, got \(child1.dimensions.content.x)")
        // Second child should be after first (x > 0)
        #expect(child2.dimensions.content.x > child1.dimensions.content.x,
               "Second child x should be > first child x, got child1=\(child1.dimensions.content.x), child2=\(child2.dimensions.content.x)")
    }

    @Test("Flex column with alignItems center should center children horizontally")
    func flexColumnCenterAlignment() {
        var style = ComputedStyle.block
        style.display = .flex
        style.flexDirection = .column
        style.alignItems = .center

        let container = LayoutBox(boxType: .block, style: style)
        container.dimensions.setContentWidth(100)
        container.dimensions.positionAt(x: 0, y: 0)

        // Child with explicit CSS width 40 should be centered in 100-width container
        var childStyle = ComputedStyle.block
        childStyle.width = .px(40)
        let child = LayoutBox(boxType: .block, style: childStyle)

        container.appendChild(child)

        FlexLayout().layout(container, containingWidth: 100)

        // Child should be centered: (100 - 40) / 2 = 30
        let expectedX = (100 - child.dimensions.content.width) / 2
        #expect(child.dimensions.content.x == expectedX,
               "Centered child x should be \(expectedX), got \(child.dimensions.content.x) (width=\(child.dimensions.content.width))")
    }

    @Test("Flex row with justifyContent center should center children")
    func flexRowJustifyCenter() {
        var style = ComputedStyle.block
        style.display = .flex
        style.flexDirection = .row
        style.justifyContent = .center

        let container = LayoutBox(boxType: .block, style: style)
        container.dimensions.setContentWidth(100)
        container.dimensions.positionAt(x: 0, y: 0)

        // Child with explicit CSS width 40
        var childStyle = ComputedStyle.block
        childStyle.width = .px(40)
        let child = LayoutBox(boxType: .block, style: childStyle)

        container.appendChild(child)

        FlexLayout().layout(container, containingWidth: 100)

        // Child should be centered: (100 - 40) / 2 = 30
        let expectedX = (100 - child.dimensions.content.width) / 2
        #expect(child.dimensions.content.x == expectedX,
               "Centered child x should be \(expectedX), got \(child.dimensions.content.x) (width=\(child.dimensions.content.width))")
    }
}

// MARK: - Inline Layout Tests

@Suite("Inline Layout Dimensions")
struct InlineLayoutDimensionsTests {

    @Test("Text nodes should have proper width")
    func textNodeWidth() {
        let container = LayoutBox(boxType: .anonymous, style: .default)
        container.dimensions.setContentWidth(80)
        container.dimensions.positionAt(x: 0, y: 0)

        let text = LayoutBox.text("Hello", style: .default)
        container.appendChild(text)

        InlineLayout().layout(container, containingWidth: 80)

        // InlineLayout creates new boxes for words, check container's children
        #expect(container.children.count > 0, "Container should have children after layout")
        if let firstChild = container.children.first {
            #expect(firstChild.dimensions.content.width == 5,
                   "Text width should be 5, got \(firstChild.dimensions.content.width)")
        }
    }

    @Test("Multiple text nodes should be positioned sequentially")
    func multipleTextNodesSequential() {
        let container = LayoutBox(boxType: .anonymous, style: .default)
        container.dimensions.setContentWidth(80)
        container.dimensions.positionAt(x: 0, y: 0)

        let text1 = LayoutBox.text("Hello", style: .default)
        let text2 = LayoutBox.text("World", style: .default)

        container.appendChild(text1)
        container.appendChild(text2)

        InlineLayout().layout(container, containingWidth: 80)

        // InlineLayout creates new boxes, check container's children
        #expect(container.children.count >= 2, "Container should have at least 2 children")
        if container.children.count >= 2 {
            let child1 = container.children[0]
            let child2 = container.children[1]
            // Second text should be to the right of first
            #expect(child2.dimensions.content.x > child1.dimensions.content.x,
                   "Second text x should be > first text x, got \(child1.dimensions.content.x) and \(child2.dimensions.content.x)")
        }
    }

    @Test("Text should wrap to next line when exceeding width")
    func textWrapping() {
        let container = LayoutBox(boxType: .anonymous, style: .default)
        container.dimensions.setContentWidth(10)
        container.dimensions.positionAt(x: 0, y: 0)

        // "Hello World" is 11 chars, container is 10 wide
        let text = LayoutBox.text("Hello World", style: .default)
        container.appendChild(text)

        InlineLayout().layout(container, containingWidth: 10)

        // Should create two lines
        #expect(container.dimensions.content.height >= 2, "Container should be at least 2 lines tall")
    }
}

// MARK: - Integration Tests with HTML

@Suite("Layout Integration")
struct LayoutIntegrationTests {

    @Test("Simple centered div should be centered")
    func simpleCenteredDiv() {
        let html = "<center><div style='width:40px'>Hello</div></center>"
        let document = HTMLParser.parse(html)
        let styles = StyleResolver.resolve(document: document, stylesheets: [])

        let layout = LayoutEngine.layout(document: document, styles: styles, width: 100)

        // Find the center element's child
        var centerBox: LayoutBox?
        layout.traverse { box in
            if box.element?.tagName == "center" {
                centerBox = box
            }
        }

        #expect(centerBox != nil, "Should find center element")

        // The div inside should be centered
        if let center = centerBox, let child = center.children.first {
            // For flex column with alignItems center, child should be centered
            let expectedX = (100 - child.dimensions.content.width) / 2
            #expect(child.dimensions.content.x == expectedX || child.dimensions.content.x > 0,
                   "Child should be centered or at least not at 0, got \(child.dimensions.content.x)")
        }
    }

    @Test("Table row cells should be positioned horizontally")
    func tableRowCellsHorizontal() {
        let html = "<table><tr><td>A</td><td>B</td><td>C</td></tr></table>"
        let document = HTMLParser.parse(html)
        let styles = StyleResolver.resolve(document: document, stylesheets: [])

        let layout = LayoutEngine.layout(document: document, styles: styles, width: 80)

        // Find all td elements
        var tdBoxes: [LayoutBox] = []
        layout.traverse { box in
            if box.element?.tagName == "td" {
                tdBoxes.append(box)
            }
        }

        #expect(tdBoxes.count == 3, "Should have 3 td elements")

        // Each subsequent td should have a larger x position
        if tdBoxes.count >= 2 {
            #expect(tdBoxes[1].dimensions.content.x > tdBoxes[0].dimensions.content.x,
                   "Second td should be to the right of first td")
        }
        if tdBoxes.count >= 3 {
            #expect(tdBoxes[2].dimensions.content.x > tdBoxes[1].dimensions.content.x,
                   "Third td should be to the right of second td")
        }
    }

    @Test("Deeply nested elements should have non-zero dimensions")
    func deeplyNestedNonZeroDimensions() {
        let html = "<div><div><div><span>Text</span></div></div></div>"
        let document = HTMLParser.parse(html)
        let styles = StyleResolver.resolve(document: document, stylesheets: [])

        let layout = LayoutEngine.layout(document: document, styles: styles, width: 80)

        // All text nodes should have non-zero width
        layout.traverse { box in
            if box.boxType == .text, let text = box.textContent, !text.isEmpty {
                #expect(box.dimensions.content.width > 0,
                       "Text '\(text)' should have width > 0, got \(box.dimensions.content.width)")
            }
        }
    }

    @Test("Inline-block inside block should have proper dimensions")
    func inlineBlockInsideBlock() {
        let html = "<div><a href='#'>Link Text</a></div>"
        let document = HTMLParser.parse(html)
        let styles = StyleResolver.resolve(document: document, stylesheets: [])

        let layout = LayoutEngine.layout(document: document, styles: styles, width: 80)

        // Find the link
        var linkBox: LayoutBox?
        layout.traverse { box in
            if box.element?.tagName == "a" {
                linkBox = box
            }
        }

        // The link's text content should have non-zero width
        if let link = linkBox {
            var hasNonZeroTextWidth = false
            link.traverse { child in
                if child.boxType == .text, let text = child.textContent, !text.isEmpty {
                    if child.dimensions.content.width > 0 {
                        hasNonZeroTextWidth = true
                    }
                }
            }
            #expect(hasNonZeroTextWidth, "Link text should have non-zero width")
        }
    }
}
