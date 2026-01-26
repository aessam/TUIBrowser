// NetworkError.swift - Network-related errors
// TUINetworking module

import TUICore

/// Errors that can occur during network operations
public enum NetworkError: TUIError, Equatable {
    /// DNS resolution failed for the specified hostname
    case dnsResolutionFailed(String)

    /// Failed to create a socket
    case socketCreationFailed(String)

    /// Connection to the server failed
    case connectionFailed(String)

    /// Connection timed out
    case timeout

    /// Failed to send data
    case sendFailed(String)

    /// Failed to receive data
    case receiveFailed(String)

    /// TLS/SSL handshake failed
    case tlsHandshakeFailed(String)

    /// Invalid HTTP response
    case invalidResponse(String)

    /// Invalid URL
    case invalidURL(String)

    /// Too many redirects
    case tooManyRedirects

    /// Connection was closed unexpectedly
    case connectionClosed

    public var description: String {
        switch self {
        case .dnsResolutionFailed(let hostname):
            return "DNS resolution failed for hostname: \(hostname)"
        case .socketCreationFailed(let reason):
            return "Socket creation failed: \(reason)"
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        case .timeout:
            return "Connection timeout"
        case .sendFailed(let reason):
            return "Send failed: \(reason)"
        case .receiveFailed(let reason):
            return "Receive failed: \(reason)"
        case .tlsHandshakeFailed(let reason):
            return "TLS handshake failed: \(reason)"
        case .invalidResponse(let reason):
            return "Invalid HTTP response: \(reason)"
        case .invalidURL(let reason):
            return "Invalid URL: \(reason)"
        case .tooManyRedirects:
            return "Too many redirects"
        case .connectionClosed:
            return "Connection was closed unexpectedly"
        }
    }
}
