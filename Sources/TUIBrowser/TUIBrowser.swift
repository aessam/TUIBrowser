// TUIBrowser - Main browser orchestration
//
// Complete terminal-based web browser implementation.

import Foundation
import TUICore
import TUITerminal
import TUIURL
import TUINetworking
import TUIHTMLParser
import TUICSSParser
import TUIJSEngine
import TUIStyle
import TUILayout
import TUIRender

// MARK: - Browser Configuration

/// Browser configuration options
public struct BrowserConfig: Sendable {
    /// User agent string
    public var userAgent: String

    /// Whether to load stylesheets
    public var loadStylesheets: Bool

    /// Whether to show images (as ASCII art)
    public var showImages: Bool

    /// Whether to enable JavaScript (placeholder)
    public var enableJavaScript: Bool

    /// Request timeout in seconds
    public var timeout: Double

    /// Maximum redirects to follow
    public var maxRedirects: Int

    public init(
        userAgent: String = Browser.userAgent,
        loadStylesheets: Bool = true,
        showImages: Bool = false,
        enableJavaScript: Bool = false,
        timeout: Double = 30.0,
        maxRedirects: Int = 10
    ) {
        self.userAgent = userAgent
        self.loadStylesheets = loadStylesheets
        self.showImages = showImages
        self.enableJavaScript = enableJavaScript
        self.timeout = timeout
        self.maxRedirects = maxRedirects
    }

    public static let `default` = BrowserConfig()
}

// MARK: - Input Mode

/// Browser input mode
public enum InputMode {
    case normal      // Normal browsing mode
    case urlInput    // Typing a URL
}

// MARK: - Browser State

/// Current state of the browser
public struct BrowserState {
    /// Current URL
    public var currentURL: TUIURL.URL?

    /// Parsed document
    public var document: Document?

    /// Computed styles
    public var styles: StyleMap?

    /// Layout tree
    public var layout: LayoutBox?

    /// Page title
    public var title: String

    /// Vertical scroll offset
    public var scrollY: Int

    /// Navigation history (URLs)
    public var history: [TUIURL.URL]

    /// Current position in history
    public var historyIndex: Int

    /// Status message
    public var statusMessage: String

    /// Whether currently loading
    public var isLoading: Bool

    /// Last error message
    public var lastError: String?

    public init() {
        self.currentURL = nil
        self.document = nil
        self.styles = nil
        self.layout = nil
        self.title = "TUIBrowser"
        self.scrollY = 0
        self.history = []
        self.historyIndex = -1
        self.statusMessage = "Ready"
        self.isLoading = false
        self.lastError = nil
    }
}

// MARK: - Browser

/// Main browser module
public final class Browser {
    public static let version = "0.1.0"
    public static let name = "TUIBrowser"
    public static let userAgent = "TUIBrowser/\(version) (Terminal; Like Links)"

    /// Browser configuration
    public let config: BrowserConfig

    /// Current state
    public private(set) var state: BrowserState

    /// HTTP client
    private let httpClient: HTTPClient

    /// Terminal canvas
    private var canvas: Canvas?

    /// Terminal dimensions
    private var terminalWidth: Int = 80
    private var terminalHeight: Int = 24

    // MARK: - Initialization

    public init(config: BrowserConfig = .default) {
        self.config = config
        self.state = BrowserState()
        self.httpClient = HTTPClient(
            timeout: config.timeout,
            maxRedirects: config.maxRedirects,
            defaultHeaders: ["User-Agent": config.userAgent]
        )
    }

    // MARK: - Navigation

    /// Navigate to a URL
    public func navigate(to urlString: String) async throws {
        state.isLoading = true
        state.statusMessage = "Loading \(urlString)..."
        state.lastError = nil

        defer {
            state.isLoading = false
        }

        // Parse URL
        let url: TUIURL.URL
        switch URLParser.parse(urlString) {
        case .success(let parsed):
            url = parsed
        case .failure(let error):
            state.lastError = "Invalid URL: \(error)"
            state.statusMessage = "Error"
            throw BrowserError.invalidURL(urlString)
        }

        // Fetch content using URLSession for better TLS support
        let response: HTTPResponse
        do {
            response = try await httpClient.fetchWithURLSession(url: url)
        } catch {
            state.lastError = "Network error: \(error)"
            state.statusMessage = "Error"
            throw BrowserError.networkError(error.localizedDescription)
        }

        // Check response status
        guard response.statusCode >= 200 && response.statusCode < 300 else {
            state.lastError = "HTTP \(response.statusCode)"
            state.statusMessage = "Error"
            throw BrowserError.httpError(response.statusCode)
        }

        // Get HTML content
        let html = response.bodyString ?? ""

        // Parse HTML
        let document = HTMLParser.parse(html)

        // Parse stylesheets (from <style> tags)
        var stylesheets: [Stylesheet] = []
        if config.loadStylesheets {
            let styleElements = document.getElementsByTagName("style")
            for styleElement in styleElements {
                let cssText = styleElement.textContent
                let stylesheet = CSSParser.parseStylesheet(cssText)
                stylesheets.append(stylesheet)
            }
        }

        // Resolve styles
        let styles = StyleResolver.resolve(
            document: document,
            stylesheets: stylesheets
        )

        // Build layout
        let layout = LayoutEngine.layout(
            document: document,
            styles: styles,
            width: terminalWidth
        )

        // Update state
        state.currentURL = url
        state.document = document
        state.styles = styles
        state.layout = layout
        state.title = document.title
        state.scrollY = 0
        state.statusMessage = "Loaded"

        // Add to history
        if state.historyIndex < state.history.count - 1 {
            state.history.removeSubrange((state.historyIndex + 1)...)
        }
        state.history.append(url)
        state.historyIndex = state.history.count - 1
    }

    /// Go back in history
    public func goBack() async throws {
        guard state.historyIndex > 0 else {
            state.statusMessage = "No previous page"
            return
        }

        state.historyIndex -= 1
        let url = state.history[state.historyIndex]
        try await navigate(to: url.description)
    }

    /// Go forward in history
    public func goForward() async throws {
        guard state.historyIndex < state.history.count - 1 else {
            state.statusMessage = "No next page"
            return
        }

        state.historyIndex += 1
        let url = state.history[state.historyIndex]
        try await navigate(to: url.description)
    }

    /// Reload current page
    public func reload() async throws {
        guard let url = state.currentURL else {
            state.statusMessage = "No page to reload"
            return
        }

        try await navigate(to: url.description)
    }

    // MARK: - Scrolling

    /// Scroll down by specified lines
    public func scrollDown(lines: Int = 1) {
        guard let layout = state.layout else { return }

        let maxScroll = max(0, layout.dimensions.content.height - terminalHeight + 2)
        state.scrollY = min(state.scrollY + lines, maxScroll)
    }

    /// Scroll up by specified lines
    public func scrollUp(lines: Int = 1) {
        state.scrollY = max(0, state.scrollY - lines)
    }

    /// Scroll to top
    public func scrollToTop() {
        state.scrollY = 0
    }

    /// Scroll to bottom
    public func scrollToBottom() {
        guard let layout = state.layout else { return }
        state.scrollY = max(0, layout.dimensions.content.height - terminalHeight + 2)
    }

    // MARK: - Rendering

    /// Render current page to a canvas
    public func render(width: Int, height: Int) -> Canvas {
        terminalWidth = width
        terminalHeight = height

        let canvas = Canvas(width: width, height: height)

        if let layout = state.layout {
            let renderer = Renderer()
            renderer.render(layout: layout, to: canvas, scrollY: state.scrollY)
        } else {
            // Render welcome/error screen
            renderWelcomeScreen(to: canvas)
        }

        // Render status bar
        renderStatusBar(to: canvas)

        return canvas
    }

    private func renderWelcomeScreen(to canvas: Canvas) {
        let style = TextStyle(bold: true, foreground: .white)
        let titleY = 2

        canvas.drawText("TUIBrowser \(Browser.version)", at: Point(x: 2, y: titleY), style: style)
        canvas.drawText("A terminal web browser", at: Point(x: 2, y: titleY + 1), style: .default)

        if let error = state.lastError {
            let errorStyle = TextStyle(foreground: .red)
            canvas.drawText("Error: \(error)", at: Point(x: 2, y: titleY + 3), style: errorStyle)
        }

        canvas.drawText("Press 'g' to enter a URL, 'q' to quit", at: Point(x: 2, y: titleY + 5), style: .default)
    }

    private func renderStatusBar(to canvas: Canvas) {
        let y = canvas.height - 1
        let style = TextStyle(inverse: true)

        // Fill status bar background
        for x in 0..<canvas.width {
            canvas.setCell(x: x, y: y, char: " ", style: style)
        }

        // URL or title
        let titleText: String
        if let url = state.currentURL {
            titleText = state.title.isEmpty ? url.description : state.title
        } else {
            titleText = "TUIBrowser"
        }

        let displayTitle = String(titleText.prefix(canvas.width - 20))
        canvas.drawText(displayTitle, at: Point(x: 1, y: y), style: style)

        // Scroll position
        if let layout = state.layout {
            let totalHeight = layout.dimensions.content.height
            let percent = totalHeight > 0 ? (state.scrollY * 100) / totalHeight : 0
            let scrollText = "\(percent)%"
            canvas.drawText(scrollText, at: Point(x: canvas.width - scrollText.count - 1, y: y), style: style)
        }
    }

    // MARK: - Run Loop

    /// Run the browser in interactive mode
    public func run(initialURL: String? = nil) async {
        // Initialize terminal for interactive mode
        let rawMode = RawMode()
        let output = TerminalOutput()
        var inputMode: InputMode = .normal
        var urlBuffer = ""
        var needsRedraw = true
        var needsFullRedraw = true
        var resizeFlag = false

        // Set up resize handler
        SignalHandler.onResize { [weak self] size in
            self?.terminalWidth = size.width
            self?.terminalHeight = size.height
            resizeFlag = true
        }

        // Enable raw mode and enter alternate screen
        do {
            try rawMode.enable()
        } catch {
            print("Error: Could not enable raw mode - \(error)")
            print("Running in non-interactive mode...")
            printStaticOutput()
            return
        }

        // Enter alternate screen buffer
        output.write(ANSICode.enterAlternateScreen)
        output.write(ANSICode.hideCursor)
        output.flush()

        // Update terminal size
        let size = TerminalSize.current()
        terminalWidth = size.width
        terminalHeight = size.height

        // Load initial URL if provided
        if let url = initialURL {
            state.statusMessage = "Loading..."
            needsRedraw = true
            do {
                try await navigate(to: url)
            } catch {
                state.lastError = error.localizedDescription
            }
            needsRedraw = true
            needsFullRedraw = true
        }

        // Main event loop
        var running = true
        while running {
            // Check for resize
            if resizeFlag {
                resizeFlag = false
                let newSize = TerminalSize.current()
                terminalWidth = newSize.width
                terminalHeight = newSize.height

                // Re-layout if we have a document
                if let document = state.document, let styles = state.styles {
                    state.layout = LayoutEngine.layout(
                        document: document,
                        styles: styles,
                        width: terminalWidth
                    )
                }

                needsRedraw = true
                needsFullRedraw = true
            }

            // Render if needed
            if needsRedraw {
                let canvas = render(width: terminalWidth, height: terminalHeight)

                // Draw URL input bar if in URL input mode
                if inputMode == .urlInput {
                    drawInputBar(to: canvas, prompt: "URL: ", text: urlBuffer)
                }

                canvas.render(to: output, fullRedraw: needsFullRedraw)
                output.flush()
                needsRedraw = false
                needsFullRedraw = false
            }

            // Read input (non-blocking with ~100ms timeout from raw mode settings)
            if let key = TerminalInput.readKey() {
                switch inputMode {
                case .normal:
                    let result = await handleNormalInput(key)
                    switch result {
                    case .exit:
                        running = false
                    case .enterURLMode:
                        inputMode = .urlInput
                        urlBuffer = ""
                        needsRedraw = true
                    case .redraw:
                        needsRedraw = true
                    case .fullRedraw:
                        needsRedraw = true
                        needsFullRedraw = true
                    case .none:
                        break
                    }

                case .urlInput:
                    let result = handleURLInput(key, buffer: &urlBuffer)
                    switch result {
                    case .stay:
                        needsRedraw = true
                    case .cancel:
                        inputMode = .normal
                        needsRedraw = true
                        needsFullRedraw = true
                    case .submit(let url):
                        inputMode = .normal
                        state.statusMessage = "Loading..."
                        needsRedraw = true
                        needsFullRedraw = true

                        // Render loading state
                        let loadingCanvas = render(width: terminalWidth, height: terminalHeight)
                        loadingCanvas.render(to: output, fullRedraw: true)
                        output.flush()

                        // Navigate
                        do {
                            try await navigate(to: url)
                        } catch {
                            state.lastError = error.localizedDescription
                        }
                        needsRedraw = true
                        needsFullRedraw = true
                    }
                }
            }
        }

        // Cleanup: restore terminal
        output.write(ANSICode.showCursor)
        output.write(ANSICode.exitAlternateScreen)
        output.flush()
        rawMode.disable()
        SignalHandler.removeAllHandlers()
    }

    /// Print static output (non-interactive fallback)
    private func printStaticOutput() {
        if state.layout != nil {
            let canvas = render(width: terminalWidth, height: terminalHeight)
            for y in 0..<canvas.height {
                var line = ""
                for x in 0..<canvas.width {
                    line.append(canvas[x, y].character)
                }
                print(line)
            }
        } else {
            print("TUIBrowser \(Browser.version)")
            print("Press 'g' to enter a URL, 'q' to quit")
        }
    }

    // MARK: - Input Handling

    /// Result of handling normal mode input
    private enum NormalInputResult {
        case none
        case exit
        case enterURLMode
        case redraw
        case fullRedraw
    }

    /// Handle input in normal browsing mode
    private func handleNormalInput(_ key: KeyCode) async -> NormalInputResult {
        switch key {
        // Exit
        case .char("q"), .char("Q"), .ctrlC:
            return .exit

        // Enter URL mode
        case .char("g"), .char("G"):
            return .enterURLMode

        // Scroll down
        case .char("j"), .down:
            scrollDown()
            return .redraw

        // Scroll up
        case .char("k"), .up:
            scrollUp()
            return .redraw

        // Page down
        case .space, .pageDown:
            scrollDown(lines: terminalHeight - 2)
            return .redraw

        // Page up
        case .ctrlU, .pageUp:
            scrollUp(lines: terminalHeight - 2)
            return .redraw

        // Scroll to top
        case .home:
            scrollToTop()
            return .redraw

        // Scroll to bottom
        case .end:
            scrollToBottom()
            return .redraw

        // Reload
        case .char("r"), .char("R"):
            do {
                try await reload()
            } catch {
                state.lastError = error.localizedDescription
            }
            return .fullRedraw

        // Go back
        case .char("b"), .char("B"):
            do {
                try await goBack()
            } catch {
                state.lastError = error.localizedDescription
            }
            return .fullRedraw

        // Go forward
        case .char("f"), .char("F"):
            do {
                try await goForward()
            } catch {
                state.lastError = error.localizedDescription
            }
            return .fullRedraw

        // Force full redraw
        case .ctrlL:
            return .fullRedraw

        default:
            return .none
        }
    }

    /// Result of handling URL input mode
    private enum URLInputResult {
        case stay
        case cancel
        case submit(String)
    }

    /// Handle input in URL entry mode
    private func handleURLInput(_ key: KeyCode, buffer: inout String) -> URLInputResult {
        switch key {
        // Submit URL
        case .enter:
            let url = buffer.trimmingCharacters(in: .whitespaces)
            if url.isEmpty {
                return .cancel
            }
            // Add https:// if no scheme provided
            let finalURL: String
            if !url.contains("://") {
                finalURL = "https://" + url
            } else {
                finalURL = url
            }
            return .submit(finalURL)

        // Cancel
        case .escape, .ctrlC:
            return .cancel

        // Delete last character
        case .backspace:
            if !buffer.isEmpty {
                buffer.removeLast()
            }
            return .stay

        // Delete word
        case .ctrlW:
            // Remove last word
            while !buffer.isEmpty && buffer.last == " " {
                buffer.removeLast()
            }
            while !buffer.isEmpty && buffer.last != " " {
                buffer.removeLast()
            }
            return .stay

        // Clear line
        case .ctrlU:
            buffer = ""
            return .stay

        // Add character
        case .char(let c):
            buffer.append(c)
            return .stay

        case .space:
            buffer.append(" ")
            return .stay

        default:
            return .stay
        }
    }

    // MARK: - Input Bar Rendering

    /// Draw the URL input bar
    private func drawInputBar(to canvas: Canvas, prompt: String, text: String) {
        let y = canvas.height - 2  // Second to last row (above status bar)
        let promptStyle = TextStyle(bold: true, foreground: .cyan)
        let textStyle = TextStyle(foreground: .white)
        let bgStyle = TextStyle(inverse: true)

        // Fill background
        for x in 0..<canvas.width {
            canvas.setCell(x: x, y: y, char: " ", style: bgStyle)
        }

        // Draw prompt
        canvas.drawText(prompt, at: Point(x: 1, y: y), style: promptStyle)

        // Draw text with cursor
        let textStart = 1 + prompt.count
        let maxTextWidth = canvas.width - textStart - 2
        let displayText: String
        if text.count > maxTextWidth {
            // Show end of text if too long
            displayText = String(text.suffix(maxTextWidth - 1))
        } else {
            displayText = text
        }
        canvas.drawText(displayText, at: Point(x: textStart, y: y), style: textStyle)

        // Draw cursor
        let cursorX = textStart + displayText.count
        if cursorX < canvas.width - 1 {
            canvas.setCell(x: cursorX, y: y, char: "█", style: textStyle)
        }
    }
}

// MARK: - Browser Errors

/// Browser-specific errors
public enum BrowserError: Error, CustomStringConvertible {
    case invalidURL(String)
    case networkError(String)
    case httpError(Int)
    case parseError(String)
    case renderError(String)

    public var description: String {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .networkError(let msg):
            return "Network error: \(msg)"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .parseError(let msg):
            return "Parse error: \(msg)"
        case .renderError(let msg):
            return "Render error: \(msg)"
        }
    }
}

// MARK: - Link Extraction

extension Browser {
    /// Get all links from the current page
    public func getLinks() -> [(text: String, href: String)] {
        guard let document = state.document else { return [] }

        var links: [(text: String, href: String)] = []
        let anchors = document.getElementsByTagName("a")

        for anchor in anchors {
            let text = anchor.textContent.trimmingCharacters(in: .whitespacesAndNewlines)
            let href = anchor.getAttribute("href") ?? ""
            if !href.isEmpty {
                links.append((text: text, href: href))
            }
        }

        return links
    }

    /// Resolve a relative URL against the current page
    public func resolveURL(_ href: String) -> String? {
        guard let currentURL = state.currentURL else {
            return href
        }

        // Handle absolute URLs
        if href.hasPrefix("http://") || href.hasPrefix("https://") {
            return href
        }

        // Handle protocol-relative URLs
        if href.hasPrefix("//") {
            return "\(currentURL.scheme):\(href)"
        }

        // Handle absolute paths
        if href.hasPrefix("/") {
            var port = ""
            if let p = currentURL.port {
                port = ":\(p)"
            }
            return "\(currentURL.scheme)://\(currentURL.host ?? "")\(port)\(href)"
        }

        // Handle relative paths
        var basePath = currentURL.path
        if !basePath.hasSuffix("/") {
            basePath = (basePath as NSString).deletingLastPathComponent
        }
        var port = ""
        if let p = currentURL.port {
            port = ":\(p)"
        }
        return "\(currentURL.scheme)://\(currentURL.host ?? "")\(port)\(basePath)/\(href)"
    }
}
