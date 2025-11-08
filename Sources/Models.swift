import Foundation

struct UsageResponse: Codable {
    let fiveHour: UsagePeriod?
    let sevenDay: UsagePeriod?
    let sevenDayOauthApps: UsagePeriod?
    let sevenDayOpus: UsagePeriod?
    let iguanaNecktie: UsagePeriod?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDayOauthApps = "seven_day_oauth_apps"
        case sevenDayOpus = "seven_day_opus"
        case iguanaNecktie = "iguana_necktie"
    }
}

struct UsagePeriod: Codable {
    let utilization: Double
    let resetsAt: String?

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }

    var resetsAtDate: Date? {
        guard let resetsAt = resetsAt else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: resetsAt)
    }

    var timeUntilReset: String {
        guard let resetDate = resetsAtDate else { return "N/A" }
        let now = Date()
        let interval = resetDate.timeIntervalSince(now)

        if interval < 0 {
            return "Expired"
        }

        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours > 0 {
            return "\(hours) hr \(minutes) min"
        } else {
            return "\(minutes) min"
        }
    }
}

struct ClaudeSettings: Codable {
    var organizationId: String
    var sessionKey: String
    var autoTriggerQuota: Bool

    static let settingsURL: URL = {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let configDirectory = homeDirectory.appendingPathComponent(".config/claude-meter")
        try? FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        return configDirectory.appendingPathComponent("settings.json")
    }()

    init(organizationId: String, sessionKey: String, autoTriggerQuota: Bool = false) {
        self.organizationId = organizationId
        self.sessionKey = sessionKey
        self.autoTriggerQuota = autoTriggerQuota
    }

    static func load() -> ClaudeSettings? {
        guard let data = try? Data(contentsOf: settingsURL) else { return nil }

        // Handle legacy settings without autoTriggerQuota field
        if let settings = try? JSONDecoder().decode(ClaudeSettings.self, from: data) {
            return settings
        }

        // Try to decode without the new field
        struct LegacySettings: Codable {
            var organizationId: String
            var sessionKey: String
        }

        if let legacy = try? JSONDecoder().decode(LegacySettings.self, from: data) {
            return ClaudeSettings(organizationId: legacy.organizationId, sessionKey: legacy.sessionKey)
        }

        return nil
    }

    func save() throws {
        let data = try JSONEncoder().encode(self)
        try data.write(to: Self.settingsURL)
    }
}

// MARK: - Quota Period Trigger Models

struct ConversationResponse: Codable {
    let uuid: String
    let name: String
}

struct MessageLimitEvent: Codable {
    let type: String
    let messageLimit: MessageLimit

    enum CodingKeys: String, CodingKey {
        case type
        case messageLimit = "message_limit"
    }
}

struct MessageLimit: Codable {
    let type: String
    let windows: Windows
}

struct Windows: Codable {
    let fiveHour: WindowDetail

    enum CodingKeys: String, CodingKey {
        case fiveHour = "5h"
    }
}

struct WindowDetail: Codable {
    let status: String
    let resetsAt: Int

    enum CodingKeys: String, CodingKey {
        case status
        case resetsAt = "resets_at"
    }
}
