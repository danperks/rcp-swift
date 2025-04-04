//
//  ContentView.swift
//  ToDo
//
//  Created by Michael Feldstein on 3/26/25.
//

import SwiftUI

struct ContentView: View {
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
                            rcpManager.info(
                                "Todo '\(todo.title)' marked as \(todo.isCompleted ? "incomplete" : "complete")"
                            )
                        }
                        .rcpInspectable(
                            id: "todo-\(todo.id)",
                            metadata: [
                                "id": todo.id.uuidString,
                                "title": todo.title,
                                "isCompleted": todo.isCompleted,
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
    }
}

#Preview {
    ContentView()
        .environmentObject(RCPManager())  // Provide a mock RCP manager for previews
}
