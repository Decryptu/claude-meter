import Foundation

class ClaudeAPIClient {
    private let settings: ClaudeSettings
    private let logger = Logger.shared

    init(settings: ClaudeSettings) {
        self.settings = settings
        Task { await logger.log("ClaudeAPIClient initialized", level: .debug) }
    }

    func fetchUsage() async throws -> UsageResponse {
        let urlString = "https://claude.ai/api/organizations/\(settings.organizationId)/usage"
        guard let url = URL(string: urlString) else {
            await logger.log("Invalid URL: \(urlString)", level: .error)
            throw APIError.invalidURL
        }

        await logger.log("Fetching usage from: \(urlString)", level: .debug)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("*/*", forHTTPHeaderField: "accept")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("sessionKey=\(settings.sessionKey)", forHTTPHeaderField: "Cookie")
        request.setValue("web_claude_ai", forHTTPHeaderField: "anthropic-client-platform")
        request.setValue("1.0.0", forHTTPHeaderField: "anthropic-client-version")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            await logger.log("Invalid response type", level: .error)
            throw APIError.invalidResponse
        }

        await logger.log("API response status: \(httpResponse.statusCode)", level: .debug)

        guard httpResponse.statusCode == 200 else {
            await logger.log("API error: HTTP \(httpResponse.statusCode)", level: .error)
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        let usageResponse = try decoder.decode(UsageResponse.self, from: data)
        await logger.log("Successfully decoded usage response", level: .debug)

        return usageResponse
    }

    // MARK: - Quota Period Trigger Methods

    /// Creates a new conversation to trigger quota period
    func createConversation() async throws -> String {
        let urlString = "https://claude.ai/api/organizations/\(settings.organizationId)/chat_conversations"
        guard let url = URL(string: urlString) else {
            await logger.log("Invalid URL: \(urlString)", level: .error)
            throw APIError.invalidURL
        }

        await logger.log("Creating new conversation at: \(urlString)", level: .debug)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("sessionKey=\(settings.sessionKey)", forHTTPHeaderField: "Cookie")
        request.setValue("web_claude_ai", forHTTPHeaderField: "anthropic-client-platform")
        request.setValue("1.0.0", forHTTPHeaderField: "anthropic-client-version")

        let conversationUUID = UUID().uuidString
        let payload: [String: Any] = [
            "uuid": conversationUUID,
            "name": "",
            "include_conversation_preferences": true,
            "is_temporary": true
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            await logger.log("Invalid response type", level: .error)
            throw APIError.invalidResponse
        }

        await logger.log("Create conversation response status: \(httpResponse.statusCode)", level: .debug)

        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            await logger.log("API error: HTTP \(httpResponse.statusCode)", level: .error)
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        let conversationResponse = try decoder.decode(ConversationResponse.self, from: data)
        await logger.log("Conversation created with UUID: \(conversationResponse.uuid)", level: .info)

        return conversationResponse.uuid
    }

    /// Sends a minimal message to trigger quota period and returns the new resets_at timestamp
    func sendMinimalMessage(conversationId: String) async throws -> Int {
        let urlString = "https://claude.ai/api/organizations/\(settings.organizationId)/chat_conversations/\(conversationId)/completion"
        guard let url = URL(string: urlString) else {
            await logger.log("Invalid URL: \(urlString)", level: .error)
            throw APIError.invalidURL
        }

        await logger.log("Sending minimal message (private/temporary conversation) to: \(conversationId)", level: .debug)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("sessionKey=\(settings.sessionKey)", forHTTPHeaderField: "Cookie")
        request.setValue("web_claude_ai", forHTTPHeaderField: "anthropic-client-platform")
        request.setValue("1.0.0", forHTTPHeaderField: "anthropic-client-version")

        let timezone = TimeZone.current.identifier
        let payload: [String: Any] = [
            "prompt": "1+1=?",
            "parent_message_uuid": "00000000-0000-4000-8000-000000000000",
            "timezone": timezone,
            "rendering_mode": "messages"
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        await logger.log("Sending payload with timezone: \(timezone)", level: .debug)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            await logger.log("Invalid response type", level: .error)
            throw APIError.invalidResponse
        }

        await logger.log("Send message response status: \(httpResponse.statusCode)", level: .debug)

        guard httpResponse.statusCode == 200 else {
            await logger.log("API error: HTTP \(httpResponse.statusCode)", level: .error)
            // Log response body for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                await logger.log("Response body: \(responseString.prefix(500))", level: .debug)
            }
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        // Parse SSE response to extract message_limit event
        let resetsAt = try await parseSSEResponse(data: data)
        await logger.log("Successfully extracted resets_at timestamp: \(resetsAt)", level: .info)

        return resetsAt
    }

    /// Parses SSE response to extract the resets_at timestamp from message_limit event
    private func parseSSEResponse(data: Data) async throws -> Int {
        guard let responseString = String(data: data, encoding: .utf8) else {
            await logger.log("Failed to decode SSE response", level: .error)
            throw APIError.parseError(message: "Could not decode response as UTF-8")
        }

        await logger.log("Parsing SSE response (\(responseString.count) characters)", level: .debug)

        // Split by lines and look for message_limit event
        let lines = responseString.components(separatedBy: .newlines)

        var isMessageLimitEvent = false
        for line in lines {
            if line.hasPrefix("event: message_limit") {
                isMessageLimitEvent = true
                await logger.log("Found message_limit event", level: .debug)
                continue
            }

            if isMessageLimitEvent && line.hasPrefix("data: ") {
                let jsonString = String(line.dropFirst(6)) // Remove "data: " prefix

                guard let jsonData = jsonString.data(using: .utf8) else {
                    await logger.log("Failed to convert data line to UTF-8", level: .error)
                    continue
                }

                // Log the JSON for debugging
                await logger.log("message_limit JSON: \(jsonString.prefix(200))", level: .debug)

                do {
                    let decoder = JSONDecoder()
                    let event = try decoder.decode(MessageLimitEvent.self, from: jsonData)
                    let resetsAt = event.messageLimit.windows.fiveHour.resetsAt
                    await logger.log("Parsed resets_at: \(resetsAt)", level: .debug)
                    return resetsAt
                } catch {
                    await logger.log("Failed to decode message_limit JSON: \(error)", level: .error)
                    throw APIError.parseError(message: "Could not parse message_limit event: \(error.localizedDescription)")
                }
            }
        }

        await logger.log("No message_limit event found in SSE response", level: .error)
        throw APIError.parseError(message: "message_limit event not found in response")
    }

    /// Triggers a new quota period by creating a conversation and sending a minimal message
    func triggerQuotaPeriod() async throws -> Int {
        await logger.log("Starting quota period trigger sequence", level: .info)

        // Step 1: Create conversation
        let conversationId = try await createConversation()

        // Step 2: Send minimal message
        let resetsAt = try await sendMinimalMessage(conversationId: conversationId)

        await logger.log("Quota period trigger complete. New period resets at: \(resetsAt)", level: .info)

        return resetsAt
    }

    enum APIError: Error, LocalizedError {
        case invalidURL
        case invalidResponse
        case httpError(statusCode: Int)
        case parseError(message: String)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL"
            case .invalidResponse:
                return "Invalid response from server"
            case .httpError(let statusCode):
                return "HTTP error: \(statusCode)"
            case .parseError(let message):
                return "Parse error: \(message)"
            }
        }
    }
}
