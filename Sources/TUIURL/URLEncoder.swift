// URLEncoder.swift - Percent encoding/decoding for URLs
// TUIURL module

import TUICore
import Foundation

/// Handles percent-encoding and decoding for URL components
public struct URLEncoder {

    /// Encodes a string using percent-encoding, preserving allowed characters
    /// - Parameters:
    ///   - string: The string to encode
    ///   - allowedCharacters: Characters that should NOT be encoded
    /// - Returns: The percent-encoded string
    public static func encode(_ string: String, allowedCharacters: CharacterSet) -> String {
        var result = ""
        result.reserveCapacity(string.count)

        for scalar in string.unicodeScalars {
            if allowedCharacters.contains(scalar) {
                result.append(Character(scalar))
            } else {
                // Encode each byte of the UTF-8 representation
                let utf8Bytes = String(scalar).utf8
                for byte in utf8Bytes {
                    result += String(format: "%%%02X", byte)
                }
            }
        }

        return result
    }

    /// Decodes a percent-encoded string
    /// - Parameter string: The percent-encoded string
    /// - Returns: The decoded string, or the original string if decoding fails
    public static func decode(_ string: String) -> String {
        if string.isEmpty {
            return ""
        }

        // First, replace + with space (common in query strings)
        let plusReplaced = string.replacingOccurrences(of: "+", with: " ")

        var result = Data()
        result.reserveCapacity(plusReplaced.count)

        var i = 0
        let chars = Array(plusReplaced)

        while i < chars.count {
            let char = chars[i]

            if char == "%" && i + 2 < chars.count {
                // Try to parse the next two characters as hex
                let hexChars = String(chars[i+1]) + String(chars[i+2])
                if let byte = UInt8(hexChars, radix: 16) {
                    result.append(byte)
                    i += 3
                    continue
                }
            }

            // Not a valid percent sequence, keep the character as-is
            for byte in String(char).utf8 {
                result.append(byte)
            }
            i += 1
        }

        return String(data: result, encoding: .utf8) ?? string
    }

    // MARK: - Common Character Sets

    /// Characters allowed in URL path components (unreserved + "/" + ":" + "@")
    public static let pathAllowed: CharacterSet = {
        var set = CharacterSet.urlPathAllowed
        // Ensure common path characters are included
        set.insert(charactersIn: "/")
        return set
    }()

    /// Characters allowed in URL query strings (unreserved + "=" + "&")
    public static let queryAllowed: CharacterSet = {
        var set = CharacterSet.urlQueryAllowed
        // Keep = and & unencoded in query strings
        set.insert(charactersIn: "=&")
        return set
    }()

    /// Characters allowed in query string values (excludes = and &)
    public static let queryValueAllowed: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "-._~")
        return set
    }()

    /// Characters allowed in URL fragments
    public static let fragmentAllowed: CharacterSet = {
        return CharacterSet.urlFragmentAllowed
    }()
}
