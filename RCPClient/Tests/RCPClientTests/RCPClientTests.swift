import XCTest
@testable import RCPClient

final class RCPClientTests: XCTestCase {
    func testClientInitialization() {
        // Test initialization with URL string
        let client1 = RCPClient(serverURLString: "ws://localhost:8080", appName: "Test App")
        XCTAssertNotNil(client1)
        
        // Test initialization with invalid URL string
        let client2 = RCPClient(serverURLString: "invalid url", appName: "Test App")
        XCTAssertNil(client2)
        
        // Test initialization with URL
        let url = URL(string: "ws://localhost:8080")!
        let client3 = RCPClient(serverURL: url, appName: "Test App")
        XCTAssertNotNil(client3)
    }
    
    func testLogLevels() {
        // Test log levels
        XCTAssertEqual(RCPClient.LogLevel.debug.rawValue, "debug")
        XCTAssertEqual(RCPClient.LogLevel.info.rawValue, "info")
        XCTAssertEqual(RCPClient.LogLevel.warn.rawValue, "warn")
        XCTAssertEqual(RCPClient.LogLevel.error.rawValue, "error")
    }
    
    func testConnectionStates() {
        // No need to test enum values directly, but we can verify they exist
        let states: [RCPClient.ConnectionState] = [
            .disconnected,
            .connecting,
            .connected
        ]
        XCTAssertEqual(states.count, 3)
    }
} 