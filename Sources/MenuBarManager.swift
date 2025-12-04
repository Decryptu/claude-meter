import AppKit
import SwiftUI

@MainActor
class MenuBarManager: NSObject {
    private let statusItem: NSStatusItem
    private let button: NSStatusBarButton
    private var menu: NSMenu!
    private var usageData: UsageResponse?
    private var refreshTask: Task<Void, Never>?
    private var apiClient: ClaudeAPIClient?
    private var settings: ClaudeSettings?
    private var settingsWindowController: SettingsWindowController?
    private let logger = Logger.shared

    // App version
    nonisolated private let appVersion = "1.2.3"

    // Auto-detection retry tracking
    private var lastAutoDetectionAttempt: Date?
    private let autoDetectionCooldownSeconds: TimeInterval = 300 // 5 minutes

    init(statusItem: NSStatusItem, button: NSStatusBarButton) {
        self.statusItem = statusItem
        self.button = button
        super.init()

        Task { await logger.log("MenuBarManager initializing", level: .info) }
        setupMenu()
        loadSettings()
        updateIcon(percentage: nil)
        updateMenu()  // Initialize menu even without credentials
        startPeriodicRefresh()
    }

    private func loadSettings() {
        Task { await logger.log("Loading settings", level: .info) }
        settings = ClaudeSettings.load()

        if let settings = settings {
            Task { await logger.log("Settings loaded successfully", level: .info) }
            Task { await logger.log("Organization ID: \(settings.organizationId)", level: .debug) }
            apiClient = ClaudeAPIClient(settings: settings)
            Task {
                await refreshUsage()
            }
        } else {
            Task { await logger.log("No settings found, showing auto-detection prompt", level: .info) }
            // Show prompt before attempting auto-detection
            showAutoDetectionPrompt()
        }
    }

    private func showAutoDetectionPrompt() {
        let alert = NSAlert()
        alert.messageText = "Welcome to ClaudeMeter"
        alert.informativeText = """
        ClaudeMeter can automatically detect your Claude credentials from:
        • Claude Desktop app
        • Brave Browser
        • Google Chrome

        This requires accessing your macOS Keychain to decrypt cookies.
        You'll see a system prompt asking for permission.

        Alternatively, you can configure credentials manually in Settings.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Try Auto-Detection")
        alert.addButton(withTitle: "Configure Manually")

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            // User chose auto-detection
            Task { await logger.log("User chose auto-detection", level: .info) }
            tryAutoDetection()
        } else {
            // User chose manual configuration
            Task { await logger.log("User chose manual configuration", level: .info) }
            updateMenu()  // Update menu to show setup options
        }
    }

    private func tryAutoDetection(isRetry: Bool = false) {
        // Update last attempt timestamp
        lastAutoDetectionAttempt = Date()

        Task { @MainActor in
            let extractor = CredentialExtractor()
            if let credentials = extractor.extractCredentials() {
                await logger.log("Auto-detection successful", level: .info)

                if let orgId = credentials.organizationId, let sessionKey = credentials.sessionKey {
                    let newSettings = ClaudeSettings(
                        organizationId: orgId,
                        sessionKey: sessionKey,
                        autoTriggerQuota: false
                    )

                    do {
                        try newSettings.save()
                        settings = newSettings
                        apiClient = ClaudeAPIClient(settings: newSettings)

                        Task {
                            await refreshUsage()
                        }

                        if isRetry {
                            await logger.log("Credentials refreshed automatically from \(credentials.source)", level: .info)
                        } else {
                            showNotification(title: "ClaudeMeter Ready", message: "Credentials detected from \(credentials.source)")
                        }
                    } catch {
                        await logger.log("Error saving auto-detected settings: \(error)", level: .error)
                    }
                }
            } else {
                await logger.log("Auto-detection failed, user needs to configure manually", level: .warning)
                updateMenu()  // Update menu to show setup options
            }
        }
    }

    private func canRetryAutoDetection() -> Bool {
        guard let lastAttempt = lastAutoDetectionAttempt else {
            return true // Never tried, can retry
        }

        let timeSinceLastAttempt = Date().timeIntervalSince(lastAttempt)
        let canRetry = timeSinceLastAttempt >= autoDetectionCooldownSeconds

        if !canRetry {
            let remainingTime = Int(autoDetectionCooldownSeconds - timeSinceLastAttempt)
            Task { await logger.log("Auto-detection on cooldown. Retry available in \(remainingTime)s", level: .debug) }
        }

        return canRetry
    }

    private func showNotification(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func setupMenu() {
        menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    private func startPeriodicRefresh() {
        Task { await logger.log("Starting periodic refresh (60s interval)", level: .debug) }

        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                await refreshUsage()
            }
        }
    }

    deinit {
        refreshTask?.cancel()
    }

    private func refreshUsage() async {
        guard let apiClient = apiClient else {
            await logger.log("Cannot refresh: No API client configured", level: .debug)
            return
        }

        await logger.log("Fetching usage data", level: .debug)

        do {
            usageData = try await apiClient.fetchUsage()

            // Check for null state (quota period expired) and auto-trigger if enabled
            if let settings = settings, settings.autoTriggerQuota {
                if let fiveHour = usageData?.fiveHour, fiveHour.resetsAt == nil {
                    await logger.log("Detected null quota state with auto-trigger enabled", level: .info)
                    await triggerQuotaPeriod()
                    // Refresh usage data after triggering
                    usageData = try await apiClient.fetchUsage()
                }
            }

            // Update menu and icon after data is fetched
            updateMenu()

            if let percentage = usageData?.fiveHour?.utilization {
                await logger.log("Usage: \(percentage)%", level: .debug)
                updateIcon(percentage: percentage)
            }
        } catch {
            await logger.log("Error fetching usage: \(error)", level: .error)
            updateIcon(percentage: nil)

            // Check if it's an authentication error and retry credential detection
            if let apiError = error as? ClaudeAPIClient.APIError,
               case .httpError(let statusCode) = apiError,
               (statusCode == 401 || statusCode == 403) {

                await logger.log("Authentication error detected (HTTP \(statusCode)). Credentials may have expired.", level: .warning)

                if canRetryAutoDetection() {
                    await logger.log("Attempting to refresh credentials automatically...", level: .info)
                    tryAutoDetection(isRetry: true)
                } else {
                    await logger.log("Cannot retry yet - cooldown period active", level: .debug)
                }
            }
        }
    }

    private func triggerQuotaPeriod() async {
        guard let apiClient = apiClient else {
            await logger.log("Cannot trigger quota: No API client configured", level: .error)
            return
        }

        await logger.log("Smart quota refresh: Triggering new quota period", level: .info)

        do {
            let resetsAt = try await apiClient.triggerQuotaPeriod()
            await logger.log("Smart quota refresh: New quota period started, resets at: \(resetsAt)", level: .info)
        } catch {
            await logger.log("Smart quota refresh: Error triggering quota period: \(error)", level: .error)
        }
    }

    private func updateIcon(percentage: Double?) {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }

            // Draw circle background
            context.setStrokeColor(NSColor.labelColor.withAlphaComponent(0.3).cgColor)
            context.setLineWidth(2.0)
            let circlePath = CGPath(ellipseIn: rect.insetBy(dx: 2, dy: 2), transform: nil)
            context.addPath(circlePath)
            context.strokePath()

            // Draw usage arc if we have a percentage
            if let percentage = percentage {
                let center = CGPoint(x: rect.midX, y: rect.midY)
                let radius = (rect.width - 4) / 2
                let startAngle = -CGFloat.pi / 2 // Start at top
                let endAngle = startAngle + (2 * CGFloat.pi * CGFloat(percentage / 100.0))

                // Color based on usage
                let color: NSColor
                if percentage < 50 {
                    color = .systemGreen
                } else if percentage < 80 {
                    color = .systemYellow
                } else {
                    color = .systemRed
                }

                context.setStrokeColor(color.cgColor)
                context.setLineWidth(2.0)
                context.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
                context.strokePath()
            }

            return true
        }

        image.isTemplate = true
        button.image = image

        // Add percentage text as title
        if let percentage = percentage {
            button.title = " \(Int(percentage))%"
        } else {
            button.title = " --"
        }
    }

    private func updateMenu() {
        menu.removeAllItems()

        if let usage = usageData, settings != nil {
            // Current session section
            if let fiveHour = usage.fiveHour {
                let headerItem = NSMenuItem(title: "Claude Usage", action: nil, keyEquivalent: "")
                headerItem.isEnabled = false
                menu.addItem(headerItem)

                menu.addItem(NSMenuItem.separator())

                let percentageItem = NSMenuItem(title: "Current Session: \(Int(fiveHour.utilization))% used", action: nil, keyEquivalent: "")
                percentageItem.isEnabled = false
                menu.addItem(percentageItem)

                // Only show reset time if it's available
                if fiveHour.resetsAt != nil {
                    let resetItem = NSMenuItem(title: "Resets in: \(fiveHour.timeUntilReset)", action: nil, keyEquivalent: "")
                    resetItem.isEnabled = false
                    menu.addItem(resetItem)
                }

                let lastUpdated = NSMenuItem(title: "Last updated: just now", action: nil, keyEquivalent: "")
                lastUpdated.isEnabled = false
                menu.addItem(lastUpdated)
            }

            menu.addItem(NSMenuItem.separator())

            let refreshItem = NSMenuItem(title: "Refresh Now", action: #selector(refreshNow), keyEquivalent: "r")
            refreshItem.target = self
            menu.addItem(refreshItem)

            menu.addItem(NSMenuItem.separator())

            // Smart Quota Refresh toggle
            let smartQuotaItem = NSMenuItem(title: "Smart Quota Refresh", action: #selector(toggleSmartQuota), keyEquivalent: "")
            smartQuotaItem.target = self
            smartQuotaItem.state = settings?.autoTriggerQuota == true ? .on : .off
            menu.addItem(smartQuotaItem)

            // Info text below toggle
            let infoItem = NSMenuItem(title: "   Keeps your quota window active", action: nil, keyEquivalent: "")
            infoItem.isEnabled = false
            menu.addItem(infoItem)

            menu.addItem(NSMenuItem.separator())

            // Launch at login toggle
            let launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
            launchAtLoginItem.target = self
            launchAtLoginItem.state = LaunchAtLoginHelper.isEnabled ? .on : .off
            menu.addItem(launchAtLoginItem)

            menu.addItem(NSMenuItem.separator())

            let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
            settingsItem.target = self
            menu.addItem(settingsItem)

            let logsItem = NSMenuItem(title: "View Logs", action: #selector(openLogs), keyEquivalent: "")
            logsItem.target = self
            menu.addItem(logsItem)

            menu.addItem(NSMenuItem.separator())

            let versionItem = NSMenuItem(title: "Version \(appVersion)", action: nil, keyEquivalent: "")
            versionItem.isEnabled = false
            menu.addItem(versionItem)

            let quitItem = NSMenuItem(title: "Quit ClaudeMeter", action: #selector(quit), keyEquivalent: "q")
            quitItem.target = self
            menu.addItem(quitItem)
        } else {
            let setupItem = NSMenuItem(title: "⚠️ Setup Required", action: nil, keyEquivalent: "")
            setupItem.isEnabled = false
            menu.addItem(setupItem)

            menu.addItem(NSMenuItem.separator())

            let configItem = NSMenuItem(title: "Configure Settings...", action: #selector(openSettings), keyEquivalent: "")
            configItem.target = self
            menu.addItem(configItem)

            let logsItem = NSMenuItem(title: "View Logs", action: #selector(openLogs), keyEquivalent: "")
            logsItem.target = self
            menu.addItem(logsItem)

            menu.addItem(NSMenuItem.separator())

            let versionItem = NSMenuItem(title: "Version \(appVersion)", action: nil, keyEquivalent: "")
            versionItem.isEnabled = false
            menu.addItem(versionItem)

            let quitItem = NSMenuItem(title: "Quit ClaudeMeter", action: #selector(quit), keyEquivalent: "q")
            quitItem.target = self
            menu.addItem(quitItem)
        }
    }

    @objc private func refreshNow() {
        Task { await logger.log("Manual refresh triggered", level: .info) }
        Task {
            await refreshUsage()
        }
    }

    @objc private func toggleSmartQuota() {
        guard var currentSettings = settings else {
            Task { await logger.log("Cannot toggle smart quota: No settings configured", level: .error) }
            return
        }

        // Toggle the setting
        currentSettings.autoTriggerQuota.toggle()

        // Save to disk
        do {
            try currentSettings.save()
            settings = currentSettings
            Task { await logger.log("Smart Quota Refresh toggled: \(currentSettings.autoTriggerQuota)", level: .info) }
            updateMenu()

            // Show brief explanation on first enable
            if currentSettings.autoTriggerQuota {
                Task {
                    // Check if quota is currently in null state and trigger immediately
                    if let fiveHour = usageData?.fiveHour, fiveHour.resetsAt == nil {
                        await logger.log("Quota in null state, triggering immediately", level: .info)
                        await triggerQuotaPeriod()
                        await refreshUsage()
                    }
                }
            }
        } catch {
            Task { await logger.log("Error saving smart quota setting: \(error)", level: .error) }
            let alert = NSAlert()
            alert.messageText = "Error"
            alert.informativeText = "Could not save setting: \(error.localizedDescription)"
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            try LaunchAtLoginHelper.toggle()
            Task { await logger.log("Launch at login toggled: \(LaunchAtLoginHelper.isEnabled)", level: .info) }
            updateMenu()
        } catch {
            Task { await logger.log("Error toggling launch at login: \(error)", level: .error) }
            let alert = NSAlert()
            alert.messageText = "Error"
            alert.informativeText = "Could not toggle launch at login: \(error.localizedDescription)"
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    @objc private func openSettings() {
        Task { await logger.log("Opening settings window", level: .info) }

        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(currentSettings: settings) { [weak self] newSettings in
                Task { await self?.logger.log("Settings updated", level: .info) }
                self?.settings = newSettings
                self?.apiClient = ClaudeAPIClient(settings: newSettings)

                Task {
                    await self?.refreshUsage()
                }
            }
        }

        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openLogs() {
        let logPath = logger.getLogFilePath()
        Task { await logger.log("Opening logs at: \(logPath)", level: .info) }

        NSWorkspace.shared.open(URL(fileURLWithPath: logPath))
    }

    @objc private func quit() {
        Task { await logger.log("ClaudeMeter quitting", level: .info) }
        NSApplication.shared.terminate(nil)
    }
}

extension MenuBarManager: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        // Don't call refreshUsage here - it causes layout shifts
        // The menu is already up-to-date from the periodic refresh
        // Only log for debugging purposes
        Task { await logger.log("Menu opened", level: .debug) }
    }
}