# Module Interface Contracts

This document defines the public interfaces each module MUST provide for integration.

## TUICore (Complete)

```swift
// Geometry
public struct Point { public var x, y: Int }
public struct Size { public var width, height: Int }
public struct Rect { public var origin: Point, size: Size }
public struct EdgeInsets { public var top, right, bottom, left: Int }

// Color
public struct Color {
    public var r, g, b, a: UInt8
    public static func fromHex(_ hex: String) -> Color?
    public static func fromName(_ name: String) -> Color?
}

// Text styling
public struct TextStyle {
    public var bold, italic, underline, strikethrough, inverse, dim: Bool
    public var foreground, background: Color?
}

// Input
public enum KeyCode { case char(Character), enter, escape, up, down, left, right, ... }

// Errors
public protocol TUIError: Error, CustomStringConvertible, Sendable {}
```

---

## TUIURL Interface

```swift
// URL representation
public struct URL: Equatable, Hashable, Sendable {
    public var scheme: String
    public var host: String?
    public var port: Int?
    public var path: String
    public var query: String?
    public var fragment: String?
    public var effectivePort: Int { get }
}

// Parsing
public struct URLParser {
    public static func parse(_ string: String) -> Result<URL, ParseError>
    public static func resolve(_ relative: String, against base: URL) -> Result<URL, ParseError>
}

// Encoding
public struct URLEncoder {
    public static func encode(_ string: String) -> String
    public static func decode(_ string: String) -> String?
}

// Query strings
public struct QueryString {
    public init(parsing query: String)
    public func get(_ name: String) -> String?
    public func encode() -> String
}
```

---

## TUIHTMLParser Interface

```swift
// Tokens
public enum HTMLToken {
    case doctype(name: String)
    case startTag(name: String, attributes: [(String, String)], selfClosing: Bool)
    case endTag(name: String)
    case character(Character)
    case comment(String)
    case eof
}

// Tokenizer
public class HTMLTokenizer {
    public init(_ html: String)
    public func nextToken() -> HTMLToken
}

// DOM Nodes
public protocol Node: AnyObject {
    var nodeType: NodeType { get }
    var parentNode: Node? { get set }
    var childNodes: [Node] { get }
    var textContent: String { get }
    func appendChild(_ child: Node)
}

public class Element: Node {
    public var tagName: String { get }
    public var attributes: [String: String] { get set }
    public var id: String? { get }
    public var classList: [String] { get }
    public var innerHTML: String { get }
    public func getAttribute(_ name: String) -> String?
    public func setAttribute(_ name: String, _ value: String)
}

public class Text: Node {
    public var data: String { get set }
}

public class Document: Node {
    public var documentElement: Element? { get }
    public var body: Element? { get }
    public var head: Element? { get }
    public func getElementById(_ id: String) -> Element?
    public func getElementsByTagName(_ tag: String) -> [Element]
    public func getElementsByClassName(_ cls: String) -> [Element]
    public func querySelector(_ selector: String) -> Element?
    public func querySelectorAll(_ selector: String) -> [Element]
}

// High-level API
public struct HTMLParser {
    public static func parse(_ html: String) -> Document
}
```

---

## TUICSSParser Interface

```swift
// Selectors
public struct SimpleSelector {
    public var tagName: String?
    public var id: String?
    public var classes: [String]
}

public struct Selector {
    public var components: [(SimpleSelector, Combinator?)]
    public var specificity: Specificity
}

public struct Specificity: Comparable {
    public let a, b, c: Int  // IDs, classes, elements
}

// Values
public enum CSSValue {
    case keyword(String)
    case length(Double, LengthUnit)
    case percentage(Double)
    case color(Color)
    case number(Double)
    case string(String)
}

// Rules
public struct CSSDeclaration {
    public let property: String
    public let value: CSSValue
    public let important: Bool
}

public struct CSSRule {
    public let selectors: [Selector]
    public let declarations: [CSSDeclaration]
}

public struct Stylesheet {
    public var rules: [CSSRule]
}

// Parsing
public struct CSSParser {
    public static func parseStylesheet(_ css: String) -> Stylesheet
    public static func parseSelector(_ selector: String) -> Selector?
    public static func parseDeclarations(_ decl: String) -> [CSSDeclaration]
}
```

---

## TUIJSEngine Interface

```swift
// Values
public enum JSValue: CustomStringConvertible {
    case undefined, null
    case boolean(Bool)
    case number(Double)
    case string(String)
    case object(JSObject)
    case array(JSArray)
    case function(JSFunction)

    public var isTruthy: Bool { get }
    public var typeOf: String { get }
}

public class JSObject {
    public subscript(key: String) -> JSValue { get set }
}

// Interpreter
public class Interpreter {
    public init()
    public func execute(_ code: String) throws -> JSValue
    public func setGlobal(_ name: String, value: JSValue)
    public func getGlobal(_ name: String) -> JSValue?
}
```

---

## TUITerminal Interface

```swift
// Raw mode
public class RawMode {
    public func enable() throws
    public func disable()
}

// Size
public struct TerminalSize {
    public static func current() -> Size
}

// ANSI codes
public enum ANSICode {
    public static func moveTo(x: Int, y: Int) -> String
    public static func foreground(_ color: ANSIColor) -> String
    public static func background(_ color: ANSIColor) -> String
    public static func foregroundRGB(_ r: UInt8, _ g: UInt8, _ b: UInt8) -> String
    public static let clearScreen: String
    public static let reset: String
    public static let bold: String
    public static let underline: String
}

// Color conversion
public struct ColorConverter {
    public static func toANSI16(_ color: Color) -> ANSIColor
    public static func toANSI256(_ color: Color) -> UInt8
}

// Input
public struct TerminalInput {
    public static func readKey() -> KeyCode?
}

// Output
public class TerminalOutput {
    public func write(_ string: String)
    public func flush()
}

// Canvas
public struct Cell {
    public var character: Character
    public var style: TextStyle
}

public class Canvas {
    public var width, height: Int { get }
    public subscript(x: Int, y: Int) -> Cell { get set }
    public func drawText(_ text: String, at: Point, style: TextStyle)
    public func clear()
    public func render(to output: TerminalOutput)
}
```

---

## TUIStyle Interface (To Be Implemented)

```swift
// Computed style for an element
public struct ComputedStyle {
    public var color: Color
    public var backgroundColor: Color?
    public var fontWeight: FontWeight  // .normal, .bold
    public var textDecoration: TextDecoration  // .none, .underline
    public var display: Display  // .block, .inline, .none
    public var margin: EdgeInsets
    public var padding: EdgeInsets
}

// Style resolution
public struct StyleResolver {
    public static func resolve(
        document: Document,
        stylesheets: [Stylesheet],
        defaultStyles: Stylesheet
    ) -> [Element: ComputedStyle]
}
```

---

## TUILayout Interface (To Be Implemented)

```swift
// Box dimensions
public struct BoxDimensions {
    public var content: Rect
    public var padding: EdgeInsets
    public var border: EdgeInsets
    public var margin: EdgeInsets
}

// Layout box
public class LayoutBox {
    public var boxType: DisplayType
    public var dimensions: BoxDimensions
    public var children: [LayoutBox]
    public weak var element: Element?
    public var style: ComputedStyle
}

// Layout computation
public struct LayoutEngine {
    public static func layout(
        document: Document,
        styles: [Element: ComputedStyle],
        width: Int
    ) -> LayoutBox
}
```

---

## TUIRender Interface (To Be Implemented)

```swift
public struct Renderer {
    public static func render(
        layout: LayoutBox,
        to canvas: Canvas
    )
}
```

---

## TUINetworking Interface (To Be Implemented)

```swift
public struct HTTPClient {
    public static func fetch(url: URL) async throws -> HTTPResponse
}

public struct HTTPResponse {
    public var statusCode: Int
    public var headers: [String: String]
    public var body: Data
}
```
