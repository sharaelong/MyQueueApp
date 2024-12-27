//
//  TodoQueue.swift
//  MyQueueApp
//
//  Created by 신기준 on 12/25/24.
//

import Foundation

class TodoQueue {
    private var items: [String] = []
    private let defaults = UserDefaults.standard
    private let queueKey = "myTodoQueue"

    init() {
        load()
    }

    func enqueue(_ item: String) {
        items.append(item)
        save()
    }

    @discardableResult
    func dequeue() -> String? {
        let item = items.isEmpty ? nil : items.removeFirst()
        save()
        return item
    }

    func peek() -> String? {
        return items.first
    }

    @discardableResult
    func requeueFront() -> String? {
        guard let front = dequeue() else { return nil }
        enqueue(front)
        return front
    }

    func isEmpty() -> Bool {
        return items.isEmpty
    }

    func listAll() -> [String] {
        return items
    }

    private func save() {
        defaults.set(items, forKey: queueKey)
    }

    private func load() {
        if let savedItems = defaults.array(forKey: queueKey) as? [String] {
            items = savedItems
        }
    }
}
