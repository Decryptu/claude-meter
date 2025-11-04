import Foundation
import SQLite3
import Security
import CommonCrypto

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

        guard FileManager.default.fileExists(atPath: cookiesPath.path) else {
            return nil
        }

        return extractFromCookieDatabase(at: cookiesPath, source: "Claude Desktop")
    }

    // MARK: - Brave Browser

    private func tryExtractFromBrave() -> ExtractedCredentials? {
        let cookiesPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/BraveSoftware/Brave-Browser/Default/Cookies")

        guard FileManager.default.fileExists(atPath: cookiesPath.path) else {
            return nil
        }

        return extractFromCookieDatabase(at: cookiesPath, source: "Brave Browser")
    }

    // MARK: - Chrome

    private func tryExtractFromChrome() -> ExtractedCredentials? {
        let cookiesPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Google/Chrome/Default/Cookies")

        guard FileManager.default.fileExists(atPath: cookiesPath.path) else {
            return nil
        }

        return extractFromCookieDatabase(at: cookiesPath, source: "Google Chrome")
    }

    // MARK: - Safari

    private func tryExtractFromSafari() -> ExtractedCredentials? {
        let cookiesPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Cookies/Cookies.binarycookies")

        guard FileManager.default.fileExists(atPath: cookiesPath.path) else {
            return nil
        }

        // Safari uses a different binary format, not yet supported
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
                logger.log("Failed to open database for \(source)", level: .error)
                sqlite3_close(db)
                return nil
            }

            defer { sqlite3_close(db) }

            // List claude.ai cookies for debugging
            listAllClaudeCookies(db: db, source: source)

            // Extract sessionKey and organization ID
            let sessionKey = extractCookie(db: db, name: "sessionKey", domain: ".claude.ai", source: source)
            let orgId = extractCookie(db: db, name: "lastActiveOrg", domain: ".claude.ai", source: source)

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
            return
        }

        defer { sqlite3_finalize(statement) }

        var count = 0
        while sqlite3_step(statement) == SQLITE_ROW {
            count += 1
        }

        if count > 0 {
            logger.log("Found \(count) claude.ai cookies in \(source)", level: .debug)
        }
    }

    private func extractCookie(db: OpaquePointer?, name: String, domain: String, source: String) -> String? {
        let query = """
        SELECT value, encrypted_value FROM cookies
        WHERE name = '\(name)' AND host_key LIKE '%claude.ai%'
        ORDER BY creation_utc DESC LIMIT 1
        """

        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            logger.log("Failed to prepare statement for \(name)", level: .error)
            return nil
        }

        defer { sqlite3_finalize(statement) }

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
                    let encryptedData = Data(bytes: encryptedPtr, count: Int(encryptedLength))

                    // Try to decrypt (Chrome v10+ encryption format)
                    if let decrypted = decryptChromeValue(encryptedData, source: source) {
                        logger.log("Successfully decrypted \(name) from \(source)", level: .info)
                        return decrypted
                    } else {
                        logger.log("Failed to decrypt \(name) from \(source)", level: .warning)
                    }
                }
            }
        }

        return nil
    }

    private func decryptChromeValue(_ data: Data, source: String) -> String? {
        // Chrome v10 uses AES-128-CBC with PBKDF2 key derivation
        // Format: "v10" (3 bytes) + CBC encrypted data with PKCS7 padding
        // IV: 16 space characters (0x20)

        guard data.count > 3 else { return nil }

        let prefix = data.prefix(3)
        logger.log("Decrypting v10 format cookie from \(source)", level: .debug)

        if prefix != Data([0x76, 0x31, 0x30]) { // "v10"
            logger.log("Unexpected encryption format", level: .warning)
            return nil
        }

        // Get the encryption key from Keychain
        guard let keychainPassword = getEncryptionKey(for: source) else {
            logger.log("Could not retrieve encryption key from Keychain for \(source)", level: .warning)
            return nil
        }

        // Derive the actual encryption key using PBKDF2
        guard let derivedKey = deriveKeyWithPBKDF2(password: keychainPassword) else {
            logger.log("Failed to derive encryption key", level: .error)
            return nil
        }

        // v10 format: "v10" (3 bytes) + ciphertext (with PKCS7 padding)
        let ciphertext = data.dropFirst(3)

        guard ciphertext.count > 0 else {
            logger.log("Encrypted data too short", level: .error)
            return nil
        }

        // Decrypt using AES-128-CBC with 16 spaces as IV
        // CCCrypt with kCCOptionPKCS7Padding automatically removes padding
        let iv = Data(repeating: 0x20, count: 16) // 16 spaces

        guard let decryptedData = decryptAES128CBC(ciphertext: ciphertext, key: derivedKey, iv: iv) else {
            logger.log("CBC decryption failed for \(source)", level: .warning)
            return nil
        }

        // For newer Chrome versions (db v24+), there may be a 32-byte SHA256 prefix
        // Try with and without the prefix
        let finalData: Data
        if decryptedData.count > 32 {
            // Try with 32-byte prefix removed (newer Chrome)
            let withoutPrefix = decryptedData.dropFirst(32)
            if let decoded = String(data: withoutPrefix, encoding: .utf8), !decoded.isEmpty && decoded.utf8.allSatisfy({ $0 >= 32 || $0 == 9 || $0 == 10 || $0 == 13 }) {
                finalData = withoutPrefix
            } else {
                // No prefix, use as-is
                finalData = decryptedData
            }
        } else {
            finalData = decryptedData
        }

        if let decryptedString = String(data: finalData, encoding: .utf8) {
            logger.log("Successfully decrypted cookie from \(source)", level: .info)
            return decryptedString
        }

        return nil
    }

    private func decryptAES128CBC(ciphertext: Data, key: Data, iv: Data) -> Data? {
        var decryptedData = Data(count: ciphertext.count + kCCBlockSizeAES128)
        var numBytesDecrypted: size_t = 0

        let cryptStatus = ciphertext.withUnsafeBytes { ciphertextBytes in
            key.withUnsafeBytes { keyBytes in
                iv.withUnsafeBytes { ivBytes in
                    decryptedData.withUnsafeMutableBytes { decryptedBytes in
                        CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress, key.count,
                            ivBytes.baseAddress,
                            ciphertextBytes.baseAddress, ciphertext.count,
                            decryptedBytes.baseAddress, decryptedData.count,
                            &numBytesDecrypted
                        )
                    }
                }
            }
        }

        guard cryptStatus == kCCSuccess else {
            return nil
        }

        decryptedData.count = numBytesDecrypted
        return decryptedData
    }

    private func deriveKeyWithPBKDF2(password: Data) -> Data? {
        // Chrome on macOS uses PBKDF2 with these parameters:
        // Salt: "saltysalt" (constant)
        // Iterations: 1003
        // Key length: 16 bytes (128 bits for AES-128)

        let salt = Data("saltysalt".utf8)
        let iterations: UInt32 = 1003
        let keyLength = 16

        var derivedKey = Data(count: keyLength)

        let result = derivedKey.withUnsafeMutableBytes { derivedKeyBytes in
            password.withUnsafeBytes { passwordBytes in
                salt.withUnsafeBytes { saltBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        password.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1),
                        iterations,
                        derivedKeyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        keyLength
                    )
                }
            }
        }

        return result == kCCSuccess ? derivedKey : nil
    }

    private func getEncryptionKey(for source: String) -> Data? {
        // Determine possible service/account combinations based on the source
        let keychainQueries: [(service: String, account: String)]
        switch source {
        case "Brave Browser":
            keychainQueries = [
                ("Brave Safe Storage", "Brave"),
                ("Chromium Safe Storage", "Chromium")
            ]
        case "Google Chrome":
            keychainQueries = [
                ("Chrome Safe Storage", "Chrome"),
                ("Chromium Safe Storage", "Chromium")
            ]
        case "Claude Desktop":
            keychainQueries = [
                ("Claude Safe Storage", "Claude Key"),
                ("Chromium Safe Storage", "Chromium"),
                ("Electron Safe Storage", "Electron")
            ]
        default:
            keychainQueries = [
                ("Chrome Safe Storage", "Chrome"),
                ("Chromium Safe Storage", "Chromium")
            ]
        }

        // Try each service/account combination
        for (serviceName, accountName) in keychainQueries {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceName,
                kSecAttrAccount as String: accountName,
                kSecReturnData as String: true
            ]

            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)

            if status == errSecSuccess, let keyData = result as? Data {
                logger.log("Retrieved encryption key from Keychain (\(serviceName))", level: .debug)
                return keyData
            }
        }

        logger.log("Could not retrieve encryption key from Keychain for \(source)", level: .warning)
        return nil
    }
}
