// QueryStringTests.swift - Tests for query string parsing and building
// TDD: Write tests first, then implement

import Testing
@testable import TUIURL

@Suite("Query String Tests")
struct QueryStringTests {

    // MARK: - Parsing Tests

    @Test func testParseSimpleQueryString() {
        let qs = QueryString(parsing: "name=John&age=30")
        #expect(qs.get("name") == "John")
        #expect(qs.get("age") == "30")
    }

    @Test func testParseEncodedValues() {
        let qs = QueryString(parsing: "msg=hello%20world")
        #expect(qs.get("msg") == "hello world")
    }

    @Test func testParseEncodedPlusAsSpace() {
        let qs = QueryString(parsing: "msg=hello+world")
        #expect(qs.get("msg") == "hello world")
    }

    @Test func testParseEmptyValue() {
        let qs = QueryString(parsing: "key=")
        #expect(qs.get("key") == "")
    }

    @Test func testParseNoValue() {
        let qs = QueryString(parsing: "key")
        #expect(qs.get("key") == "")
    }

    @Test func testParseDuplicateKeys() {
        let qs = QueryString(parsing: "key=a&key=b&key=c")
        #expect(qs.get("key") == "a") // First value
        #expect(qs.getAll("key") == ["a", "b", "c"])
    }

    @Test func testParseEmptyString() {
        let qs = QueryString(parsing: "")
        #expect(qs.get("anything") == nil)
    }

    @Test func testParseSpecialCharacters() {
        let qs = QueryString(parsing: "email=test%40example.com")
        #expect(qs.get("email") == "test@example.com")
    }

    @Test func testParseWithLeadingQuestionMark() {
        let qs = QueryString(parsing: "?name=value")
        #expect(qs.get("name") == "value")
    }

    // MARK: - Building Tests

    @Test func testBuildEmptyQueryString() {
        let qs = QueryString()
        #expect(qs.encode() == "")
    }

    @Test func testBuildSimpleQueryString() {
        var qs = QueryString()
        qs.add(name: "name", value: "John")
        qs.add(name: "age", value: "30")
        let encoded = qs.encode()
        #expect(encoded == "name=John&age=30")
    }

    @Test func testBuildEncodesSpecialCharacters() {
        var qs = QueryString()
        qs.add(name: "msg", value: "hello world")
        let encoded = qs.encode()
        #expect(encoded == "msg=hello%20world")
    }

    @Test func testBuildDuplicateKeys() {
        var qs = QueryString()
        qs.add(name: "key", value: "a")
        qs.add(name: "key", value: "b")
        let encoded = qs.encode()
        #expect(encoded == "key=a&key=b")
    }

    @Test func testBuildEncodesAmpersandInValue() {
        var qs = QueryString()
        qs.add(name: "url", value: "a&b=c")
        let encoded = qs.encode()
        #expect(encoded.contains("url=a%26b%3Dc"))
    }

    @Test func testBuildEncodesEqualsInValue() {
        var qs = QueryString()
        qs.add(name: "expr", value: "1+1=2")
        let encoded = qs.encode()
        #expect(encoded.contains("expr="))
        #expect(encoded.contains("%3D")) // Encoded =
    }

    // MARK: - Accessors

    @Test func testGetNonexistent() {
        let qs = QueryString(parsing: "a=1")
        #expect(qs.get("b") == nil)
    }

    @Test func testGetAllNonexistent() {
        let qs = QueryString(parsing: "a=1")
        #expect(qs.getAll("b") == [])
    }

    @Test func testParametersProperty() {
        let qs = QueryString(parsing: "a=1&b=2")
        #expect(qs.parameters.count == 2)
        #expect(qs.parameters[0].0 == "a")
        #expect(qs.parameters[0].1 == "1")
        #expect(qs.parameters[1].0 == "b")
        #expect(qs.parameters[1].1 == "2")
    }

    // MARK: - Round Trip

    @Test func testRoundTrip() {
        let original = "name=John%20Doe&age=30&city=New%20York"
        let qs = QueryString(parsing: original)
        let encoded = qs.encode()
        let qs2 = QueryString(parsing: encoded)

        #expect(qs2.get("name") == "John Doe")
        #expect(qs2.get("age") == "30")
        #expect(qs2.get("city") == "New York")
    }
}
