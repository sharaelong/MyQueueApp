//
//  OverlayWindowController.swift
//  MyQueueApp
//
//  Created by 신기준 on 12/25/24.
//


import Cocoa

class BorderlessKeyWindow: NSWindow {
    override var canBecomeKey: Bool {
        true
    }
    
    override var canBecomeMain: Bool {
        true
    }
}

class OverlayWindowController: NSWindowController, NSTextFieldDelegate {
    private var containerView: ChatOverlayView!
    let todoQueue = (NSApplication.shared.delegate as! AppDelegate).todoQueue
    private var isShiftKeyPressed = false
    private var baseHeight: CGFloat?

    override init(window: NSWindow?) {
        let initialRect = NSRect(x: 0, y: 0, width: 450, height: 100) // Initial height
        let newWindow = BorderlessKeyWindow(
            contentRect: initialRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        super.init(window: newWindow)
        configureWindow()
        buildUI()
        layoutUI()
        containerView?.messageField.delegate = self
        updateInfoDisplay()
    }

    private func updateInfoDisplay() {
        if let window = self.window {
            baseHeight = window.frame.size.height
        }

        containerView?.setQueueItems(todoQueue.listAll())
        containerView?.updateInfoDisplay(isTextFieldEmpty: containerView?.messageField.stringValue.isEmpty ?? true, typingText: containerView?.messageField.stringValue)
        if containerView.isExpanded {
            containerView.showTodoList(todoQueue.listAll())
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    private func configureWindow() {
        guard let window = self.window else { return }
        window.level = .floating
        window.center()
        window.backgroundColor = .clear
        window.isMovableByWindowBackground = true
        window.hasShadow = true

        let visualEffect = NSVisualEffectView()
        visualEffect.translatesAutoresizingMaskIntoConstraints = false
        visualEffect.material = .hudWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 16.0  // Adjusted corner radius

        guard let contentView = window.contentView else { return }
        contentView.addSubview(visualEffect)

        NSLayoutConstraint.activate([
            visualEffect.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            visualEffect.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            visualEffect.topAnchor.constraint(equalTo: contentView.topAnchor),
            visualEffect.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    private func buildUI() {
        guard let contentView = window?.contentView else { return }
        containerView = ChatOverlayView() // Pass the delegate
        contentView.addSubview(containerView)
    }

    private func layoutUI() {
        guard let contentView = window?.contentView else { return }
        containerView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(insertNewline(_:)) {
            let text = containerView.messageField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if text.isEmpty {
                // If shift key is down => requeue
                // else => pop
                if isShiftKeyPressed {
                    todoQueue.requeueFront()
                } else {
                    todoQueue.dequeue()
                }
                updateInfoDisplay()
            } else {
                // Enqueue
                todoQueue.enqueue(text)
                containerView.messageField.stringValue = ""
                updateInfoDisplay()
            }
            return true
        } else if commandSelector == #selector(moveDown(_:)) {
            if !containerView.isExpanded {
                containerView.showTodoList(todoQueue.listAll())
                adjustWindowHeightForList(show: true)
            }
            return true
        } else if commandSelector == #selector(moveUp(_:)) {
            if containerView.isExpanded {
                containerView.hideTodoList()
                adjustWindowHeightForList(show: false)
            }
            return true
        }
        return false
    }
    
    func controlTextDidChange(_ obj: Notification) {
        updateInfoDisplay()
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField, textField === containerView?.messageField else { return }
        let text = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            todoQueue.enqueue(text)
            textField.stringValue = ""
            updateInfoDisplay()
        }
    }

    override func flagsChanged(with event: NSEvent) {
        let shiftKeyPressed = event.modifierFlags.contains(.shift)
        if isShiftKeyPressed != shiftKeyPressed {
            isShiftKeyPressed = shiftKeyPressed
            containerView?.setShiftKeyPressed(isShiftKeyPressed)
        }
    }
    
    private func adjustWindowHeightForList(show: Bool) {
        guard let window = self.window else { return }
        guard let base = baseHeight else { return }  // fallback if not set
        
        let listHeight: CGFloat = 180
        var newFrame = window.frame
        
        // Top edge remains pinned in place by adjusting origin.y to compensate
        let topY = newFrame.maxY  // store the top coordinate
        
        if show {
            // Increase window height by `listHeight`
            newFrame.size.height = base + listHeight
        } else {
            // Back to the base height
            newFrame.size.height = base
        }
        
        // Re-pin the top edge so it doesn't shift
        newFrame.origin.y = topY - newFrame.size.height
        
        window.setFrame(newFrame, display: true, animate: true)
    }

    func windowDidBecomeKey(_ notification: Notification) {
        containerView?.window?.makeFirstResponder(containerView?.messageField)
    }
}
