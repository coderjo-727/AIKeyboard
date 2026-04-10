public struct CorrectionProviderRequest: Sendable, Equatable {
    public let sentence: String
    public let shouldAddTerminalPunctuation: Bool

    public init(sentence: String, shouldAddTerminalPunctuation: Bool) {
        self.sentence = sentence
        self.shouldAddTerminalPunctuation = shouldAddTerminalPunctuation
    }
}

public protocol CorrectionProvider: Sendable {
    func suggestCorrection(for request: CorrectionProviderRequest) async throws -> CorrectionSuggestion?
}
