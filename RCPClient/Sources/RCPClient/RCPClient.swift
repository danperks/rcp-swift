import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

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
    public init?(serverURLString: String, appName: String) {
        guard let url = URL(string: serverURLString) else {
            return nil
        }
        self.serverURL = url
        self.appName = appName
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
            "maxRcpVersion": maxRcpVersion
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
           let rcpVersion = json["rcpVersion"] as? Int {
            self.sessionId = sessionId
            self.rcpVersion = rcpVersion
            connectionState = .connected
            delegate?.rcpClientDidConnect(self)
        }
    }
    
    /// Handle a response from the server
    private func handleResponse(_ json: [String: Any]) {
        guard let requestId = json["requestId"] as? String,
              let payload = json["payload"] as? [String: Any] else {
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
              let command = payload["command"] as? String else {
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
                        "data": screenshotData
                    ]
                ]
                
                self.send(response)
            }
            
        default:
            delegate?.rcpClient(self, didReceiveCommand: command, payload: payload) { [weak self] responsePayload in
                guard let self = self else { return }
                
                let response: [String: Any] = [
                    "type": "response",
                    "requestId": requestId,
                    "payload": responsePayload
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
            "message": message
        ]
        
        if let tags = tags {
            payload["tags"] = tags
        }
        
        let event: [String: Any] = [
            "type": "event",
            "payload": payload
        ]
        
        send(event)
    }
    
    /// Send a UI element picked event to the server
    /// - Parameter elementID: The ID of the UI element that was picked
    public func sendUIElementPicked(elementID: String, metadata: [String: Any]? = nil) {
        guard connectionState == .connected else { return }
        
        var payload: [String: Any] = [
            "eventName": "uiElementPicked",
            "elementID": elementID
        ]
        
        if let metadata = metadata {
            payload["metadata"] = metadata
        }
        
        let event: [String: Any] = [
            "type": "event",
            "payload": payload
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
            "payload": eventPayload
        ]
        
        send(event)
    }
    
    /// Make a request to the server
    /// - Parameters:
    ///   - command: The command to send
    ///   - parameters: The parameters for the command
    ///   - completion: The callback for when the request completes
    public func makeRequest(command: String, parameters: [String: Any]? = nil, completion: @escaping ([String: Any]) -> Void) {
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
            "payload": commandPayload
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
            let data = try JSONSerialization.data(withJSONObject: message)
            let string = String(data: data, encoding: .utf8)!
            
            webSocketTask?.send(.string(string)) { [weak self] error in
                if let error = error {
                    self?.delegate?.rcpClient(self!, didReceiveError: error)
                }
            }
        } catch {
            delegate?.rcpClient(self, didReceiveError: error)
        }
    }
    
    /// Capture a screenshot of the current application
    /// - Parameter completion: The callback for when the screenshot is captured
    private func captureScreenshot(completion: @escaping (String) -> Void) {
        #if canImport(UIKit) && !os(watchOS)
        DispatchQueue.main.async {
            guard let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) else {
                completion("")
                return
            }
            
            UIGraphicsBeginImageContextWithOptions(window.bounds.size, false, UIScreen.main.scale)
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
                if let cgImage = CGWindowListCreateImage(CGRect.null, .optionIncludingWindow, CGWindowID(window.windowNumber), .bestResolution) {
                    let image = NSImage(cgImage: cgImage, size: rect.size)
                    
                    if let tiffData = image.tiffRepresentation,
                       let bitmapImage = NSBitmapImageRep(data: tiffData),
                       let pngData = bitmapImage.representation(using: .png, properties: [:]) {
                        let base64String = "data:image/png;base64," + pngData.base64EncodedString()
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