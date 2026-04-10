import Foundation

public struct RelayCorrectionProvider: CorrectionProvider {
    public struct Configuration: Sendable, Equatable {
        public let endpoint: URL
        public let apiKey: String?

        public init(endpoint: URL, apiKey: String? = nil) {
            self.endpoint = endpoint
            self.apiKey = apiKey
        }
    }

    private let configuration: Configuration

    public init(configuration: Configuration) {
        self.configuration = configuration
    }

    public func suggestCorrection(for request: CorrectionProviderRequest) async throws -> CorrectionSuggestion? {
        var urlRequest = URLRequest(url: configuration.endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let apiKey = configuration.apiKey, !apiKey.isEmpty {
            urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let payload = RelayRequest(
            sentence: request.sentence,
            shouldAddTerminalPunctuation: request.shouldAddTerminalPunctuation
        )
        urlRequest.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RelayCorrectionProviderError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw RelayCorrectionProviderError.requestFailed(statusCode: httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(RelayResponse.self, from: data)
        guard let corrected = decoded.corrected?.trimmingCharacters(in: .whitespacesAndNewlines),
              !corrected.isEmpty else {
            return nil
        }

        return CorrectionSuggestion(
            original: request.sentence.trimmingCharacters(in: .whitespacesAndNewlines),
            corrected: corrected,
            confidence: min(max(decoded.confidence ?? 0.9, 0), 1)
        )
    }
}

public enum RelayCorrectionProviderError: Error, Sendable {
    case invalidResponse
    case requestFailed(statusCode: Int)
}

private struct RelayRequest: Encodable {
    let sentence: String
    let shouldAddTerminalPunctuation: Bool
}

private struct RelayResponse: Decodable {
    let corrected: String?
    let confidence: Double?
}
