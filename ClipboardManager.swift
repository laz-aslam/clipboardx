//
//  ClipboardManager.swift
//  clipboardx
//
//  Created by Lazim Aslam on 27/01/25.
//

import Foundation
import AppKit

class ClipboardManager {
    static let shared = ClipboardManager()
    private var clipboardHistory: [String] = []
    private let maxHistoryItems = 20
    
    private init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        NSPasteboard.general.changeCount // Initial count
        
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }
    
    private func checkClipboard() {
        guard let newString = NSPasteboard.general.string(forType: .string) else { return }
        
        // Don't add if it's the same as the most recent item
        if let lastItem = clipboardHistory.first, lastItem == newString {
            return
        }
        
        clipboardHistory.insert(newString, at: 0)
        
        // Keep only maxHistoryItems
        if clipboardHistory.count > maxHistoryItems {
            clipboardHistory = Array(clipboardHistory.prefix(maxHistoryItems))
        }
    }
    
    func getHistory() -> [String] {
        return clipboardHistory
    }
    
    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
