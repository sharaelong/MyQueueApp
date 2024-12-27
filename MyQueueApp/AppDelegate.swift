//
//  AppDelegate.swift
//  MyQueueApp
//
//  Created by 신기준 on 12/25/24.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    var overlayWindowController: OverlayWindowController?
    var statusItem: NSStatusItem?
    let todoQueue = TodoQueue() // from your queue class

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Create the overlay window
        overlayWindowController = OverlayWindowController()
        
        // Or keep it hidden until the user toggles it via a menu/status bar/hotkey
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.title = "Q" // or set an icon
            button.target = self
            button.action = #selector(toggleOverlay)
        }
    }
    
    @objc func toggleOverlay() {
        guard let controller = overlayWindowController else { return }
        
        if controller.window?.isVisible == true {
            controller.window?.orderOut(nil)
        } else {
            controller.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
