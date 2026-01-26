// URL.swift - Complete URL representation
// TUIURL module

import TUICore
import Foundation

/// A complete URL representation following RFC 3986
public struct URL: Equatable, Hashable, Sendable, CustomStringConvertible {
    /// The URL scheme (e.g., "http", "https", "file")
    public var scheme: String

    /// Optional username for authentication
    public var username: String?

    /// Optional password for authentication
    public var password: String?

    /// The host component (domain name or IP address)
    public var host: String?

    /// Optional port number
    public var port: Int?

    /// The path component (always starts with "/" for absolute URLs)
    public var path: String

    /// Optional query string (without the leading "?")
    public var query: String?

    /// Optional fragment identifier (without the leading "#")
    public var fragment: String?

    /// Creates a new URL with the specified components
    public init(
        scheme: String,
        username: String? = nil,
        password: String? = nil,
        host: String? = nil,
        port: Int? = nil,
        path: String = "/",
        query: String? = nil,
        fragment: String? = nil
    ) {
        self.scheme = scheme.lowercased()
        self.username = username
        self.password = password
        self.host = host
        self.port = port
        self.path = path.isEmpty ? "/" : path
        self.query = query
        self.fragment = fragment
    }

    /// Returns the effective port, using the default port for the scheme if none specified
    public var effectivePort: Int {
        port ?? Self.defaultPort(for: scheme)
    }

    /// Returns "host:port" or just "host" if using the default port
    /// Returns nil if there is no host
    public var hostWithPort: String? {
        guard let host = host else { return nil }

        if let port = port {
            return "\(host):\(port)"
        } else {
            return host
        }
    }

    /// Reconstructs the full URL string
    public var description: String {
        var result = "\(scheme)://"

        // Add authentication if present
        if let username = username {
            result += username
            if let password = password {
                result += ":\(password)"
            }
            result += "@"
        }

        // Add host
        if let host = host {
            result += host

            // Add port if not the default
            if let port = port {
                result += ":\(port)"
            }
        }

        // Add path
        result += path

        // Add query
        if let query = query {
            result += "?\(query)"
        }

        // Add fragment
        if let fragment = fragment {
            result += "#\(fragment)"
        }

        return result
    }

    /// Returns the default port for a given scheme
    public static func defaultPort(for scheme: String) -> Int {
        switch scheme.lowercased() {
        case "http":
            return 80
        case "https":
            return 443
        case "ftp":
            return 21
        case "ssh":
            return 22
        case "ws":
            return 80
        case "wss":
            return 443
        default:
            return 80
        }
    }
}
