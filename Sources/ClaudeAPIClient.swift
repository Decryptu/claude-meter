import Foundation

class ClaudeAPIClient {
    private let settings: ClaudeSettings
    private let logger = Logger.shared

    init(settings: ClaudeSettings) {
        self.settings = settings
        logger.log("ClaudeAPIClient initialized", level: .debug)
    }

    func fetchUsage() async throws -> UsageResponse {
        let urlString = "https://claude.ai/api/organizations/\(settings.organizationId)/usage"
        guard let url = URL(string: urlString) else {
            logger.log("Invalid URL: \(urlString)", level: .error)
            throw APIError.invalidURL
        }

        logger.log("Fetching usage from: \(urlString)", level: .debug)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("*/*", forHTTPHeaderField: "accept")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("sessionKey=\(settings.sessionKey)", forHTTPHeaderField: "Cookie")
        request.setValue("web_claude_ai", forHTTPHeaderField: "anthropic-client-platform")
        request.setValue("1.0.0", forHTTPHeaderField: "anthropic-client-version")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            logger.log("Invalid response type", level: .error)
            throw APIError.invalidResponse
        }

        logger.log("API response status: \(httpResponse.statusCode)", level: .debug)

        guard httpResponse.statusCode == 200 else {
            logger.log("API error: HTTP \(httpResponse.statusCode)", level: .error)
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        let usageResponse = try decoder.decode(UsageResponse.self, from: data)
        logger.log("Successfully decoded usage response", level: .debug)

        return usageResponse
    }

    enum APIError: Error, LocalizedError {
        case invalidURL
        case invalidResponse
        case httpError(statusCode: Int)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL"
            case .invalidResponse:
                return "Invalid response from server"
            case .httpError(let statusCode):
                return "HTTP error: \(statusCode)"
            }
        }
    }
}
