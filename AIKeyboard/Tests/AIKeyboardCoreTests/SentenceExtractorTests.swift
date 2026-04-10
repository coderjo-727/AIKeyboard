import Testing
@testable import AIKeyboardCore

@Test
func extractsSentenceAroundCursorFromLocalContext() {
    let context = TextContext(
        beforeInput: "Hey there. i has a apple",
        afterInput: " for lunch! Want some?"
    )

    let activeSentence = SentenceExtractor.extractActiveSentence(from: context)

    #expect(activeSentence.leadingContext == "Hey there. ")
    #expect(activeSentence.text == "i has a apple for lunch!")
    #expect(activeSentence.trailingContext == " Want some?")
    #expect(activeSentence.cursorOffset == "i has a apple".count)
}

@Test
func treatsEntireVisibleTextAsSentenceWhenNoBoundaryExists() {
    let context = TextContext(
        beforeInput: "omw to the store",
        afterInput: ""
    )

    let activeSentence = SentenceExtractor.extractActiveSentence(from: context)

    #expect(activeSentence.leadingContext.isEmpty)
    #expect(activeSentence.text == "omw to the store")
    #expect(activeSentence.trailingContext.isEmpty)
}

@Test
func trimsWhitespaceAfterBoundaryIntoLeadingContext() {
    let context = TextContext(
        beforeInput: "Done.\n   fixing this now",
        afterInput: ""
    )

    let activeSentence = SentenceExtractor.extractActiveSentence(from: context)

    #expect(activeSentence.leadingContext == "Done.\n   ")
    #expect(activeSentence.text == "fixing this now")
}
