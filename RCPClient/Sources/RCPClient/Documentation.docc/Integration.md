# Integrating RCPClient

Learn how to integrate the Runtime Context Protocol (RCP) client into your Swift application.

## Overview

The Runtime Context Protocol (RCP) enables your application to communicate with the Cursor IDE. This integration allows for real-time interaction, debugging, and inspection of your application directly from the IDE.

## SwiftUI Integration

### Basic Setup

The simplest way to integrate RCP into a SwiftUI application is using the `withRCP` view modifier:

```swift
import SwiftUI
import RCPClient

struct ContentView: View {
    var body: some View {
        Text("Hello, World!")
            .withRCP(
                serverURLString: "ws://localhost:8080",
                appName: "My SwiftUI App"
            )
    }
}
```

This sets up the RCP client and connects to the Cursor IDE on app launch.

### Accessing the RCP Manager

You can access the RCP manager to send logs and events:

```swift
import SwiftUI
import RCPClient

struct ContentView: View {
    @EnvironmentObject private var rcpManager: RCPManager

    var body: some View {
        VStack {
            Text("Hello, World!")

            Button("Send Log") {
                rcpManager.info("Button tapped!")
            }
        }
        .withRCP(
            serverURLString: "ws://localhost:8080",
            appName: "My SwiftUI App"
        )
    }
}
```

### Making Views Inspectable

You can make specific views inspectable, allowing them to be picked and highlighted in the IDE:

```swift
import SwiftUI
import RCPClient

struct ContentView: View {
    var body: some View {
        VStack {
            Text("Hello, World!")
                .rcpInspectable(id: "greeting")

            Button("Tap Me") {
                // Action
            }
            .rcpInspectable(id: "tapButton", metadata: ["type": "button"])
        }
        .withRCP(
            serverURLString: "ws://localhost:8080",
            appName: "My SwiftUI App"
        )
    }
}
```

## UIKit Integration

### Basic Setup

For UIKit applications, you can create and manage the RCP client directly:

```swift
import UIKit
import RCPClient

class ViewController: UIViewController, RCPClientDelegate {

    private var rcpClient: RCPClient?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Create and connect the RCP client
        if let client = RCPClient(serverURLString: "ws://localhost:8080", appName: "My UIKit App") {
            rcpClient = client
            client.delegate = self
            client.connect()
        }
    }

    // MARK: - RCPClientDelegate

    func rcpClientDidConnect(_ client: RCPClient) {
        print("Connected to RCP server")
        client.sendLog("Application started", level: .info)
    }

    func rcpClient(_ client: RCPClient, didDisconnectWithError error: Error) {
        print("Disconnected from RCP server with error: \(error)")
    }

    func rcpClient(_ client: RCPClient, didReceiveError error: Error) {
        print("Received error from RCP server: \(error)")
    }

    func rcpClient(_ client: RCPClient, didReceiveCommand command: String, payload: [String: Any], responseHandler: @escaping ([String: Any]) -> Void) {
        print("Received command: \(command)")

        // Handle custom commands
        if command == "customAction" {
            // Do something
            responseHandler(["command": command, "status": "success"])
        } else {
            // Use default implementation for unhandled commands
            responseHandler(["command": command, "status": "notImplemented"])
        }
    }
}
```
