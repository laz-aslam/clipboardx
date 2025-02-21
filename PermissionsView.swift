//
//  PermissionsView.swift
//  clipboardx
//
//  Created by Lazim Aslam on 27/01/25.
//

import Foundation
import SwiftUI
import ServiceManagement
import ApplicationServices

struct PermissionsView: View {
    @AppStorage("hasGrantedPermissions") private var hasGrantedPermissions = false
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @State private var isAccessibilityEnabled = false
    @State private var isRequestingPermission = false
    
    var onComplete: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.on.clipboard")
                .imageScale(.large)
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            
            Text("Welcome to ClipboardX")
                .font(.title)
            
            Text("To use ClipboardX, we need a few permissions:")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 15) {
                PermissionRow(
                    title: "Accessibility",
                    description: "Required to detect keyboard shortcuts",
                    buttonTitle: "Grant Access",
                    isEnabled: isAccessibilityEnabled,
                    isLoading: isRequestingPermission,
                    action: requestAccessibilityPermission
                )
                
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        setLaunchAtLogin(enabled: newValue)
                    }
            }
            .padding()
            .frame(maxWidth: 400)
            
            
            Button("Continue") {
                hasGrantedPermissions = true
                onComplete()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!isAccessibilityEnabled)
        }
        .padding(40)
        .frame(width: 500)
        .onAppear {
            // Check initial state
            isAccessibilityEnabled = AXIsProcessTrusted()
            
            // Set up periodic checking
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                let trusted = AXIsProcessTrusted()
                if trusted != isAccessibilityEnabled {
                    isAccessibilityEnabled = trusted
                }
            }
        }
    }
    
    private func requestAccessibilityPermission() {
        isRequestingPermission = true
        
        // Open System Settings directly
        if let settingsUrl = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(settingsUrl)
        }
        
        // Start checking for permission after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: true]
            let enabled = AXIsProcessTrustedWithOptions(options)
            isAccessibilityEnabled = enabled
            
            // If not immediately granted, start checking periodically
            if !enabled {
                Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                    isAccessibilityEnabled = AXIsProcessTrusted()
                    if isAccessibilityEnabled {
                        timer.invalidate()
                        isRequestingPermission = false
                    }
                }
            } else {
                isRequestingPermission = false
            }
        }
    }
    
    private func setLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
        }
    }
}

struct PermissionRow: View {
    let title: String
    let description: String
    let buttonTitle: String
    let isEnabled: Bool
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            if !isEnabled {
                Button(action: action) {
                    if isLoading {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Opening Settings...")
                        }
                    } else {
                        Text(buttonTitle)
                    }
                }
                .padding(.top, 4)
                .disabled(isLoading)
            } else {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Access granted")
                }
                .padding(.top, 4)
            }
        }
    }
}
