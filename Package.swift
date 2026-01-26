// swift-tools-version: 6.2
// TUIBrowser - A terminal-based web browser from scratch
// Modular architecture for parallel development

import PackageDescription

let package = Package(
    name: "TUIBrowser",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        // Main executable
        .executable(name: "tuibrowser", targets: ["TUIBrowserCLI"]),

        // Individual libraries for modular use
        .library(name: "TUICore", targets: ["TUICore"]),
        .library(name: "TUITerminal", targets: ["TUITerminal"]),
        .library(name: "TUIURL", targets: ["TUIURL"]),
        .library(name: "TUINetworking", targets: ["TUINetworking"]),
        .library(name: "TUIHTMLParser", targets: ["TUIHTMLParser"]),
        .library(name: "TUICSSParser", targets: ["TUICSSParser"]),
        .library(name: "TUIJSEngine", targets: ["TUIJSEngine"]),
        .library(name: "TUIStyle", targets: ["TUIStyle"]),
        .library(name: "TUILayout", targets: ["TUILayout"]),
        .library(name: "TUIRender", targets: ["TUIRender"]),
        .library(name: "TUIBrowser", targets: ["TUIBrowser"]),
    ],
    targets: [
        // ============================================================
        // LAYER 1: Core (no dependencies)
        // ============================================================

        /// Core types, errors, and utilities used by all modules
        .target(
            name: "TUICore",
            path: "Sources/TUICore"
        ),
        .testTarget(
            name: "TUICoreTests",
            dependencies: ["TUICore"],
            path: "Tests/TUICoreTests"
        ),

        // ============================================================
        // LAYER 2: Independent modules (can be developed in parallel)
        // ============================================================

        /// Terminal I/O: raw mode, input handling, ANSI codes
        .target(
            name: "TUITerminal",
            dependencies: ["TUICore"],
            path: "Sources/TUITerminal"
        ),
        .testTarget(
            name: "TUITerminalTests",
            dependencies: ["TUITerminal"],
            path: "Tests/TUITerminalTests"
        ),

        /// URL parsing and manipulation
        .target(
            name: "TUIURL",
            dependencies: ["TUICore"],
            path: "Sources/TUIURL"
        ),
        .testTarget(
            name: "TUIURLTests",
            dependencies: ["TUIURL"],
            path: "Tests/TUIURLTests"
        ),

        /// HTML tokenizer and DOM tree construction
        .target(
            name: "TUIHTMLParser",
            dependencies: ["TUICore"],
            path: "Sources/TUIHTMLParser"
        ),
        .testTarget(
            name: "TUIHTMLParserTests",
            dependencies: ["TUIHTMLParser"],
            path: "Tests/TUIHTMLParserTests"
        ),

        /// CSS tokenizer, parser, selectors, and rules
        .target(
            name: "TUICSSParser",
            dependencies: ["TUICore"],
            path: "Sources/TUICSSParser"
        ),
        .testTarget(
            name: "TUICSSParserTests",
            dependencies: ["TUICSSParser"],
            path: "Tests/TUICSSParserTests"
        ),

        /// JavaScript lexer, parser, and interpreter
        .target(
            name: "TUIJSEngine",
            dependencies: ["TUICore"],
            path: "Sources/TUIJSEngine"
        ),
        .testTarget(
            name: "TUIJSEngineTests",
            dependencies: ["TUIJSEngine"],
            path: "Tests/TUIJSEngineTests"
        ),

        // ============================================================
        // LAYER 3: Integration modules
        // ============================================================

        /// HTTP/HTTPS networking with BSD sockets and SecureTransport
        .target(
            name: "TUINetworking",
            dependencies: ["TUICore", "TUIURL"],
            path: "Sources/TUINetworking"
        ),
        .testTarget(
            name: "TUINetworkingTests",
            dependencies: ["TUINetworking"],
            path: "Tests/TUINetworkingTests"
        ),

        /// Style resolution: CSS cascade, specificity, computed styles
        .target(
            name: "TUIStyle",
            dependencies: ["TUICore", "TUIHTMLParser", "TUICSSParser"],
            path: "Sources/TUIStyle"
        ),
        .testTarget(
            name: "TUIStyleTests",
            dependencies: ["TUIStyle"],
            path: "Tests/TUIStyleTests"
        ),

        // ============================================================
        // LAYER 4: High-level modules
        // ============================================================

        /// Layout engine: box model, block/inline flow, text wrapping
        .target(
            name: "TUILayout",
            dependencies: ["TUICore", "TUIStyle"],
            path: "Sources/TUILayout"
        ),
        .testTarget(
            name: "TUILayoutTests",
            dependencies: ["TUILayout"],
            path: "Tests/TUILayoutTests"
        ),

        /// Terminal rendering: paint layout to terminal canvas
        .target(
            name: "TUIRender",
            dependencies: ["TUICore", "TUITerminal", "TUILayout"],
            path: "Sources/TUIRender"
        ),
        .testTarget(
            name: "TUIRenderTests",
            dependencies: ["TUIRender"],
            path: "Tests/TUIRenderTests"
        ),

        // ============================================================
        // LAYER 5: Browser orchestration
        // ============================================================

        /// Main browser: navigation, event loop, UI components
        .target(
            name: "TUIBrowser",
            dependencies: [
                "TUICore",
                "TUITerminal",
                "TUIURL",
                "TUINetworking",
                "TUIHTMLParser",
                "TUICSSParser",
                "TUIJSEngine",
                "TUIStyle",
                "TUILayout",
                "TUIRender"
            ],
            path: "Sources/TUIBrowser"
        ),
        .testTarget(
            name: "TUIBrowserTests",
            dependencies: ["TUIBrowser"],
            path: "Tests/TUIBrowserTests"
        ),

        /// CLI executable entry point
        .executableTarget(
            name: "TUIBrowserCLI",
            dependencies: ["TUIBrowser"],
            path: "Sources/TUIBrowserCLI"
        ),

        /// CSS Parser Test executable
        .executableTarget(
            name: "CSSParserTest",
            dependencies: ["TUICore", "TUICSSParser"],
            path: "Sources/CSSParserTest"
        ),
    ]
)
