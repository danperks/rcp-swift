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

## Integration Details

### Using `withRCP`

`withRCP` is a convenience `View` extension that performs the following tasks:

1. Instantiates an `RCPClient` with the supplied server URL and application name.
2. Stores the client in an `@StateObject` called `RCPManager`.
3. Injects the manager into the SwiftUI environment, allowing descendant views to
   • send structured log messages (`rcpManager.info(_:)`, `rcpManager.debug(_:)`, etc.)  
   • publish custom runtime events  
   • obtain direct access to the live `RCPClient` instance when necessary.

Because `withRCP` is implemented as a `ViewModifier`, it can be attached to any
view. In practice, it should be applied near the root of the hierarchy (for
example, to the view presented by `WindowGroup` or to `ContentView`) so that the
`RCPManager` environment object is available application-wide.

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .withRCP(
                    serverURLString: "ws://localhost:9876", // port on which Cursor is listening
                    appName: "My SwiftUI App"
                )
        }
    }
}
```

### Marking Views as Inspectable

Any view can be made discoverable from the Cursor IDE by applying the
`rcpInspectable` modifier:

```swift
Text(todo.title)
    .rcpInspectable(
        id: "todo-\(todo.id)",               // a stable identifier
        metadata: [                           // optional, JSON-serialisable metadata
            "title": todo.title,
            "completed": todo.isCompleted
        ]
    )
```

In debug builds, tapping an inspectable view sends an `uiElementPicked` event to
Cursor, which is then surfaced in the IDE as a runtime element.

### Logging and Event Reporting

`RCPManager` is a thin wrapper around `RCPClient` that exposes convenience
methods for the standard log levels:

```swift
rcpManager.debug("Text changed …")
rcpManager.info("Todo added")
rcpManager.warn("Validation failed")
rcpManager.error("Network error: \(error)")
```

Custom events can be dispatched through `RCPClient` or by adding additional
helpers to `RCPManager` as required by your application.

### End-to-End Example (`/ToDo`)

The *ToDo* sample application demonstrates a complete integration:

* **`ToDoApp.swift`** establishes an `RCPManager` and connects to the server at
  launch.
* **`ContentView.swift`**
  * logs user interactions (adding, toggling, and deleting Todos);
  * annotates interactive views with `rcpInspectable` so they can be selected
    from within Cursor.

Build and run the sample while Cursor is listening on the specified WebSocket
port. Logged messages and selected UI elements will appear in the IDE in real
-time.

### Relationship to the Protocol Specification

The document [`rcp.md`](./rcp.md) describes the underlying Runtime Context
Protocol in detail, including the handshake sequence and message formats. The
Swift implementation abstracts these details, but the specification is provided
for reference and for developers who may need to implement custom runtimes. 