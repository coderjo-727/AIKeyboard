import Foundation

public struct OpenAICorrectionProvider: CorrectionProvider {
    public struct Configuration: Sendable, Equatable {
        public let apiKey: String
        public let model: String
        public let endpoint: URL

        public init(
            apiKey: String,
            model: String = "gpt-5.4-mini",
            endpoint: URL = URL(string: "https://api.openai.com/v1/responses")!
        ) {
            self.apiKey = apiKey
            self.model = model
            self.endpoint = endpoint
        }
    }

    private let configuration: Configuration

    public init(configuration: Configuration) {
        self.configuration = configuration
    }

    public func suggestCorrection(for request: CorrectionProviderRequest) async throws -> CorrectionSuggestion? {
        let payload = ResponseRequest(
            model: configuration.model,
            input: [
                MessageInput(
                    role: "system",
                    content: [
                        .init(
                            type: "input_text",
                            text: """
                            You are a conservative writing-correction engine for an iOS keyboard.
                            Only suggest spelling, grammar, and terminal punctuation fixes.
                            Preserve slang, tone, and phrasing whenever possible.
                            Return null when the sentence should be left unchanged.
                            """
                        ),
                    ]
                ),
                MessageInput(
                    role: "user",
                    content: [
                        .init(
                            type: "input_text",
                            text: """
                            Sentence: \(request.sentence)
                            Add terminal punctuation if context says it is complete: \(request.shouldAddTerminalPunctuation ? "yes" : "no")
                            """
                        ),
                    ]
                ),
            ],
            text: .init(
                format: .init(
                    type: "json_schema",
                    name: "correction_result",
                    strict: true,
                    schema: CorrectionSchema.schema
                )
            )
        )

        var urlRequest = URLRequest(url: configuration.endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAICorrectionProviderError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw OpenAICorrectionProviderError.requestFailed(statusCode: httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(ResponseEnvelope.self, from: data)
        guard let jsonText = decoded.outputText else {
            throw OpenAICorrectionProviderError.missingOutputText
        }

        let result = try JSONDecoder().decode(
            CorrectionResult.self,
            from: Data(jsonText.utf8)
        )

        guard let corrected = result.corrected?.trimmingCharacters(in: .whitespacesAndNewlines),
              !corrected.isEmpty else {
            return nil
        }

        return CorrectionSuggestion(
            original: request.sentence.trimmingCharacters(in: .whitespacesAndNewlines),
            corrected: corrected,
            confidence: min(max(result.confidence ?? 0.9, 0), 1)
        )
    }
}

public enum OpenAICorrectionProviderError: Error, Sendable {
    case invalidResponse
    case requestFailed(statusCode: Int)
    case missingOutputText
}

private struct ResponseRequest: Encodable {
    let model: String
    let input: [MessageInput]
    let text: TextFormatContainer
}

private struct MessageInput: Encodable {
    struct ContentItem: Encodable {
        let type: String
        let text: String
    }

    let role: String
    let content: [ContentItem]
}

private struct TextFormatContainer: Encodable {
    let format: JSONSchemaFormat
}

private struct JSONSchemaFormat: Encodable {
    let type: String
    let name: String
    let strict: Bool
    let schema: JSONValue
}

private struct ResponseEnvelope: Decodable {
    let output: [ResponseOutput]

    var outputText: String? {
        output
            .flatMap(\.content)
            .first(where: { $0.type == "output_text" })?
            .text
    }
}

private struct ResponseOutput: Decodable {
    let content: [ResponseContent]
}

private struct ResponseContent: Decodable {
    let type: String
    let text: String?
}

private struct CorrectionResult: Decodable {
    let corrected: String?
    let confidence: Double?
}

private enum CorrectionSchema {
    static let schema = JSONValue.object([
        "type": .string("object"),
        "additionalProperties": .bool(false),
        "properties": .object([
            "corrected": .object([
                "anyOf": .array([
                    .object(["type": .string("string")]),
                    .object(["type": .string("null")]),
                ]),
            ]),
            "confidence": .object([
                "type": .string("number"),
                "minimum": .number(0),
                "maximum": .number(1),
            ]),
        ]),
        "required": .array([
            .string("corrected"),
            .string("confidence"),
        ]),
    ])
}

private enum JSONValue: Encodable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        }
    }
}
