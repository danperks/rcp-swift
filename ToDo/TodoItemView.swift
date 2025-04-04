//
//  TodoItemView.swift
//  ToDo
//
//  Created for Todo App
//

import SwiftUI

struct TodoItemView: View {
    let todo: TodoItem
    let onToggle: () -> Void
    
    var body: some View {
        HStack {
            Button(action: {
                print("Toggle button tapped for '\(todo.title)'")
                onToggle()
            }) {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(todo.isCompleted ? .green : .gray)
            }
            .buttonStyle(PlainButtonStyle())
            
            Text(todo.title)
                .strikethrough(todo.isCompleted)
                .foregroundColor(todo.isCompleted ? .gray : .primary)
            
            Spacer()
        }
        .padding(.vertical, 8)
        .onAppear {
            print("TodoItemView appeared for '\(todo.title)'")
        }
    }
}

#Preview {
    TodoItemView(
        todo: TodoItem(title: "Sample Todo", isCompleted: false),
        onToggle: {}
    )
} 