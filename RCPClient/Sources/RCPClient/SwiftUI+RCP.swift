import Foundation
import SwiftUI

// MARK: - View Extensions

public extension View {
    /// Adds RCP client integration to a SwiftUI view
    /// - Parameters:
    ///   - serverURL: The URL for the RCP server
    ///   - appName: The name of the application
    ///   - onSetup: Optional callback for when the RCP client is set up
    /// - Returns: A view with RCP client integration
    func withRCP(
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
    func withRCP(
        serverURLString: String,
        appName: String,
        onSetup: ((RCPClient) -> Void)? = nil
    ) -> some View {
        guard let url = URL(string: serverURLString) else {
            return self.onAppear {
                print("RCP Error: Invalid server URL: \(serverURLString)")
            }
        }
        
        return withRCP(serverURL: url, appName: appName, onSetup: onSetup)
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

// MARK: - View Inspection Extension

/// A protocol for inspectable views for RCP integration
public protocol RCPInspectable {
    /// The ID to report when the view is picked
    var rcpElementID: String { get }
    
    /// Optional metadata to associate with the view
    var rcpMetadata: [String: Any]? { get }
}

public extension RCPInspectable {
    /// Default implementation that returns nil for metadata
    var rcpMetadata: [String: Any]? { nil }
}

public extension View {
    /// Mark a view as inspectable by RCP
    /// - Parameters:
    ///   - id: The ID to report when the view is picked
    ///   - metadata: Optional metadata to associate with the view
    /// - Returns: A view that can be inspected by RCP
    func rcpInspectable(id: String, metadata: [String: Any]? = nil) -> some View {
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
            .contentShape(Rectangle()) // Make the whole area tappable
            .onTapGesture {
                #if DEBUG
                rcpManager.reportUIElement(id: id, metadata: metadata)
                #endif
            }
    }
} 