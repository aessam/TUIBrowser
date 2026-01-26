// TUIHTMLParser - High-Level HTML Parser API
// Main entry point for parsing HTML documents

import TUICore

/// High-level HTML parser API
public struct HTMLParser {
    /// Module version
    public static let version = "0.1.0"

    /// Parse an HTML string into a Document
    /// - Parameter html: The HTML string to parse
    /// - Returns: A Document representing the parsed HTML
    public static func parse(_ html: String) -> Document {
        let tokenizer = HTMLTokenizer(html)
        let tokens = tokenizer.tokenize()
        let treeBuilder = HTMLTreeBuilder()
        return treeBuilder.build(from: tokens)
    }

    /// Parse an HTML fragment string
    /// - Parameters:
    ///   - html: The HTML fragment string to parse
    ///   - context: Optional context element for parsing
    /// - Returns: A Document containing the parsed fragment
    public static func parseFragment(_ html: String, context: Element? = nil) -> Document {
        let tokenizer = HTMLTokenizer(html)
        let tokens = tokenizer.tokenize()
        let treeBuilder = HTMLTreeBuilder()
        return treeBuilder.buildFragment(from: tokens, context: context)
    }

    /// Tokenize HTML without building a tree
    /// - Parameter html: The HTML string to tokenize
    /// - Returns: An array of HTML tokens
    public static func tokenize(_ html: String) -> [HTMLToken] {
        let tokenizer = HTMLTokenizer(html)
        return tokenizer.tokenize()
    }
}

// Re-export main types for convenience
public typealias TUIHTMLParserVersion = String
