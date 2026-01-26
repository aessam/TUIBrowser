import Testing
@testable import TUINetworking

@Suite("TUINetworking Tests")
struct TUINetworkingTests {
    @Test func testVersion() {
        #expect(TUINetworking.version == "0.1.0")
    }
}
