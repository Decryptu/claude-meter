import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var organizationId: String
    @State private var sessionKey: String
    @State private var autoTriggerQuota: Bool
    @State private var isAutoExtracting = false
    @State private var extractionResult: String?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showHelpAlert = false

    let onSave: (ClaudeSettings) -> Void

    init(currentSettings: ClaudeSettings?, onSave: @escaping (ClaudeSettings) -> Void) {
        _organizationId = State(initialValue: currentSettings?.organizationId ?? "")
        _sessionKey = State(initialValue: currentSettings?.sessionKey ?? "")
        _autoTriggerQuota = State(initialValue: currentSettings?.autoTriggerQuota ?? false)
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Claude Meter Settings")
                .font(.title2)
                .fontWeight(.bold)

            if isAutoExtracting {
                VStack(spacing: 10) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Searching for credentials...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Credentials")
                            .font(.headline)

                        Button(action: {
                            showHelpAlert = true
                        }) {
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        .help("How to get credentials manually")

                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Organization ID")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        TextField("6e35a193-deaa-46a0-80bd-f7a1652d383f", text: $organizationId)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Session Key")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        SecureField("sk-ant-sid01-...", text: $sessionKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }

                    if let result = extractionResult {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(result)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(8)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding()

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Quota Optimization")
                        .font(.headline)

                    Toggle("Auto-trigger quota period", isOn: $autoTriggerQuota)
                        .help("Automatically start a new 5-hour quota period when inactive")

                    Text("When enabled, automatically sends a minimal message (~10-20 tokens) to start a new quota period when the current one expires.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()

                Divider()

                HStack(spacing: 12) {
                    Button("Auto-Detect") {
                        autoDetectCredentials()
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("Cancel") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)

                    Button("Save") {
                        saveSettings()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(organizationId.isEmpty || sessionKey.isEmpty)
                }
                .padding()
            }
        }
        .frame(width: 500, height: 380)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("How to Get Credentials Manually", isPresented: $showHelpAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("""
            For Chrome/Brave browsers:

            1. Open https://claude.ai in your browser
            2. Make sure you're logged in
            3. Press F12 to open Developer Tools
            4. Click on the "Application" tab
            5. In the left sidebar, expand "Cookies"
            6. Click on "https://claude.ai"

            7. Find and copy these two cookies:
               • sessionKey: Copy the entire value
               • lastActiveOrg: This is your Organization ID

            8. Paste them into the fields above

            Note: sessionKey usually starts with "sk-ant-sid01-"
            """)
        }
    }

    private func autoDetectCredentials() {
        isAutoExtracting = true
        extractionResult = nil

        Task {
            let extractor = CredentialExtractor()

            if let credentials = extractor.extractCredentials() {
                await MainActor.run {
                    if let orgId = credentials.organizationId {
                        organizationId = orgId
                    }
                    if let sessionKey = credentials.sessionKey {
                        self.sessionKey = sessionKey
                    }

                    extractionResult = "Credentials found in \(credentials.source)"
                    isAutoExtracting = false
                }
            } else {
                await MainActor.run {
                    isAutoExtracting = false
                    errorMessage = """
                    Could not automatically detect credentials.

                    Please enter them manually:

                    1. Open https://claude.ai/settings/usage
                    2. Open Developer Tools (Cmd+Option+I)
                    3. Go to Network tab and refresh
                    4. Find the 'usage' request
                    5. Copy Organization ID from URL
                    6. Copy Session Key from Cookie header
                    """
                    showError = true
                }
            }
        }
    }

    private func saveSettings() {
        let settings = ClaudeSettings(
            organizationId: organizationId.trimmingCharacters(in: .whitespacesAndNewlines),
            sessionKey: sessionKey.trimmingCharacters(in: .whitespacesAndNewlines),
            autoTriggerQuota: autoTriggerQuota
        )

        do {
            try settings.save()
            Logger.shared.log("Settings saved successfully (auto-trigger: \(autoTriggerQuota))", level: .info)
            onSave(settings)
            dismiss()
        } catch {
            Logger.shared.log("Error saving settings: \(error)", level: .error)
            errorMessage = "Failed to save settings: \(error.localizedDescription)"
            showError = true
        }
    }
}

// Settings Window Controller
class SettingsWindowController: NSWindowController {
    convenience init(currentSettings: ClaudeSettings?, onSave: @escaping (ClaudeSettings) -> Void) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "Settings"
        window.center()
        window.isReleasedWhenClosed = false

        let settingsView = SettingsView(currentSettings: currentSettings, onSave: onSave)
        window.contentView = NSHostingView(rootView: settingsView)

        self.init(window: window)
    }
}
