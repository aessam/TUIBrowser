// URLParserTests.swift - Tests for URL parsing
// TDD: Write tests first, then implement

import Testing
@testable import TUIURL

@Suite("URL Parser Tests")
struct URLParserTests {

    // MARK: - Basic URL Parsing

    @Test func testParseSimpleURL() {
        let result = URLParser.parse("http://example.com")
        switch result {
        case .success(let url):
            #expect(url.scheme == "http")
            #expect(url.host == "example.com")
            #expect(url.port == nil)
            #expect(url.path == "/")
        case .failure(let error):
            Issue.record("Expected success but got error: \(error)")
        }
    }

    @Test func testParseURLWithPath() {
        let result = URLParser.parse("https://example.com/path/to/page")
        switch result {
        case .success(let url):
            #expect(url.scheme == "https")
            #expect(url.host == "example.com")
            #expect(url.path == "/path/to/page")
        case .failure(let error):
            Issue.record("Expected success but got error: \(error)")
        }
    }

    @Test func testParseURLWithPort() {
        let result = URLParser.parse("http://localhost:8080/")
        switch result {
        case .success(let url):
            #expect(url.host == "localhost")
            #expect(url.port == 8080)
            #expect(url.path == "/")
        case .failure(let error):
            Issue.record("Expected success but got error: \(error)")
        }
    }

    @Test func testParseURLWithQuery() {
        let result = URLParser.parse("http://example.com/search?q=hello&page=1")
        switch result {
        case .success(let url):
            #expect(url.scheme == "http")
            #expect(url.path == "/search")
            #expect(url.query == "q=hello&page=1")
        case .failure(let error):
            Issue.record("Expected success but got error: \(error)")
        }
    }

    @Test func testParseURLWithFragment() {
        let result = URLParser.parse("http://example.com/page#section")
        switch result {
        case .success(let url):
            #expect(url.path == "/page")
            #expect(url.fragment == "section")
        case .failure(let error):
            Issue.record("Expected success but got error: \(error)")
        }
    }

    @Test func testParseCompleteURL() {
        let result = URLParser.parse("https://user:pass@example.com:8443/path?query=value#frag")
        switch result {
        case .success(let url):
            #expect(url.scheme == "https")
            #expect(url.username == "user")
            #expect(url.password == "pass")
            #expect(url.host == "example.com")
            #expect(url.port == 8443)
            #expect(url.path == "/path")
            #expect(url.query == "query=value")
            #expect(url.fragment == "frag")
        case .failure(let error):
            Issue.record("Expected success but got error: \(error)")
        }
    }

    // MARK: - Effective Port

    @Test func testEffectivePortHTTP() {
        let result = URLParser.parse("http://example.com")
        switch result {
        case .success(let url):
            #expect(url.effectivePort == 80)
        case .failure(let error):
            Issue.record("Expected success but got error: \(error)")
        }
    }

    @Test func testEffectivePortHTTPS() {
        let result = URLParser.parse("https://example.com")
        switch result {
        case .success(let url):
            #expect(url.effectivePort == 443)
        case .failure(let error):
            Issue.record("Expected success but got error: \(error)")
        }
    }

    @Test func testEffectivePortCustom() {
        let result = URLParser.parse("http://example.com:8080")
        switch result {
        case .success(let url):
            #expect(url.effectivePort == 8080)
        case .failure(let error):
            Issue.record("Expected success but got error: \(error)")
        }
    }

    // MARK: - Relative URL Resolution

    @Test func testResolveRelativeURLParent() {
        let baseResult = URLParser.parse("http://example.com/dir/page.html")
        guard case .success(let base) = baseResult else {
            Issue.record("Failed to parse base URL")
            return
        }

        let result = URLParser.resolve("../other.html", against: base)
        switch result {
        case .success(let resolved):
            #expect(resolved.scheme == "http")
            #expect(resolved.host == "example.com")
            #expect(resolved.path == "/other.html")
        case .failure(let error):
            Issue.record("Expected success but got error: \(error)")
        }
    }

    @Test func testResolveRelativeURLAbsolute() {
        let baseResult = URLParser.parse("http://example.com/dir/page.html")
        guard case .success(let base) = baseResult else {
            Issue.record("Failed to parse base URL")
            return
        }

        let result = URLParser.resolve("/absolute/path.html", against: base)
        switch result {
        case .success(let resolved):
            #expect(resolved.scheme == "http")
            #expect(resolved.host == "example.com")
            #expect(resolved.path == "/absolute/path.html")
        case .failure(let error):
            Issue.record("Expected success but got error: \(error)")
        }
    }

    @Test func testResolveRelativeURLSameDir() {
        let baseResult = URLParser.parse("http://example.com/dir/page.html")
        guard case .success(let base) = baseResult else {
            Issue.record("Failed to parse base URL")
            return
        }

        let result = URLParser.resolve("./sibling.html", against: base)
        switch result {
        case .success(let resolved):
            #expect(resolved.path == "/dir/sibling.html")
        case .failure(let error):
            Issue.record("Expected success but got error: \(error)")
        }
    }

    @Test func testResolveRelativeURLSimple() {
        let baseResult = URLParser.parse("http://example.com/dir/page.html")
        guard case .success(let base) = baseResult else {
            Issue.record("Failed to parse base URL")
            return
        }

        let result = URLParser.resolve("file.html", against: base)
        switch result {
        case .success(let resolved):
            #expect(resolved.path == "/dir/file.html")
        case .failure(let error):
            Issue.record("Expected success but got error: \(error)")
        }
    }

    @Test func testResolveAbsoluteURL() {
        let baseResult = URLParser.parse("http://example.com/dir/page.html")
        guard case .success(let base) = baseResult else {
            Issue.record("Failed to parse base URL")
            return
        }

        let result = URLParser.resolve("https://other.com/new/path", against: base)
        switch result {
        case .success(let resolved):
            #expect(resolved.scheme == "https")
            #expect(resolved.host == "other.com")
            #expect(resolved.path == "/new/path")
        case .failure(let error):
            Issue.record("Expected success but got error: \(error)")
        }
    }

    // MARK: - Default Scheme

    @Test func testParseURLWithoutScheme() {
        let result = URLParser.parse("example.com/path")
        switch result {
        case .success(let url):
            #expect(url.scheme == "http")
            #expect(url.host == "example.com")
            #expect(url.path == "/path")
        case .failure(let error):
            Issue.record("Expected success but got error: \(error)")
        }
    }

    // MARK: - Error Cases

    @Test func testParseEmptyURL() {
        let result = URLParser.parse("")
        switch result {
        case .success:
            Issue.record("Expected failure for empty URL")
        case .failure(let error):
            #expect(error == .invalidURL)
        }
    }

    @Test func testParseInvalidPort() {
        let result = URLParser.parse("http://example.com:notaport/")
        switch result {
        case .success:
            Issue.record("Expected failure for invalid port")
        case .failure(let error):
            #expect(error == .invalidPort)
        }
    }

    // MARK: - URL Description

    @Test func testURLDescription() {
        let url = URL(scheme: "https", host: "example.com", port: 8080, path: "/path", query: "q=1", fragment: "top")
        #expect(url.description == "https://example.com:8080/path?q=1#top")
    }

    @Test func testURLDescriptionDefaultPort() {
        let url = URL(scheme: "http", host: "example.com", path: "/path")
        #expect(url.description == "http://example.com/path")
    }

    @Test func testURLDescriptionWithAuth() {
        let url = URL(scheme: "http", username: "user", password: "pass", host: "example.com", path: "/")
        #expect(url.description == "http://user:pass@example.com/")
    }

    // MARK: - Host With Port

    @Test func testHostWithPortCustom() {
        let url = URL(scheme: "http", host: "example.com", port: 8080, path: "/")
        #expect(url.hostWithPort == "example.com:8080")
    }

    @Test func testHostWithPortDefault() {
        let url = URL(scheme: "http", host: "example.com", path: "/")
        #expect(url.hostWithPort == "example.com")
    }

    @Test func testHostWithPortNil() {
        let url = URL(scheme: "file", path: "/local/file")
        #expect(url.hostWithPort == nil)
    }

    // MARK: - File URLs

    @Test func testParseFileURL() {
        let result = URLParser.parse("file:///path/to/file.txt")
        switch result {
        case .success(let url):
            #expect(url.scheme == "file")
            #expect(url.host == nil)
            #expect(url.path == "/path/to/file.txt")
        case .failure(let error):
            Issue.record("Expected success but got error: \(error)")
        }
    }
}
