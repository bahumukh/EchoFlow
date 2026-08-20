import Cocoa

class EchoflowHistorySheetController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    
    private var tableView: NSTableView!
    weak var delegate: EchoflowAppDelegate?
    
    convenience init(delegate: EchoflowAppDelegate) {
        let sheetWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 660, height: 500),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        self.init(window: sheetWindow)
        self.delegate = delegate
        
        sheetWindow.titlebarAppearsTransparent = true
        sheetWindow.titleVisibility = .hidden
        sheetWindow.isOpaque = false
        sheetWindow.backgroundColor = NSColor.windowBackgroundColor
        
        buildUI(in: sheetWindow.contentView!)
    }
    
    private func buildUI(in view: NSView) {
        var y: CGFloat = 450
        
        let titleLabel = NSTextField(labelWithString: "Transcription History")
        titleLabel.font = NSFont.systemFont(ofSize: 17, weight: .semibold)
        titleLabel.frame = NSRect(x: 30, y: y, width: 400, height: 22)
        view.addSubview(titleLabel)
        
        let clearButton = NSButton(title: "Clear History", target: self, action: #selector(clearHistoryClicked(_:)))
        clearButton.frame = NSRect(x: 500, y: y - 4, width: 130, height: 30)
        clearButton.bezelStyle = .rounded
        view.addSubview(clearButton)
        
        y -= 25
        
        let descLabel = NSTextField(labelWithString: "Your recent dictations. Audio and text stay entirely on this Mac.")
        descLabel.font = NSFont.systemFont(ofSize: 13)
        descLabel.textColor = .secondaryLabelColor
        descLabel.frame = NSRect(x: 30, y: y, width: 600, height: 20)
        view.addSubview(descLabel)
        y -= 20
        
        let listHeight: CGFloat = y - 70
        let scrollView = NSScrollView(frame: NSRect(x: 30, y: 70, width: 600, height: listHeight))
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        
        tableView = NSTableView(frame: scrollView.bounds)
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("HistoryColumn"))
        column.width = 580
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 60
        tableView.style = .plain
        
        scrollView.documentView = tableView
        view.addSubview(scrollView)
        
        let closeButton = NSButton(title: "Close", target: self, action: #selector(closeClicked(_:)))
        closeButton.frame = NSRect(x: 530, y: 20, width: 100, height: 30)
        closeButton.bezelStyle = .rounded
        closeButton.keyEquivalent = "\r"
        view.addSubview(closeButton)
    }
    
    func refreshList() {
        tableView.reloadData()
    }
    
    @objc private func closeClicked(_ sender: NSButton) {
        guard let sheet = window, let parent = sheet.sheetParent else { return }
        parent.endSheet(sheet)
    }
    
    @objc private func clearHistoryClicked(_ sender: NSButton) {
        guard let delegate = delegate else { return }
        delegate.history = []
        delegate.saveSettings() // Since history saving logic is private in delegate, we might need to expose it, but wait, saving is private.
        // I will just ask delegate to clear it.
        // Let's create a clearHistory() method on AppDelegate in a bit, for now I'll just clear the array and call a method.
        delegate.clearHistory()
        refreshList()
    }
    
    // MARK: - NSTableView
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return delegate?.history.count ?? 0
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let entry = delegate?.history[row] else { return nil }
        
        let cellID = NSUserInterfaceItemIdentifier("HistoryCell")
        var cell = tableView.makeView(withIdentifier: cellID, owner: nil) as? NSTableCellView
        
        if cell == nil {
            cell = NSTableCellView()
            cell?.identifier = cellID
            
            let textField = NSTextField(labelWithString: "")
            textField.font = NSFont.systemFont(ofSize: 13)
            textField.lineBreakMode = .byTruncatingTail
            textField.maximumNumberOfLines = 2
            textField.translatesAutoresizingMaskIntoConstraints = false
            
            let timeField = NSTextField(labelWithString: "")
            timeField.font = NSFont.systemFont(ofSize: 11)
            timeField.textColor = .secondaryLabelColor
            timeField.translatesAutoresizingMaskIntoConstraints = false
            
            let copyButton = NSButton(title: "Copy", target: self, action: #selector(copyEntry(_:)))
            copyButton.bezelStyle = .inline
            copyButton.translatesAutoresizingMaskIntoConstraints = false
            
            cell?.addSubview(textField)
            cell?.addSubview(timeField)
            cell?.addSubview(copyButton)
            
            cell?.textField = textField
            
            NSLayoutConstraint.activate([
                timeField.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 10),
                timeField.topAnchor.constraint(equalTo: cell!.topAnchor, constant: 5),
                
                textField.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 10),
                textField.topAnchor.constraint(equalTo: timeField.bottomAnchor, constant: 2),
                textField.trailingAnchor.constraint(equalTo: copyButton.leadingAnchor, constant: -10),
                
                copyButton.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -10),
                copyButton.centerYAnchor.constraint(equalTo: cell!.centerYAnchor)
            ])
        }
        
        let finalText = entry["finalText"] as? String ?? ""
        cell?.textField?.stringValue = finalText
        
        if let timestamp = entry["createdAt"] as? TimeInterval {
            let date = Date(timeIntervalSince1970: timestamp)
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            cell?.subviews.compactMap { $0 as? NSTextField }.first(where: { $0 != cell?.textField })?.stringValue = formatter.string(from: date)
        }
        
        if let btn = cell?.subviews.compactMap({ $0 as? NSButton }).first {
            btn.tag = row
        }
        
        return cell
    }
    
    @objc private func copyEntry(_ sender: NSButton) {
        guard let entry = delegate?.history[sender.tag],
              let text = entry["finalText"] as? String else { return }
        
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }
}
