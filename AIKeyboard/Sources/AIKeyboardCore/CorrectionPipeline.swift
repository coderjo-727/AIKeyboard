public enum CorrectionPipeline {
    public static let defaultProvider = RuleBasedCorrectionProvider()

    public static func analyze(
        context: TextContext,
        using provider: some CorrectionProvider = defaultProvider
    ) async throws -> CorrectionAnalysis {
        let (activeSentence, request) = makeRequest(for: context)
        let rawSuggestion = try await provider.suggestCorrection(for: request)
        return buildAnalysis(
            context: context,
            activeSentence: activeSentence,
            rawSuggestion: rawSuggestion
        )
    }

    public static func analyzeLocally(context: TextContext) -> CorrectionAnalysis {
        let (activeSentence, request) = makeRequest(for: context)
        let rawSuggestion = RuleBasedCorrectionProvider.localSuggestion(for: request)
        return buildAnalysis(
            context: context,
            activeSentence: activeSentence,
            rawSuggestion: rawSuggestion
        )
    }

    static func makeRequest(for context: TextContext) -> (ActiveSentence, CorrectionProviderRequest) {
        let activeSentence = SentenceExtractor.extractActiveSentence(from: context)
        let request = CorrectionProviderRequest(
            sentence: activeSentence.text,
            shouldAddTerminalPunctuation: contextSupportsTerminalPunctuation(
                context: context,
                activeSentence: activeSentence
            )
        )
        return (activeSentence, request)
    }

    static func buildAnalysis(
        context: TextContext,
        activeSentence: ActiveSentence,
        rawSuggestion: CorrectionSuggestion?
    ) -> CorrectionAnalysis {
        let suggestion = shouldSurfaceSuggestion(
            rawSuggestion,
            context: context,
            activeSentence: activeSentence
        ) ? rawSuggestion : nil
        let diff = suggestion.map {
            DiffRenderer.render(original: $0.original, corrected: $0.corrected)
        } ?? []

        return CorrectionAnalysis(
            activeSentence: activeSentence,
            suggestion: suggestion,
            diff: diff
        )
    }

    static func shouldSurfaceSuggestion(
        _ suggestion: CorrectionSuggestion?,
        context: TextContext,
        activeSentence: ActiveSentence
    ) -> Bool {
        guard suggestion != nil else {
            return false
        }

        let wordCount = activeSentence.text.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).count
        guard wordCount >= 2 else {
            return false
        }

        return !isCursorInsideWord(context: context)
    }

    static func isCursorInsideWord(context: TextContext) -> Bool {
        guard
            let last = context.beforeInput.last,
            let first = context.afterInput.first
        else {
            return false
        }

        return last.isLetterOrNumber && first.isLetterOrNumber
    }

    static func contextSupportsTerminalPunctuation(
        context: TextContext,
        activeSentence: ActiveSentence
    ) -> Bool {
        guard let last = activeSentence.text.last, !".!?".contains(last) else {
            return false
        }

        if let trailingFirst = activeSentence.trailingContext.first {
            return trailingFirst.isWhitespace || ".!?".contains(trailingFirst)
        }

        guard let beforeLast = context.beforeInput.last else {
            return false
        }

        return beforeLast.isWhitespace || beforeLast.isNewline
    }
}

private extension Character {
    var isLetterOrNumber: Bool {
        isLetter || isNumber
    }
}
