//
//  TodoModel.swift
//  ToDo
//
//  Created for Todo App
//

import Foundation

struct TodoItem: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var isCompleted: Bool = false
}

class TodoModel: ObservableObject {
    @Published var todos: [TodoItem] = []
    
    init() {
        print("TodoModel initialized")
        // Add some sample todos
        todos = [
            TodoItem(title: "Buy groceries"),
            TodoItem(title: "Finish SwiftUI project"),
            TodoItem(title: "Go for a run")
        ]
    }
    
    func addTodo(title: String) {
        let newTodo = TodoItem(title: title)
        todos.append(newTodo)
        print("Added new todo: \(title)")
    }
    
    func toggleCompletion(for todoId: UUID) {
        if let index = todos.firstIndex(where: { $0.id == todoId }) {
            todos[index].isCompleted.toggle()
            let status = todos[index].isCompleted ? "completed" : "incomplete"
            print("Todo '\(todos[index].title)' marked as \(status)")
        }
    }
    
    func deleteTodo(at indexSet: IndexSet) {
        for index in indexSet {
            print("Deleted todo: \(todos[index].title)")
        }
        todos.remove(atOffsets: indexSet)
    }
} 