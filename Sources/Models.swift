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

    static let settingsURL: URL = {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let configDirectory = homeDirectory.appendingPathComponent(".config/claude-meter")
        try? FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        return configDirectory.appendingPathComponent("settings.json")
    }()

    static func load() -> ClaudeSettings? {
        guard let data = try? Data(contentsOf: settingsURL) else { return nil }
        return try? JSONDecoder().decode(ClaudeSettings.self, from: data)
    }

    func save() throws {
        let data = try JSONEncoder().encode(self)
        try data.write(to: Self.settingsURL)
    }
}
