import Foundation
import SQLite3

class CredentialExtractor {
    private let logger = Logger.shared

    struct ExtractedCredentials {
        let organizationId: String?
        let sessionKey: String?
        let source: String
    }

    enum ExtractionError: Error, LocalizedError {
        case noCookiesFound
        case databaseAccessDenied
        case invalidCookieFormat
        case noClaudeData

        var errorDescription: String? {
            switch self {
            case .noCookiesFound:
                return "No cookies database found"
            case .databaseAccessDenied:
                return "Cannot access cookies database. You may need to grant Full Disk Access to Terminal or this app."
            case .invalidCookieFormat:
                return "Could not parse cookie data"
            case .noClaudeData:
                return "No Claude session data found in cookies"
            }
        }
    }

    // MARK: - Main extraction method

    func extractCredentials() -> ExtractedCredentials? {
        logger.log("Starting automatic credential extraction", level: .info)

        // Priority 1: Try Claude Desktop App
        if let credentials = tryExtractFromClaudeDesktop() {
            logger.log("Successfully extracted credentials from Claude Desktop", level: .info)
            return credentials
        }

        // Priority 2: Try Brave Browser
        if let credentials = tryExtractFromBrave() {
            logger.log("Successfully extracted credentials from Brave", level: .info)
            return credentials
        }

        // Priority 3: Try Chrome
        if let credentials = tryExtractFromChrome() {
            logger.log("Successfully extracted credentials from Chrome", level: .info)
            return credentials
        }

        // Priority 4: Try Safari
        if let credentials = tryExtractFromSafari() {
            logger.log("Successfully extracted credentials from Safari", level: .info)
            return credentials
        }

        logger.log("Could not extract credentials from any source", level: .warning)
        return nil
    }

    // MARK: - Claude Desktop

    private func tryExtractFromClaudeDesktop() -> ExtractedCredentials? {
        let cookiesPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Claude/Cookies")

        logger.log("Checking Claude Desktop at: \(cookiesPath.path)", level: .debug)

        guard FileManager.default.fileExists(atPath: cookiesPath.path) else {
            logger.log("Claude Desktop cookies not found", level: .debug)
            return nil
        }

        return extractFromCookieDatabase(at: cookiesPath, source: "Claude Desktop")
    }

    // MARK: - Brave Browser

    private func tryExtractFromBrave() -> ExtractedCredentials? {
        let cookiesPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/BraveSoftware/Brave-Browser/Default/Cookies")

        logger.log("Checking Brave at: \(cookiesPath.path)", level: .debug)

        guard FileManager.default.fileExists(atPath: cookiesPath.path) else {
            logger.log("Brave cookies not found", level: .debug)
            return nil
        }

        return extractFromCookieDatabase(at: cookiesPath, source: "Brave Browser")
    }

    // MARK: - Chrome

    private func tryExtractFromChrome() -> ExtractedCredentials? {
        let cookiesPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Google/Chrome/Default/Cookies")

        logger.log("Checking Chrome at: \(cookiesPath.path)", level: .debug)

        guard FileManager.default.fileExists(atPath: cookiesPath.path) else {
            logger.log("Chrome cookies not found", level: .debug)
            return nil
        }

        return extractFromCookieDatabase(at: cookiesPath, source: "Google Chrome")
    }

    // MARK: - Safari

    private func tryExtractFromSafari() -> ExtractedCredentials? {
        let cookiesPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Cookies/Cookies.binarycookies")

        logger.log("Checking Safari at: \(cookiesPath.path)", level: .debug)

        guard FileManager.default.fileExists(atPath: cookiesPath.path) else {
            logger.log("Safari cookies not found", level: .debug)
            return nil
        }

        // Safari uses a different binary format, we'll skip for now
        logger.log("Safari uses binary cookie format (not yet supported)", level: .debug)
        return nil
    }

    // MARK: - SQLite extraction

    private func extractFromCookieDatabase(at path: URL, source: String) -> ExtractedCredentials? {
        // Create a temporary copy to avoid locking issues
        let tempPath = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        do {
            try FileManager.default.copyItem(at: path, to: tempPath)
            defer { try? FileManager.default.removeItem(at: tempPath) }

            var db: OpaquePointer?

            guard sqlite3_open(tempPath.path, &db) == SQLITE_OK else {
                logger.log("Failed to open database: \(String(cString: sqlite3_errmsg(db)))", level: .error)
                sqlite3_close(db)
                return nil
            }

            defer { sqlite3_close(db) }

            // Extract sessionKey
            let sessionKey = extractCookie(db: db, name: "sessionKey", domain: ".claude.ai")

            // Extract organization ID from lastActiveOrg
            let orgId = extractCookie(db: db, name: "lastActiveOrg", domain: ".claude.ai")

            if let sessionKey = sessionKey {
                logger.log("Found sessionKey in \(source)", level: .info)
                logger.log("SessionKey preview: \(String(sessionKey.prefix(20)))...", level: .debug)
            }

            if let orgId = orgId {
                logger.log("Found organizationId in \(source): \(orgId)", level: .info)
            }

            if sessionKey != nil || orgId != nil {
                return ExtractedCredentials(
                    organizationId: orgId,
                    sessionKey: sessionKey,
                    source: source
                )
            }

        } catch {
            logger.log("Error copying database: \(error.localizedDescription)", level: .error)
        }

        return nil
    }

    private func extractCookie(db: OpaquePointer?, name: String, domain: String) -> String? {
        let query = """
        SELECT value, encrypted_value FROM cookies
        WHERE name = ? AND (host_key = ? OR host_key = ?)
        ORDER BY creation_utc DESC LIMIT 1
        """

        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            logger.log("Failed to prepare statement for \(name)", level: .error)
            return nil
        }

        defer { sqlite3_finalize(statement) }

        // Bind parameters
        sqlite3_bind_text(statement, 1, name, -1, nil)
        sqlite3_bind_text(statement, 2, domain, -1, nil)
        sqlite3_bind_text(statement, 3, "claude.ai", -1, nil)

        if sqlite3_step(statement) == SQLITE_ROW {
            // Try plain text value first
            if let valuePtr = sqlite3_column_text(statement, 0) {
                let value = String(cString: valuePtr)
                if !value.isEmpty {
                    return value
                }
            }

            // Try encrypted value (Chrome/Brave on macOS)
            if let encryptedPtr = sqlite3_column_blob(statement, 1) {
                let encryptedLength = sqlite3_column_bytes(statement, 1)
                if encryptedLength > 0 {
                    logger.log("Cookie \(name) is encrypted, attempting to decrypt", level: .debug)
                    let encryptedData = Data(bytes: encryptedPtr, count: Int(encryptedLength))

                    // Try to decrypt (Chrome v10+ encryption format)
                    if let decrypted = decryptChromeValue(encryptedData) {
                        return decrypted
                    }
                }
            }
        }

        return nil
    }

    private func decryptChromeValue(_ data: Data) -> String? {
        // Chrome v10+ uses the format: v10 + encrypted data
        // The encryption uses AES with a key stored in the Keychain

        guard data.count > 3 else { return nil }

        let prefix = data.prefix(3)
        if prefix != Data([0x76, 0x31, 0x30]) { // "v10"
            logger.log("Unexpected encryption format", level: .warning)
            return nil
        }

        // For now, we'll log that we found encrypted cookies
        // Full decryption requires accessing the Keychain which needs more complex implementation
        logger.log("Found encrypted cookie (Chrome v10 format). Decryption not yet implemented.", level: .warning)
        logger.log("Please use manual credential entry for now.", level: .info)

        return nil
    }
}
