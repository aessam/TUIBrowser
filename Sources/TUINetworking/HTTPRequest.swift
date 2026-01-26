// TUINetworking - HTTP Request Builder
// Builds HTTP/1.1 request strings

import Foundation
import TUIURL

/// HTTP request methods
public enum HTTPMethod: String, Sendable, CaseIterable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case head = "HEAD"
    case options = "OPTIONS"
    case patch = "PATCH"
    case trace = "TRACE"
    case connect = "CONNECT"
}

/// HTTP request builder
public struct HTTPRequest: Sendable {
    /// The HTTP method
    public var method: HTTPMethod

    /// The request URL
    public var url: TUIURL.URL

    /// Request headers
    public var headers: [String: String]

    /// Request body (optional)
    public var body: Data?

    /// Create a new HTTP request
    /// - Parameters:
    ///   - method: The HTTP method
    ///   - url: The request URL
    ///   - headers: Request headers
    ///   - body: Optional request body
    public init(method: HTTPMethod, url: TUIURL.URL, headers: [String: String] = [:], body: Data? = nil) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
    }

    /// Build the HTTP request string
    /// - Returns: The complete HTTP request as a string
    public func build() -> String {
        var request = ""

        // Request line
        let path = url.path.isEmpty ? "/" : url.path
        let pathWithQuery: String
        if let query = url.query, !query.isEmpty {
            pathWithQuery = "\(path)?\(query)"
        } else {
            pathWithQuery = path
        }
        request += "\(method.rawValue) \(pathWithQuery) HTTP/1.1\r\n"

        // Build headers with defaults
        var allHeaders = headers

        // Add Host header if not present
        if allHeaders["Host"] == nil {
            var host = url.host ?? "localhost"
            if let port = url.port, port != 80 && port != 443 {
                host += ":\(port)"
            }
            allHeaders["Host"] = host
        }

        // Add User-Agent if not present
        if allHeaders["User-Agent"] == nil {
            allHeaders["User-Agent"] = TUINetworking.defaultUserAgent
        }

        // Add Connection header if not present
        if allHeaders["Connection"] == nil {
            allHeaders["Connection"] = "close"
        }

        // Add Content-Length if body is present
        if let body = body {
            allHeaders["Content-Length"] = String(body.count)
        }

        // Write headers
        for (name, value) in allHeaders.sorted(by: { $0.key < $1.key }) {
            request += "\(name): \(value)\r\n"
        }

        // Empty line to end headers
        request += "\r\n"

        return request
    }

    /// Build the complete request data including body
    /// - Returns: The complete HTTP request as Data
    public func buildData() -> Data {
        var data = build().data(using: .utf8) ?? Data()
        if let body = body {
            data.append(body)
        }
        return data
    }

    // MARK: - Convenience Constructors

    /// Create a GET request
    /// - Parameter url: The request URL
    /// - Returns: A new HTTPRequest configured for GET
    public static func get(_ url: TUIURL.URL) -> HTTPRequest {
        return HTTPRequest(method: .get, url: url)
    }

    /// Create a POST request
    /// - Parameters:
    ///   - url: The request URL
    ///   - body: The request body
    ///   - contentType: The Content-Type header value
    /// - Returns: A new HTTPRequest configured for POST
    public static func post(_ url: TUIURL.URL, body: Data, contentType: String) -> HTTPRequest {
        return HTTPRequest(
            method: .post,
            url: url,
            headers: ["Content-Type": contentType],
            body: body
        )
    }

    /// Create a POST request with JSON body
    /// - Parameters:
    ///   - url: The request URL
    ///   - json: The JSON data
    /// - Returns: A new HTTPRequest configured for POST with JSON
    public static func postJSON(_ url: TUIURL.URL, json: Data) -> HTTPRequest {
        return post(url, body: json, contentType: "application/json")
    }

    /// Create a POST request with form data
    /// - Parameters:
    ///   - url: The request URL
    ///   - formData: Dictionary of form field names and values
    /// - Returns: A new HTTPRequest configured for POST with form data
    public static func postForm(_ url: TUIURL.URL, formData: [String: String]) -> HTTPRequest {
        let encoded = formData.map { key, value in
            let encodedKey = URLEncoder.encode(key) ?? key
            let encodedValue = URLEncoder.encode(value) ?? value
            return "\(encodedKey)=\(encodedValue)"
        }.joined(separator: "&")

        let body = encoded.data(using: .utf8) ?? Data()
        return post(url, body: body, contentType: "application/x-www-form-urlencoded")
    }

    /// Create a HEAD request
    /// - Parameter url: The request URL
    /// - Returns: A new HTTPRequest configured for HEAD
    public static func head(_ url: TUIURL.URL) -> HTTPRequest {
        return HTTPRequest(method: .head, url: url)
    }

    /// Create a DELETE request
    /// - Parameter url: The request URL
    /// - Returns: A new HTTPRequest configured for DELETE
    public static func delete(_ url: TUIURL.URL) -> HTTPRequest {
        return HTTPRequest(method: .delete, url: url)
    }

    /// Create a PUT request
    /// - Parameters:
    ///   - url: The request URL
    ///   - body: The request body
    ///   - contentType: The Content-Type header value
    /// - Returns: A new HTTPRequest configured for PUT
    public static func put(_ url: TUIURL.URL, body: Data, contentType: String) -> HTTPRequest {
        return HTTPRequest(
            method: .put,
            url: url,
            headers: ["Content-Type": contentType],
            body: body
        )
    }
}
