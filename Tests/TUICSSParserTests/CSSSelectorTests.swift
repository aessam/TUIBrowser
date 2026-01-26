import Testing
@testable import TUICSSParser

@Suite("CSS Selector Tests")
struct CSSSelectorTests {

    // MARK: - Simple Selectors

    @Test func testParseTagSelector() {
        let selector = CSSParser.parseSelector("div")

        #expect(selector != nil)
        #expect(selector?.components.count == 1)
        #expect(selector?.components[0].0.tagName == "div")
        #expect(selector?.components[0].0.id == nil)
        #expect(selector?.components[0].0.classes.isEmpty == true)
    }

    @Test func testParseClassSelector() {
        let selector = CSSParser.parseSelector(".my-class")

        #expect(selector != nil)
        #expect(selector?.components.count == 1)
        #expect(selector?.components[0].0.tagName == nil)
        #expect(selector?.components[0].0.classes == ["my-class"])
    }

    @Test func testParseIdSelector() {
        let selector = CSSParser.parseSelector("#my-id")

        #expect(selector != nil)
        #expect(selector?.components.count == 1)
        #expect(selector?.components[0].0.id == "my-id")
    }

    @Test func testParseUniversalSelector() {
        let selector = CSSParser.parseSelector("*")

        #expect(selector != nil)
        #expect(selector?.components.count == 1)
        #expect(selector?.components[0].0.tagName == "*")
    }

    // MARK: - Compound Selectors

    @Test func testParseTagWithClass() {
        let selector = CSSParser.parseSelector("div.container")

        #expect(selector != nil)
        #expect(selector?.components.count == 1)
        #expect(selector?.components[0].0.tagName == "div")
        #expect(selector?.components[0].0.classes == ["container"])
    }

    @Test func testParseTagWithId() {
        let selector = CSSParser.parseSelector("div#main")

        #expect(selector != nil)
        #expect(selector?.components.count == 1)
        #expect(selector?.components[0].0.tagName == "div")
        #expect(selector?.components[0].0.id == "main")
    }

    @Test func testParseTagWithClassAndId() {
        let selector = CSSParser.parseSelector("div.container#main")

        #expect(selector != nil)
        #expect(selector?.components.count == 1)
        #expect(selector?.components[0].0.tagName == "div")
        #expect(selector?.components[0].0.classes == ["container"])
        #expect(selector?.components[0].0.id == "main")
    }

    @Test func testParseMultipleClasses() {
        let selector = CSSParser.parseSelector(".class1.class2.class3")

        #expect(selector != nil)
        #expect(selector?.components.count == 1)
        #expect(selector?.components[0].0.classes.contains("class1") == true)
        #expect(selector?.components[0].0.classes.contains("class2") == true)
        #expect(selector?.components[0].0.classes.contains("class3") == true)
    }

    @Test func testParseTagWithMultipleClasses() {
        let selector = CSSParser.parseSelector("p.intro.highlight")

        #expect(selector != nil)
        #expect(selector?.components[0].0.tagName == "p")
        #expect(selector?.components[0].0.classes.count == 2)
        #expect(selector?.components[0].0.classes.contains("intro") == true)
        #expect(selector?.components[0].0.classes.contains("highlight") == true)
    }

    // MARK: - Combinator Selectors

    @Test func testParseDescendantCombinator() {
        let selector = CSSParser.parseSelector("div p")

        #expect(selector != nil)
        #expect(selector?.components.count == 2)
        #expect(selector?.components[0].0.tagName == "div")
        #expect(selector?.components[0].1 == .descendant)
        #expect(selector?.components[1].0.tagName == "p")
    }

    @Test func testParseChildCombinator() {
        let selector = CSSParser.parseSelector("div > p")

        #expect(selector != nil)
        #expect(selector?.components.count == 2)
        #expect(selector?.components[0].0.tagName == "div")
        #expect(selector?.components[0].1 == .child)
        #expect(selector?.components[1].0.tagName == "p")
    }

    @Test func testParseAdjacentSiblingCombinator() {
        let selector = CSSParser.parseSelector("h1 + p")

        #expect(selector != nil)
        #expect(selector?.components.count == 2)
        #expect(selector?.components[0].0.tagName == "h1")
        #expect(selector?.components[0].1 == .adjacentSibling)
        #expect(selector?.components[1].0.tagName == "p")
    }

    @Test func testParseGeneralSiblingCombinator() {
        let selector = CSSParser.parseSelector("h1 ~ p")

        #expect(selector != nil)
        #expect(selector?.components.count == 2)
        #expect(selector?.components[0].0.tagName == "h1")
        #expect(selector?.components[0].1 == .generalSibling)
        #expect(selector?.components[1].0.tagName == "p")
    }

    @Test func testParseMultipleCombinators() {
        let selector = CSSParser.parseSelector("div > ul li")

        #expect(selector != nil)
        #expect(selector?.components.count == 3)
        #expect(selector?.components[0].0.tagName == "div")
        #expect(selector?.components[0].1 == .child)
        #expect(selector?.components[1].0.tagName == "ul")
        #expect(selector?.components[1].1 == .descendant)
        #expect(selector?.components[2].0.tagName == "li")
    }

    @Test func testParseComplexSelector() {
        let selector = CSSParser.parseSelector("div.container > ul#nav li.item")

        #expect(selector != nil)
        #expect(selector?.components.count == 3)
        #expect(selector?.components[0].0.tagName == "div")
        #expect(selector?.components[0].0.classes == ["container"])
        #expect(selector?.components[0].1 == .child)
        #expect(selector?.components[1].0.tagName == "ul")
        #expect(selector?.components[1].0.id == "nav")
        #expect(selector?.components[1].1 == .descendant)
        #expect(selector?.components[2].0.tagName == "li")
        #expect(selector?.components[2].0.classes == ["item"])
    }

    // MARK: - Specificity

    @Test func testSpecificityTypeSelector() {
        let selector = CSSParser.parseSelector("div")

        #expect(selector?.specificity == Specificity(a: 0, b: 0, c: 1))
    }

    @Test func testSpecificityClassSelector() {
        let selector = CSSParser.parseSelector(".class")

        #expect(selector?.specificity == Specificity(a: 0, b: 1, c: 0))
    }

    @Test func testSpecificityIdSelector() {
        let selector = CSSParser.parseSelector("#id")

        #expect(selector?.specificity == Specificity(a: 1, b: 0, c: 0))
    }

    @Test func testSpecificityCompoundSelector() {
        let selector = CSSParser.parseSelector("div.class#id")

        #expect(selector?.specificity == Specificity(a: 1, b: 1, c: 1))
    }

    @Test func testSpecificityMultipleClasses() {
        let selector = CSSParser.parseSelector(".a.b.c")

        #expect(selector?.specificity == Specificity(a: 0, b: 3, c: 0))
    }

    @Test func testSpecificityCombinedSelectors() {
        let selector = CSSParser.parseSelector("div p span")

        #expect(selector?.specificity == Specificity(a: 0, b: 0, c: 3))
    }

    @Test func testSpecificityComplexSelector() {
        // div#main .container ul.nav li
        let selector = CSSParser.parseSelector("div#main .container ul.nav li")

        // 1 id (#main) + 2 classes (.container, .nav) + 4 types (div, ul, li)
        // Wait, .container has no type so: 1 id + 2 classes + 3 types (div, ul, li)
        #expect(selector?.specificity == Specificity(a: 1, b: 2, c: 3))
    }

    @Test func testSpecificityUniversalSelector() {
        let selector = CSSParser.parseSelector("*")

        #expect(selector?.specificity == Specificity(a: 0, b: 0, c: 0))
    }

    // MARK: - Specificity Comparison

    @Test func testSpecificityComparison() {
        let low = Specificity(a: 0, b: 0, c: 1)      // div
        let medium = Specificity(a: 0, b: 1, c: 0)  // .class
        let high = Specificity(a: 1, b: 0, c: 0)    // #id

        #expect(low < medium)
        #expect(medium < high)
        #expect(low < high)
    }

    @Test func testSpecificityEqualityWithDifferentComponents() {
        let a = Specificity(a: 0, b: 1, c: 1)  // .class div
        let b = Specificity(a: 0, b: 0, c: 11) // 11 type selectors

        // 0,1,1 > 0,0,11 because b component is higher
        #expect(a > b)
    }

    @Test func testSpecificityEquality() {
        let a = Specificity(a: 1, b: 2, c: 3)
        let b = Specificity(a: 1, b: 2, c: 3)

        #expect(a == b)
        #expect(!(a < b))
        #expect(!(a > b))
    }
}

@Suite("Specificity Tests")
struct SpecificityTests {

    @Test func testSpecificityInitialization() {
        let specificity = Specificity(a: 1, b: 2, c: 3)

        #expect(specificity.a == 1)
        #expect(specificity.b == 2)
        #expect(specificity.c == 3)
    }

    @Test func testSpecificityZero() {
        let specificity = Specificity.zero

        #expect(specificity.a == 0)
        #expect(specificity.b == 0)
        #expect(specificity.c == 0)
    }

    @Test func testSpecificityAddition() {
        let a = Specificity(a: 1, b: 2, c: 3)
        let b = Specificity(a: 0, b: 1, c: 2)
        let sum = a + b

        #expect(sum == Specificity(a: 1, b: 3, c: 5))
    }

    @Test func testSpecificityLessThanByA() {
        let low = Specificity(a: 0, b: 10, c: 10)
        let high = Specificity(a: 1, b: 0, c: 0)

        #expect(low < high)
    }

    @Test func testSpecificityLessThanByB() {
        let low = Specificity(a: 0, b: 0, c: 10)
        let high = Specificity(a: 0, b: 1, c: 0)

        #expect(low < high)
    }

    @Test func testSpecificityLessThanByC() {
        let low = Specificity(a: 0, b: 0, c: 1)
        let high = Specificity(a: 0, b: 0, c: 2)

        #expect(low < high)
    }
}
