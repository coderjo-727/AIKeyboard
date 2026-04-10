import Testing
@testable import AIKeyboardCore

@Test
func rendersReplacementForWordChange() {
    let diff = DiffRenderer.render(
        original: "I has a apple.",
        corrected: "I have an apple."
    )
    let hasReplacement = diff.contains { segment in
        segment.kind == .replacement &&
        segment.original == "has" &&
        segment.replacement == "have"
    }
    let articleReplacement = diff.contains { segment in
        segment.kind == .replacement &&
        segment.original == "a" &&
        segment.replacement == "an"
    }

    #expect(hasReplacement)
    #expect(articleReplacement)
}

@Test
func rendersInsertionForMissingPunctuation() {
    let diff = DiffRenderer.render(
        original: "See you soon",
        corrected: "See you soon."
    )

    #expect(diff.last?.kind == .insertion)
    #expect(diff.last?.replacement == ".")
}

@Test
func mergesAdjacentDeletesAndInsertsIntoSingleReplacement() {
    let diff = DiffRenderer.render(
        original: "teh keyboard",
        corrected: "the keyboard"
    )

    let replacements = diff.filter { $0.kind == .replacement }
    #expect(replacements.count == 1)
    #expect(replacements[0].original == "teh")
    #expect(replacements[0].replacement == "the")
}
