import Foundation
import ServiceManagement

class LaunchAtLoginHelper {
    private let logger = Logger.shared

    // Check if launch at login is enabled
    static var isEnabled: Bool {
        get {
            // For macOS 13+, use SMAppService
            if #available(macOS 13.0, *) {
                let service = SMAppService.mainApp
                return service.status == .enabled
            }

            // Fallback: check if plist exists
            let plistPath = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/LaunchAgents/com.claudemeter.agent.plist")
            return FileManager.default.fileExists(atPath: plistPath.path)
        }
    }

    // Toggle launch at login
    static func toggle() throws {
        if isEnabled {
            try disable()
        } else {
            try enable()
        }
    }

    // Enable launch at login
    static func enable() throws {
        let logger = Logger.shared
        logger.log("Enabling launch at login", level: .info)

        if #available(macOS 13.0, *) {
            // Use SMAppService for macOS 13+
            let service = SMAppService.mainApp
            try service.register()
            logger.log("Launch at login enabled via SMAppService", level: .info)
        } else {
            // Fallback: create launch agent plist
            try createLaunchAgent()
        }
    }

    // Disable launch at login
    static func disable() throws {
        let logger = Logger.shared
        logger.log("Disabling launch at login", level: .info)

        if #available(macOS 13.0, *) {
            // Use SMAppService for macOS 13+
            let service = SMAppService.mainApp
            try service.unregister()
            logger.log("Launch at login disabled via SMAppService", level: .info)
        } else {
            // Fallback: remove launch agent plist
            try removeLaunchAgent()
        }
    }

    // Create launch agent plist (legacy method)
    private static func createLaunchAgent() throws {
        let executablePath = ProcessInfo.processInfo.arguments[0]

        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.claudemeter.agent</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(executablePath)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <false/>
        </dict>
        </plist>
        """

        let plistDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
        try FileManager.default.createDirectory(at: plistDirectory, withIntermediateDirectories: true)

        let plistPath = plistDirectory.appendingPathComponent("com.claudemeter.agent.plist")
        try plistContent.write(to: plistPath, atomically: true, encoding: .utf8)

        Logger.shared.log("Launch agent plist created at \(plistPath.path)", level: .info)
    }

    // Remove launch agent plist
    private static func removeLaunchAgent() throws {
        let plistPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.claudemeter.agent.plist")

        if FileManager.default.fileExists(atPath: plistPath.path) {
            try FileManager.default.removeItem(at: plistPath)
            Logger.shared.log("Launch agent plist removed", level: .info)
        }
    }
}
