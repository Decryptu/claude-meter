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

    init(statusItem: NSStatusItem, button: NSStatusBarButton) {
        self.statusItem = statusItem
        self.button = button
        super.init()

        setupMenu()
        loadSettings()
        updateIcon(percentage: nil)
        startPeriodicRefresh()
    }

    private func loadSettings() {
        settings = ClaudeSettings.load()
        if let settings = settings {
            apiClient = ClaudeAPIClient(settings: settings)
            Task {
                await refreshUsage()
            }
        }
    }

    private func setupMenu() {
        menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    private func startPeriodicRefresh() {
        // Refresh every 60 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshUsage()
            }
        }
    }

    @MainActor
    private func refreshUsage() async {
        guard let apiClient = apiClient else { return }

        do {
            usageData = try await apiClient.fetchUsage()
            updateMenu()

            if let percentage = usageData?.fiveHour?.utilization {
                updateIcon(percentage: percentage)
            }
        } catch {
            print("Error fetching usage: \(error)")
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

        if let settings = settings, let usage = usageData {
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

            let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
            settingsItem.target = self
            menu.addItem(settingsItem)
        } else {
            let setupItem = NSMenuItem(title: "⚠️ Setup Required", action: nil, keyEquivalent: "")
            setupItem.isEnabled = false
            menu.addItem(setupItem)

            menu.addItem(NSMenuItem.separator())

            let configItem = NSMenuItem(title: "Configure Settings...", action: #selector(openSettings), keyEquivalent: "")
            configItem.target = self
            menu.addItem(configItem)
        }

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit ClaudeMeter", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func refreshNow() {
        Task { @MainActor in
            await refreshUsage()
        }
    }

    @objc private func openSettings() {
        let alert = NSAlert()
        alert.messageText = "Claude Meter Settings"
        alert.informativeText = "Enter your Claude organization ID and session key.\n\nYou can find these in your browser when visiting claude.ai/settings/usage"

        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 8
        stackView.alignment = .leading

        let orgIdLabel = NSTextField(labelWithString: "Organization ID:")
        let orgIdField = NSTextField(frame: NSRect(x: 0, y: 0, width: 400, height: 24))
        orgIdField.placeholderString = "e.g., 6e35a193-deaa-46a0-80bd-f7a1652d383f"
        if let settings = settings {
            orgIdField.stringValue = settings.organizationId
        }

        let sessionKeyLabel = NSTextField(labelWithString: "Session Key:")
        let sessionKeyField = NSTextField(frame: NSRect(x: 0, y: 0, width: 400, height: 24))
        sessionKeyField.placeholderString = "sk-ant-sid01-..."
        if let settings = settings {
            sessionKeyField.stringValue = settings.sessionKey
        }

        stackView.addArrangedSubview(orgIdLabel)
        stackView.addArrangedSubview(orgIdField)
        stackView.addArrangedSubview(sessionKeyLabel)
        stackView.addArrangedSubview(sessionKeyField)

        alert.accessoryView = stackView
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            let newSettings = ClaudeSettings(
                organizationId: orgIdField.stringValue,
                sessionKey: sessionKeyField.stringValue
            )

            do {
                try newSettings.save()
                settings = newSettings
                apiClient = ClaudeAPIClient(settings: newSettings)

                Task { @MainActor in
                    await refreshUsage()
                }
            } catch {
                let errorAlert = NSAlert()
                errorAlert.messageText = "Error Saving Settings"
                errorAlert.informativeText = error.localizedDescription
                errorAlert.runModal()
            }
        }
    }

    @objc private func quit() {
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
