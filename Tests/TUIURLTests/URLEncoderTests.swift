// URLEncoderTests.swift - Tests for URL percent encoding
// TDD: Write tests first, then implement

import Testing
import Foundation
@testable import TUIURL

@Suite("URL Encoder Tests")
struct URLEncoderTests {

    // MARK: - Encoding Tests

    @Test func testEncodeSpace() {
        let encoded = URLEncoder.encode("hello world", allowedCharacters: URLEncoder.pathAllowed)
        #expect(encoded == "hello%20world")
    }

    @Test func testEncodeSpecialCharacters() {
        // Test with queryValueAllowed which has a stricter charset
        let encoded = URLEncoder.encode("hello@world!", allowedCharacters: URLEncoder.queryValueAllowed)
        #expect(encoded.contains("%40")) // @ should be encoded in query values
        #expect(encoded.contains("%21")) // ! should be encoded in query values
    }

    @Test func testEncodePreservesAlphanumeric() {
        let encoded = URLEncoder.encode("abc123", allowedCharacters: URLEncoder.pathAllowed)
        #expect(encoded == "abc123")
    }

    @Test func testEncodePreservesPathCharacters() {
        let encoded = URLEncoder.encode("/path/to/file", allowedCharacters: URLEncoder.pathAllowed)
        #expect(encoded == "/path/to/file")
    }

    @Test func testEncodeQueryAllowedPreservesEqualsAndAmpersand() {
        let encoded = URLEncoder.encode("a=b&c=d", allowedCharacters: URLEncoder.queryAllowed)
        // = and & should NOT be encoded in query strings
        #expect(encoded == "a=b&c=d")
    }

    @Test func testEncodeQueryValue() {
        let encoded = URLEncoder.encode("hello world", allowedCharacters: URLEncoder.queryValueAllowed)
        #expect(encoded == "hello%20world")
    }

    @Test func testEncodeUnicode() {
        let encoded = URLEncoder.encode("cafe", allowedCharacters: URLEncoder.pathAllowed)
        #expect(encoded == "cafe")

        let encoded2 = URLEncoder.encode("caf\u{00E9}", allowedCharacters: URLEncoder.pathAllowed)
        #expect(encoded2 == "caf%C3%A9")
    }

    @Test func testEncodeEmptyString() {
        let encoded = URLEncoder.encode("", allowedCharacters: URLEncoder.pathAllowed)
        #expect(encoded == "")
    }

    // MARK: - Decoding Tests

    @Test func testDecodeSpace() {
        let decoded = URLEncoder.decode("hello%20world")
        #expect(decoded == "hello world")
    }

    @Test func testDecodeMultipleEncoded() {
        let decoded = URLEncoder.decode("hello%20world%21")
        #expect(decoded == "hello world!")
    }

    @Test func testDecodePlainText() {
        let decoded = URLEncoder.decode("hello")
        #expect(decoded == "hello")
    }

    @Test func testDecodePlusAsSpace() {
        let decoded = URLEncoder.decode("hello+world")
        #expect(decoded == "hello world")
    }

    @Test func testDecodeUnicode() {
        let decoded = URLEncoder.decode("caf%C3%A9")
        #expect(decoded == "caf\u{00E9}")
    }

    @Test func testDecodeInvalidSequence() {
        // Invalid percent sequence should be preserved
        let decoded = URLEncoder.decode("hello%GG")
        #expect(decoded == "hello%GG")
    }

    @Test func testDecodeIncompleteSequence() {
        // Incomplete percent sequence should be preserved
        let decoded = URLEncoder.decode("hello%2")
        #expect(decoded == "hello%2")
    }

    @Test func testDecodeEmptyString() {
        let decoded = URLEncoder.decode("")
        #expect(decoded == "")
    }

    // MARK: - Round Trip Tests

    @Test func testRoundTrip() {
        let original = "hello world!"
        let encoded = URLEncoder.encode(original, allowedCharacters: URLEncoder.pathAllowed)
        let decoded = URLEncoder.decode(encoded)
        #expect(decoded == original)
    }

    @Test func testRoundTripUnicode() {
        let original = "Hello, 世界! Привет!"
        let encoded = URLEncoder.encode(original, allowedCharacters: URLEncoder.pathAllowed)
        let decoded = URLEncoder.decode(encoded)
        #expect(decoded == original)
    }
}
