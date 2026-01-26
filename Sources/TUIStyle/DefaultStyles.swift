// TUIStyle - Default Browser Styles
//
// Defines the user-agent stylesheet (browser defaults).

import TUICore
import TUICSSParser

/// Default browser styles (user-agent stylesheet)
public struct DefaultStyles: Sendable {

    /// Create the default stylesheet
    public static func create() -> Stylesheet {
        var stylesheet = Stylesheet()

        // Block elements
        stylesheet.addRule(blockRule(for: "html"))
        stylesheet.addRule(blockRule(for: "body"))
        stylesheet.addRule(blockRule(for: "div"))
        stylesheet.addRule(blockRule(for: "main"))
        stylesheet.addRule(blockRule(for: "section"))
        stylesheet.addRule(blockRule(for: "article"))
        stylesheet.addRule(blockRule(for: "aside"))
        stylesheet.addRule(blockRule(for: "nav"))
        stylesheet.addRule(blockRule(for: "header"))
        stylesheet.addRule(blockRule(for: "footer"))
        stylesheet.addRule(blockRule(for: "address"))
        stylesheet.addRule(blockRule(for: "hgroup"))
        stylesheet.addRule(blockRule(for: "figure"))
        stylesheet.addRule(blockRule(for: "figcaption"))
        stylesheet.addRule(blockRule(for: "blockquote"))
        stylesheet.addRule(blockRule(for: "form"))
        stylesheet.addRule(blockRule(for: "fieldset"))
        stylesheet.addRule(blockRule(for: "pre"))

        // Headings - block with bold, margins
        stylesheet.addRule(headingRule(for: "h1"))
        stylesheet.addRule(headingRule(for: "h2"))
        stylesheet.addRule(headingRule(for: "h3"))
        stylesheet.addRule(headingRule(for: "h4"))
        stylesheet.addRule(headingRule(for: "h5"))
        stylesheet.addRule(headingRule(for: "h6"))

        // Paragraphs
        stylesheet.addRule(paragraphRule())

        // Lists
        stylesheet.addRule(listRule(for: "ul"))
        stylesheet.addRule(listRule(for: "ol"))
        stylesheet.addRule(listItemRule())

        // Inline elements
        stylesheet.addRule(inlineRule(for: "span"))
        stylesheet.addRule(linkRule())
        stylesheet.addRule(strongRule())
        stylesheet.addRule(emRule())
        stylesheet.addRule(codeRule())
        stylesheet.addRule(delRule())
        stylesheet.addRule(insRule())
        stylesheet.addRule(markRule())
        stylesheet.addRule(smallRule())
        stylesheet.addRule(subSupRule())

        // Table elements
        stylesheet.addRule(tableRule())
        stylesheet.addRule(tableRowRule())
        stylesheet.addRule(tableCellRule())

        // BR, HR
        stylesheet.addRule(brRule())
        stylesheet.addRule(hrRule())

        // Hidden elements
        stylesheet.addRule(hiddenRule(for: "head"))
        stylesheet.addRule(hiddenRule(for: "script"))
        stylesheet.addRule(hiddenRule(for: "style"))
        stylesheet.addRule(hiddenRule(for: "meta"))
        stylesheet.addRule(hiddenRule(for: "link"))
        stylesheet.addRule(hiddenRule(for: "title"))
        stylesheet.addRule(hiddenRule(for: "template"))
        stylesheet.addRule(hiddenRule(for: "noscript"))

        return stylesheet
    }

    // MARK: - Rule Builders

    private static func selector(for tagName: String) -> Selector {
        let simple = SimpleSelector(tagName: tagName)
        return Selector(
            components: [(simple, nil)],
            specificity: Specificity(a: 0, b: 0, c: 1)
        )
    }

    private static func blockRule(for tagName: String) -> CSSRule {
        CSSRule(
            selectors: [selector(for: tagName)],
            declarations: [
                CSSDeclaration(property: "display", value: .keyword("block"))
            ]
        )
    }

    private static func inlineRule(for tagName: String) -> CSSRule {
        CSSRule(
            selectors: [selector(for: tagName)],
            declarations: [
                CSSDeclaration(property: "display", value: .keyword("inline"))
            ]
        )
    }

    private static func hiddenRule(for tagName: String) -> CSSRule {
        CSSRule(
            selectors: [selector(for: tagName)],
            declarations: [
                CSSDeclaration(property: "display", value: .keyword("none"))
            ]
        )
    }

    private static func headingRule(for tagName: String) -> CSSRule {
        CSSRule(
            selectors: [selector(for: tagName)],
            declarations: [
                CSSDeclaration(property: "display", value: .keyword("block")),
                CSSDeclaration(property: "font-weight", value: .keyword("bold")),
                CSSDeclaration(property: "margin-top", value: .length(16, .px)),
                CSSDeclaration(property: "margin-bottom", value: .length(8, .px))
            ]
        )
    }

    private static func paragraphRule() -> CSSRule {
        CSSRule(
            selectors: [selector(for: "p")],
            declarations: [
                CSSDeclaration(property: "display", value: .keyword("block")),
                CSSDeclaration(property: "margin-top", value: .length(8, .px)),
                CSSDeclaration(property: "margin-bottom", value: .length(8, .px))
            ]
        )
    }

    private static func listRule(for tagName: String) -> CSSRule {
        CSSRule(
            selectors: [selector(for: tagName)],
            declarations: [
                CSSDeclaration(property: "display", value: .keyword("block")),
                CSSDeclaration(property: "padding-left", value: .length(32, .px)),  // 4 characters indent
                CSSDeclaration(property: "margin-top", value: .length(8, .px)),
                CSSDeclaration(property: "margin-bottom", value: .length(8, .px)),
                CSSDeclaration(property: "list-style-type", value: .keyword(tagName == "ol" ? "decimal" : "disc"))
            ]
        )
    }

    private static func listItemRule() -> CSSRule {
        CSSRule(
            selectors: [selector(for: "li")],
            declarations: [
                CSSDeclaration(property: "display", value: .keyword("list-item"))
            ]
        )
    }

    private static func linkRule() -> CSSRule {
        CSSRule(
            selectors: [selector(for: "a")],
            declarations: [
                CSSDeclaration(property: "display", value: .keyword("inline")),
                CSSDeclaration(property: "color", value: .color(.cyan)),
                CSSDeclaration(property: "text-decoration", value: .keyword("underline"))
            ]
        )
    }

    private static func strongRule() -> CSSRule {
        CSSRule(
            selectors: [selector(for: "strong"), selector(for: "b")],
            declarations: [
                CSSDeclaration(property: "display", value: .keyword("inline")),
                CSSDeclaration(property: "font-weight", value: .keyword("bold"))
            ]
        )
    }

    private static func emRule() -> CSSRule {
        CSSRule(
            selectors: [selector(for: "em"), selector(for: "i")],
            declarations: [
                CSSDeclaration(property: "display", value: .keyword("inline")),
                CSSDeclaration(property: "font-style", value: .keyword("italic"))
            ]
        )
    }

    private static func codeRule() -> CSSRule {
        CSSRule(
            selectors: [selector(for: "code"), selector(for: "kbd"), selector(for: "samp")],
            declarations: [
                CSSDeclaration(property: "display", value: .keyword("inline")),
                CSSDeclaration(property: "background-color", value: .color(Color(r: 40, g: 40, b: 40)))
            ]
        )
    }

    private static func delRule() -> CSSRule {
        CSSRule(
            selectors: [selector(for: "del"), selector(for: "s"), selector(for: "strike")],
            declarations: [
                CSSDeclaration(property: "display", value: .keyword("inline")),
                CSSDeclaration(property: "text-decoration", value: .keyword("line-through"))
            ]
        )
    }

    private static func insRule() -> CSSRule {
        CSSRule(
            selectors: [selector(for: "ins"), selector(for: "u")],
            declarations: [
                CSSDeclaration(property: "display", value: .keyword("inline")),
                CSSDeclaration(property: "text-decoration", value: .keyword("underline"))
            ]
        )
    }

    private static func markRule() -> CSSRule {
        CSSRule(
            selectors: [selector(for: "mark")],
            declarations: [
                CSSDeclaration(property: "display", value: .keyword("inline")),
                CSSDeclaration(property: "background-color", value: .color(.yellow)),
                CSSDeclaration(property: "color", value: .color(.black))
            ]
        )
    }

    private static func smallRule() -> CSSRule {
        CSSRule(
            selectors: [selector(for: "small")],
            declarations: [
                CSSDeclaration(property: "display", value: .keyword("inline"))
            ]
        )
    }

    private static func subSupRule() -> CSSRule {
        CSSRule(
            selectors: [selector(for: "sub"), selector(for: "sup")],
            declarations: [
                CSSDeclaration(property: "display", value: .keyword("inline"))
            ]
        )
    }

    private static func tableRule() -> CSSRule {
        CSSRule(
            selectors: [selector(for: "table")],
            declarations: [
                CSSDeclaration(property: "display", value: .keyword("block"))
            ]
        )
    }

    private static func tableRowRule() -> CSSRule {
        CSSRule(
            selectors: [selector(for: "tr")],
            declarations: [
                CSSDeclaration(property: "display", value: .keyword("block"))
            ]
        )
    }

    private static func tableCellRule() -> CSSRule {
        CSSRule(
            selectors: [selector(for: "td"), selector(for: "th")],
            declarations: [
                CSSDeclaration(property: "display", value: .keyword("inline")),
                CSSDeclaration(property: "padding-right", value: .length(16, .px))
            ]
        )
    }

    private static func brRule() -> CSSRule {
        CSSRule(
            selectors: [selector(for: "br")],
            declarations: [
                CSSDeclaration(property: "display", value: .keyword("block"))
            ]
        )
    }

    private static func hrRule() -> CSSRule {
        CSSRule(
            selectors: [selector(for: "hr")],
            declarations: [
                CSSDeclaration(property: "display", value: .keyword("block")),
                CSSDeclaration(property: "margin-top", value: .length(8, .px)),
                CSSDeclaration(property: "margin-bottom", value: .length(8, .px))
            ]
        )
    }
}
