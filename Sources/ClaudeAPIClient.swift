import Foundation

class ClaudeAPIClient {
    private let settings: ClaudeSettings

    init(settings: ClaudeSettings) {
        self.settings = settings
    }

    func fetchUsage() async throws -> UsageResponse {
        let urlString = "https://claude.ai/api/organizations/\(settings.organizationId)/usage"
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("*/*", forHTTPHeaderField: "accept")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("sessionKey=\(settings.sessionKey)", forHTTPHeaderField: "Cookie")
        request.setValue("web_claude_ai", forHTTPHeaderField: "anthropic-client-platform")
        request.setValue("1.0.0", forHTTPHeaderField: "anthropic-client-version")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(UsageResponse.self, from: data)
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
