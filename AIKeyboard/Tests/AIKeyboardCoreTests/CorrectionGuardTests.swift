import Testing
@testable import AIKeyboardCore

@Test
func acceptsHighConfidenceConservativeFix() {
    let suggestion = CorrectionSuggestion(
        original: "I has a apple.",
        corrected: "I have an apple.",
        confidence: 0.94
    )

    #expect(CorrectionGuard.isEligible(suggestion: suggestion))
}

@Test
func rejectsLowConfidenceSuggestion() {
    let suggestion = CorrectionSuggestion(
        original: "I has a apple.",
        corrected: "I have an apple.",
        confidence: 0.60
    )

    #expect(!CorrectionGuard.isEligible(suggestion: suggestion))
}

@Test
func rejectsRewriteHeavySuggestion() {
    let suggestion = CorrectionSuggestion(
        original: "lol im late",
        corrected: "I am running late, sorry about that.",
        confidence: 0.99
    )

    #expect(!CorrectionGuard.isEligible(suggestion: suggestion))
}
