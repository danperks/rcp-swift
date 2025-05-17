# RCPClient

A Swift implementation of the Runtime Context Protocol (RCP) client for connecting applications to the Cursor IDE.

## Overview

The RCPClient library provides a Swift implementation of the Runtime Context Protocol, allowing your application to communicate with the Cursor IDE. This integration enables real-time interaction, debugging, and inspection of your application directly from the IDE.

## Features

- WebSocket communication with Cursor IDE
- Screenshot capture
- Logging to the IDE
- Custom events
- UI element inspection
- SwiftUI integration

## Installation

### Swift Package Manager

Add the package to your Swift package dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/RCPClient.git", from: "1.0.0")
]
```

## Usage

### SwiftUI Integration

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

### UIKit Integration

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

    // ... implement delegate methods
}
```

## Example: ToDo App Integration

This repository includes an example of integrating RCPClient with a SwiftUI ToDo app. The integration demonstrates:

1. Setting up the RCP client in the app's entry point (`ToDoApp.swift`)
2. Using the RCP manager to log events and user interactions
3. Making UI elements inspectable with the `rcpInspectable` modifier
4. Implementing a custom delegate to handle commands from the Cursor IDE

Key features of the ToDo app integration:

- Logging when todos are added, completed, or deleted
- Making todo items inspectable with metadata
- Handling custom commands from the Cursor IDE
- Showing how to structure a real-world application with RCP

To run the example, open the ToDo app project and build it. Make sure the Cursor IDE is running and configured to listen for RCP connections.

## Documentation

For more detailed documentation, see the [Integration Guide](RCPClient/Sources/RCPClient/Documentation.docc/Integration.md).

## Requirements

- iOS 14.0+ / macOS 11.0+
- Swift 5.5+

## License

This project is available under the MIT license. See the LICENSE file for more info. 