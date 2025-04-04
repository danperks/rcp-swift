Cursor is the current leader in using AI to manipulate code, however looking at and writing code is only a small portion of a developers job. In order to fulfill our mission of creating the AI Programmer of the future, we need Cursor to be able to do the other 50% of the job which happens in the artifact they’re building. Enter the Runtime Context Protocol.

## Leapfrog

Windsurf and others are approaching this by building a tight integration with an embedded webview. We can do much much better

- We can work with _any application,_ web, native, mobile, terminal
- We can connect to the actual runtime information, ie React/Svelte components instead of css-selected divs which dont actually map to code
- We can work in your actual browser so you don’t have to worry about okta/auth in a sketchy webview, use your existing cookies
- We can still do the tight embedded webview thing on top of this, with a clean separation of concerns

## How

Cursor will spin up a server that listens to apps implementing Runtime Context Protocol clients. Runtimes will connect to it via implementations provided by us for the standard case, or written by project maintainers to work with their own runtimes for the long tail.

- In web we can provide an extension or an injectable script tag.
- React and other frameworks can have slim adapters to help map components to divs
- SwiftUI can provide a package as well
- Everything else will have very simple interfaces to implement and it can work anywhere

### APIs

Eyes

- Agent can call the `runtime_visual` tool to see a screenshot of the app/site
- The user can pick an element/view/object/whatever from the runtime, and it gets added into the composer as a `runtime_element` context pill

Ears

- Agent can call the `runtime_logs` tool to see system logs
- specify filtering by all/warn/error
- specify filtering by a key (logs added by the agent can prefix ‘[agent]’, and filter to that so context window doesn’t get bloated)

Fingers

- Agent can send `runtime_message` calls to perform any arbitrary action supported by the client implementation
- Reload a website
- Tap a SwiftUI element
- Read state of data structures

### Why not just MCP

Many things can’t spin up a server, so this protocol has to be something where the apps being developed call into Cursor, vs the other way around. A website can’t host an incoming connection for example.

However we might match a lot of the MCP protocol so people can share code they’ve already written.

## API

The protocol runs over a websocket served by the server (IDE). The client is given a url+port to connect to, either manually, or for embedded Previews the IDE can provide it to the client app. We can also try to get bonjour working to auto-detect.

### Handshake

When the client connects to the server it sends a handshake to identify itself. It sends an rcpVersion to tell the server what version of the protocol it supports

```tsx
{
  "type": "handshake",
	"name": "Some Cool App"
	"maxRcpVersion": 1
}
```

The server responds with an ack. It returns an rcpVersion of the highest version both the client and server will support and can communicate over.

```tsx
{
  "type": "handshakeAcknowledged",
  "sessionId": "session123",
  "rcpVersion": number
}
```

### Requests

Requests are made from the IDE→Runtime, requesting information such as a screenshot or result of an arbitrary action. Request IDs are used to prevent async ordering issues.

- getScreenshot returns the current viewport screenshot in base64 (for now)
- getData

```tsx
{
  "type": "request",
  "requestId": "req-1",
  "payload": {
    "command": "getScreenshot"
  }
}
```

### Responses

Responses are in direct response from a Request from the IDE returning the result

```tsx
{
  "type": "response",
  "requestId": "req-1",
  "payload": {
    "command": "getScreenshot",
    "data": "data:image/png;base64, iVBOR..."
  }
}
```

### Events

Events are sent from the runtime to the IDE at any time, the most obvious example being logs. Another example is a UI element being picked to add to the context.

```tsx
{
  "type": "event",
  "payload": {
    "eventName": "log",
    "level": "warn",
    "message": "Something suspicious happened..."
  }
}

{
  "type": "event",
  "payload": {
    "eventName": "uiElementPicked",
		"elementID": "some identifier"
  }
}
```
