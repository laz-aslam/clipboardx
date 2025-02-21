//
//  clipboardxApp.swift
//  clipboardx
//
//  Created by Lazim Aslam on 27/01/25.
//

import SwiftUI
import Carbon
import AppKit
import ServiceManagement

@main
struct clipboardxApp: App {
    @AppStorage("hasGrantedPermissions") private var hasGrantedPermissions = false
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var showingPermissions = false
    
    var body: some Scene {
        WindowGroup {
            if !hasGrantedPermissions {
                PermissionsView {
                    NSApplication.shared.windows.first?.close()
                }
                .onAppear { showingPermissions = true }
                .frame(width: 500, height: 500)
            } else {
                PermissionsView {
                    NSApplication.shared.windows.first?.close()
                }
                .onAppear { showingPermissions = true }
                .frame(width: 500, height: 500)
                // EmptyView()  // <-- This will show a blank screen
            }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 500, height: 500)
        .handlesExternalEvents(matching: Set(arrayLiteral: "*"))
        
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    var clipboardManager = ClipboardManager.shared
    private var eventMonitor: Any?
    private var hotKeyRef: EventHotKeyRef?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        registerGlobalShortcut()
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipboard Manager")
        }
        
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }
    
    private func registerGlobalShortcut() {
        // Register CMD+SHIFT+V globally
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(("CBMX" as NSString).utf8String!.pointee)
        hotKeyID.id = 1
        
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)
        
        // Create weak reference to self
        let weakSelf = Unmanaged.passUnretained(self).toOpaque()
        
        // Install handler
        InstallEventHandler(GetApplicationEventTarget(), { (_, event, userData) -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            let appDelegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
            appDelegate.showClipboardHistory()
            return noErr
        }, 1, &eventType, weakSelf, nil)
        
        // Register hotkey (CMD+SHIFT+V)
        var gHotKeyRef: EventHotKeyRef?
        RegisterEventHotKey(UInt32(kVK_ANSI_V),
                           UInt32(cmdKey | shiftKey),
                           hotKeyID,
                           GetApplicationEventTarget(),
                           0,
                           &gHotKeyRef)
        
        hotKeyRef = gHotKeyRef
    }
    
    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()
        
        for item in clipboardManager.getHistory() {
            let menuItem = NSMenuItem(title: item.prefix(50) + (item.count > 50 ? "..." : ""),
                                    action: #selector(menuItemClicked(_:)),
                                    keyEquivalent: "")
            menuItem.representedObject = item
            menu.addItem(menuItem)
        }
        
        if clipboardManager.getHistory().isEmpty {
            menu.addItem(NSMenuItem(title: "No items in history", action: nil, keyEquivalent: ""))
        }
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
    }
    
    @objc private func menuItemClicked(_ sender: NSMenuItem) {
        guard let text = sender.representedObject as? String else { return }
        clipboardManager.copyToClipboard(text)
        
        // Simulate CMD+V to paste immediately
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let source = CGEventSource(stateID: .hidSystemState)
            
            // Create CMD+V events
            let cmdVDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
            cmdVDown?.flags = .maskCommand
            
            let cmdVUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
            cmdVUp?.flags = .maskCommand
            
            // Post events
            cmdVDown?.post(tap: .cghidEventTap)
            cmdVUp?.post(tap: .cghidEventTap)
        }
    }
    
    private func showClipboardHistory() {
        let mouseLocation = NSEvent.mouseLocation
        let screenFrame = NSScreen.main?.frame ?? .zero
        
        // Convert from screen coordinates (bottom-left) to window coordinates (top-left)
        let adjustedLocation = NSPoint(
            x: mouseLocation.x,
            y: screenFrame.height - mouseLocation.y
        )
        
        statusItem.menu?.popUp(positioning: nil,
                             at: adjustedLocation,
                             in: nil)
    }
    
    @objc private func quitApp() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        NSApplication.shared.terminate(nil)
    }
}
