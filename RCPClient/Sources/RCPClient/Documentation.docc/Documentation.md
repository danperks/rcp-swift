# `RCPClient`

A Swift implementation of the Runtime Context Protocol (RCP) client for connecting applications to the Cursor IDE.

## Overview

The RCPClient library provides a Swift implementation of the Runtime Context Protocol, allowing your application to communicate with the Cursor IDE. This integration enables real-time interaction, debugging, and inspection of your application directly from the IDE.

Key features include:

- **WebSocket communication**: Connect to the Cursor IDE server using WebSockets
- **Screenshot capture**: Automatically capture screenshots of your application
- **Logging**: Send log messages to the Cursor IDE
- **Custom events**: Send custom events to the Cursor IDE
- **UI element inspection**: Allow UI elements to be picked and highlighted in the IDE
- **SwiftUI integration**: Easy integration with SwiftUI applications

## Topics

### Getting Started

- <doc:Integration>

### Main Classes

- `RCPClient`
- `RCPManager`
- `RCPClientDelegate`

### SwiftUI Integration

- `View/withRCP(serverURL:appName:onSetup:)`
- `View/withRCP(serverURLString:appName:onSetup:)`
- `View/rcpInspectable(id:metadata:)`
- `RCPInspectable`
