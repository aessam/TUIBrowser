// TUINetworking - HTTP Client
// High-level HTTP client with async/await API

import Foundation
import TUIURL

/// HTTP client for making requests
public final class HTTPClient: @unchecked Sendable {
    /// Connection timeout in seconds
    public let timeout: Double

    /// Maximum number of redirects to follow
    public let maxRedirects: Int

    /// Whether to automatically follow redirects
    public let followRedirects: Bool

    /// Default headers to include in all requests
    public var defaultHeaders: [String: String]

    private let lock = NSLock()

    /// Shared default HTTP client instance
    public static let shared = HTTPClient()

    /// Create a new HTTP client
    /// - Parameters:
    ///   - timeout: Connection timeout in seconds (default: 30)
    ///   - maxRedirects: Maximum number of redirects to follow (default: 10)
    ///   - followRedirects: Whether to automatically follow redirects (default: true)
    ///   - defaultHeaders: Default headers to include in all requests
    public init(
        timeout: Double = 30.0,
        maxRedirects: Int = 10,
        followRedirects: Bool = true,
        defaultHeaders: [String: String] = [:]
    ) {
        self.timeout = timeout
        self.maxRedirects = maxRedirects
        self.followRedirects = followRedirects
        self.defaultHeaders = defaultHeaders
    }

    /// Fetch a URL using GET method
    /// - Parameter url: The URL to fetch
    /// - Returns: The HTTP response
    /// - Throws: NetworkError if the request fails
    public func fetch(url: TUIURL.URL) async throws -> HTTPResponse {
        let request = HTTPRequest.get(url)
        return try await fetch(request: request)
    }

    /// Fetch a URL string using GET method
    /// - Parameter urlString: The URL string to fetch
    /// - Returns: The HTTP response
    /// - Throws: NetworkError if the request fails
    public func fetch(urlString: String) async throws -> HTTPResponse {
        guard let url = URLParser.parse(urlString) else {
            throw NetworkError.invalidURL("Invalid URL: \(urlString)")
        }
        return try await fetch(url: url)
    }

    /// Execute an HTTP request
    /// - Parameter request: The HTTP request to execute
    /// - Returns: The HTTP response
    /// - Throws: NetworkError if the request fails
    public func fetch(request: HTTPRequest) async throws -> HTTPResponse {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                do {
                    let response = try self.fetchSync(request: request, redirectCount: 0)
                    continuation.resume(returning: response)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Synchronous Internal Implementation

    private func fetchSync(request: HTTPRequest, redirectCount: Int) throws -> HTTPResponse {
        guard let host = request.url.host else {
            throw NetworkError.invalidURL("Missing host in URL")
        }

        let scheme = request.url.scheme?.lowercased() ?? "http"
        let isHTTPS = scheme == "https"
        let port = request.url.port ?? (isHTTPS ? 443 : 80)

        // Resolve DNS
        let addressInfo = try DNSResolver.getAddressInfo(hostname: host, port: port)

        // Create and connect socket
        let socket = try Socket.create(family: SocketFamily(fromRaw: addressInfo.family))
        try socket.setTimeout(seconds: Int(timeout))
        try socket.connect(to: addressInfo)

        defer { socket.close() }

        // Build request with default headers
        var finalRequest = request
        for (key, value) in defaultHeaders {
            if finalRequest.headers[key] == nil {
                finalRequest.headers[key] = value
            }
        }

        let response: HTTPResponse

        if isHTTPS {
            // TLS connection
            let tls = TLSConnection(socket: socket, hostname: host)
            try tls.handshake()
            defer { tls.close() }

            // Send request
            try tls.send(finalRequest.build())
            if let body = finalRequest.body {
                try tls.send(body)
            }

            // Read response
            response = try readTLSResponse(from: tls)
        } else {
            // Plain HTTP
            try socket.send(finalRequest.build())
            if let body = finalRequest.body {
                try socket.send(body)
            }

            // Read response
            response = try HTTPResponse.read(from: socket)
        }

        // Handle redirects
        if response.isRedirect && followRedirects {
            guard redirectCount < maxRedirects else {
                throw NetworkError.tooManyRedirects
            }

            guard let location = response.location else {
                return response
            }

            // Parse redirect URL
            let redirectURL: TUIURL.URL
            if location.hasPrefix("http://") || location.hasPrefix("https://") {
                guard let url = URLParser.parse(location) else {
                    throw NetworkError.invalidURL("Invalid redirect URL: \(location)")
                }
                redirectURL = url
            } else {
                // Relative URL
                redirectURL = TUIURL.URL(
                    scheme: request.url.scheme,
                    host: request.url.host,
                    port: request.url.port,
                    path: location.hasPrefix("/") ? location : "/\(location)",
                    query: nil,
                    fragment: nil
                )
            }

            let redirectRequest = HTTPRequest.get(redirectURL)
            return try fetchSync(request: redirectRequest, redirectCount: redirectCount + 1)
        }

        return response
    }

    /// Read HTTP response from TLS connection
    private func readTLSResponse(from tls: TLSConnection) throws -> HTTPResponse {
        var responseData = Data()
        var headersParsed = false
        var contentLength: Int?
        var isChunked = false
        var headersEndIndex = 0

        // Read until we have complete headers
        while !headersParsed {
            let chunk = try tls.receive(maxBytes: 4096)
            responseData.append(chunk)

            if let string = String(data: responseData, encoding: .utf8),
               let range = string.range(of: "\r\n\r\n") {
                headersParsed = true
                headersEndIndex = string.distance(from: string.startIndex, to: range.upperBound)

                // Parse headers to determine body length
                let headerSection = String(string[..<range.lowerBound])
                let headerLines = headerSection.split(separator: "\r\n")
                for line in headerLines {
                    let lineLower = line.lowercased()
                    if lineLower.hasPrefix("content-length:") {
                        let value = line.dropFirst("content-length:".count).trimmingCharacters(in: .whitespaces)
                        contentLength = Int(value)
                    } else if lineLower.hasPrefix("transfer-encoding:") && lineLower.contains("chunked") {
                        isChunked = true
                    }
                }
            }
        }

        // Read remaining body
        if isChunked {
            while true {
                if let string = String(data: responseData, encoding: .utf8),
                   string.contains("0\r\n\r\n") {
                    break
                }
                do {
                    let chunk = try tls.receive(maxBytes: 4096)
                    if chunk.isEmpty { break }
                    responseData.append(chunk)
                } catch NetworkError.connectionClosed {
                    break
                }
            }
        } else if let length = contentLength {
            let bodyBytesNeeded = length - (responseData.count - headersEndIndex)
            if bodyBytesNeeded > 0 {
                var remaining = bodyBytesNeeded
                while remaining > 0 {
                    do {
                        let chunk = try tls.receive(maxBytes: min(remaining, 4096))
                        if chunk.isEmpty { break }
                        responseData.append(chunk)
                        remaining -= chunk.count
                    } catch NetworkError.connectionClosed {
                        break
                    }
                }
            }
        } else {
            // No content-length, read until connection closes
            while true {
                do {
                    let chunk = try tls.receive(maxBytes: 4096)
                    if chunk.isEmpty { break }
                    responseData.append(chunk)
                } catch NetworkError.connectionClosed {
                    break
                } catch NetworkError.timeout {
                    break
                }
            }
        }

        return try HTTPResponse.parse(responseData)
    }
}
