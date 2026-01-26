// TUINetworking - HTTP Response Parser
// Parses HTTP/1.1 responses including chunked transfer encoding

import Foundation

/// Case-insensitive HTTP headers collection
public struct HTTPHeaders: Sendable, ExpressibleByDictionaryLiteral, Sequence {
    private var storage: [String: String] = [:]
    private var originalKeys: [String: String] = [:]  // lowercase -> original

    public init() {}

    public init(dictionaryLiteral elements: (String, String)...) {
        for (key, value) in elements {
            self[key] = value
        }
    }

    /// Get or set a header value (case-insensitive)
    public subscript(key: String) -> String? {
        get {
            storage[key.lowercased()]
        }
        set {
            let lowerKey = key.lowercased()
            if let value = newValue {
                storage[lowerKey] = value
                originalKeys[lowerKey] = key
            } else {
                storage.removeValue(forKey: lowerKey)
                originalKeys.removeValue(forKey: lowerKey)
            }
        }
    }

    /// Get all header names
    public var keys: [String] {
        originalKeys.values.sorted()
    }

    /// Number of headers
    public var count: Int {
        storage.count
    }

    /// Check if headers is empty
    public var isEmpty: Bool {
        storage.isEmpty
    }

    /// Make headers iterable
    public func makeIterator() -> AnyIterator<(key: String, value: String)> {
        var iterator = storage.makeIterator()
        return AnyIterator {
            guard let (lowerKey, value) = iterator.next() else { return nil }
            let originalKey = self.originalKeys[lowerKey] ?? lowerKey
            return (originalKey, value)
        }
    }

    /// Convert to dictionary
    public func toDictionary() -> [String: String] {
        var result: [String: String] = [:]
        for (lowerKey, value) in storage {
            let originalKey = originalKeys[lowerKey] ?? lowerKey
            result[originalKey] = value
        }
        return result
    }
}

/// HTTP response
public struct HTTPResponse: Sendable {
    /// HTTP status code (e.g., 200, 404)
    public var statusCode: Int

    /// HTTP status message (e.g., "OK", "Not Found")
    public var statusMessage: String

    /// Response headers (case-insensitive access)
    public var headers: HTTPHeaders

    /// Response body
    public var body: Data

    /// HTTP version (e.g., "HTTP/1.1")
    public var httpVersion: String

    /// Check if response indicates success (2xx status)
    public var isSuccess: Bool {
        statusCode >= 200 && statusCode < 300
    }

    /// Check if response is a redirect (3xx status)
    public var isRedirect: Bool {
        statusCode >= 300 && statusCode < 400
    }

    /// Check if response indicates client error (4xx status)
    public var isClientError: Bool {
        statusCode >= 400 && statusCode < 500
    }

    /// Check if response indicates server error (5xx status)
    public var isServerError: Bool {
        statusCode >= 500 && statusCode < 600
    }

    /// Get body as string (UTF-8)
    public var bodyString: String? {
        String(data: body, encoding: .utf8)
    }

    /// Get Content-Type header
    public var contentType: String? {
        headers["Content-Type"]
    }

    /// Get Content-Length header as Int
    public var contentLength: Int? {
        guard let value = headers["Content-Length"] else { return nil }
        return Int(value)
    }

    /// Get Location header (for redirects)
    public var location: String? {
        headers["Location"]
    }

    public init(statusCode: Int, statusMessage: String, headers: HTTPHeaders, body: Data, httpVersion: String = "HTTP/1.1") {
        self.statusCode = statusCode
        self.statusMessage = statusMessage
        self.headers = headers
        self.body = body
        self.httpVersion = httpVersion
    }

    // MARK: - Parsing

    /// Parse an HTTP response from raw data
    /// - Parameter data: The raw response data
    /// - Returns: Parsed HTTPResponse
    /// - Throws: NetworkError.invalidResponse if parsing fails
    public static func parse(_ data: Data) throws -> HTTPResponse {
        guard let string = String(data: data, encoding: .utf8) else {
            throw NetworkError.invalidResponse("Failed to decode response as UTF-8")
        }

        // Find the header/body separator
        guard let separatorRange = string.range(of: "\r\n\r\n") else {
            throw NetworkError.invalidResponse("No header/body separator found")
        }

        let headerSection = String(string[..<separatorRange.lowerBound])
        let bodyStartIndex = separatorRange.upperBound

        // Parse status line and headers
        let lines = headerSection.split(separator: "\r\n", omittingEmptySubsequences: false)
        guard !lines.isEmpty else {
            throw NetworkError.invalidResponse("Empty response")
        }

        // Parse status line: "HTTP/1.1 200 OK"
        let statusLine = String(lines[0])
        let statusParts = statusLine.split(separator: " ", maxSplits: 2)
        guard statusParts.count >= 2 else {
            throw NetworkError.invalidResponse("Invalid status line: \(statusLine)")
        }

        let httpVersion = String(statusParts[0])
        guard let statusCode = Int(statusParts[1]) else {
            throw NetworkError.invalidResponse("Invalid status code: \(statusParts[1])")
        }
        let statusMessage = statusParts.count > 2 ? String(statusParts[2]) : ""

        // Parse headers
        var headers = HTTPHeaders()
        for i in 1..<lines.count {
            let line = String(lines[i])
            if line.isEmpty { continue }

            if let colonIndex = line.firstIndex(of: ":") {
                let name = String(line[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                headers[name] = value
            }
        }

        // Extract body
        let bodyString = String(string[bodyStartIndex...])
        var body = bodyString.data(using: .utf8) ?? Data()

        // Handle chunked transfer encoding
        if headers["Transfer-Encoding"]?.lowercased() == "chunked" {
            body = try parseChunkedBody(body)
        }

        return HTTPResponse(
            statusCode: statusCode,
            statusMessage: statusMessage,
            headers: headers,
            body: body,
            httpVersion: httpVersion
        )
    }

    /// Read and parse an HTTP response from a socket
    /// - Parameter socket: The socket to read from
    /// - Returns: Parsed HTTPResponse
    /// - Throws: NetworkError if reading or parsing fails
    public static func read(from socket: Socket) throws -> HTTPResponse {
        var responseData = Data()
        var headersParsed = false
        var contentLength: Int?
        var isChunked = false
        var headersEndIndex = 0

        // Read until we have complete headers
        while !headersParsed {
            let chunk = try socket.receive(maxBytes: 4096)
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

        // Read remaining body based on Content-Length or chunked encoding
        if isChunked {
            // Read until we see the final chunk (0\r\n\r\n)
            while true {
                if let string = String(data: responseData, encoding: .utf8),
                   string.contains("0\r\n\r\n") || string.hasSuffix("0\r\n\r\n") {
                    break
                }
                do {
                    let chunk = try socket.receive(maxBytes: 4096)
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
                        let chunk = try socket.receive(maxBytes: min(remaining, 4096))
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
                    let chunk = try socket.receive(maxBytes: 4096)
                    if chunk.isEmpty { break }
                    responseData.append(chunk)
                } catch NetworkError.connectionClosed {
                    break
                } catch NetworkError.timeout {
                    break
                }
            }
        }

        return try parse(responseData)
    }

    // MARK: - Private Helpers

    /// Parse chunked transfer encoding body
    private static func parseChunkedBody(_ data: Data) throws -> Data {
        guard let string = String(data: data, encoding: .utf8) else {
            return data
        }

        var result = Data()
        var remaining = string

        while !remaining.isEmpty {
            // Find chunk size line
            guard let lineEnd = remaining.range(of: "\r\n") else { break }

            let sizeLine = String(remaining[..<lineEnd.lowerBound])
            // Remove any chunk extensions
            let sizeHex = sizeLine.split(separator: ";").first.map(String.init) ?? sizeLine

            guard let chunkSize = Int(sizeHex.trimmingCharacters(in: .whitespaces), radix: 16) else { break }

            // End of chunks
            if chunkSize == 0 { break }

            // Extract chunk data
            remaining = String(remaining[lineEnd.upperBound...])
            if remaining.count < chunkSize { break }

            let chunkData = String(remaining.prefix(chunkSize))
            if let chunkBytes = chunkData.data(using: .utf8) {
                result.append(chunkBytes)
            }

            // Skip chunk data and trailing CRLF
            remaining = String(remaining.dropFirst(chunkSize))
            if remaining.hasPrefix("\r\n") {
                remaining = String(remaining.dropFirst(2))
            }
        }

        return result
    }
}
