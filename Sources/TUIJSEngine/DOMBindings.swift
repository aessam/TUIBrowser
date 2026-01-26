// TUIJSEngine - DOM Bindings
//
// Provides JavaScript bindings for the Document Object Model (DOM).
// Bridges between the JavaScript interpreter and the HTML DOM tree.

import Foundation
import TUIHTMLParser

// MARK: - DOM Bindings

/// DOM bindings for JavaScript
public struct DOMBindings {

    /// Install DOM bindings into the interpreter with the given document
    public static func install(into interpreter: Interpreter, document: Document) {
        // Create the document object
        let docObj = createDocumentObject(document: document, interpreter: interpreter)
        interpreter.setGlobal("document", value: .object(docObj))

        // Create window object with document reference
        let windowObj = createWindowObject(document: document, interpreter: interpreter)
        interpreter.setGlobal("window", value: .object(windowObj))

        // Also set 'this' in global scope to window
        interpreter.globalScope.thisBinding = .object(windowObj)
    }

    // MARK: - Document Object

    private static func createDocumentObject(document: Document, interpreter: Interpreter) -> JSObject {
        let docObj = JSObject(className: "HTMLDocument")

        // document.getElementById
        docObj.set("getElementById", .function(JSFunction(name: "getElementById") { args, _ in
            guard let id = args.first?.stringValue else {
                return .null
            }
            if let element = document.getElementById(id) {
                return wrapElement(element, interpreter: interpreter)
            }
            return .null
        }))

        // document.getElementsByTagName
        docObj.set("getElementsByTagName", .function(JSFunction(name: "getElementsByTagName") { args, _ in
            guard let tagName = args.first?.stringValue else {
                return .array(JSArray())
            }
            let elements = document.getElementsByTagName(tagName)
            let jsElements = elements.map { wrapElement($0, interpreter: interpreter) }
            return createHTMLCollection(jsElements)
        }))

        // document.getElementsByClassName
        docObj.set("getElementsByClassName", .function(JSFunction(name: "getElementsByClassName") { args, _ in
            guard let className = args.first?.stringValue else {
                return .array(JSArray())
            }
            let elements = document.getElementsByClassName(className)
            let jsElements = elements.map { wrapElement($0, interpreter: interpreter) }
            return createHTMLCollection(jsElements)
        }))

        // document.querySelector
        docObj.set("querySelector", .function(JSFunction(name: "querySelector") { args, _ in
            guard let selector = args.first?.stringValue else {
                return .null
            }
            if let element = document.querySelector(selector) {
                return wrapElement(element, interpreter: interpreter)
            }
            return .null
        }))

        // document.querySelectorAll
        docObj.set("querySelectorAll", .function(JSFunction(name: "querySelectorAll") { args, _ in
            guard let selector = args.first?.stringValue else {
                return .array(JSArray())
            }
            let elements = document.querySelectorAll(selector)
            let jsElements = elements.map { wrapElement($0, interpreter: interpreter) }
            return createNodeList(jsElements)
        }))

        // document.createElement
        docObj.set("createElement", .function(JSFunction(name: "createElement") { args, _ in
            guard let tagName = args.first?.stringValue else {
                return .null
            }
            let element = Element(tagName: tagName)
            return wrapElement(element, interpreter: interpreter)
        }))

        // document.createTextNode
        docObj.set("createTextNode", .function(JSFunction(name: "createTextNode") { args, _ in
            let text = args.first?.toString ?? ""
            let textNode = Text(data: text)
            return wrapTextNode(textNode)
        }))

        // document.body
        if let body = document.body {
            docObj.set("body", wrapElement(body, interpreter: interpreter))
        } else {
            docObj.set("body", .null)
        }

        // document.head
        if let head = document.head {
            docObj.set("head", wrapElement(head, interpreter: interpreter))
        } else {
            docObj.set("head", .null)
        }

        // document.documentElement
        if let root = document.documentElement {
            docObj.set("documentElement", wrapElement(root, interpreter: interpreter))
        } else {
            docObj.set("documentElement", .null)
        }

        // document.title
        docObj.set("title", .string(document.title))

        // document.URL
        docObj.set("URL", .string(""))

        // document.location (simplified)
        let location = JSObject(className: "Location")
        location.set("href", .string(""))
        docObj.set("location", .object(location))

        return docObj
    }

    // MARK: - Window Object

    private static func createWindowObject(document: Document, interpreter: Interpreter) -> JSObject {
        let windowObj = JSObject(className: "Window")

        // window.document
        windowObj.set("document", .object(createDocumentObject(document: document, interpreter: interpreter)))

        // window.location
        let location = JSObject(className: "Location")
        location.set("href", .string(""))
        location.set("hostname", .string(""))
        location.set("pathname", .string(""))
        location.set("search", .string(""))
        location.set("hash", .string(""))
        location.set("protocol", .string("https:"))
        windowObj.set("location", .object(location))

        // window.navigator
        let navigator = JSObject(className: "Navigator")
        navigator.set("userAgent", .string("TUIBrowser/0.1.0 (Terminal)"))
        navigator.set("language", .string("en-US"))
        navigator.set("platform", .string("MacIntel"))
        windowObj.set("navigator", .object(navigator))

        // window.innerWidth / innerHeight (terminal size approximation)
        windowObj.set("innerWidth", .number(80))
        windowObj.set("innerHeight", .number(24))

        // window.alert (simplified - just logs)
        windowObj.set("alert", .function(JSFunction(name: "alert") { args, _ in
            let message = args.first?.toString ?? ""
            interpreter.consoleOutput?("[Alert] \(message)")
            return .undefined
        }))

        // window.confirm (always returns true for now)
        windowObj.set("confirm", .function(JSFunction(name: "confirm") { args, _ in
            let message = args.first?.toString ?? ""
            interpreter.consoleOutput?("[Confirm] \(message)")
            return .boolean(true)
        }))

        // window.prompt (returns empty string)
        windowObj.set("prompt", .function(JSFunction(name: "prompt") { args, _ in
            let message = args.first?.toString ?? ""
            interpreter.consoleOutput?("[Prompt] \(message)")
            return .string("")
        }))

        // window.setTimeout (simplified)
        windowObj.set("setTimeout", .function(JSFunction(name: "setTimeout") { args, _ in
            // For now, just return a dummy timer ID
            // Real implementation would use TimerManager
            return .number(0)
        }))

        // window.setInterval (simplified)
        windowObj.set("setInterval", .function(JSFunction(name: "setInterval") { args, _ in
            return .number(0)
        }))

        // window.clearTimeout / clearInterval
        windowObj.set("clearTimeout", .function(JSFunction(name: "clearTimeout") { _, _ in
            return .undefined
        }))

        windowObj.set("clearInterval", .function(JSFunction(name: "clearInterval") { _, _ in
            return .undefined
        }))

        return windowObj
    }

    // MARK: - Element Wrapper

    /// Wrap a DOM Element as a JSObject
    public static func wrapElement(_ element: Element, interpreter: Interpreter) -> JSValue {
        let elemObj = JSObject(className: "HTMLElement")

        // Store reference to actual element
        elemObj.set("__element__", .string(ObjectIdentifier(element).debugDescription))

        // tagName
        elemObj.set("tagName", .string(element.tagName.uppercased()))
        elemObj.set("nodeName", .string(element.tagName.uppercased()))
        elemObj.set("nodeType", .number(1)) // ELEMENT_NODE

        // id
        elemObj.set("id", .string(element.id))

        // className
        elemObj.set("className", .string(element.className))

        // classList
        let classList = createClassList(element)
        elemObj.set("classList", .object(classList))

        // textContent
        elemObj.set("textContent", .string(element.textContent))

        // innerHTML
        elemObj.set("innerHTML", .string(element.innerHTML))

        // outerHTML
        elemObj.set("outerHTML", .string(element.outerHTML))

        // getAttribute
        elemObj.set("getAttribute", .function(JSFunction(name: "getAttribute") { args, _ in
            guard let name = args.first?.stringValue else {
                return .null
            }
            if let value = element.getAttribute(name) {
                return .string(value)
            }
            return .null
        }))

        // setAttribute
        elemObj.set("setAttribute", .function(JSFunction(name: "setAttribute") { args, _ in
            guard args.count >= 2,
                  let name = args[0].stringValue else {
                return .undefined
            }
            let value = args[1].toString
            element.setAttribute(name, value)
            return .undefined
        }))

        // removeAttribute
        elemObj.set("removeAttribute", .function(JSFunction(name: "removeAttribute") { args, _ in
            guard let name = args.first?.stringValue else {
                return .undefined
            }
            element.removeAttribute(name)
            return .undefined
        }))

        // hasAttribute
        elemObj.set("hasAttribute", .function(JSFunction(name: "hasAttribute") { args, _ in
            guard let name = args.first?.stringValue else {
                return .boolean(false)
            }
            return .boolean(element.hasAttribute(name))
        }))

        // appendChild
        elemObj.set("appendChild", .function(JSFunction(name: "appendChild") { args, _ in
            // Would need to extract the actual node from the JSObject wrapper
            return args.first ?? .undefined
        }))

        // removeChild
        elemObj.set("removeChild", .function(JSFunction(name: "removeChild") { args, _ in
            return args.first ?? .undefined
        }))

        // children (HTMLCollection)
        let childElements = element.children
        let jsChildren = childElements.map { wrapElement($0, interpreter: interpreter) }
        elemObj.set("children", createHTMLCollection(jsChildren))

        // childNodes (NodeList)
        elemObj.set("childNodes", createNodeList(jsChildren))

        // firstChild / lastChild
        if let first = element.firstChild as? Element {
            elemObj.set("firstChild", wrapElement(first, interpreter: interpreter))
        } else {
            elemObj.set("firstChild", .null)
        }

        if let last = element.lastChild as? Element {
            elemObj.set("lastChild", wrapElement(last, interpreter: interpreter))
        } else {
            elemObj.set("lastChild", .null)
        }

        // parentNode / parentElement
        if let parent = element.parentElement {
            elemObj.set("parentNode", wrapElement(parent, interpreter: interpreter))
            elemObj.set("parentElement", wrapElement(parent, interpreter: interpreter))
        } else {
            elemObj.set("parentNode", .null)
            elemObj.set("parentElement", .null)
        }

        // nextSibling / previousSibling
        if let next = element.nextSibling as? Element {
            elemObj.set("nextSibling", wrapElement(next, interpreter: interpreter))
            elemObj.set("nextElementSibling", wrapElement(next, interpreter: interpreter))
        } else {
            elemObj.set("nextSibling", .null)
            elemObj.set("nextElementSibling", .null)
        }

        if let prev = element.previousSibling as? Element {
            elemObj.set("previousSibling", wrapElement(prev, interpreter: interpreter))
            elemObj.set("previousElementSibling", wrapElement(prev, interpreter: interpreter))
        } else {
            elemObj.set("previousSibling", .null)
            elemObj.set("previousElementSibling", .null)
        }

        // style (simplified)
        let style = JSObject(className: "CSSStyleDeclaration")
        elemObj.set("style", .object(style))

        // addEventListener (simplified - just stores, doesn't execute)
        elemObj.set("addEventListener", .function(JSFunction(name: "addEventListener") { _, _ in
            return .undefined
        }))

        // removeEventListener
        elemObj.set("removeEventListener", .function(JSFunction(name: "removeEventListener") { _, _ in
            return .undefined
        }))

        // querySelector (on element)
        elemObj.set("querySelector", .function(JSFunction(name: "querySelector") { args, _ in
            guard let selector = args.first?.stringValue else {
                return .null
            }
            if let found = element.querySelector(selector) {
                return wrapElement(found, interpreter: interpreter)
            }
            return .null
        }))

        // querySelectorAll (on element)
        elemObj.set("querySelectorAll", .function(JSFunction(name: "querySelectorAll") { args, _ in
            guard let selector = args.first?.stringValue else {
                return .array(JSArray())
            }
            let elements = element.querySelectorAll(selector)
            let jsElements = elements.map { wrapElement($0, interpreter: interpreter) }
            return createNodeList(jsElements)
        }))

        // matches (simplified - would need full selector matching)
        elemObj.set("matches", .function(JSFunction(name: "matches") { args, _ in
            guard let selector = args.first?.stringValue else {
                return .boolean(false)
            }
            // Simple matching for common cases
            if selector.hasPrefix("#") {
                return .boolean(element.id == String(selector.dropFirst()))
            }
            if selector.hasPrefix(".") {
                return .boolean(element.classList.contains(String(selector.dropFirst())))
            }
            return .boolean(element.tagName == selector.lowercased())
        }))

        // closest (simplified - traverses up to find matching parent)
        elemObj.set("closest", .function(JSFunction(name: "closest") { args, _ in
            guard let selector = args.first?.stringValue else {
                return .null
            }
            // Walk up the DOM tree looking for a match
            var current: Element? = element
            while let el = current {
                // Simple matching
                if selector.hasPrefix("#") {
                    if el.id == String(selector.dropFirst()) {
                        return wrapElement(el, interpreter: interpreter)
                    }
                } else if selector.hasPrefix(".") {
                    if el.classList.contains(String(selector.dropFirst())) {
                        return wrapElement(el, interpreter: interpreter)
                    }
                } else {
                    if el.tagName == selector.lowercased() {
                        return wrapElement(el, interpreter: interpreter)
                    }
                }
                current = el.parentElement
            }
            return .null
        }))

        // focus / blur (no-op for terminal)
        elemObj.set("focus", .function(JSFunction(name: "focus") { _, _ in .undefined }))
        elemObj.set("blur", .function(JSFunction(name: "blur") { _, _ in .undefined }))

        // click (no-op)
        elemObj.set("click", .function(JSFunction(name: "click") { _, _ in .undefined }))

        return .object(elemObj)
    }

    // MARK: - Text Node Wrapper

    private static func wrapTextNode(_ textNode: Text) -> JSValue {
        let obj = JSObject(className: "Text")
        obj.set("nodeType", .number(3)) // TEXT_NODE
        obj.set("nodeName", .string("#text"))
        obj.set("textContent", .string(textNode.data))
        obj.set("data", .string(textNode.data))
        obj.set("length", .number(Double(textNode.data.count)))
        return .object(obj)
    }

    // MARK: - ClassList

    private static func createClassList(_ element: Element) -> JSObject {
        let classList = JSObject(className: "DOMTokenList")

        classList.set("length", .number(Double(element.classList.count)))

        classList.set("add", .function(JSFunction(name: "add") { args, _ in
            for arg in args {
                if let className = arg.stringValue {
                    var classes = element.classList
                    classes.insert(className)
                    element.classList = classes
                }
            }
            return .undefined
        }))

        classList.set("remove", .function(JSFunction(name: "remove") { args, _ in
            for arg in args {
                if let className = arg.stringValue {
                    var classes = element.classList
                    classes.remove(className)
                    element.classList = classes
                }
            }
            return .undefined
        }))

        classList.set("contains", .function(JSFunction(name: "contains") { args, _ in
            guard let className = args.first?.stringValue else {
                return .boolean(false)
            }
            return .boolean(element.classList.contains(className))
        }))

        classList.set("toggle", .function(JSFunction(name: "toggle") { args, _ in
            guard let className = args.first?.stringValue else {
                return .boolean(false)
            }
            var classes = element.classList
            if classes.contains(className) {
                classes.remove(className)
                element.classList = classes
                return .boolean(false)
            } else {
                classes.insert(className)
                element.classList = classes
                return .boolean(true)
            }
        }))

        return classList
    }

    // MARK: - Collection Types

    private static func createHTMLCollection(_ elements: [JSValue]) -> JSValue {
        let collection = JSArray(elements: elements)
        return .array(collection)
    }

    private static func createNodeList(_ elements: [JSValue]) -> JSValue {
        let nodeList = JSArray(elements: elements)
        return .array(nodeList)
    }
}

