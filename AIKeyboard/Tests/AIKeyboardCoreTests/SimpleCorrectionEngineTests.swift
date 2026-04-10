import Testing
@testable import AIKeyboardCore

@Test
func suggestsConservativeFixForCommonTypos() {
    let suggestion = SimpleCorrectionEngine.suggestCorrection(for: "i has a apple")

    #expect(suggestion?.corrected == "I have an apple.")
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
