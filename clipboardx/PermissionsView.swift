import SwiftUI
import ServiceManagement
import ApplicationServices

struct PermissionsView: View {
    @AppStorage("hasGrantedPermissions") private var hasGrantedPermissions = false
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @State private var isAccessibilityEnabled = false
    
    var onComplete: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "doc.on.clipboard")
                    .imageScale(.large)
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)
                
                Text("Welcome to ClipboardX")
                    .font(.title)
                    .fontWeight(.semibold)
            }
            .padding(.top, 20)
            
            VStack(spacing: 8) {
                Text("To use ClipboardX, we need a few permissions:")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 16) {
                    PermissionRow(
                        title: "Accessibility",
                        description: "Required to detect keyboard shortcuts",
                        buttonTitle: "Grant Access",
                        isEnabled: isAccessibilityEnabled,
                        action: requestAccessibilityPermission
                    )
                    
                    Toggle("Launch at startup", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { newValue in
                            setLaunchAtLogin(enabled: newValue)
                        }
                }
                .padding()
                .frame(maxWidth: 400)
            }
            
            Spacer()
            
            Button("Continue") {
                hasGrantedPermissions = true
                onComplete()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!isAccessibilityEnabled)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.bottom, 24)
        }
        .padding(40)
        .frame(width: 500, height: 500)
        .onAppear {
            isAccessibilityEnabled = AXIsProcessTrusted()
        }
    }
    
    private func requestAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: true]
        let enabled = AXIsProcessTrustedWithOptions(options)
        isAccessibilityEnabled = enabled
        
        // If not immediately granted, start checking periodically
        if !enabled {
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                isAccessibilityEnabled = AXIsProcessTrusted()
                if isAccessibilityEnabled {
                    timer.invalidate()
                }
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
    let action: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            if !isEnabled {
                Button(buttonTitle, action: action)
                    .padding(.top, 4)
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