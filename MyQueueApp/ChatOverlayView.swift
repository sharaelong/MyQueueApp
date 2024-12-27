import Cocoa

class ChatOverlayView: NSView, NSTextViewDelegate {

    weak var delegate: NSTextFieldDelegate?

    let messageField: NSTextField = {
        let tf = NSTextField()
        tf.placeholderString = "Enter TODO item"
        tf.font = NSFont.systemFont(ofSize: 18, weight: .regular)
        tf.isBordered = false
        tf.drawsBackground = false
        tf.backgroundColor = .clear
        tf.focusRingType = .none
        return tf
    }()

    private let tableView: NSTableView = {
        let tv = NSTableView()

        // Add one column for the TODO items
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("QueueItemColumn"))
        tv.addTableColumn(col)
        
        tv.intercellSpacing = .zero

        tv.headerView = nil  // remove the header row
        tv.rowHeight = 32
        tv.usesAlternatingRowBackgroundColors = false
        tv.backgroundColor = .clear

        return tv
    }()
    
    private let divider: NSBox = {
        let d = NSBox()
        d.boxType = .separator  // gives a standard macOS separator line
        return d
    }()
    
    private let scrollView: NSScrollView = {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.isHidden = false
        scrollView.drawsBackground = false
        scrollView.scrollerStyle = .overlay
        return scrollView
    }()

    private var enterIcon: NSImageView = {
        let iv = NSImageView()
        iv.image = NSImage(systemSymbolName: "return", accessibilityDescription: "Enter")
        iv.symbolConfiguration = .init(pointSize: 14, weight: .regular)
        iv.imageScaling = .scaleProportionallyDown
        return iv
    }()

    private var shiftIcon: NSImageView = {
        let iv = NSImageView()
        iv.image = NSImage(systemSymbolName: "shift", accessibilityDescription: "Shift")
        iv.symbolConfiguration = .init(pointSize: 14, weight: .regular)
        iv.imageScaling = .scaleProportionallyDown
        iv.isHidden = true
        return iv
    }()

    private var listViewHeightConstraint: NSLayoutConstraint?
    
    internal var isExpanded = false
    private var typedItem: String? = nil
    private var queueItems: [String] = []
    private var visibleItems: [String] {
        // If user typed something, that becomes row 0
        // If queue is empty, we might still show “Nothing to do!” as fallback
        if isExpanded {
            // Show the entire queue + typed item at the top if any
            if let typed = typedItem, !typed.isEmpty {
                // typed item + full queue
                return [typed] + (queueItems.isEmpty ? [] : queueItems)
            } else {
                // no typed item => either full queue or “Nothing to do!”
                return queueItems.isEmpty ? ["Nothing to do!"] : queueItems
            }
        }
        else {
            // Collapsed => show only the first row
            if let typed = typedItem, !typed.isEmpty {
                // typed item is row 0
                return [typed]
            }
            else {
                // not typing => real front item or “Nothing to do!”
                guard !queueItems.isEmpty else { return ["Nothing to do!"] }
                return [queueItems[0]]
            }
        }
    }
    
    func setQueueItems(_ items: [String]) {
        self.queueItems = items
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureAppearance()
        buildUI()
        setupConstraints()
        messageField.delegate = delegate
        updateInfoDisplay(isTextFieldEmpty: messageField.stringValue.isEmpty, typingText: messageField.stringValue)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureAppearance()
        buildUI()
        setupConstraints()
        messageField.delegate = delegate
        updateInfoDisplay(isTextFieldEmpty: messageField.stringValue.isEmpty, typingText: messageField.stringValue)
    }

    private func configureAppearance() {
        wantsLayer = true
        layer?.backgroundColor = .none
    }

    private func buildUI() {
        addSubview(messageField)
        addSubview(divider)
        addSubview(scrollView)
        scrollView.documentView = tableView
        
        tableView.dataSource = self
        tableView.delegate = self
    }
    
    private var tableHeightConstraint: NSLayoutConstraint?

    private func setupConstraints() {
        [messageField, divider, scrollView, tableView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        tableHeightConstraint = scrollView.heightAnchor.constraint(equalToConstant: 56)
        tableHeightConstraint?.isActive = true
        
        NSLayoutConstraint.activate([
            messageField.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            messageField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            messageField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            messageField.heightAnchor.constraint(equalToConstant: 30),
            
            // Divider is pinned horizontally at the same insets as scrollView
            divider.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 1),
            divider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -1),
            // Place it just below messageField
            divider.topAnchor.constraint(equalTo: messageField.bottomAnchor, constant: 8),
            // 1px or so in height
            divider.heightAnchor.constraint(equalToConstant: 1),

            // Now, adjust scrollView’s top so it’s below the divider
            scrollView.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 0),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 0),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 0),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 0),
        ])
    }

    func updateInfoDisplay(isTextFieldEmpty: Bool, typingText: String?) {
        if !isTextFieldEmpty, let text = typingText, !text.isEmpty {
            // User is typing => store the “+ Add TODO …” text as typedItem
            typedItem = "+ Add TODO item: \(text)"
        }
        else {
            // Not typing => typedItem is nil
            typedItem = nil
        }
        
        // Now reload the table to reflect the new “front” (either typed item or real queue front)
        tableView.reloadData()
        
        // Always highlight row 0 if we have content
        if !visibleItems.isEmpty {
            let frontItem = visibleItems[0]
            if frontItem != "Nothing to do!" {
                tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
                tableView.scrollRowToVisible(0)
            } else {
                tableView.deselectAll(nil)
            }
        }
    }

    func showTodoList(_ items: [String]) {
        // Fill the queue
        self.queueItems = items
        self.isExpanded = true

        // Up the table height to show multiple rows
        tableHeightConstraint?.constant = 180 // or however tall you want
        tableView.reloadData()

        // If queue is not empty, highlight first row
        if !visibleItems.isEmpty {
            let frontItem = visibleItems[0]
            if frontItem != "Nothing to do!" {
                tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
                tableView.scrollRowToVisible(0)
            } else {
                tableView.deselectAll(nil)
            }
        }

        needsLayout = true
        layoutSubtreeIfNeeded()
    }

    func hideTodoList() {
        self.isExpanded = false
        // Show only 1 row
        tableHeightConstraint?.constant = 56
        tableView.reloadData()

        // Possibly highlight first row if there's an item
        if !visibleItems.isEmpty {
            let frontItem = visibleItems[0]
            if frontItem != "Nothing to do!" {
                tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
                tableView.scrollRowToVisible(0)
            } else {
                tableView.deselectAll(nil)
            }
        }

        needsLayout = true
        layoutSubtreeIfNeeded()
    }
    
    private func highlightFrontElement() {
        guard !queueItems.isEmpty else { return }
        tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        // Optionally scroll to that row:
        tableView.scrollRowToVisible(0)
    }

    func setShiftKeyPressed(_ isPressed: Bool) {
        shiftIcon.isHidden = !isPressed
        enterIcon.isHidden = false
    }
}

extension ChatOverlayView: NSTableViewDataSource, NSTableViewDelegate {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return visibleItems.count
    }

    // Provide the view for each row/column
    func tableView(_ tableView: NSTableView,
                   viewFor tableColumn: NSTableColumn?,
                   row: Int) -> NSView? {
        
        let item = visibleItems[row]
        
        // Reuse or create a NSTextField-based view
        let identifier = NSUserInterfaceItemIdentifier("QueueItemCell")
        var cellView: NSTableCellView? =
            tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView
        
        if cellView == nil {
            // Create a new cell
            cellView = NSTableCellView(frame: .zero)
            cellView?.identifier = identifier
            
            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.font = NSFont.systemFont(ofSize: 14)
            cellView?.addSubview(textField)
            
            // Pin textField edges
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView!.leadingAnchor, constant: 8),
                textField.trailingAnchor.constraint(equalTo: cellView!.trailingAnchor, constant: -8),
                textField.centerYAnchor.constraint(equalTo: cellView!.centerYAnchor),
            ])
            cellView?.textField = textField
        }
        
        // Set the text
        cellView?.textField?.stringValue = item
        
        // If row == 0, place the icons in the cell
        if row == 0 {
            if enterIcon.superview != cellView { // to avoid re-adding
                cellView?.addSubview(enterIcon)
                cellView?.addSubview(shiftIcon)
                
                enterIcon.translatesAutoresizingMaskIntoConstraints = false
                shiftIcon.translatesAutoresizingMaskIntoConstraints = false
                
                // Example constraints to put icons on the right side
                NSLayoutConstraint.activate([
                    enterIcon.centerYAnchor.constraint(equalTo: cellView!.centerYAnchor),
                    enterIcon.trailingAnchor.constraint(equalTo: cellView!.trailingAnchor, constant: -12),
                    
                    shiftIcon.centerYAnchor.constraint(equalTo: cellView!.centerYAnchor),
                    shiftIcon.trailingAnchor.constraint(equalTo: enterIcon.leadingAnchor, constant: -6),
                ])
            }
        }
        else {
            // If not row 0, remove icons if they are still attached
            if enterIcon.superview == cellView {
                enterIcon.removeFromSuperview()
                shiftIcon.removeFromSuperview()
            }
        }
        
        return cellView
    }
}
