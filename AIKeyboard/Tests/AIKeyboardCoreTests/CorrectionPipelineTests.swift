import Testing
@testable import AIKeyboardCore

private struct StubCorrectionProvider: CorrectionProvider {
    let suggestion: CorrectionSuggestion?

    func suggestCorrection(for request: CorrectionProviderRequest) async throws -> CorrectionSuggestion? {
        guard let suggestion else {
            return nil
        }

        return CorrectionSuggestion(
            original: request.sentence,
            corrected: suggestion.corrected,
            confidence: suggestion.confidence
        )
    }
}

@Test
func pipelineUsesProviderSuggestionAndBuildsDiff() async throws {
    let analysis = try await CorrectionPipeline.analyze(
        context: TextContext(
            beforeInput: "Hey. i has a apple ",
            afterInput: ""
        ),
        using: StubCorrectionProvider(
            suggestion: CorrectionSuggestion(
                original: "i has a apple",
                corrected: "I have an apple.",
                confidence: 0.96
            )
        )
    )

    #expect(analysis.suggestion?.corrected == "I have an apple.")
    #expect(!analysis.diff.isEmpty)
}

@Test
func pipelineSuppressesProviderOutputWhenCursorSitsInsideWord() async throws {
    let analysis = try await CorrectionPipeline.analyze(
        context: TextContext(
            beforeInput: "i ha",
            afterInput: "s a apple"
        ),
        using: StubCorrectionProvider(
            suggestion: CorrectionSuggestion(
                original: "i has a apple",
                corrected: "I have an apple.",
                confidence: 0.96
            )
        )
    )

    #expect(analysis.suggestion == nil)
}

@Test
func runtimeUsesRemoteProviderWhenAvailable() async {
    let result = await CorrectionRuntime.analyze(
        context: TextContext(
            beforeInput: "Hey. i has a apple ",
            afterInput: ""
        ),
        remoteProvider: StubCorrectionProvider(
            suggestion: CorrectionSuggestion(
                original: "i has a apple",
                corrected: "I have an apple.",
                confidence: 0.97
            )
        ),
        fallbackProvider: StubCorrectionProvider(suggestion: nil)
    )

    #expect(result.source == .relay)
    #expect(result.analysis.suggestion?.corrected == "I have an apple.")
}

@Test
func runtimeFallsBackWhenRemoteReturnsNothing() async {
    let result = await CorrectionRuntime.analyze(
        context: TextContext(
            beforeInput: "Hey. i has a apple ",
            afterInput: ""
        ),
        remoteProvider: StubCorrectionProvider(suggestion: nil),
        fallbackProvider: StubCorrectionProvider(
            suggestion: CorrectionSuggestion(
                original: "i has a apple",
                corrected: "I have an apple.",
                confidence: 0.92
            )
        )
    )

    #expect(result.source == .localFallback)
    #expect(result.analysis.suggestion?.corrected == "I have an apple.")
}

@Test
func runtimeConfigurationLoadsRelayFromEnvironment() {
    let configuration = CorrectionRuntimeConfigurationLoader.load(
        environment: [
            "AIKEYBOARD_RELAY_ENDPOINT": "https://example.com/v1/corrections",
            "AIKEYBOARD_RELAY_TOKEN": "test-token",
        ]
    )

    #expect(configuration?.relay?.endpoint.absoluteString == "https://example.com/v1/corrections")
    #expect(configuration?.relay?.apiKey == "test-token")
}
