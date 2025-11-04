import AppKit
import SwiftUI

class MenuBarManager: NSObject {
    private let statusItem: NSStatusItem
    private let button: NSStatusBarButton
    private var menu: NSMenu!
    private var usageData: UsageResponse?
    private var timer: Timer?
    private var apiClient: ClaudeAPIClient?
    private var settings: ClaudeSettings?
    private var settingsWindowController: SettingsWindowController?
    private let logger = Logger.shared

    init(statusItem: NSStatusItem, button: NSStatusBarButton) {
        self.statusItem = statusItem
        self.button = button
        super.init()

        logger.log("MenuBarManager initializing", level: .info)
        setupMenu()
        loadSettings()
        updateIcon(percentage: nil)
        startPeriodicRefresh()
    }

    private func loadSettings() {
        logger.log("Loading settings", level: .info)
        settings = ClaudeSettings.load()

        if let settings = settings {
            logger.log("Settings loaded successfully", level: .info)
            logger.log("Organization ID: \(settings.organizationId)", level: .debug)
            apiClient = ClaudeAPIClient(settings: settings)
            Task {
                await refreshUsage()
            }
        } else {
            logger.log("No settings found, attempting auto-detection", level: .info)
            // Try auto-detection on first run
            tryAutoDetection()
        }
    }

    private func tryAutoDetection() {
        Task {
            let extractor = CredentialExtractor()
            if let credentials = extractor.extractCredentials() {
                logger.log("Auto-detection successful", level: .info)

                await MainActor.run {
                    if let orgId = credentials.organizationId, let sessionKey = credentials.sessionKey {
                        let newSettings = ClaudeSettings(
                            organizationId: orgId,
                            sessionKey: sessionKey
                        )

                        do {
                            try newSettings.save()
                            settings = newSettings
                            apiClient = ClaudeAPIClient(settings: newSettings)

                            Task {
                                await refreshUsage()
                            }

                            showNotification(title: "ClaudeMeter Ready", message: "Credentials detected from \(credentials.source)")
                        } catch {
                            logger.log("Error saving auto-detected settings: \(error)", level: .error)
                        }
                    }
                }
            } else {
                logger.log("Auto-detection failed, user needs to configure manually", level: .warning)
            }
        }
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
        logger.log("Starting periodic refresh (60s interval)", level: .debug)
        // Refresh every 60 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshUsage()
            }
        }
    }

    @MainActor
    private func refreshUsage() async {
        guard let apiClient = apiClient else {
            logger.log("Cannot refresh: No API client configured", level: .debug)
            return
        }

        logger.log("Fetching usage data", level: .debug)

        do {
            usageData = try await apiClient.fetchUsage()
            updateMenu()

            if let percentage = usageData?.fiveHour?.utilization {
                logger.log("Usage: \(percentage)%", level: .debug)
                updateIcon(percentage: percentage)
            }
        } catch {
            logger.log("Error fetching usage: \(error)", level: .error)
            updateIcon(percentage: nil)
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

                let resetItem = NSMenuItem(title: "Resets in: \(fiveHour.timeUntilReset)", action: nil, keyEquivalent: "")
                resetItem.isEnabled = false
                menu.addItem(resetItem)

                let lastUpdated = NSMenuItem(title: "Last updated: just now", action: nil, keyEquivalent: "")
                lastUpdated.isEnabled = false
                menu.addItem(lastUpdated)
            }

            menu.addItem(NSMenuItem.separator())

            let refreshItem = NSMenuItem(title: "Refresh Now", action: #selector(refreshNow), keyEquivalent: "r")
            refreshItem.target = self
            menu.addItem(refreshItem)

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
        }

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit ClaudeMeter", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func refreshNow() {
        logger.log("Manual refresh triggered", level: .info)
        Task { @MainActor in
            await refreshUsage()
        }
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            try LaunchAtLoginHelper.toggle()
            logger.log("Launch at login toggled: \(LaunchAtLoginHelper.isEnabled)", level: .info)
            updateMenu()
        } catch {
            logger.log("Error toggling launch at login: \(error)", level: .error)
            let alert = NSAlert()
            alert.messageText = "Error"
            alert.informativeText = "Could not toggle launch at login: \(error.localizedDescription)"
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    @objc private func openSettings() {
        logger.log("Opening settings window", level: .info)

        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(currentSettings: settings) { [weak self] newSettings in
                self?.logger.log("Settings updated", level: .info)
                self?.settings = newSettings
                self?.apiClient = ClaudeAPIClient(settings: newSettings)

                Task { @MainActor in
                    await self?.refreshUsage()
                }
            }
        }

        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openLogs() {
        let logPath = logger.getLogFilePath()
        logger.log("Opening logs at: \(logPath)", level: .info)

        NSWorkspace.shared.open(URL(fileURLWithPath: logPath))
    }

    @objc private func quit() {
        logger.log("ClaudeMeter quitting", level: .info)
        NSApplication.shared.terminate(nil)
    }
}

extension MenuBarManager: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        Task { @MainActor in
            await refreshUsage()
        }
    }
}
