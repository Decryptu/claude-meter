import Foundation

class Logger {
    static let shared = Logger()

    private let logFileURL: URL
    private let dateFormatter: DateFormatter

    private init() {
        let logsDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/claude-meter/logs")

        try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)

        let dateString = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        logFileURL = logsDirectory.appendingPathComponent("claudemeter-\(dateString).log")

        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

        log("ClaudeMeter started", level: .info)
        log("Log file: \(logFileURL.path)", level: .info)
        log("macOS Version: \(ProcessInfo.processInfo.operatingSystemVersionString)", level: .info)
    }

    enum LogLevel: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
    }

    func log(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        let timestamp = dateFormatter.string(from: Date())
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "[\(timestamp)] [\(level.rawValue)] [\(fileName):\(line) \(function)] \(message)\n"

        // Print to console
        print(logMessage, terminator: "")

        // Write to file
        if let data = logMessage.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    try? fileHandle.close()
                }
            } else {
                try? data.write(to: logFileURL)
            }
        }
    }

    func getLogFilePath() -> String {
        return logFileURL.path
    }
}
