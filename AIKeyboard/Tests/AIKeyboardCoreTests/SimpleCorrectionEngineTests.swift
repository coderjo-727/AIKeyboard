import Testing
@testable import AIKeyboardCore

@Test
func suggestsConservativeFixForCommonTypos() {
    let suggestion = SimpleCorrectionEngine.suggestCorrection(for: "i has a apple")

    #expect(suggestion?.corrected == "I have an apple.")
}

@Test
func suggestsCommonSpellingAndContractionFixes() {
    let suggestion = SimpleCorrectionEngine.suggestCorrection(for: "im definately going")

    #expect(suggestion?.corrected == "I'm definitely going.")
}

@Test
func suggestsExpandedLocalTestRules() {
    let spellingSuggestion = SimpleCorrectionEngine.suggestCorrection(for: "we leave becuase")
    let phraseSuggestion = SimpleCorrectionEngine.suggestCorrection(for: "your welcome")

    #expect(spellingSuggestion?.corrected == "We leave because.")
    #expect(phraseSuggestion?.corrected == "You're welcome.")
}

@Test
func suggestsFixForPersonalIntroSmokeTest() {
    let suggestion = SimpleCorrectionEngine.suggestCorrection(for: "my name es jym")

    #expect(suggestion?.corrected == "My name is Jim.")
}

@Test
func preservesAlreadyAcceptableInformalSentence() {
    let suggestion = SimpleCorrectionEngine.suggestCorrection(for: "lol that was wild")

    #expect(suggestion == nil)
}

@Test
func analyzesContextUsingActiveSentenceWindow() {
    let analysis = SimpleCorrectionEngine.analyze(
        context: TextContext(
            beforeInput: "Hey. i has a apple",
            afterInput: ""
        )
    )

    #expect(analysis.activeSentence.text == "i has a apple")
    #expect(analysis.suggestion?.corrected == "I have an apple")
}

@Test
func addsTerminalPunctuationWhenSentenceLooksCompleteInContext() {
    let analysis = SimpleCorrectionEngine.analyze(
        context: TextContext(
            beforeInput: "Hey. i has a apple ",
            afterInput: ""
        )
    )

    #expect(analysis.suggestion?.corrected == "I have an apple.")
}

@Test
func suppressesPreviewWhenCursorSitsInsideWord() {
    let analysis = SimpleCorrectionEngine.analyze(
        context: TextContext(
            beforeInput: "i ha",
            afterInput: "s a apple"
        )
    )

    #expect(analysis.suggestion == nil)
}
