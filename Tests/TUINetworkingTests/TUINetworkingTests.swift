import Testing
import Foundation
@testable import TUINetworking
@testable import TUIURL

@Suite("TUINetworking Tests")
struct TUINetworkingTests {
    @Test func testVersion() {
        #expect(TUINetworking.version == "0.1.0")
    }

    @Test func testDefaultUserAgent() {
        #expect(TUINetworking.defaultUserAgent == "TUIBrowser/1.0")
    }
}

// MARK: - DNS Resolver Tests

@Suite("DNSResolver Tests")
struct DNSResolverTests {

    @Test func testResolveLocalhost() throws {
        let addresses = try DNSResolver.resolve(hostname: "localhost")
        #expect(!addresses.isEmpty)
        // localhost should resolve to 127.0.0.1 or ::1
        let hasLocalAddress = addresses.contains { $0 == "127.0.0.1" || $0 == "::1" }
        #expect(hasLocalAddress)
    }

    @Test func testResolveFirstLocalhost() throws {
        let result = try DNSResolver.resolveFirst(hostname: "localhost", preferIPv4: true)
        #expect(result.address == "127.0.0.1" || result.address == "::1")
        #expect(result.family == AF_INET || result.family == AF_INET6)
    }

    @Test func testGetAddressInfo() throws {
        let info = try DNSResolver.getAddressInfo(hostname: "localhost", port: 80)
        #expect(info.family == AF_INET || info.family == AF_INET6)
        #expect(info.socketType == SOCK_STREAM)
        #expect(!info.addressData.isEmpty)
        #expect(info.addressLength > 0)
    }

    @Test func testResolveInvalidHostname() {
        #expect(throws: NetworkError.self) {
            _ = try DNSResolver.resolve(hostname: "this-hostname-should-not-exist-12345.invalid")
        }
    }
}

// MARK: - Socket Tests

@Suite("Socket Tests")
struct SocketTests {

    @Test func testCreateSocket() throws {
        let socket = try Socket.create(family: .inet, type: .stream)
        #expect(socket.fileDescriptor >= 0)
        #expect(!socket.isClosed)
        socket.close()
        #expect(socket.isClosed)
    }

    @Test func testCreateIPv6Socket() throws {
        let socket = try Socket.create(family: .inet6, type: .stream)
        #expect(socket.fileDescriptor >= 0)
        socket.close()
    }

    @Test func testSocketClose() throws {
        let socket = try Socket.create()
        #expect(!socket.isClosed)
        socket.close()
        #expect(socket.isClosed)
        // Closing again should be safe
        socket.close()
        #expect(socket.isClosed)
    }

    @Test func testSocketFamily() {
        #expect(SocketFamily.inet.rawValue == 2)
        #expect(SocketFamily.inet6.rawValue == 30)
    }

    @Test func testSocketType() {
        #expect(SocketType.stream.rawValue == 1)
        #expect(SocketType.dgram.rawValue == 2)
    }
}

// MARK: - HTTP Request Tests

@Suite("HTTPRequest Tests")
struct HTTPRequestTests {

    @Test func testHTTPMethods() {
        #expect(HTTPMethod.get.rawValue == "GET")
        #expect(HTTPMethod.post.rawValue == "POST")
        #expect(HTTPMethod.put.rawValue == "PUT")
        #expect(HTTPMethod.delete.rawValue == "DELETE")
        #expect(HTTPMethod.head.rawValue == "HEAD")
        #expect(HTTPMethod.options.rawValue == "OPTIONS")
        #expect(HTTPMethod.patch.rawValue == "PATCH")
    }

    @Test func testBuildSimpleRequest() {
        let url = TUIURL.URL(scheme: "http", host: "example.com", port: nil, path: "/test", query: nil, fragment: nil)
        let request = HTTPRequest.get(url)
        let built = request.build()

        #expect(built.contains("GET /test HTTP/1.1\r\n"))
        #expect(built.contains("Host: example.com\r\n"))
        #expect(built.contains("User-Agent: TUIBrowser/1.0\r\n"))
        #expect(built.hasSuffix("\r\n\r\n"))
    }

    @Test func testBuildRequestWithQuery() {
        let url = TUIURL.URL(scheme: "http", host: "example.com", port: nil, path: "/search", query: "q=test", fragment: nil)
        let request = HTTPRequest.get(url)
        let built = request.build()

        #expect(built.contains("GET /search?q=test HTTP/1.1\r\n"))
    }

    @Test func testBuildRequestWithPort() {
        let url = TUIURL.URL(scheme: "http", host: "example.com", port: 8080, path: "/", query: nil, fragment: nil)
        let request = HTTPRequest.get(url)
        let built = request.build()

        #expect(built.contains("Host: example.com:8080\r\n"))
    }

    @Test func testBuildPOSTRequest() {
        let url = TUIURL.URL(scheme: "http", host: "example.com", port: nil, path: "/api", query: nil, fragment: nil)
        let body = "test=value".data(using: .utf8)!
        let request = HTTPRequest.post(url, body: body, contentType: "application/x-www-form-urlencoded")
        let built = request.build()

        #expect(built.contains("POST /api HTTP/1.1\r\n"))
        #expect(built.contains("Content-Type: application/x-www-form-urlencoded\r\n"))
        #expect(built.contains("Content-Length: 10\r\n"))
    }

    @Test func testBuildDataIncludesBody() {
        let url = TUIURL.URL(scheme: "http", host: "example.com", port: nil, path: "/", query: nil, fragment: nil)
        let body = "hello".data(using: .utf8)!
        let request = HTTPRequest.post(url, body: body, contentType: "text/plain")
        let data = request.buildData()

        let string = String(data: data, encoding: .utf8)!
        #expect(string.hasSuffix("hello"))
    }

    @Test func testPostJSONFactory() {
        let url = TUIURL.URL(scheme: "http", host: "api.example.com", port: nil, path: "/data", query: nil, fragment: nil)
        let json = "{\"key\":\"value\"}".data(using: .utf8)!
        let request = HTTPRequest.postJSON(url, json: json)

        #expect(request.method == .post)
        #expect(request.headers["Content-Type"] == "application/json")
    }

    @Test func testHeadFactory() {
        let url = TUIURL.URL(scheme: "http", host: "example.com", port: nil, path: "/", query: nil, fragment: nil)
        let request = HTTPRequest.head(url)
        #expect(request.method == .head)
    }

    @Test func testDeleteFactory() {
        let url = TUIURL.URL(scheme: "http", host: "example.com", port: nil, path: "/resource/1", query: nil, fragment: nil)
        let request = HTTPRequest.delete(url)
        #expect(request.method == .delete)
    }
}

// MARK: - HTTP Headers Tests

@Suite("HTTPHeaders Tests")
struct HTTPHeadersTests {

    @Test func testCaseInsensitiveAccess() {
        var headers = HTTPHeaders()
        headers["Content-Type"] = "text/html"

        #expect(headers["content-type"] == "text/html")
        #expect(headers["CONTENT-TYPE"] == "text/html")
        #expect(headers["Content-Type"] == "text/html")
    }

    @Test func testSetAndRemove() {
        var headers = HTTPHeaders()
        headers["X-Custom"] = "value"
        #expect(headers["x-custom"] == "value")

        headers["X-Custom"] = nil
        #expect(headers["x-custom"] == nil)
    }

    @Test func testDictionaryLiteral() {
        let headers: HTTPHeaders = [
            "Accept": "application/json",
            "Cache-Control": "no-cache"
        ]

        #expect(headers["accept"] == "application/json")
        #expect(headers["cache-control"] == "no-cache")
        #expect(headers.count == 2)
    }

    @Test func testToDictionary() {
        var headers = HTTPHeaders()
        headers["Content-Type"] = "text/plain"
        headers["Accept"] = "*/*"

        let dict = headers.toDictionary()
        #expect(dict.count == 2)
    }
}

// MARK: - HTTP Response Tests

@Suite("HTTPResponse Tests")
struct HTTPResponseTests {

    @Test func testParseSimpleResponse() throws {
        let responseString = """
        HTTP/1.1 200 OK\r
        Content-Type: text/html\r
        Content-Length: 13\r
        \r
        Hello, World!
        """
        let data = responseString.data(using: .utf8)!

        let response = try HTTPResponse.parse(data)
        #expect(response.statusCode == 200)
        #expect(response.statusMessage == "OK")
        #expect(response.httpVersion == "HTTP/1.1")
        #expect(response.headers["Content-Type"] == "text/html")
        #expect(response.isSuccess)
        #expect(!response.isRedirect)
    }

    @Test func testParseRedirectResponse() throws {
        let responseString = """
        HTTP/1.1 301 Moved Permanently\r
        Location: https://example.com/new\r
        Content-Length: 0\r
        \r

        """
        let data = responseString.data(using: .utf8)!

        let response = try HTTPResponse.parse(data)
        #expect(response.statusCode == 301)
        #expect(response.isRedirect)
        #expect(response.location == "https://example.com/new")
    }

    @Test func testParse404Response() throws {
        let responseString = """
        HTTP/1.1 404 Not Found\r
        Content-Type: text/html\r
        Content-Length: 9\r
        \r
        Not Found
        """
        let data = responseString.data(using: .utf8)!

        let response = try HTTPResponse.parse(data)
        #expect(response.statusCode == 404)
        #expect(response.isClientError)
        #expect(!response.isSuccess)
    }

    @Test func testParse500Response() throws {
        let responseString = """
        HTTP/1.1 500 Internal Server Error\r
        Content-Length: 5\r
        \r
        Error
        """
        let data = responseString.data(using: .utf8)!

        let response = try HTTPResponse.parse(data)
        #expect(response.statusCode == 500)
        #expect(response.isServerError)
    }

    @Test func testBodyString() throws {
        let responseString = """
        HTTP/1.1 200 OK\r
        Content-Length: 4\r
        \r
        Test
        """
        let data = responseString.data(using: .utf8)!

        let response = try HTTPResponse.parse(data)
        #expect(response.bodyString == "Test")
    }

    @Test func testContentLength() throws {
        let responseString = """
        HTTP/1.1 200 OK\r
        Content-Length: 100\r
        \r

        """
        let data = responseString.data(using: .utf8)!

        let response = try HTTPResponse.parse(data)
        #expect(response.contentLength == 100)
    }

    @Test func testContentType() throws {
        let responseString = """
        HTTP/1.1 200 OK\r
        Content-Type: application/json; charset=utf-8\r
        \r

        """
        let data = responseString.data(using: .utf8)!

        let response = try HTTPResponse.parse(data)
        #expect(response.contentType == "application/json; charset=utf-8")
    }
}

// MARK: - Network Error Tests

@Suite("NetworkError Tests")
struct NetworkErrorTests {

    @Test func testErrorDescriptions() {
        #expect(NetworkError.dnsResolutionFailed("test").description.contains("DNS"))
        #expect(NetworkError.socketCreationFailed("test").description.contains("Socket"))
        #expect(NetworkError.connectionFailed("test").description.contains("Connection"))
        #expect(NetworkError.timeout.description.contains("timeout"))
        #expect(NetworkError.sendFailed("test").description.contains("Send"))
        #expect(NetworkError.receiveFailed("test").description.contains("Receive"))
        #expect(NetworkError.tlsHandshakeFailed("test").description.contains("TLS"))
        #expect(NetworkError.invalidResponse("test").description.contains("Invalid"))
        #expect(NetworkError.invalidURL("test").description.contains("URL"))
        #expect(NetworkError.tooManyRedirects.description.contains("redirect"))
        #expect(NetworkError.connectionClosed.description.contains("closed"))
    }

    @Test func testErrorEquality() {
        #expect(NetworkError.timeout == NetworkError.timeout)
        #expect(NetworkError.connectionClosed == NetworkError.connectionClosed)
        #expect(NetworkError.tooManyRedirects == NetworkError.tooManyRedirects)
    }
}

// MARK: - TLS Connection Tests

@Suite("TLSConnection Tests")
struct TLSConnectionTests {

    @Test func testTLSConnectionInit() throws {
        let socket = try Socket.create()
        let tls = TLSConnection(socket: socket, hostname: "example.com")
        #expect(!tls.isConnected)
        socket.close()
    }
}

// MARK: - HTTP Client Tests

@Suite("HTTPClient Tests")
struct HTTPClientTests {

    @Test func testClientInit() {
        let client = HTTPClient(timeout: 60, maxRedirects: 5, followRedirects: false)
        #expect(client.timeout == 60)
        #expect(client.maxRedirects == 5)
        #expect(client.followRedirects == false)
    }

    @Test func testSharedClient() {
        let shared = HTTPClient.shared
        #expect(shared.timeout == 30)
        #expect(shared.maxRedirects == 10)
        #expect(shared.followRedirects == true)
    }

    @Test func testDefaultHeaders() {
        var client = HTTPClient()
        client.defaultHeaders["X-Custom"] = "test"
        #expect(client.defaultHeaders["X-Custom"] == "test")
    }

    @Test func testInvalidURLThrows() async {
        let client = HTTPClient()
        do {
            _ = try await client.fetch(urlString: "not a valid url")
            #expect(Bool(false), "Should have thrown")
        } catch let error as NetworkError {
            #expect(error.description.contains("URL"))
        } catch {
            #expect(Bool(false), "Wrong error type")
        }
    }
}

// MARK: - AddressInfo Tests

@Suite("AddressInfo Tests")
struct AddressInfoTests {

    @Test func testAddressInfoInit() {
        let info = AddressInfo(
            family: AF_INET,
            socketType: SOCK_STREAM,
            socketProtocol: IPPROTO_TCP,
            addressData: Data([0, 0, 0, 0]),
            addressLength: 16
        )

        #expect(info.family == AF_INET)
        #expect(info.socketType == SOCK_STREAM)
        #expect(info.socketProtocol == IPPROTO_TCP)
        #expect(info.addressData.count == 4)
        #expect(info.addressLength == 16)
    }
}
