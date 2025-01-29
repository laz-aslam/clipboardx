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
                EmptyView()
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
    private var historyMenu: NSMenu?
    private var trackingTimer: Timer?
    private var isMenuVisible = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        registerGlobalShortcut()
        setupHistoryMenu()
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
    
    private func setupHistoryMenu() {
        historyMenu = NSMenu()
        historyMenu?.delegate = self
    }
    
    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()
        
        // Get history items (limited to 10 for menu bar)
        let historyItems = clipboardManager.getHistory().prefix(10)
        
        // Add history items
        for item in historyItems {
            let menuItem = NSMenuItem(title: item.prefix(50) + (item.count > 50 ? "..." : ""),
                                    action: #selector(menuItemClicked(_:)),
                                    keyEquivalent: "")
            menuItem.representedObject = item
            menu.addItem(menuItem)
        }
        
        if clipboardManager.getHistory().isEmpty {
            menu.addItem(NSMenuItem(title: "No items in history", action: nil, keyEquivalent: ""))
        }
        
        // Add Quit option only to the status item menu
        if menu === statusItem.menu {
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        }
    }
    
    private func showClipboardHistory() {
        isMenuVisible = true
        
        // Show initial menu at current mouse location
        updateMenuPosition()
        
        // Start tracking mouse movement
        trackingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateMenuPosition()
        }
        
        // Add event monitor for ESC key and clicks outside
        let eventMask: NSEvent.EventTypeMask = [.keyDown, .leftMouseDown, .rightMouseDown]
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: eventMask) { [weak self] event in
            if event.type == .keyDown {
                if event.keyCode == 53 { // ESC key
                    self?.dismissMenu()
                }
            } else {
                self?.dismissMenu()
            }
        }
    }
    
    private func updateMenuPosition() {
        let mouseLocation = NSEvent.mouseLocation
        let screenFrame = NSScreen.main?.frame ?? .zero
        
        let point = NSPoint(
            x: mouseLocation.x,
            y: screenFrame.height - mouseLocation.y
        )
        
        // Update menu items before showing
        if !isMenuVisible {
            menuWillOpen(historyMenu!)
        }
        
        // Show menu at cursor position
        historyMenu?.popUp(
            positioning: historyMenu?.items.first,
            at: NSPoint(x: point.x, y: point.y - 5),
            in: nil
        )
    }
    
    private func dismissMenu() {
        isMenuVisible = false
        trackingTimer?.invalidate()
        trackingTimer = nil
        eventMonitor = nil
        historyMenu?.cancelTracking()
    }
    
    @objc private func menuItemClicked(_ sender: NSMenuItem) {
        guard let text = sender.representedObject as? String else { return }
        clipboardManager.copyToClipboard(text)
        
        // Dismiss menu
        dismissMenu()
        
        // Simulate CMD+V to paste immediately
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let source = CGEventSource(stateID: .hidSystemState)
            
            let cmdVDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
            cmdVDown?.flags = .maskCommand
            
            let cmdVUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
            cmdVUp?.flags = .maskCommand
            
            cmdVDown?.post(tap: .cghidEventTap)
            cmdVUp?.post(tap: .cghidEventTap)
        }
    }
    
    @objc private func quitApp() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        NSApplication.shared.terminate(nil)
    }
}
