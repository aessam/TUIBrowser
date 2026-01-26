# TUIBrowser Architecture

A terminal-based web browser built from scratch in Swift with zero external dependencies.

## Module Dependency Graph

```
Layer 1 (No dependencies):
    TUICore
       │
Layer 2 (Independent, can be developed in parallel):
    ┌──────────┬───────────┬───────────┬───────────┬───────────┐
    │          │           │           │           │           │
 TUIURL   TUIHTMLParser TUICSSParser TUIJSEngine TUITerminal
    │          │           │           │           │
    │          │           │           │           │
Layer 3 (Integration):
    │          └─────┬─────┘           │           │
    ▼                ▼                 │           │
TUINetworking    TUIStyle ◄────────────┘           │
    │                │                             │
    │                ▼                             │
Layer 4:             │                             │
    │           TUILayout                          │
    │                │                             │
    │                ▼                             │
Layer 5:        TUIRender ◄────────────────────────┘
    │                │
    └────────────────┼────────────────────────────────┐
                     ▼                                │
Layer 6:        TUIBrowser ◄──────────────────────────┘
                     │
                     ▼
               TUIBrowserCLI (executable)
```

## Module Responsibilities

### TUICore (Layer 1)
**Purpose**: Shared types used by all modules.
**Files**: Types.swift, Color.swift, TextStyle.swift, Errors.swift, KeyCode.swift, StringUtils.swift
**Exports**:
- `Point`, `Size`, `Rect`, `EdgeInsets` - Geometry types
- `Color` - RGB color with hex/name parsing
- `TextStyle` - Text rendering attributes
- `KeyCode` - Keyboard input codes
- `TUIError`, `BoxedError` - Error types

### TUIURL (Layer 2)
**Purpose**: Parse and manipulate URLs.
**Dependencies**: TUICore
**Files**: URL.swift, URLParser.swift, URLEncoder.swift, QueryString.swift
**Exports**:
- `URL` - URL representation (scheme, host, port, path, query, fragment)
- `URLParser` - Parse URL strings, resolve relative URLs
- `URLEncoder` - Percent encoding/decoding
- `QueryString` - Parse and build query strings

### TUIHTMLParser (Layer 2)
**Purpose**: Parse HTML into DOM tree.
**Dependencies**: TUICore
**Files**: HTMLToken.swift, HTMLTokenizer.swift, Node.swift, Element.swift, Text.swift, Document.swift, HTMLTreeBuilder.swift, HTMLParser.swift
**Exports**:
- `HTMLToken` - Token types (StartTag, EndTag, Character, etc.)
- `HTMLTokenizer` - State machine tokenizer
- `Node`, `Element`, `Text`, `Comment` - DOM nodes
- `Document` - Document root with query methods
- `HTMLParser` - High-level parsing API

### TUICSSParser (Layer 2)
**Purpose**: Parse CSS into rules and selectors.
**Dependencies**: TUICore
**Files**: CSSToken.swift, CSSTokenizer.swift, CSSSelector.swift, Specificity.swift, CSSValue.swift, CSSDeclaration.swift, CSSRule.swift, CSSParser.swift
**Exports**:
- `CSSToken`, `CSSTokenizer` - CSS tokenization
- `Selector`, `SimpleSelector`, `Combinator` - Selector types
- `Specificity` - (a,b,c) specificity calculation
- `CSSValue`, `LengthUnit` - CSS value types
- `CSSDeclaration`, `CSSRule`, `Stylesheet` - CSS structure
- `CSSParser` - High-level parsing API

### TUIJSEngine (Layer 2)
**Purpose**: Execute JavaScript with DOM bindings.
**Dependencies**: TUICore
**Files**: Token.swift, Lexer.swift, AST.swift, Parser.swift, Value.swift, Environment.swift, Interpreter.swift, Builtins.swift
**Exports**:
- `Token`, `Lexer` - JavaScript tokenization
- `Expression`, `Statement` - AST nodes
- `Parser` - Pratt parser for expressions
- `JSValue`, `JSObject`, `JSArray`, `JSFunction` - Runtime values
- `Environment` - Scope chain
- `Interpreter` - Tree-walking interpreter

### TUITerminal (Layer 2)
**Purpose**: Terminal I/O and rendering primitives.
**Dependencies**: TUICore
**Files**: RawMode.swift, TerminalSize.swift, ANSICode.swift, ColorConverter.swift, TerminalInput.swift, TerminalOutput.swift, SignalHandler.swift, Canvas.swift
**Exports**:
- `RawMode` - Enter/exit terminal raw mode
- `TerminalSize` - Get terminal dimensions
- `ANSICode`, `ANSIColor` - ANSI escape sequences
- `ColorConverter` - RGB to ANSI color mapping
- `TerminalInput` - Keyboard input handling
- `TerminalOutput` - Buffered output
- `SignalHandler` - Handle SIGWINCH, SIGINT
- `Canvas`, `Cell` - Character cell grid

### TUINetworking (Layer 3)
**Purpose**: HTTP/HTTPS client using BSD sockets.
**Dependencies**: TUICore, TUIURL
**Files**: DNSResolver.swift, Socket.swift, TLSConnection.swift, HTTPRequest.swift, HTTPResponse.swift, HTTPClient.swift
**Exports**:
- `DNSResolver` - Resolve hostnames
- `Socket` - BSD socket wrapper
- `TLSConnection` - TLS via SecureTransport
- `HTTPRequest`, `HTTPResponse` - HTTP messages
- `HTTPClient` - High-level fetch API

### TUIStyle (Layer 3)
**Purpose**: CSS cascade and style resolution.
**Dependencies**: TUICore, TUIHTMLParser, TUICSSParser
**Files**: StyleResolver.swift, CascadeEngine.swift, ComputedStyle.swift, DefaultStyles.swift
**Exports**:
- `StyleResolver` - Match selectors to elements
- `CascadeEngine` - Apply cascade rules
- `ComputedStyle` - Final computed styles per element
- `DefaultStyles` - Browser default stylesheet

### TUILayout (Layer 4)
**Purpose**: Layout engine for terminal grid.
**Dependencies**: TUICore, TUIStyle
**Files**: BoxDimensions.swift, LayoutBox.swift, BlockLayout.swift, InlineLayout.swift, TextLayout.swift, LayoutTree.swift
**Exports**:
- `BoxDimensions` - Content, padding, border, margin
- `LayoutBox` - Layout tree node
- `BlockLayout`, `InlineLayout` - Formatting contexts
- `TextLayout` - Text wrapping
- `LayoutTree` - Build layout from styled DOM

### TUIRender (Layer 5)
**Purpose**: Render layout tree to terminal.
**Dependencies**: TUICore, TUITerminal, TUILayout
**Files**: Renderer.swift, TextRenderer.swift, BoxRenderer.swift
**Exports**:
- `Renderer` - Traverse layout, paint to canvas
- `TextRenderer` - Render styled text
- `BoxRenderer` - Render borders/backgrounds

### TUIBrowser (Layer 6)
**Purpose**: Browser orchestration and UI.
**Dependencies**: All modules
**Files**: Browser.swift, EventLoop.swift, NavigationController.swift, History.swift, Screen.swift, URLBar.swift, StatusBar.swift
**Exports**:
- `Browser` - Main browser class
- `EventLoop` - Main run loop
- `NavigationController` - Page loading
- UI components

## Data Flow

```
User enters URL
       │
       ▼
┌─────────────────┐
│  URLParser      │ Parse URL string
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  HTTPClient     │ Fetch page via HTTP/HTTPS
└────────┬────────┘
         │ HTML string
         ▼
┌─────────────────┐
│  HTMLTokenizer  │ Tokenize HTML
└────────┬────────┘
         │ Token stream
         ▼
┌─────────────────┐
│ HTMLTreeBuilder │ Build DOM tree
└────────┬────────┘
         │ DOM tree
         ▼
┌─────────────────┐
│  StyleResolver  │ Match CSS selectors, compute styles
└────────┬────────┘
         │ Styled DOM
         ▼
┌─────────────────┐
│  LayoutTree     │ Calculate positions for terminal
└────────┬────────┘
         │ Layout tree
         ▼
┌─────────────────┐
│    Renderer     │ Paint to canvas
└────────┬────────┘
         │ Canvas
         ▼
┌─────────────────┐
│ TerminalOutput  │ Write ANSI to stdout
└─────────────────┘
```

## Coding Conventions

1. **All types public**: Export everything that other modules might need
2. **Sendable**: Make types Sendable where possible for concurrency safety
3. **No external dependencies**: Only use Swift standard library and Darwin/Foundation
4. **TDD**: Write tests first, then implement
5. **Module isolation**: Each module should be independently testable

## Testing

Each module has its own test target:
- `swift test --filter TUICore`
- `swift test --filter TUIURL`
- `swift test --filter TUIHTMLParser`
- etc.

Run all tests: `swift test`
