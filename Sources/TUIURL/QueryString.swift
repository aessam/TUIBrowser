// QueryString.swift - Query string parsing and building
// TUIURL module

import TUICore
import Foundation

/// Represents a URL query string with support for duplicate keys
public struct QueryString: Sendable, Equatable {

    /// The query parameters as an ordered list of name-value pairs
    public var parameters: [(String, String)]

    /// Creates an empty QueryString
    public init() {
        self.parameters = []
    }

    /// Parses a query string into name-value pairs
    /// - Parameter query: The query string to parse (with or without leading "?")
    public init(parsing query: String) {
        self.parameters = []

        var queryString = query

        // Remove leading ? if present
        if queryString.hasPrefix("?") {
            queryString = String(queryString.dropFirst())
        }

        if queryString.isEmpty {
            return
        }

        // Split by &
        let pairs = queryString.split(separator: "&", omittingEmptySubsequences: true)

        for pair in pairs {
            let pairString = String(pair)

            if let equalsIndex = pairString.firstIndex(of: "=") {
                let name = String(pairString[..<equalsIndex])
                let value = String(pairString[pairString.index(after: equalsIndex)...])

                // Decode the name and value
                let decodedName = URLEncoder.decode(name)
                let decodedValue = URLEncoder.decode(value)

                parameters.append((decodedName, decodedValue))
            } else {
                // No = sign, treat as key with empty value
                let decodedName = URLEncoder.decode(pairString)
                parameters.append((decodedName, ""))
            }
        }
    }

    /// Adds a parameter to the query string
    /// - Parameters:
    ///   - name: The parameter name
    ///   - value: The parameter value
    public mutating func add(name: String, value: String) {
        parameters.append((name, value))
    }

    /// Gets the first value for a parameter name
    /// - Parameter name: The parameter name
    /// - Returns: The first value for the name, or nil if not found
    public func get(_ name: String) -> String? {
        for (key, value) in parameters {
            if key == name {
                return value
            }
        }
        return nil
    }

    /// Gets all values for a parameter name
    /// - Parameter name: The parameter name
    /// - Returns: All values for the name, or an empty array if not found
    public func getAll(_ name: String) -> [String] {
        return parameters.filter { $0.0 == name }.map { $0.1 }
    }

    /// Encodes the query string for use in a URL
    /// - Returns: The percent-encoded query string
    public func encode() -> String {
        if parameters.isEmpty {
            return ""
        }

        var result: [String] = []

        for (name, value) in parameters {
            let encodedName = URLEncoder.encode(name, allowedCharacters: URLEncoder.queryValueAllowed)
            let encodedValue = URLEncoder.encode(value, allowedCharacters: URLEncoder.queryValueAllowed)
            result.append("\(encodedName)=\(encodedValue)")
        }

        return result.joined(separator: "&")
    }

    /// Equatable conformance
    public static func == (lhs: QueryString, rhs: QueryString) -> Bool {
        guard lhs.parameters.count == rhs.parameters.count else { return false }
        for (index, param) in lhs.parameters.enumerated() {
            if param.0 != rhs.parameters[index].0 || param.1 != rhs.parameters[index].1 {
                return false
            }
        }
        return true
    }
}
