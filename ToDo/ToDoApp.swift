//
//  ToDoApp.swift
//  ToDo
//
//  Created by Michael Feldstein on 3/26/25.
//

import SwiftUI

@main
struct ToDoApp: App {
    // Create an environment object for the RCP manager
    @StateObject private var rcpManager = RCPManager()

    // Store a strong reference to the delegate
    private let rcpDelegate = RCPTodoDelegate()

    init() {
        print("============================")
        print("Todo App starting up...")
        print("============================")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(rcpManager)
                .onAppear {
                    print("Main window appeared")

                    // Connect to RCP server
                    if rcpManager.client == nil {
                        let client = RCPClient(
                            serverURLString: "ws://localhost:9876", appName: "ToDo App")
                        rcpManager.client = client
                        client?.delegate = rcpDelegate
                        client?.connect()

                        // Log that we've started the app
                        rcpManager.info("Todo App started", tags: ["startup"])
                    }
                }
        }
    }
}

// Custom delegate implementation for RCP
class RCPTodoDelegate: NSObject, RCPClientDelegate {
    func rcpClientDidConnect(_ client: RCPClient) {
        print("RCP connected to server")
        client.sendLog("ToDo app connected to Cursor IDE", level: .info)
    }

    func rcpClient(_ client: RCPClient, didDisconnectWithError error: Error) {
        print("RCP disconnected: \(error.localizedDescription)")
    }

    func rcpClient(_ client: RCPClient, didReceiveError error: Error) {
        print("RCP error: \(error.localizedDescription)")
    }

    func rcpClientConnectionStateDidChange(_ client: RCPClient, state: RCPClient.ConnectionState) {
        print("RCP connection state changed to: \(state)")
    }

    func rcpClient(
        _ client: RCPClient, didReceiveCommand command: String, payload: [String: Any],
        responseHandler: @escaping ([String: Any]) -> Void
    ) {
        // Handle custom commands from Cursor IDE
        switch command {
        case "addTodo":
            if let title = payload["title"] as? String {
                // You would need to find a way to communicate with your app's model here
                print("Received command to add todo: \(title)")
                responseHandler(["status": "success", "message": "Added todo: \(title)"])
            } else {
                responseHandler(["status": "error", "message": "Missing title parameter"])
            }

        case "clearCompletedTodos":
            // You would need to find a way to communicate with your app's model here
            print("Received command to clear completed todos")
            responseHandler(["status": "success", "message": "Cleared completed todos"])

        default:
            // Use default implementation for unhandled commands
            responseHandler(["command": command, "status": "notImplemented"])
        }
    }
}
