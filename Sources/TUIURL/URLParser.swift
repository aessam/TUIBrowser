// URLParser.swift - Parse URL strings into URL structures
// TUIURL module

import TUICore
import Foundation

/// Parses URL strings into URL structures
public struct URLParser {

    /// Errors that can occur during URL parsing
    public enum ParseError: Error, Equatable {
        case invalidURL
        case invalidScheme
        case invalidHost
        case invalidPort
    }

    /// Parses a URL string into a URL structure
    /// - Parameter string: The URL string to parse
    /// - Returns: A Result containing either the parsed URL or a ParseError
    public static func parse(_ string: String) -> Result<URL, ParseError> {
        let trimmed = string.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            return .failure(.invalidURL)
        }

        var remaining = trimmed
        var scheme: String
        var username: String?
        var password: String?
        var host: String?
        var port: Int?
        var path = "/"
        var query: String?
        var fragment: String?

        // Parse scheme
        if let schemeEnd = remaining.range(of: "://") {
            scheme = String(remaining[..<schemeEnd.lowerBound]).lowercased()
            remaining = String(remaining[schemeEnd.upperBound...])
        } else if remaining.hasPrefix("//") {
            // Protocol-relative URL
            scheme = "http"
            remaining = String(remaining.dropFirst(2))
        } else if remaining.contains("://") == false && !remaining.hasPrefix("/") {
            // No scheme, assume http
            scheme = "http"
        } else {
            scheme = "http"
        }

        // Handle file:// URLs specially - they have no host
        if scheme == "file" {
            // For file:// URLs, the rest is the path
            path = remaining.isEmpty ? "/" : remaining
            return .success(URL(
                scheme: scheme,
                path: path
            ))
        }

        // Parse fragment (from the end)
        if let fragmentStart = remaining.range(of: "#") {
            fragment = String(remaining[fragmentStart.upperBound...])
            remaining = String(remaining[..<fragmentStart.lowerBound])
        }

        // Parse query (from the end)
        if let queryStart = remaining.range(of: "?") {
            query = String(remaining[queryStart.upperBound...])
            remaining = String(remaining[..<queryStart.lowerBound])
        }

        // Parse path
        if let pathStart = remaining.firstIndex(of: "/") {
            path = String(remaining[pathStart...])
            remaining = String(remaining[..<pathStart])
        }

        // Now remaining should be [user:pass@]host[:port]

        // Parse authentication
        if let atSign = remaining.range(of: "@") {
            let authPart = String(remaining[..<atSign.lowerBound])
            remaining = String(remaining[atSign.upperBound...])

            if let colonIndex = authPart.firstIndex(of: ":") {
                username = String(authPart[..<colonIndex])
                password = String(authPart[authPart.index(after: colonIndex)...])
            } else {
                username = authPart
            }
        }

        // Parse port
        if let colonIndex = remaining.lastIndex(of: ":") {
            let portString = String(remaining[remaining.index(after: colonIndex)...])

            // Make sure this isn't part of an IPv6 address
            if !portString.contains("]") {
                if let portNum = Int(portString) {
                    port = portNum
                    remaining = String(remaining[..<colonIndex])
                } else if !portString.isEmpty {
                    return .failure(.invalidPort)
                }
            }
        }

        // What remains is the host
        if !remaining.isEmpty {
            host = remaining
        }

        return .success(URL(
            scheme: scheme,
            username: username,
            password: password,
            host: host,
            port: port,
            path: path,
            query: query,
            fragment: fragment
        ))
    }

    /// Resolves a relative URL against a base URL
    /// - Parameters:
    ///   - relative: The relative URL string
    ///   - base: The base URL to resolve against
    /// - Returns: A Result containing either the resolved URL or a ParseError
    public static func resolve(_ relative: String, against base: URL) -> Result<URL, ParseError> {
        let trimmed = relative.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            return .success(base)
        }

        // Check if it's an absolute URL
        if trimmed.contains("://") {
            return parse(trimmed)
        }

        // Protocol-relative URL
        if trimmed.hasPrefix("//") {
            return parse("\(base.scheme):\(trimmed)")
        }

        // Absolute path
        if trimmed.hasPrefix("/") {
            return .success(URL(
                scheme: base.scheme,
                username: base.username,
                password: base.password,
                host: base.host,
                port: base.port,
                path: trimmed,
                query: nil,
                fragment: nil
            ))
        }

        // Parse relative path components
        var relativePath = trimmed
        var query: String?
        var fragment: String?

        // Extract fragment
        if let fragmentStart = relativePath.range(of: "#") {
            fragment = String(relativePath[fragmentStart.upperBound...])
            relativePath = String(relativePath[..<fragmentStart.lowerBound])
        }

        // Extract query
        if let queryStart = relativePath.range(of: "?") {
            query = String(relativePath[queryStart.upperBound...])
            relativePath = String(relativePath[..<queryStart.lowerBound])
        }

        // Resolve the path
        let resolvedPath = resolvePath(relativePath, against: base.path)

        return .success(URL(
            scheme: base.scheme,
            username: base.username,
            password: base.password,
            host: base.host,
            port: base.port,
            path: resolvedPath,
            query: query,
            fragment: fragment
        ))
    }

    /// Resolves a relative path against a base path
    private static func resolvePath(_ relative: String, against basePath: String) -> String {
        // Get the directory of the base path
        var baseDir: String
        if let lastSlash = basePath.lastIndex(of: "/") {
            baseDir = String(basePath[...lastSlash])
        } else {
            baseDir = "/"
        }

        // Combine base directory with relative path
        var combined = baseDir + relative

        // Normalize the path by resolving . and ..
        combined = normalizePath(combined)

        return combined
    }

    /// Normalizes a path by resolving . and .. segments
    private static func normalizePath(_ path: String) -> String {
        let segments = path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        var result: [String] = []

        for segment in segments {
            switch segment {
            case ".":
                // Current directory, skip it
                continue
            case "..":
                // Parent directory, remove last segment if possible
                if !result.isEmpty && result.last != "" {
                    result.removeLast()
                }
            default:
                result.append(segment)
            }
        }

        let normalized = result.joined(separator: "/")

        // Ensure path starts with /
        if normalized.isEmpty || !normalized.hasPrefix("/") {
            return "/" + normalized
        }

        return normalized
    }
}
