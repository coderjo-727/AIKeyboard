public struct FallbackCorrectionProvider<Primary: CorrectionProvider, Fallback: CorrectionProvider>: CorrectionProvider {
    private let primary: Primary
    private let fallback: Fallback

    public init(primary: Primary, fallback: Fallback) {
        self.primary = primary
        self.fallback = fallback
    }

    public func suggestCorrection(for request: CorrectionProviderRequest) async throws -> CorrectionSuggestion? {
        do {
            if let suggestion = try await primary.suggestCorrection(for: request) {
                return suggestion
            }
        } catch {
            return try await fallback.suggestCorrection(for: request)
        }

        return try await fallback.suggestCorrection(for: request)
    }
}
