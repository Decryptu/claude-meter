import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var organizationId: String
    @State private var sessionKey: String
    @State private var isAutoExtracting = false
    @State private var extractionResult: String?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showHelpAlert = false

    let onSave: (ClaudeSettings) -> Void

    init(currentSettings: ClaudeSettings?, onSave: @escaping (ClaudeSettings) -> Void) {
        _organizationId = State(initialValue: currentSettings?.organizationId ?? "")
        _sessionKey = State(initialValue: currentSettings?.sessionKey ?? "")
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            if isAutoExtracting {
                VStack(spacing: 16) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Searching for credentials...")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    // Credentials section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Credentials")
                                .font(.headline)

                            Spacer()

                            Button(action: { showHelpAlert = true }) {
                                Image(systemName: "questionmark.circle")
                            }
                            .buttonStyle(.plain)
                            .help("How to get credentials manually")
                        }

                        Text("Required to monitor your Claude usage")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Divider()

                        // Organization ID
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Organization ID")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            TextField("6e35a193-deaa-46a0-80bd-f7a1652d383f", text: $organizationId)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                        }

                        // Session Key
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Session Key")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            SecureField("sk-ant-sid01-...", text: $sessionKey)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                        }

                        if let result = extractionResult {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text(result)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))

                    Spacer()
                }
                .padding()

                // Bottom action bar
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
                .background(.regularMaterial)
            }
        }
        .frame(width: 540, height: 340)
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
        // Preserve autoTriggerQuota setting when saving credentials
        let currentAutoTrigger = ClaudeSettings.load()?.autoTriggerQuota ?? false

        let settings = ClaudeSettings(
            organizationId: organizationId.trimmingCharacters(in: .whitespacesAndNewlines),
            sessionKey: sessionKey.trimmingCharacters(in: .whitespacesAndNewlines),
            autoTriggerQuota: currentAutoTrigger
        )

        do {
            try settings.save()
            Task { await Logger.shared.log("Settings saved successfully", level: .info) }
            onSave(settings)
            dismiss()
        } catch {
            Task { await Logger.shared.log("Error saving settings: \(error)", level: .error) }
            errorMessage = "Failed to save settings: \(error.localizedDescription)"
            showError = true
        }
    }
}

// Settings Window Controller
class SettingsWindowController: NSWindowController {
    convenience init(currentSettings: ClaudeSettings?, onSave: @escaping (ClaudeSettings) -> Void) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 340),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "Settings"
        window.titlebarAppearsTransparent = true
        window.center()
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true

        let settingsView = SettingsView(currentSettings: currentSettings, onSave: onSave)
        window.contentView = NSHostingView(rootView: settingsView)

        self.init(window: window)
    }
}
