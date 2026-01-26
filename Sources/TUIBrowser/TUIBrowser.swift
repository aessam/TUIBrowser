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
        showImages: Bool = true,
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
public enum InputMode: Equatable {
    case normal                    // Normal browsing mode
    case urlInput                  // Typing a URL
    case textInput(cursor: Int)    // Typing in a form field (cursor position)

    public static func == (lhs: InputMode, rhs: InputMode) -> Bool {
        switch (lhs, rhs) {
        case (.normal, .normal): return true
        case (.urlInput, .urlInput): return true
        case (.textInput(let c1), .textInput(let c2)): return c1 == c2
        default: return false
        }
    }
}

// MARK: - Image Cache

/// Cache for decoded images
public final class ImageCache: @unchecked Sendable, ImageCacheProtocol {
    private var cache: [String: PixelBuffer] = [:]
    private let lock = NSLock()

    public init() {}

    /// Get cached image for URL
    public func get(_ url: String) -> PixelBuffer? {
        lock.lock()
        defer { lock.unlock() }
        return cache[url]
    }

    /// Store decoded image for URL
    public func set(_ url: String, image: PixelBuffer) {
        lock.lock()
        defer { lock.unlock() }
        cache[url] = image
    }

    /// Check if URL is cached
    public func contains(_ url: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return cache[url] != nil
    }

    /// Clear the cache
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAll()
    }

    /// Number of cached images
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return cache.count
    }
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

    /// Focusable elements in the current document
    public var focusableElements: [Element] = []

    /// Index of currently focused element (nil if nothing focused)
    public var focusedElementIndex: Int? = nil

    /// Text buffer for focused text input
    public var textInputBuffer: String = ""

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
        self.focusableElements = []
        self.focusedElementIndex = nil
        self.textInputBuffer = ""
    }

    /// Get the currently focused element
    public var focusedElement: Element? {
        guard let index = focusedElementIndex,
              index >= 0 && index < focusableElements.count else {
            return nil
        }
        return focusableElements[index]
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

    /// Image cache for decoded images
    public let imageCache: ImageCache

    /// Focus manager for keyboard navigation
    private let focusManager: FocusManager

    /// Terminal canvas
    private var canvas: Canvas?

    /// Terminal dimensions
    private var terminalWidth: Int = 80
    private var terminalHeight: Int = 24

    // MARK: - Initialization

    public init(config: BrowserConfig = .default) {
        self.config = config
        self.state = BrowserState()
        self.imageCache = ImageCache()
        self.focusManager = FocusManager()
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

        // Collect focusable elements for keyboard navigation
        state.focusableElements = focusManager.collectFocusableElements(from: document)
        state.focusedElementIndex = nil
        state.textInputBuffer = ""

        // Fetch images if enabled
        if config.showImages {
            await fetchImages(from: document, baseURL: url)
        }
    }

    // MARK: - Image Fetching

    /// Fetch and decode images from the document
    private func fetchImages(from document: Document, baseURL: TUIURL.URL) async {
        let imgElements = document.getElementsByTagName("img")

        for img in imgElements {
            guard let src = img.getAttribute("src"), !src.isEmpty else {
                continue
            }

            // Resolve relative URL
            let absoluteURL = resolveImageURL(src, baseURL: baseURL)
            guard let imageURLString = absoluteURL else {
                continue
            }

            // Skip if already cached
            if imageCache.contains(imageURLString) {
                continue
            }

            // Parse URL
            guard case .success(let imageURL) = URLParser.parse(imageURLString) else {
                continue
            }

            // Skip non-http(s) URLs
            guard imageURL.scheme == "http" || imageURL.scheme == "https" else {
                continue
            }

            do {
                // Fetch image data
                let response = try await httpClient.fetchWithURLSession(url: imageURL)

                // Check for success
                guard response.statusCode >= 200 && response.statusCode < 300 else {
                    continue
                }

                let imageData = response.body
                guard !imageData.isEmpty else {
                    continue
                }

                // Decode image
                let decoder = ImageDecoder()
                if let pixelBuffer = decoder.decode(imageData) {
                    imageCache.set(imageURLString, image: pixelBuffer)
                }
            } catch {
                // Silently skip failed image loads
                continue
            }
        }
    }

    /// Resolve image URL relative to base URL
    private func resolveImageURL(_ src: String, baseURL: TUIURL.URL) -> String? {
        // Handle data URLs (skip them)
        if src.hasPrefix("data:") {
            return nil
        }

        // Handle absolute URLs
        if src.hasPrefix("http://") || src.hasPrefix("https://") {
            return src
        }

        // Handle protocol-relative URLs
        if src.hasPrefix("//") {
            return "\(baseURL.scheme):\(src)"
        }

        // Handle absolute paths
        if src.hasPrefix("/") {
            var port = ""
            if let p = baseURL.port {
                port = ":\(p)"
            }
            return "\(baseURL.scheme)://\(baseURL.host ?? "")\(port)\(src)"
        }

        // Handle relative paths
        var basePath = baseURL.path
        if !basePath.hasSuffix("/") {
            basePath = (basePath as NSString).deletingLastPathComponent
        }
        if basePath.isEmpty {
            basePath = "/"
        }
        var port = ""
        if let p = baseURL.port {
            port = ":\(p)"
        }

        // Normalize path
        let fullPath = basePath.hasSuffix("/") ? "\(basePath)\(src)" : "\(basePath)/\(src)"
        return "\(baseURL.scheme)://\(baseURL.host ?? "")\(port)\(fullPath)"
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
    public func render(width: Int, height: Int, inputMode: InputMode = .normal) -> Canvas {
        terminalWidth = width
        terminalHeight = height

        let canvas = Canvas(width: width, height: height)

        if let layout = state.layout {
            // Create renderer with image cache and focus state
            let isInTextInput: Bool
            let textCursor: Int
            switch inputMode {
            case .textInput(let cursor):
                isInTextInput = true
                textCursor = cursor
            default:
                isInTextInput = false
                textCursor = 0
            }

            let renderer = Renderer(
                imageCache: config.showImages ? imageCache : nil,
                focusedElement: state.focusedElement,
                isInTextInputMode: isInTextInput,
                textInputCursor: textCursor
            )
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
            // Non-interactive mode: still load and display the page
            if let url = initialURL {
                print("Loading \(url)...")
                do {
                    try await navigate(to: url)
                    printStaticOutput()
                } catch {
                    print("Error loading page: \(error)")
                }
            } else {
                print("TUIBrowser \(Browser.version)")
                print("Usage: tuibrowser <url>")
                print("Run in a terminal for interactive mode.")
            }
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
                let canvas = render(width: terminalWidth, height: terminalHeight, inputMode: inputMode)

                // Draw URL input bar if in URL input mode
                if inputMode == .urlInput {
                    drawInputBar(to: canvas, prompt: "URL: ", text: urlBuffer)
                }

                // Draw text input indicator when in text input mode
                if case .textInput = inputMode {
                    if let element = state.focusedElement {
                        let inputType = element.getAttribute("type")?.lowercased() ?? "text"
                        let prompt = inputType == "password" ? "Password: " : "Input: "
                        drawInputBar(to: canvas, prompt: prompt, text: state.textInputBuffer)
                    }
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
                    case .enterTextInputMode:
                        inputMode = .textInput(cursor: state.textInputBuffer.count)
                        needsRedraw = true
                    case .redraw:
                        needsRedraw = true
                    case .fullRedraw:
                        needsRedraw = true
                        needsFullRedraw = true
                    case .none:
                        break
                    }

                case .textInput(let cursor):
                    var newCursor = cursor
                    let result = await handleTextInput(key, buffer: &state.textInputBuffer, cursor: &newCursor)
                    switch result {
                    case .stay:
                        inputMode = .textInput(cursor: newCursor)
                        needsRedraw = true
                    case .cancel:
                        inputMode = .normal
                        needsRedraw = true
                        needsFullRedraw = true
                    case .submit:
                        inputMode = .normal
                        // Update the element's value
                        if let element = state.focusedElement {
                            element.setAttribute("value", state.textInputBuffer)
                        }
                        // Try to submit form
                        if let element = state.focusedElement {
                            let submitResult = await submitParentForm(of: element)
                            switch submitResult {
                            case .fullRedraw:
                                needsFullRedraw = true
                            default:
                                break
                            }
                        }
                        needsRedraw = true
                        needsFullRedraw = true
                    case .exitInputMode:
                        inputMode = .normal
                        // Update the element's value
                        if let element = state.focusedElement {
                            element.setAttribute("value", state.textInputBuffer)
                        }
                        needsRedraw = true
                        needsFullRedraw = true
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
        case enterTextInputMode
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

        // Tab navigation: move focus forward
        case .tab:
            return moveFocusForward()

        // Enter: activate focused element
        case .enter:
            return await activateFocusedElement()

        default:
            return .none
        }
    }

    // MARK: - Focus Navigation

    /// Move focus to the next focusable element
    private func moveFocusForward() -> NormalInputResult {
        guard !state.focusableElements.isEmpty else {
            state.statusMessage = "No focusable elements"
            return .redraw
        }

        if let nextIndex = focusManager.nextFocusIndex(from: state.focusedElementIndex, in: state.focusableElements) {
            state.focusedElementIndex = nextIndex

            // Scroll to make focused element visible
            scrollToFocusedElement()

            if let element = state.focusedElement {
                let tagName = element.tagName.lowercased()
                let text = element.textContent.trimmingCharacters(in: .whitespacesAndNewlines)
                let displayText = text.isEmpty ? tagName : String(text.prefix(30))
                state.statusMessage = "[\(tagName)] \(displayText)"
            }
        }
        return .redraw
    }

    /// Move focus to the previous focusable element
    private func moveFocusBackward() -> NormalInputResult {
        guard !state.focusableElements.isEmpty else {
            state.statusMessage = "No focusable elements"
            return .redraw
        }

        if let prevIndex = focusManager.previousFocusIndex(from: state.focusedElementIndex, in: state.focusableElements) {
            state.focusedElementIndex = prevIndex

            // Scroll to make focused element visible
            scrollToFocusedElement()

            if let element = state.focusedElement {
                let tagName = element.tagName.lowercased()
                let text = element.textContent.trimmingCharacters(in: .whitespacesAndNewlines)
                let displayText = text.isEmpty ? tagName : String(text.prefix(30))
                state.statusMessage = "[\(tagName)] \(displayText)"
            }
        }
        return .redraw
    }

    /// Scroll the viewport to ensure the focused element is visible
    private func scrollToFocusedElement() {
        guard let element = state.focusedElement,
              let layout = state.layout,
              let box = focusManager.findLayoutBox(for: element, in: layout) else {
            return
        }

        let elementY = box.dimensions.content.y
        let elementHeight = box.dimensions.content.height
        let viewportHeight = terminalHeight - 2  // Account for status bar

        // If element is above viewport, scroll up
        if elementY < state.scrollY {
            state.scrollY = max(0, elementY - 1)
        }
        // If element is below viewport, scroll down
        else if elementY + elementHeight > state.scrollY + viewportHeight {
            state.scrollY = elementY + elementHeight - viewportHeight + 1
        }
    }

    /// Activate the currently focused element
    private func activateFocusedElement() async -> NormalInputResult {
        guard let element = state.focusedElement else {
            return .none
        }

        let tagName = element.tagName.lowercased()

        switch tagName {
        case "a":
            // Follow link
            if let href = element.getAttribute("href"),
               let resolvedURL = resolveURL(href) {
                state.statusMessage = "Loading..."
                do {
                    try await navigate(to: resolvedURL)
                } catch {
                    state.lastError = error.localizedDescription
                }
                return .fullRedraw
            }

        case "input":
            let inputType = element.getAttribute("type")?.lowercased() ?? "text"
            switch inputType {
            case "submit":
                // Submit the form
                return await submitParentForm(of: element)
            case "checkbox":
                // Toggle checkbox
                if element.hasAttribute("checked") {
                    element.removeAttribute("checked")
                } else {
                    element.setAttribute("checked", "checked")
                }
                return .redraw
            case "radio":
                // Select radio button
                element.setAttribute("checked", "checked")
                return .redraw
            case "text", "password", "email", "search", "url", "tel", "number":
                // Enter text input mode
                state.textInputBuffer = element.getAttribute("value") ?? ""
                return .enterTextInputMode
            default:
                break
            }

        case "button":
            // Check if button is inside a form and submits it
            return await submitParentForm(of: element)

        case "select":
            // TODO: Implement select dropdown
            state.statusMessage = "Select dropdowns not yet supported"
            return .redraw

        case "textarea":
            // Enter text input mode for textarea
            state.textInputBuffer = element.textContent
            return .enterTextInputMode

        default:
            break
        }

        return .none
    }

    /// Submit the parent form of an element
    private func submitParentForm(of element: Element) async -> NormalInputResult {
        // Find parent form
        var current: Node? = element
        while let node = current {
            if let el = node as? Element, el.tagName.lowercased() == "form" {
                return await submitForm(el)
            }
            current = node.parentNode
        }
        return .none
    }

    /// Submit a form
    private func submitForm(_ form: Element) async -> NormalInputResult {
        let formSubmission = FormSubmission()

        guard let currentURL = state.currentURL,
              let submitURL = formSubmission.buildSubmitURL(form, baseURL: currentURL) else {
            state.statusMessage = "Cannot submit form"
            return .redraw
        }

        state.statusMessage = "Submitting form..."
        do {
            try await navigate(to: submitURL)
        } catch {
            state.lastError = error.localizedDescription
        }
        return .fullRedraw
    }

    /// Result of handling URL input mode
    private enum URLInputResult {
        case stay
        case cancel
        case submit(String)
    }

    /// Result of handling text input mode
    private enum TextInputResult {
        case stay
        case cancel
        case submit
        case exitInputMode
    }

    /// Handle input in text input mode (form fields)
    private func handleTextInput(_ key: KeyCode, buffer: inout String, cursor: inout Int) async -> TextInputResult {
        switch key {
        // Submit form
        case .enter:
            return .submit

        // Cancel
        case .escape:
            return .cancel

        // Exit input mode without submitting
        case .tab:
            return .exitInputMode

        // Delete character before cursor
        case .backspace:
            if cursor > 0 && !buffer.isEmpty {
                let index = buffer.index(buffer.startIndex, offsetBy: cursor - 1)
                buffer.remove(at: index)
                cursor -= 1
            }
            return .stay

        // Delete character at cursor
        case .delete:
            if cursor < buffer.count {
                let index = buffer.index(buffer.startIndex, offsetBy: cursor)
                buffer.remove(at: index)
            }
            return .stay

        // Move cursor left
        case .left:
            if cursor > 0 {
                cursor -= 1
            }
            return .stay

        // Move cursor right
        case .right:
            if cursor < buffer.count {
                cursor += 1
            }
            return .stay

        // Move cursor to beginning
        case .home, .ctrlA:
            cursor = 0
            return .stay

        // Move cursor to end
        case .end, .ctrlE:
            cursor = buffer.count
            return .stay

        // Delete word
        case .ctrlW:
            while cursor > 0 && (cursor > buffer.count || buffer[buffer.index(buffer.startIndex, offsetBy: cursor - 1)] == " ") {
                let index = buffer.index(buffer.startIndex, offsetBy: cursor - 1)
                buffer.remove(at: index)
                cursor -= 1
            }
            while cursor > 0 && buffer[buffer.index(buffer.startIndex, offsetBy: cursor - 1)] != " " {
                let index = buffer.index(buffer.startIndex, offsetBy: cursor - 1)
                buffer.remove(at: index)
                cursor -= 1
            }
            return .stay

        // Clear line
        case .ctrlU:
            buffer = ""
            cursor = 0
            return .stay

        // Kill to end of line
        case .ctrlK:
            if cursor < buffer.count {
                let index = buffer.index(buffer.startIndex, offsetBy: cursor)
                buffer.removeSubrange(index...)
            }
            return .stay

        // Add character
        case .char(let c):
            let index = buffer.index(buffer.startIndex, offsetBy: cursor)
            buffer.insert(c, at: index)
            cursor += 1
            return .stay

        case .space:
            let index = buffer.index(buffer.startIndex, offsetBy: cursor)
            buffer.insert(" ", at: index)
            cursor += 1
            return .stay

        default:
            return .stay
        }
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
