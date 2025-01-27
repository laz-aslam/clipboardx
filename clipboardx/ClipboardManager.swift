import Foundation
import AppKit

class ClipboardManager {
    static let shared = ClipboardManager()
    private var clipboardHistory: [String] = []
    private let maxHistoryItems = 20
    private let historyFile = "clipboard_history.json"
    
    private init() {
        loadHistory()
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
        
        saveHistory()
    }
    
    private func getApplicationSupportDirectory() -> URL? {
        let fileManager = FileManager.default
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let bundleID = Bundle.main.bundleIdentifier ?? "com.saphlinks.clipboardx"
        let appDirectory = appSupportURL.appendingPathComponent(bundleID)
        
        if !fileManager.fileExists(atPath: appDirectory.path) {
            do {
                try fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
            } catch {
                print("Failed to create app directory: \(error)")
                return nil
            }
        }
        
        return appDirectory
    }
    
    private func saveHistory() {
        guard let appDirectory = getApplicationSupportDirectory() else { return }
        let historyURL = appDirectory.appendingPathComponent(historyFile)
        
        do {
            let data = try JSONEncoder().encode(clipboardHistory)
            try data.write(to: historyURL)
        } catch {
            print("Failed to save clipboard history: \(error)")
        }
    }
    
    private func loadHistory() {
        guard let appDirectory = getApplicationSupportDirectory() else { return }
        let historyURL = appDirectory.appendingPathComponent(historyFile)
        
        do {
            let data = try Data(contentsOf: historyURL)
            clipboardHistory = try JSONDecoder().decode([String].self, from: data)
        } catch {
            print("Failed to load clipboard history: \(error)")
            clipboardHistory = []
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