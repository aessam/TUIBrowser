// TUIHTMLParser - HTML Tree Builder
// Builds a DOM tree from HTML tokens

import TUICore

/// Builds a DOM tree from HTML tokens
internal final class HTMLTreeBuilder {
    private var document: Document
    private var openElements: [Element] = []
    private var currentInsertionMode: InsertionMode = .initial

    /// Elements that automatically close when certain tags are encountered
    private static let implicitCloseElements: [String: Set<String>] = [
        "p": ["address", "article", "aside", "blockquote", "details", "div", "dl",
              "fieldset", "figcaption", "figure", "footer", "form", "h1", "h2", "h3",
              "h4", "h5", "h6", "header", "hgroup", "hr", "main", "menu", "nav", "ol",
              "p", "pre", "section", "table", "ul"],
        "li": ["li"],
        "dt": ["dt", "dd"],
        "dd": ["dt", "dd"],
        "rt": ["rt", "rp"],
        "rp": ["rt", "rp"],
        "optgroup": ["optgroup"],
        "option": ["option", "optgroup"],
        "thead": ["tbody", "tfoot"],
        "tbody": ["tbody", "tfoot"],
        "tfoot": ["tbody"],
        "tr": ["tr"],
        "td": ["td", "th"],
        "th": ["td", "th"],
    ]

    /// Void elements that never have children
    private static let voidElements: Set<String> = [
        "area", "base", "br", "col", "embed", "hr", "img", "input",
        "link", "meta", "param", "source", "track", "wbr"
    ]

    /// Formatting elements
    private static let formattingElements: Set<String> = [
        "a", "b", "big", "code", "em", "font", "i", "nobr", "s", "small",
        "strike", "strong", "tt", "u"
    ]

    private enum InsertionMode {
        case initial
        case beforeHtml
        case beforeHead
        case inHead
        case afterHead
        case inBody
        case afterBody
        case afterAfterBody
    }

    init() {
        self.document = Document()
    }

    /// Build a document from tokens
    func build(from tokens: [HTMLToken]) -> Document {
        document = Document()
        openElements = []
        currentInsertionMode = .initial

        for token in tokens {
            processToken(token)
        }

        return document
    }

    /// Build a document fragment from tokens (for innerHTML)
    func buildFragment(from tokens: [HTMLToken], context: Element?) -> Document {
        document = Document()
        openElements = []

        // Set up context
        if let ctx = context {
            let htmlElement = document.createElement("html")
            let bodyElement = document.createElement("body")
            document.appendChild(htmlElement)
            htmlElement.appendChild(bodyElement)
            openElements = [htmlElement, bodyElement]
            currentInsertionMode = .inBody
        } else {
            currentInsertionMode = .initial
        }

        for token in tokens {
            processToken(token)
        }

        return document
    }

    // MARK: - Token Processing

    private func processToken(_ token: HTMLToken) {
        switch token {
        case .doctype(let name, let publicId, let systemId):
            processDoctype(name: name, publicId: publicId, systemId: systemId)

        case .startTag(let name, let attributes, let selfClosing):
            processStartTag(name: name, attributes: attributes, selfClosing: selfClosing)

        case .endTag(let name):
            processEndTag(name: name)

        case .character(let text):
            processCharacter(text: text)

        case .comment(let data):
            processComment(data: data)

        case .eof:
            // End of file - close all open elements
            break
        }
    }

    private func processDoctype(name: String, publicId: String?, systemId: String?) {
        let doctype = DocumentType(name: name, publicId: publicId ?? "", systemId: systemId ?? "")
        document.setDoctype(doctype)
        currentInsertionMode = .beforeHtml
    }

    private func processStartTag(name: String, attributes: [HTMLAttribute], selfClosing: Bool) {
        let tagName = name.lowercased()

        // Handle implicit element closing
        handleImplicitClose(forTag: tagName)

        switch tagName {
        case "html":
            if currentInsertionMode == .initial || currentInsertionMode == .beforeHtml {
                let element = createElement(tagName: tagName, attributes: attributes)
                document.appendChild(element)
                openElements.append(element)
                currentInsertionMode = .beforeHead
            }

        case "head":
            ensureHtml()
            let element = createElement(tagName: tagName, attributes: attributes)
            insertElement(element)
            currentInsertionMode = .inHead

        case "body":
            ensureHtml()
            let element = createElement(tagName: tagName, attributes: attributes)
            insertElement(element)
            currentInsertionMode = .inBody

        case "title", "style", "script", "noscript", "template":
            if currentInsertionMode == .inHead || currentInsertionMode == .beforeHead {
                ensureHead()
            }
            let element = createElement(tagName: tagName, attributes: attributes)
            insertElement(element)

        case "meta", "link", "base":
            if currentInsertionMode == .inHead || currentInsertionMode == .beforeHead {
                ensureHead()
            }
            let element = createElement(tagName: tagName, attributes: attributes)
            insertElement(element)
            // These are void elements, don't push to stack
            if !selfClosing && Self.voidElements.contains(tagName) {
                openElements.removeLast()
            }

        default:
            ensureBody()
            let element = createElement(tagName: tagName, attributes: attributes)
            insertElement(element)

            // Handle void elements
            if selfClosing || Self.voidElements.contains(tagName) {
                openElements.removeLast()
            }
        }
    }

    private func processEndTag(name: String) {
        let tagName = name.lowercased()

        switch tagName {
        case "html":
            currentInsertionMode = .afterBody

        case "head":
            popToTag(tagName)
            currentInsertionMode = .afterHead

        case "body":
            popToTag(tagName)
            currentInsertionMode = .afterBody

        default:
            popToTag(tagName)
        }
    }

    private func processCharacter(text: String) {
        guard !text.isEmpty else { return }

        // In early modes (before html/head), skip whitespace-only text
        if currentInsertionMode == .initial || currentInsertionMode == .beforeHtml || currentInsertionMode == .beforeHead {
            if text.allSatisfy({ $0.isWhitespace }) {
                return
            }
        }

        // Only call ensureBody if we're not in head-related modes
        if currentInsertionMode != .inHead && currentInsertionMode != .beforeHead &&
           currentInsertionMode != .initial && currentInsertionMode != .beforeHtml {
            ensureBody()
        }

        // Insert text into current element
        if let currentElement = openElements.last {
            // Check if last child is a text node to merge
            if let lastText = currentElement.lastChild as? Text {
                lastText.data += text
            } else {
                let textNode = Text(data: text)
                currentElement.appendChild(textNode)
            }
        }
    }

    private func processComment(data: String) {
        let comment = Comment(data: data)

        if let currentElement = openElements.last {
            currentElement.appendChild(comment)
        } else {
            document.appendChild(comment)
        }
    }

    // MARK: - Helper Methods

    private func createElement(tagName: String, attributes: [HTMLAttribute]) -> Element {
        let element = Element(tagName: tagName, attributes: attributes)
        element.ownerDocument = document
        return element
    }

    private func insertElement(_ element: Element) {
        if let currentElement = openElements.last {
            currentElement.appendChild(element)
        } else if let docElement = document.documentElement {
            docElement.appendChild(element)
        } else {
            document.appendChild(element)
        }
        openElements.append(element)
    }

    private func popToTag(_ tagName: String) {
        while let last = openElements.last {
            openElements.removeLast()
            if last.tagName == tagName {
                break
            }
        }
    }

    private func handleImplicitClose(forTag tagName: String) {
        // Check if we need to close any elements implicitly
        guard let closeSet = Self.implicitCloseElements.values.first(where: { $0.contains(tagName) }) else {
            return
        }

        // Find elements that should close
        for (elementTag, triggers) in Self.implicitCloseElements {
            if triggers.contains(tagName) {
                // Close any open elements of this type
                while let last = openElements.last, last.tagName == elementTag {
                    openElements.removeLast()
                }
            }
        }
    }

    private func ensureHtml() {
        if document.documentElement == nil {
            let html = document.createElement("html")
            document.appendChild(html)
            openElements.append(html)
            currentInsertionMode = .beforeHead
        }
    }

    private func ensureHead() {
        ensureHtml()
        if document.head == nil {
            let head = document.createElement("head")
            document.documentElement?.appendChild(head)
            openElements.append(head)
            currentInsertionMode = .inHead
        } else if !openElements.contains(where: { $0.tagName == "head" }) {
            // If head exists but is not in the open elements stack, add it
            openElements.append(document.head!)
            currentInsertionMode = .inHead
        }
    }

    private func ensureBody() {
        ensureHtml()

        // Make sure we're not in the head
        if openElements.last?.tagName == "head" {
            openElements.removeLast()
            currentInsertionMode = .afterHead
        }

        if document.body == nil {
            // If there's no head, create one first
            if document.head == nil {
                let head = document.createElement("head")
                document.documentElement?.appendChild(head)
            }

            let body = document.createElement("body")
            document.documentElement?.appendChild(body)
            openElements.append(body)
            currentInsertionMode = .inBody
        } else if openElements.last?.tagName != "body" &&
                  !openElements.contains(where: { $0.tagName == "body" }) {
            if let body = document.body {
                openElements.append(body)
            }
        }
    }
}
