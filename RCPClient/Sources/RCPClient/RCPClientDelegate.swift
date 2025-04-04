import Foundation

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
    func rcpClient(_ client: RCPClient, didReceiveCommand command: String, payload: [String: Any], responseHandler: @escaping ([String: Any]) -> Void)
}

// Default implementations
public extension RCPClientDelegate {
    func rcpClientConnectionStateDidChange(_ client: RCPClient, state: RCPClient.ConnectionState) {}
    
    func rcpClientDidConnect(_ client: RCPClient) {}
    
    func rcpClient(_ client: RCPClient, didDisconnectWithError error: Error) {}
    
    func rcpClient(_ client: RCPClient, didReceiveError error: Error) {}
    
    func rcpClient(_ client: RCPClient, didReceiveCommand command: String, payload: [String: Any], responseHandler: @escaping ([String: Any]) -> Void) {
        // Default implementation that just returns an empty response
        responseHandler(["command": command, "status": "notImplemented"])
    }
} 