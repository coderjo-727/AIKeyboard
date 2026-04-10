import Testing
@testable import AIKeyboardCore

@Test
func plansFullReplacementWhenCursorIsAtSentenceEnd() {
    let analysis = CorrectionAnalysis(
        activeSentence: ActiveSentence(
            text: "i has a apple",
            leadingContext: "",
            trailingContext: "",
            cursorOffset: "i has a apple".count
        ),
        suggestion: CorrectionSuggestion(
            original: "i has a apple",
            corrected: "I have an apple.",
            confidence: 0.96
        ),
        diff: []
    )

    let plan = SentenceReplacementPlanner.plan(for: analysis)

    #expect(plan == SentenceReplacementPlan(
        deletionCount: "i has a apple".count,
        insertionText: "I have an apple."
    ))
}

@Test
func plansPrefixReplacementWhenCursorSitsBeforeUnchangedPunctuation() {
    let analysis = CorrectionAnalysis(
        activeSentence: ActiveSentence(
            text: "i has a apple.",
            leadingContext: "",
            trailingContext: "",
            cursorOffset: "i has a apple".count
        ),
        suggestion: CorrectionSuggestion(
            original: "i has a apple.",
            corrected: "I have an apple.",
            confidence: 0.96
        ),
        diff: []
    )

    let plan = SentenceReplacementPlanner.plan(for: analysis)

    #expect(plan == SentenceReplacementPlan(
        deletionCount: "i has a apple".count,
        insertionText: "I have an apple"
    ))
}

@Test
func rejectsReplacementWhenSuffixAfterCursorWouldNeedMutation() {
    let analysis = CorrectionAnalysis(
        activeSentence: ActiveSentence(
            text: "i has a apple",
            leadingContext: "",
            trailingContext: "",
            cursorOffset: 2
        ),
        suggestion: CorrectionSuggestion(
            original: "i has a apple",
            corrected: "I have an apple.",
            confidence: 0.96
        ),
        diff: []
    )

    #expect(SentenceReplacementPlanner.plan(for: analysis) == nil)
}
