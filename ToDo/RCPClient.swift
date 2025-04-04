import Foundation
import SwiftUI

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

// MARK: - RCPClient

/// RCPClient is a Swift implementation of the Runtime Context Protocol client
/// that connects to Cursor IDE for real-time interaction.
public class RCPClient {

    // MARK: - Types

    /// Represents the log levels for the RCP protocol
    public enum LogLevel: String {
        case debug
        case info
        case warn
        case error
    }

    /// Connection state of the client
    public enum ConnectionState {
        case disconnected
        case connecting
        case connected
    }

    // MARK: - Properties

    /// The current connection state
    public private(set) var connectionState: ConnectionState = .disconnected {
        didSet {
            if connectionState != oldValue {
                delegate?.rcpClientConnectionStateDidChange(self, state: connectionState)
            }
        }
    }

    /// The name of the application to send in the handshake
    private let appName: String

    /// The maximum RCP protocol version this client supports
    private let maxRcpVersion: Int = 1

    /// The session ID provided by the server after successful handshake
    private var sessionId: String?

    /// The agreed RCP protocol version between client and server
    private var rcpVersion: Int?

    /// The URL for the RCP server
    private let serverURL: URL

    /// The websocket task for communication
    private var webSocketTask: URLSessionWebSocketTask?

    /// A dictionary to track pending requests
    private var pendingRequests: [String: (Any) -> Void] = [:]

    /// A sequential counter for generating request IDs
    private var requestIdCounter: Int = 0

    /// Delegate for the RCP client events
    public weak var delegate: RCPClientDelegate?

    // MARK: - Initialization

    /// Initialize an RCP client with the specified server URL
    /// - Parameters:
    ///   - serverURLString: The URL string for the RCP server
    ///   - appName: The name of the application
    public convenience init?(serverURLString: String, appName: String) {
        guard let url = URL(string: serverURLString) else {
            return nil
        }
        self.init(serverURL: url, appName: appName)
    }

    /// Initialize an RCP client with the specified server URL
    /// - Parameters:
    ///   - serverURL: The URL for the RCP server
    ///   - appName: The name of the application
    public init(serverURL: URL, appName: String) {
        self.serverURL = serverURL
        self.appName = appName
    }

    // MARK: - Connection Management

    /// Connect to the RCP server
    public func connect() {
        guard connectionState == .disconnected else { return }

        connectionState = .connecting

        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: serverURL)

        webSocketTask?.resume()

        // Send handshake message
        sendHandshake()

        // Start listening for messages
        receiveMessage()
    }

    /// Disconnect from the RCP server
    public func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        sessionId = nil
        rcpVersion = nil
        connectionState = .disconnected
        pendingRequests.removeAll()
    }

    // MARK: - Message Handling

    /// Send a handshake message to the server
    private func sendHandshake() {
        let handshake: [String: Any] = [
            "type": "handshake",
            "name": appName,
            "maxRcpVersion": maxRcpVersion,
        ]

        send(handshake)
    }

    /// Receive a message from the server
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                switch message {
                case .data(let data):
                    self.handleReceivedData(data)
                case .string(let string):
                    if let data = string.data(using: .utf8) {
                        self.handleReceivedData(data)
                    }
                @unknown default:
                    break
                }

                // Continue receiving messages
                self.receiveMessage()

            case .failure(let error):
                self.delegate?.rcpClient(self, didDisconnectWithError: error)
                self.connectionState = .disconnected
            }
        }
    }

    /// Handle received data from the server
    private func handleReceivedData(_ data: Data) {
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return
            }

            if let type = json["type"] as? String {
                switch type {
                case "handshakeAcknowledged":
                    handleHandshakeAcknowledged(json)
                case "response":
                    handleResponse(json)
                case "request":
                    handleRequest(json)
                default:
                    break
                }
            }
        } catch {
            delegate?.rcpClient(self, didReceiveError: error)
        }
    }

    /// Handle a handshake acknowledgment from the server
    private func handleHandshakeAcknowledged(_ json: [String: Any]) {
        if let sessionId = json["sessionId"] as? String,
            let rcpVersion = json["rcpVersion"] as? Int
        {
            self.sessionId = sessionId
            self.rcpVersion = rcpVersion
            connectionState = .connected
            delegate?.rcpClientDidConnect(self)
        }
    }

    /// Handle a response from the server
    private func handleResponse(_ json: [String: Any]) {
        guard let requestId = json["requestId"] as? String,
            let payload = json["payload"] as? [String: Any]
        else {
            return
        }

        if let callback = pendingRequests[requestId] {
            callback(payload)
            pendingRequests.removeValue(forKey: requestId)
        }
    }

    /// Handle a request from the server
    private func handleRequest(_ json: [String: Any]) {
        guard let requestId = json["requestId"] as? String,
            let payload = json["payload"] as? [String: Any],
            let command = payload["command"] as? String
        else {
            return
        }

        switch command {
        case "getScreenshot":
            captureScreenshot { [weak self] screenshotData in
                guard let self = self else { return }

                let response: [String: Any] = [
                    "type": "response",
                    "requestId": requestId,
                    "payload": [
                        "command": "getScreenshot",
                        "data": screenshotData,
                    ],
                ]

                self.send(response)
            }

        default:
            delegate?.rcpClient(self, didReceiveCommand: command, payload: payload) {
                [weak self] responsePayload in
                guard let self = self else { return }

                let response: [String: Any] = [
                    "type": "response",
                    "requestId": requestId,
                    "payload": responsePayload,
                ]

                self.send(response)
            }
        }
    }

    // MARK: - Outgoing Messages

    /// Send a log event to the server
    /// - Parameters:
    ///   - message: The log message to send
    ///   - level: The log level
    ///   - tags: Optional tags to associate with the log
    public func sendLog(_ message: String, level: LogLevel = .info, tags: [String]? = nil) {
        guard connectionState == .connected else { return }

        var payload: [String: Any] = [
            "eventName": "log",
            "level": level.rawValue,
            "message": message,
        ]

        if let tags = tags {
            payload["tags"] = tags
        }

        let event: [String: Any] = [
            "type": "event",
            "payload": payload,
        ]

        send(event)
    }

    /// Send a UI element picked event to the server
    /// - Parameter elementID: The ID of the UI element that was picked
    public func sendUIElementPicked(elementID: String, metadata: [String: Any]? = nil) {
        guard connectionState == .connected else { return }

        var payload: [String: Any] = [
            "eventName": "uiElementPicked",
            "elementID": elementID,
        ]

        if let metadata = metadata {
            payload["metadata"] = metadata
        }

        let event: [String: Any] = [
            "type": "event",
            "payload": payload,
        ]

        send(event)
    }

    /// Send a custom event to the server
    /// - Parameters:
    ///   - eventName: The name of the event
    ///   - payload: The payload for the event
    public func sendCustomEvent(eventName: String, payload: [String: Any]) {
        guard connectionState == .connected else { return }

        var eventPayload = payload
        eventPayload["eventName"] = eventName

        let event: [String: Any] = [
            "type": "event",
            "payload": eventPayload,
        ]

        send(event)
    }

    /// Make a request to the server
    /// - Parameters:
    ///   - command: The command to send
    ///   - parameters: The parameters for the command
    ///   - completion: The callback for when the request completes
    public func makeRequest(
        command: String, parameters: [String: Any]? = nil,
        completion: @escaping ([String: Any]) -> Void
    ) {
        guard connectionState == .connected else {
            completion(["error": "Not connected"])
            return
        }

        let requestId = "req-\(requestIdCounter)"
        requestIdCounter += 1

        var commandPayload: [String: Any] = ["command": command]
        if let parameters = parameters {
            for (key, value) in parameters {
                commandPayload[key] = value
            }
        }

        let request: [String: Any] = [
            "type": "request",
            "requestId": requestId,
            "payload": commandPayload,
        ]

        pendingRequests[requestId] = { response in
            if let responseDict = response as? [String: Any] {
                completion(responseDict)
            } else {
                completion(["error": "Invalid response format"])
            }
        }

        send(request)
    }

    // MARK: - Utility Functions

    /// Send a message to the server
    /// - Parameter message: The message to send
    private func send(_ message: [String: Any]) {
        do {
            // Convert the message to a JSON-safe dictionary by converting UUIDs to strings
            let jsonSafeMessage = convertToJSONSafe(message)

            let data = try JSONSerialization.data(withJSONObject: jsonSafeMessage)
            let string = String(data: data, encoding: .utf8)!

            webSocketTask?.send(.string(string)) { [weak self] error in
                if let error = error, let self = self {
                    self.delegate?.rcpClient(self, didReceiveError: error)
                }
            }
        } catch {
            delegate?.rcpClient(self, didReceiveError: error)
        }
    }

    /// Convert a dictionary to a JSON-safe dictionary by converting UUIDs to strings
    /// - Parameter dictionary: The dictionary to convert
    /// - Returns: A JSON-safe dictionary
    private func convertToJSONSafe(_ value: Any) -> Any {
        if let uuid = value as? UUID {
            return uuid.uuidString
        } else if let dict = value as? [String: Any] {
            var result = [String: Any]()
            for (key, value) in dict {
                result[key] = convertToJSONSafe(value)
            }
            return result
        } else if let array = value as? [Any] {
            return array.map { convertToJSONSafe($0) }
        } else {
            return value
        }
    }

    /// Capture a screenshot of the current application
    /// - Parameter completion: The callback for when the screenshot is captured
    private func captureScreenshot(completion: @escaping (String) -> Void) {
        #if canImport(UIKit) && !os(watchOS)
            DispatchQueue.main.async {
                guard let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow })
                else {
                    completion("")
                    return
                }

                UIGraphicsBeginImageContextWithOptions(
                    window.bounds.size, false, UIScreen.main.scale)
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                guard let image = UIGraphicsGetImageFromCurrentImageContext() else {
                    UIGraphicsEndImageContext()
                    completion("")
                    return
                }
                UIGraphicsEndImageContext()

                if let imageData = image.pngData() {
                    let base64String = "data:image/png;base64," + imageData.base64EncodedString()
                    completion(base64String)
                } else {
                    completion("")
                }
            }
        #elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
            DispatchQueue.main.async {
                if let window = NSApplication.shared.mainWindow {
                    let rect = window.contentView?.bounds ?? NSRect.zero

                    // Take a screenshot of the window using a different approach
                    // since CGWindowListCreateImage is deprecated
                    if let bitmapRep = window.contentView?.bitmapImageRepForCachingDisplay(in: rect)
                    {
                        window.contentView?.cacheDisplay(in: rect, to: bitmapRep)

                        if let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                            let base64String =
                                "data:image/png;base64," + pngData.base64EncodedString()
                            completion(base64String)
                            return
                        }
                    }
                }
                completion("")
            }
        #else
            completion("")
        #endif
    }
}

// MARK: - RCPClientDelegate

/// Delegate protocol for handling RCPClient events
public protocol RCPClientDelegate: AnyObject {

    /// Called when the RCP client connection state changes
    /// - Parameters:
    ///   - client: The RCP client
    ///   - state: The new connection state
    func rcpClientConnectionStateDidChange(_ client: RCPClient, state: RCPClient.ConnectionState)

    /// Called when the RCP client connects to the server
    /// - Parameter client: The RCP client
    func rcpClientDidConnect(_ client: RCPClient)

    /// Called when the RCP client disconnects with an error
    /// - Parameters:
    ///   - client: The RCP client
    ///   - error: The error that caused the disconnection
    func rcpClient(_ client: RCPClient, didDisconnectWithError error: Error)

    /// Called when the RCP client receives an error
    /// - Parameters:
    ///   - client: The RCP client
    ///   - error: The error that was received
    func rcpClient(_ client: RCPClient, didReceiveError error: Error)

    /// Called when the RCP client receives a command
    /// - Parameters:
    ///   - client: The RCP client
    ///   - command: The command that was received
    ///   - payload: The payload for the command
    ///   - responseHandler: The handler for sending a response
    func rcpClient(
        _ client: RCPClient, didReceiveCommand command: String, payload: [String: Any],
        responseHandler: @escaping ([String: Any]) -> Void)
}

// Default implementations
extension RCPClientDelegate {
    public func rcpClientConnectionStateDidChange(
        _ client: RCPClient, state: RCPClient.ConnectionState
    ) {}

    public func rcpClientDidConnect(_ client: RCPClient) {}

    public func rcpClient(_ client: RCPClient, didDisconnectWithError error: Error) {}

    public func rcpClient(_ client: RCPClient, didReceiveError error: Error) {}

    public func rcpClient(
        _ client: RCPClient, didReceiveCommand command: String, payload: [String: Any],
        responseHandler: @escaping ([String: Any]) -> Void
    ) {
        // Default implementation that just returns an empty response
        responseHandler(["command": command, "status": "notImplemented"])
    }
}

// MARK: - RCP Manager

/// An observable object for managing the RCP client
public class RCPManager: ObservableObject {
    /// The RCP client
    public internal(set) var client: RCPClient?

    /// Initialize the RCP manager
    public init() {}

    /// Send a log message to the RCP server
    /// - Parameters:
    ///   - message: The log message to send
    ///   - level: The log level
    ///   - tags: Optional tags to associate with the log
    public func log(_ message: String, level: RCPClient.LogLevel = .info, tags: [String]? = nil) {
        client?.sendLog(message, level: level, tags: tags)
    }

    /// Send a debug log message to the RCP server
    /// - Parameters:
    ///   - message: The log message to send
    ///   - tags: Optional tags to associate with the log
    public func debug(_ message: String, tags: [String]? = nil) {
        log(message, level: .debug, tags: tags)
    }

    /// Send an info log message to the RCP server
    /// - Parameters:
    ///   - message: The log message to send
    ///   - tags: Optional tags to associate with the log
    public func info(_ message: String, tags: [String]? = nil) {
        log(message, level: .info, tags: tags)
    }

    /// Send a warning log message to the RCP server
    /// - Parameters:
    ///   - message: The log message to send
    ///   - tags: Optional tags to associate with the log
    public func warn(_ message: String, tags: [String]? = nil) {
        log(message, level: .warn, tags: tags)
    }

    /// Send an error log message to the RCP server
    /// - Parameters:
    ///   - message: The log message to send
    ///   - tags: Optional tags to associate with the log
    public func error(_ message: String, tags: [String]? = nil) {
        log(message, level: .error, tags: tags)
    }

    /// Report a UI element that was picked to the RCP server
    /// - Parameters:
    ///   - elementID: The ID of the UI element that was picked
    ///   - metadata: Optional metadata to associate with the element
    public func reportUIElement(id elementID: String, metadata: [String: Any]? = nil) {
        client?.sendUIElementPicked(elementID: elementID, metadata: metadata)
    }
}

// MARK: - View Extensions

extension View {
    /// Adds RCP client integration to a SwiftUI view
    /// - Parameters:
    ///   - serverURL: The URL for the RCP server
    ///   - appName: The name of the application
    ///   - onSetup: Optional callback for when the RCP client is set up
    /// - Returns: A view with RCP client integration
    public func withRCP(
        serverURL: URL,
        appName: String,
        onSetup: ((RCPClient) -> Void)? = nil
    ) -> some View {
        modifier(RCPViewModifier(serverURL: serverURL, appName: appName, onSetup: onSetup))
    }

    /// Adds RCP client integration to a SwiftUI view
    /// - Parameters:
    ///   - serverURLString: The URL string for the RCP server
    ///   - appName: The name of the application
    ///   - onSetup: Optional callback for when the RCP client is set up
    /// - Returns: A view with RCP client integration
    public func withRCP(
        serverURLString: String,
        appName: String,
        onSetup: ((RCPClient) -> Void)? = nil
    ) -> some View {
        guard let url = URL(string: serverURLString) else {
            // Return a view with just a modifier applied to handle invalid URLs
            return self.modifier(InvalidURLModifier(serverURLString: serverURLString))
        }

        return withRCP(serverURL: url, appName: appName, onSetup: onSetup)
    }
}

// MARK: - Support Modifiers

/// A view modifier that handles invalid URLs
private struct InvalidURLModifier: ViewModifier {
    let serverURLString: String

    func body(content: Content) -> some View {
        content
            .onAppear {
                print("RCP Error: Invalid server URL: \(serverURLString)")
            }
    }
}

// MARK: - RCP View Modifier

/// A view modifier that adds RCP client integration to a view
private struct RCPViewModifier: ViewModifier {
    /// The URL for the RCP server
    private let serverURL: URL

    /// The name of the application
    private let appName: String

    /// Optional callback for when the RCP client is set up
    private let onSetup: ((RCPClient) -> Void)?

    /// The RCP manager for handling the RCP client
    @StateObject private var rcpManager = RCPManager()

    /// Initialize the RCP view modifier
    /// - Parameters:
    ///   - serverURL: The URL for the RCP server
    ///   - appName: The name of the application
    ///   - onSetup: Optional callback for when the RCP client is set up
    init(serverURL: URL, appName: String, onSetup: ((RCPClient) -> Void)? = nil) {
        self.serverURL = serverURL
        self.appName = appName
        self.onSetup = onSetup
    }

    /// Create the body of the view modifier
    /// - Parameter content: The content to modify
    /// - Returns: The modified content
    func body(content: Content) -> some View {
        content
            .environmentObject(rcpManager)
            .onAppear {
                // Initialize the RCP client on first appearance
                if rcpManager.client == nil {
                    let client = RCPClient(serverURL: serverURL, appName: appName)
                    rcpManager.client = client
                    onSetup?(client)
                    client.connect()
                }
            }
    }
}

// MARK: - View Inspection Extension

/// A protocol for inspectable views for RCP integration
public protocol RCPInspectable {
    /// The ID to report when the view is picked
    var rcpElementID: String { get }

    /// Optional metadata to associate with the view
    var rcpMetadata: [String: Any]? { get }
}

extension RCPInspectable {
    /// Default implementation that returns nil for metadata
    public var rcpMetadata: [String: Any]? { nil }
}

extension View {
    /// Mark a view as inspectable by RCP
    /// - Parameters:
    ///   - id: The ID to report when the view is picked
    ///   - metadata: Optional metadata to associate with the view
    /// - Returns: A view that can be inspected by RCP
    public func rcpInspectable(id: String, metadata: [String: Any]? = nil) -> some View {
        modifier(RCPInspectableModifier(id: id, metadata: metadata))
    }
}

/// A view modifier that makes a view inspectable by RCP
private struct RCPInspectableModifier: ViewModifier {
    /// The ID to report when the view is picked
    private let id: String

    /// Optional metadata to associate with the view
    private let metadata: [String: Any]?

    /// The RCP manager for handling the RCP client
    @EnvironmentObject private var rcpManager: RCPManager

    /// Initialize the RCP inspectable modifier
    /// - Parameters:
    ///   - id: The ID to report when the view is picked
    ///   - metadata: Optional metadata to associate with the view
    init(id: String, metadata: [String: Any]? = nil) {
        self.id = id
        self.metadata = metadata
    }

    /// Create the body of the view modifier
    /// - Parameter content: The content to modify
    /// - Returns: The modified content
    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())  // Make the whole area tappable
            .onTapGesture {
                #if DEBUG
                    // Before sending to RCP, convert any UUIDs in the metadata to strings
                    rcpManager.reportUIElement(id: id, metadata: metadata)
                #endif
            }
    }
}
