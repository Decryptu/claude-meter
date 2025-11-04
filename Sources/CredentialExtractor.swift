import Foundation
import SQLite3
import Security
import CryptoKit

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
            logger.log("Copying database for \(source)", level: .debug)
            try FileManager.default.copyItem(at: path, to: tempPath)
            defer { try? FileManager.default.removeItem(at: tempPath) }

            var db: OpaquePointer?

            logger.log("Opening database for \(source)", level: .debug)
            guard sqlite3_open(tempPath.path, &db) == SQLITE_OK else {
                logger.log("Failed to open database: \(String(cString: sqlite3_errmsg(db)))", level: .error)
                sqlite3_close(db)
                return nil
            }

            defer { sqlite3_close(db) }
            logger.log("Database opened successfully for \(source)", level: .debug)

            // Debug: List all claude.ai cookies to understand the schema
            listAllClaudeCookies(db: db, source: source)

            // Extract sessionKey
            logger.log("Extracting sessionKey from \(source)", level: .debug)
            let sessionKey = extractCookie(db: db, name: "sessionKey", domain: ".claude.ai", source: source)

            // Extract organization ID from lastActiveOrg
            logger.log("Extracting lastActiveOrg from \(source)", level: .debug)
            let orgId = extractCookie(db: db, name: "lastActiveOrg", domain: ".claude.ai", source: source)

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
            logger.log("Error accessing database for \(source): \(error.localizedDescription)", level: .error)
        }

        logger.log("Returning nil from extractFromCookieDatabase for \(source)", level: .debug)
        return nil
    }

    private func listAllClaudeCookies(db: OpaquePointer?, source: String) {
        let query = """
        SELECT name, host_key, length(value) as value_len, length(encrypted_value) as enc_len
        FROM cookies
        WHERE host_key LIKE '%claude.ai%'
        LIMIT 20
        """

        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            logger.log("Failed to prepare debug query", level: .error)
            return
        }

        defer { sqlite3_finalize(statement) }

        logger.log("=== All claude.ai cookies in \(source) ===", level: .info)
        var count = 0
        while sqlite3_step(statement) == SQLITE_ROW {
            let name = String(cString: sqlite3_column_text(statement, 0))
            let hostKey = String(cString: sqlite3_column_text(statement, 1))
            let valueLen = sqlite3_column_int(statement, 2)
            let encLen = sqlite3_column_int(statement, 3)

            logger.log("Cookie: name='\(name)', host_key='\(hostKey)', value_len=\(valueLen), enc_len=\(encLen)", level: .info)
            count += 1
        }
        logger.log("=== Found \(count) claude.ai cookies ===", level: .info)
    }

    private func extractCookie(db: OpaquePointer?, name: String, domain: String, source: String) -> String? {
        let query = """
        SELECT value, encrypted_value FROM cookies
        WHERE name = ? AND host_key LIKE ?
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
        sqlite3_bind_text(statement, 2, "%claude.ai%", -1, nil)

        logger.log("Executing query for cookie: \(name)", level: .debug)
        let stepResult = sqlite3_step(statement)
        logger.log("Query step result: \(stepResult) (SQLITE_ROW=100, SQLITE_DONE=101)", level: .debug)

        if stepResult == SQLITE_ROW {
            logger.log("Found cookie row for \(name)", level: .debug)

            // Try plain text value first
            if let valuePtr = sqlite3_column_text(statement, 0) {
                let value = String(cString: valuePtr)
                logger.log("Plain text value length: \(value.count)", level: .debug)
                if !value.isEmpty {
                    logger.log("Using plain text value for \(name)", level: .debug)
                    return value
                }
            }

            // Try encrypted value (Chrome/Brave on macOS)
            if let encryptedPtr = sqlite3_column_blob(statement, 1) {
                let encryptedLength = sqlite3_column_bytes(statement, 1)
                logger.log("Encrypted value length: \(encryptedLength)", level: .debug)
                if encryptedLength > 0 {
                    logger.log("Cookie \(name) is encrypted, attempting to decrypt", level: .info)
                    let encryptedData = Data(bytes: encryptedPtr, count: Int(encryptedLength))

                    // Try to decrypt (Chrome v10+ encryption format)
                    if let decrypted = decryptChromeValue(encryptedData, source: source) {
                        logger.log("Successfully decrypted \(name)", level: .info)
                        return decrypted
                    } else {
                        logger.log("Failed to decrypt \(name)", level: .warning)
                    }
                }
            } else {
                logger.log("No encrypted value found for \(name)", level: .debug)
            }
        } else {
            logger.log("No cookie found for \(name)", level: .warning)
        }

        return nil
    }

    private func decryptChromeValue(_ data: Data, source: String) -> String? {
        // Chrome v10+ uses the format: v10 + nonce(12) + ciphertext + tag(16)
        // The encryption uses AES-128-GCM with a key stored in the Keychain

        guard data.count > 3 else { return nil }

        let prefix = data.prefix(3)
        if prefix != Data([0x76, 0x31, 0x30]) { // "v10"
            logger.log("Unexpected encryption format", level: .warning)
            return nil
        }

        // Get the encryption key from Keychain
        guard let key = getEncryptionKey(for: source) else {
            logger.log("Could not retrieve encryption key from Keychain for \(source)", level: .warning)
            return nil
        }

        // v10 format: "v10" (3 bytes) + nonce (12 bytes) + ciphertext + auth tag (16 bytes)
        let encryptedData = data.dropFirst(3) // Remove "v10" prefix

        guard encryptedData.count >= 28 else { // 12 (nonce) + 16 (tag) minimum
            logger.log("Encrypted data too short", level: .error)
            return nil
        }

        let nonce = encryptedData.prefix(12)
        let ciphertext = encryptedData.dropFirst(12)

        do {
            let symmetricKey = SymmetricKey(data: key)
            let sealedBox = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: nonce), ciphertext: ciphertext.dropLast(16), tag: ciphertext.suffix(16))
            let decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)

            if let decryptedString = String(data: decryptedData, encoding: .utf8) {
                logger.log("Successfully decrypted cookie", level: .debug)
                return decryptedString
            }
        } catch {
            logger.log("Decryption failed: \(error.localizedDescription)", level: .error)
        }

        return nil
    }

    private func getEncryptionKey(for source: String) -> Data? {
        // Determine the service name based on the source
        let serviceName: String
        switch source {
        case "Brave Browser":
            serviceName = "Brave Safe Storage"
        case "Google Chrome":
            serviceName = "Chrome Safe Storage"
        case "Claude Desktop":
            serviceName = "Claude Safe Storage"
        default:
            serviceName = "Chrome Safe Storage"
        }

        logger.log("Attempting to retrieve key from Keychain service: \(serviceName)", level: .debug)

        // Query the Keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: serviceName,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let keyData = result as? Data {
            logger.log("Successfully retrieved encryption key from Keychain", level: .debug)
            return keyData
        } else {
            let errorMessage = SecCopyErrorMessageString(status, nil) as String? ?? "Unknown error"
            logger.log("Failed to retrieve key from Keychain: \(errorMessage) (status: \(status))", level: .warning)
            return nil
        }
    }
}
