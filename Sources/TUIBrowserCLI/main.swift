// TUIBrowser CLI - Entry point
//
// Command-line interface for the TUI browser.

import Foundation
import TUIBrowser
import TUITerminal
import TUICore
import TUIHTMLParser
import TUILayout
import TUIRender

// MARK: - Command Line Arguments

struct CLIOptions {
    var url: String?
    var width: Int?
    var height: Int?
    var dumpHTML: Bool = false
    var dumpLayout: Bool = false
    var renderPNG: String? = nil  // Path to render PNG output
    var showHelp: Bool = false
    var showVersion: Bool = false
    var noColor: Bool = false
}

func parseArguments() -> CLIOptions {
    var options = CLIOptions()
    let allArgs = Array(CommandLine.arguments.dropFirst())
    var index = 0

    while index < allArgs.count {
        let arg = allArgs[index]
        switch arg {
        case "-h", "--help":
            options.showHelp = true
        case "-v", "--version":
            options.showVersion = true
        case "--dump-html":
            options.dumpHTML = true
        case "--dump-layout":
            options.dumpLayout = true
        case "--no-color":
            options.noColor = true
        case "-w", "--width":
            index += 1
            if index < allArgs.count, let width = Int(allArgs[index]) {
                options.width = width
            }
        case "-H", "--height":
            index += 1
            if index < allArgs.count, let height = Int(allArgs[index]) {
                options.height = height
            }
        case "--render-png":
            index += 1
            if index < allArgs.count {
                options.renderPNG = allArgs[index]
            }
        default:
            if !arg.hasPrefix("-") {
                options.url = arg
            }
        }
        index += 1
    }

    return options
}

func showHelp() {
    print("""
    TUIBrowser \(Browser.version) - A terminal web browser

    USAGE:
        tuibrowser [OPTIONS] [URL]

    ARGUMENTS:
        [URL]                    URL to open (optional)

    OPTIONS:
        -h, --help               Show this help message
        -v, --version            Show version information
        -w, --width <WIDTH>      Set terminal width (default: auto-detect)
        -H, --height <HEIGHT>    Set terminal height (default: auto-detect)
        --dump-html              Dump parsed HTML and exit
        --dump-layout            Dump layout tree and exit
        --render-png <PATH>      Render page to PNG file and exit
        --no-color               Disable color output

    EXAMPLES:
        tuibrowser https://example.com
        tuibrowser --dump-html https://example.com
        tuibrowser -w 120 -H 40 https://example.com

    KEYBOARD SHORTCUTS (in interactive mode):
        q           Quit
        g           Go to URL
        r           Reload
        b           Go back
        f           Go forward
        j/Down      Scroll down
        k/Up        Scroll up
        Space       Page down
        Ctrl+U      Page up
        Home        Scroll to top
        End         Scroll to bottom
        /           Search in page
        n           Next search result
        ?           Show help

    """)
}

func showVersion() {
    print("TUIBrowser \(Browser.version)")
    print("A terminal-based web browser built from scratch")
    print("")
    print("Components:")
    print("  - TUICore: Foundation types")
    print("  - TUITerminal: Terminal I/O")
    print("  - TUIURL: URL parsing")
    print("  - TUINetworking: HTTP client")
    print("  - TUIHTMLParser: HTML parsing")
    print("  - TUICSSParser: CSS parsing")
    print("  - TUIStyle: CSS cascade")
    print("  - TUILayout: Box model layout")
    print("  - TUIRender: Terminal rendering")
}

// MARK: - Main

func runMain() async {
    // Flush stdout immediately
    setbuf(stdout, nil)

    let options = parseArguments()

    if options.showHelp {
        showHelp()
        return
    }

    if options.showVersion {
        showVersion()
        return
    }

    // Get terminal size
    let termSize = TerminalSize.current()
    let width = options.width ?? termSize.width
    let _ = options.height ?? termSize.height  // Reserved for future use

    // Create browser
    let config = BrowserConfig()
    let browser = Browser(config: config)

    // Handle URL
    if let url = options.url {
        // Debug/dump modes (non-interactive)
        if options.dumpHTML || options.dumpLayout || options.renderPNG != nil {
            // Set terminal size for layout calculation
            let height = options.height ?? termSize.height
            browser.setTerminalSize(width: width, height: height)

            do {
                print("Fetching: \(url)...")
                try await browser.navigate(to: url)
                print("Loaded: \(browser.state.title)")

                if options.dumpHTML {
                    // Dump parsed HTML
                    if let doc = browser.state.document {
                        print("=== Parsed HTML ===")
                        print("Title: \(doc.title)")
                        print("")
                        if let body = doc.body {
                            dumpElement(body, indent: 0)
                        }
                    }
                    return
                }

                if options.dumpLayout {
                    // Dump layout tree
                    if let layout = browser.state.layout {
                        print("=== Layout Tree ===")
                        print("Width: \(width)")
                        print("")
                        dumpLayoutBox(layout, indent: 0)
                    }
                    return
                }

                if let pngPath = options.renderPNG {
                    // Render to PNG
                    #if canImport(CoreGraphics) && canImport(ImageIO)
                    let renderWidth = options.width ?? 240  // Default to 240 columns (Full HD at 8px/char)
                    let renderHeight = options.height ?? 67  // Default to ~67 rows (1080 at 16px/char)
                    browser.setTerminalSize(width: renderWidth, height: renderHeight)

                    // Re-layout with new size
                    try await browser.navigate(to: url)

                    // Create canvas and render
                    if let layout = browser.state.layout {
                        let canvas = Canvas(width: renderWidth, height: renderHeight)
                        let renderer = Renderer()
                        renderer.render(layout: layout, to: canvas, scrollY: 0)

                        // Render to PNG
                        let pngRenderer = PNGRenderer()
                        if pngRenderer.render(canvas, to: pngPath) {
                            print("Rendered to: \(pngPath)")
                            print("Image size: \(renderWidth * pngRenderer.cellWidth)x\(renderHeight * pngRenderer.cellHeight) pixels")
                        } else {
                            print("Error: Failed to render PNG")
                            exit(1)
                        }
                    }
                    #else
                    print("Error: PNG rendering requires macOS (CoreGraphics)")
                    exit(1)
                    #endif
                    return
                }
            } catch {
                print("Error: \(error)")
                exit(1)
            }
        } else {
            // Interactive mode with initial URL
            await browser.run(initialURL: url)
        }
    } else {
        // Interactive mode without initial URL
        await browser.run()
    }
}

// MARK: - Debug Output

func dumpElement(_ element: Element, indent: Int) {
    let prefix = String(repeating: "  ", count: indent)
    var attrs = ""
    if !element.id.isEmpty {
        attrs += " id=\"\(element.id)\""
    }
    if !element.classList.isEmpty {
        attrs += " class=\"\(element.classList.joined(separator: " "))\""
    }
    print("\(prefix)<\(element.tagName)\(attrs)>")

    for child in element.childNodes {
        if let childElement = child as? Element {
            dumpElement(childElement, indent: indent + 1)
        } else if let text = child as? Text {
            let content = text.data.trimmingCharacters(in: .whitespacesAndNewlines)
            if !content.isEmpty {
                let truncated = content.prefix(50)
                print("\(prefix)  \"\(truncated)\"")
            }
        }
    }

    print("\(prefix)</\(element.tagName)>")
}

func dumpLayoutBox(_ box: LayoutBox, indent: Int) {
    let prefix = String(repeating: "  ", count: indent)
    let content = box.dimensions.content
    let typeStr: String
    switch box.boxType {
    case .block: typeStr = "BLOCK"
    case .inline: typeStr = "INLINE"
    case .inlineBlock: typeStr = "INLINE-BLOCK"
    case .anonymous: typeStr = "ANON"
    case .text: typeStr = "TEXT"
    }

    var info = "[\(typeStr)]"
    if let element = box.element {
        info += " <\(element.tagName)>"
    }
    if let text = box.textContent {
        let truncated = text.prefix(30).replacingOccurrences(of: "\n", with: "\\n")
        info += " \"\(truncated)\""
    }
    info += " (\(content.x),\(content.y) \(content.width)x\(content.height))"

    print("\(prefix)\(info)")

    for child in box.children {
        dumpLayoutBox(child, indent: indent + 1)
    }
}

// MARK: - Entry Point

@main
struct TUIBrowserCLI {
    static func main() async {
        await runMain()
    }
}
