// TUICore - Error types used across all modules

import Foundation

/// Base protocol for all TUIBrowser errors
public protocol TUIError: Error, CustomStringConvertible, Sendable {}

/// Core errors that can occur anywhere
public enum CoreError: TUIError {
    case invalidArgument(String)
    case notImplemented(String)
    case internalError(String)

    public var description: String {
        switch self {
        case .invalidArgument(let msg): return "Invalid argument: \(msg)"
        case .notImplemented(let msg): return "Not implemented: \(msg)"
        case .internalError(let msg): return "Internal error: \(msg)"
        }
    }
}

/// Boxed error for use in Result types
public struct BoxedError: Error, Sendable {
    public let underlying: any TUIError

    public init(_ error: any TUIError) {
        self.underlying = error
    }

    public var description: String {
        underlying.description
    }
}

/// Result type alias for convenience
public typealias TUIResult<T> = Result<T, BoxedError>
