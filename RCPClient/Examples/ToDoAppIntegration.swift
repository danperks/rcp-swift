import SwiftUI
import RCPClient

// This is a sample implementation showing how to integrate the RCP client with the ToDo app

struct ContentViewWithRCP: View {
    @StateObject private var todoModel = TodoModel()
    @State private var newTodoTitle = ""
    @EnvironmentObject private var rcpManager: RCPManager
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(todoModel.todos) { todo in
                        TodoItemView(todo: todo) {
                            todoModel.toggleCompletion(for: todo.id)
                            rcpManager.info("Todo '\(todo.title)' marked as \(todo.isCompleted ? "incomplete" : "complete")")
                        }
                        .rcpInspectable(id: "todo-\(todo.id)", metadata: [
                            "id": todo.id,
                            "title": todo.title,
                            "isCompleted": todo.isCompleted
                        ])
                    }
                    .onDelete { indexSet in
                        let todosToDelete = indexSet.map { todoModel.todos[$0].title }
                        rcpManager.info("Deleting todos: \(todosToDelete.joined(separator: ", "))")
                        todoModel.deleteTodo(at: indexSet)
                    }
                }
                
                HStack {
                    TextField("Add new todo", text: $newTodoTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: newTodoTitle) { oldValue, newValue in
                            rcpManager.debug("Todo text changed: '\(oldValue)' -> '\(newValue)'")
                        }
                        .rcpInspectable(id: "new-todo-input")
                    
                    Button(action: {
                        guard !newTodoTitle.isEmpty else {
                            rcpManager.warn("Attempted to add empty todo")
                            return
                        }
                        
                        todoModel.addTodo(title: newTodoTitle)
                        rcpManager.info("Added new todo: '\(newTodoTitle)'")
                        newTodoTitle = ""
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundColor(.blue)
                    }
                    .rcpInspectable(id: "add-todo-button")
                }
                .padding()
            }
            .navigationTitle("Todo List")
            .onAppear {
                rcpManager.info("ContentView appeared with \(todoModel.todos.count) todos")
            }
        }
        // Apply the RCP client to the view
        .withRCP(
            serverURLString: "ws://localhost:8080",
            appName: "ToDo App",
            onSetup: { client in
                // Optional: Configure the client when it's set up
                client.delegate = CustomRCPDelegate()
            }
        )
    }
}

// Custom RCP client delegate for handling more complex scenarios
class CustomRCPDelegate: NSObject, RCPClientDelegate {
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
    
    func rcpClient(_ client: RCPClient, didReceiveCommand command: String, payload: [String: Any], responseHandler: @escaping ([String: Any]) -> Void) {
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