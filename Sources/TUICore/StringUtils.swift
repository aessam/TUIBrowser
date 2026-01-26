// TUICore - String utilities

import Foundation

extension String {
    /// Get character at index safely
    public subscript(safe index: Int) -> Character? {
        guard index >= 0 && index < count else { return nil }
        return self[self.index(startIndex, offsetBy: index)]
    }

    /// Get substring by range
    public subscript(range: Range<Int>) -> Substring {
        let start = index(startIndex, offsetBy: max(0, range.lowerBound))
        let end = index(startIndex, offsetBy: min(count, range.upperBound))
        return self[start..<end]
    }

    /// Check if string starts with character (case insensitive option)
    public func starts(with char: Character, caseInsensitive: Bool = false) -> Bool {
        guard let first = first else { return false }
        if caseInsensitive {
            return first.lowercased() == char.lowercased()
        }
        return first == char
    }

    /// Trim whitespace and newlines
    public var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Check if string is empty or whitespace only
    public var isBlank: Bool {
        trimmed.isEmpty
    }

    /// Split into lines
    public var lines: [String] {
        components(separatedBy: .newlines)
    }

    /// Calculate visible width (accounting for wide characters)
    public var visibleWidth: Int {
        var width = 0
        for char in self {
            // Simple heuristic: CJK characters are double-width
            if char.isWideCharacter {
                width += 2
            } else if !char.isZeroWidth {
                width += 1
            }
        }
        return width
    }
}

extension Character {
    /// Check if character is a wide (double-width) character
    public var isWideCharacter: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        let value = scalar.value

        // CJK ranges
        if (0x4E00...0x9FFF).contains(value) { return true }  // CJK Unified Ideographs
        if (0x3400...0x4DBF).contains(value) { return true }  // CJK Extension A
        if (0xF900...0xFAFF).contains(value) { return true }  // CJK Compatibility
        if (0xFF00...0xFFEF).contains(value) { return true }  // Fullwidth forms
        if (0x3000...0x303F).contains(value) { return true }  // CJK Punctuation

        return false
    }

    /// Check if character is zero-width
    public var isZeroWidth: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        let value = scalar.value

        // Zero-width characters
        if value == 0x200B { return true }  // Zero-width space
        if value == 0x200C { return true }  // Zero-width non-joiner
        if value == 0x200D { return true }  // Zero-width joiner
        if value == 0xFEFF { return true }  // BOM

        // Combining marks (simplified check)
        if (0x0300...0x036F).contains(value) { return true }

        return false
    }
}

extension StringProtocol {
    /// Convert to array of characters
    public var chars: [Character] {
        Array(self)
    }
}
