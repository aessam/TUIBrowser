# TUIBrowser Research: Making It Actually Work

## Research Date: 2026-01-26

---

## Terminal Browser Landscape

### Carbonyl (Best-in-Class)
- **How it works**: Chromium + custom Skia backend → SVG → terminal characters
- **Image rendering**: Unicode half-block (▄) with fg/bg colors = 2 pixels/char
- **JS Support**: Full (it's Chromium)
- **Performance**: 60 FPS, <1s startup, 0% idle CPU
- **Source**: https://github.com/fathyb/carbonyl

### Browsh
- **How it works**: Firefox headless + browser extension → simplified HTML → terminal
- **JS Support**: Full (it's Firefox)
- **Downsides**: 50x more CPU than Carbonyl, slow, formatting issues
- **Source**: https://github.com/nickolasburr/browsh

### Robinson (Toy Browser)
- **How it works**: Custom HTML/CSS parser → layout → paint (no networking, no JS)
- **What it implements**: DOM tree, CSS selectors, box layout, painting
- **What it skips**: JavaScript, networking, most CSS, namespaces
- **Source**: https://limpet.net/mbrubeck/2014/08/08/toy-layout-engine-1.html

---

## Terminal Image Rendering Protocols

### 1. Half-Block Characters (Carbonyl's approach)
- Unicode ▄ (U+2584) lower half block
- Set foreground = top pixel color, background = bottom pixel color
- Result: 2 vertical pixels per character cell
- **Works everywhere** - just needs 24-bit color support

### 2. Braille Patterns (Already implemented in TUIBrowser!)
- Unicode U+2800-U+28FF
- 2x4 = 8 dots per character
- Higher resolution but monochrome per cell
- Good for line art, graphs

### 3. Sixel Protocol
- Ancient DEC protocol, palette-based (limited colors)
- Supported: xterm, mlterm, foot, VS Code terminal
- NOT supported: iTerm2 (uses own protocol), most others
- Check support: https://www.arewesixelyet.com/

### 4. Kitty Graphics Protocol
- Modern, full RGBA, best quality
- Only supported by Kitty terminal
- https://sw.kovidgoyal.net/kitty/graphics-protocol/

---

## JavaScript Engine Options

### QuickJS (Recommended for embedding)
- **Size**: ~367 KB compiled
- **Features**: ES2023, modules, async/generators, Proxy, BigInt
- **Speed**: Fast interpreter, <300μs runtime lifecycle
- **License**: MIT
- **Source**: https://bellard.org/quickjs/

### Duktape
- **Size**: ~4MB source
- **Features**: ES5/5.1 + some ES6
- **API**: Lua-like stack API
- **Works with**: C89 compilers
- **Source**: https://duktape.org/

### JavaScriptCore (macOS built-in)
- **Access**: `import JavaScriptCore` in Swift
- **Features**: Full modern JS
- **Limitation**: NO DOM included - must implement yourself
- **Swift bindings**: JXKit library available

### Critical Note
**All these engines are JS interpreters ONLY. They don't include:**
- document, window, navigator objects
- DOM manipulation (createElement, appendChild, etc.)
- Web APIs (fetch, XMLHttpRequest, localStorage)
- Event system (addEventListener)
- CSS Object Model

You must implement all DOM/Web APIs yourself or the JS is useless for web pages.

---

## Minimum DOM APIs for Basic Website Support

### Tier 1: Essential (Most sites break without these)
```javascript
// Document
document.getElementById(id)
document.querySelector(selector)
document.querySelectorAll(selector)
document.createElement(tag)
document.createTextNode(text)
document.body
document.head
document.documentElement

// Element
element.appendChild(child)
element.removeChild(child)
element.setAttribute(name, value)
element.getAttribute(name)
element.innerHTML  // getter and setter
element.textContent
element.classList.add/remove/contains
element.style  // CSSStyleDeclaration
element.parentNode
element.children
element.firstChild / lastChild
element.nextSibling / previousSibling

// Events
element.addEventListener(type, handler)
element.removeEventListener(type, handler)
event.preventDefault()
event.stopPropagation()
event.target
```

### Tier 2: Common (Many sites need these)
```javascript
// Document
document.getElementsByClassName(name)
document.getElementsByTagName(name)
document.createDocumentFragment()

// Element
element.insertBefore(new, reference)
element.replaceChild(new, old)
element.cloneNode(deep)
element.contains(other)
element.matches(selector)
element.closest(selector)
element.getBoundingClientRect()
element.scrollIntoView()

// Window/Global
window.setTimeout / clearTimeout
window.setInterval / clearInterval
window.requestAnimationFrame
window.location
window.history
window.localStorage / sessionStorage
console.log/warn/error

// Network
fetch(url, options)  // or XMLHttpRequest
```

### Tier 3: Modern SPAs (React/Vue/Angular sites)
```javascript
// These sites typically need:
- Full ES6+ (classes, modules, async/await, Proxy)
- MutationObserver
- IntersectionObserver
- ResizeObserver
- CustomEvent
- Promise
- Symbol, Map, Set, WeakMap, WeakSet
- Reflect, Proxy
- And hundreds more APIs...
```

---

## Practical Approaches for TUIBrowser

### Option A: Static Site Focus (Easiest)
**Target**: Wikipedia, documentation, blogs, news sites with SSR
**Effort**: Low
**What to add**:
1. Image decoding (CoreGraphics) + rendering (half-block/braille)
2. Better form element rendering
3. Better CSS support (flexbox basics, more selectors)

**Limitation**: No JS-heavy sites (Twitter, Gmail, etc.)

### Option B: Minimal JS + DOM (Medium)
**Target**: Sites with basic interactivity
**Effort**: Medium-High
**What to add**:
1. Embed QuickJS or use JavaScriptCore
2. Implement Tier 1 DOM APIs (~50 methods)
3. Implement basic events (click, input, submit)
4. Implement fetch() or XMLHttpRequest

**Limitation**: Modern SPAs still won't work

### Option C: Headless WebKit (Like Browsh)
**Target**: All websites
**Effort**: Medium (but heavy dependencies)
**How**:
1. Use WKWebView in headless mode
2. Inject JS to serialize rendered DOM
3. Convert to terminal output

**Limitation**: Requires macOS, heavy resource usage

### Option D: Embed Chromium (Like Carbonyl)
**Target**: All websites
**Effort**: Very High (but Carbonyl exists)
**Alternative**: Just use Carbonyl directly

---

## Recommended Path Forward

Given TUIBrowser's current state (HTML parser, CSS parser, layout engine, terminal rendering), the most practical approach is:

### Phase 1: Make static sites work well
1. Add image decoding + rendering
2. Improve CSS support
3. Better form rendering
4. Fix any remaining layout bugs

### Phase 2: Add minimal JavaScript
1. Embed JavaScriptCore (already on macOS)
2. Implement document.getElementById, querySelector, etc.
3. Implement element manipulation
4. Implement click events and form submission

### Phase 3: Add networking for JS
1. Implement fetch() binding
2. Implement XMLHttpRequest basics
3. Add localStorage/sessionStorage

This gets us to "Option B" level - supporting many sites with basic JS, while acknowledging that SPAs like Twitter will never work without a full browser engine.

---

## Image Decoding on macOS

```swift
import CoreGraphics
import ImageIO

func decodeImage(data: Data) -> PixelBuffer? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        return nil
    }

    let width = cgImage.width
    let height = cgImage.height
    var pixels = [UInt8](repeating: 0, count: width * height * 4)

    let context = CGContext(
        data: &pixels,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )

    context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    // Convert to PixelBuffer...
}
```

---

## Sources

- [Carbonyl GitHub](https://github.com/fathyb/carbonyl)
- [Robinson Toy Browser](https://limpet.net/mbrubeck/2014/08/08/toy-layout-engine-1.html)
- [QuickJS](https://bellard.org/quickjs/)
- [Duktape](https://duktape.org/)
- [JavaScriptCore Docs](https://developer.apple.com/documentation/javascriptcore)
- [Are We Sixel Yet?](https://www.arewesixelyet.com/)
- [Kitty Graphics Protocol](https://sw.kovidgoyal.net/kitty/graphics-protocol/)
- [JXKit (Swift JavaScriptCore)](https://github.com/jectivex/JXKit)
