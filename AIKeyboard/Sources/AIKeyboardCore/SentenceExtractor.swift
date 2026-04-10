import Foundation

public enum SentenceExtractor {
    private static let sentenceTerminators = CharacterSet(charactersIn: ".!?\n")
    private static let trimAfterBoundary = CharacterSet.whitespacesAndNewlines

    public static func extractActiveSentence(from context: TextContext) -> ActiveSentence {
        let beforeScalars = Array(context.beforeInput.unicodeScalars)
        let afterScalars = Array(context.afterInput.unicodeScalars)

        let sentenceStartScalar = scalarIndexAfterLastBoundary(in: beforeScalars)
        let sentenceEndScalar = scalarIndexThroughNextBoundary(in: afterScalars)

        let leadingContext = String(String.UnicodeScalarView(beforeScalars[..<sentenceStartScalar]))
        let sentenceBeforeCursor = String(String.UnicodeScalarView(beforeScalars[sentenceStartScalar...]))
        let sentenceAfterCursor = String(String.UnicodeScalarView(afterScalars[..<sentenceEndScalar]))
        let trailingContext = String(String.UnicodeScalarView(afterScalars[sentenceEndScalar...]))

        let sentence = sentenceBeforeCursor + sentenceAfterCursor
        let normalizedLeading = trimLeadingBoundaryWhitespace(
            sentence: sentence,
            leadingContext: leadingContext
        )

        return ActiveSentence(
            text: normalizedLeading.sentence,
            leadingContext: normalizedLeading.leadingContext,
            trailingContext: trailingContext,
            cursorOffset: max(0, sentenceBeforeCursor.count - normalizedLeading.trimmedCount)
        )
    }

    private static func scalarIndexAfterLastBoundary(in scalars: [UnicodeScalar]) -> Int {
        guard let boundaryIndex = scalars.lastIndex(where: { sentenceTerminators.contains($0) }) else {
            return 0
        }

        var candidate = boundaryIndex + 1
        while candidate < scalars.count, trimAfterBoundary.contains(scalars[candidate]) {
            candidate += 1
        }
        return candidate
    }

    private static func scalarIndexThroughNextBoundary(in scalars: [UnicodeScalar]) -> Int {
        guard let boundaryIndex = scalars.firstIndex(where: { sentenceTerminators.contains($0) }) else {
            return scalars.count
        }
        return boundaryIndex + 1
    }

    private static func trimLeadingBoundaryWhitespace(
        sentence: String,
        leadingContext: String
    ) -> (sentence: String, leadingContext: String, trimmedCount: Int) {
        let trimmedSentence = sentence.drop(while: { $0.isWhitespace || $0.isNewline })
        let trimmedCount = sentence.count - trimmedSentence.count
        guard trimmedCount > 0 else {
            return (sentence, leadingContext, 0)
        }

        let movedWhitespace = String(sentence.prefix(trimmedCount))
        return (String(trimmedSentence), leadingContext + movedWhitespace, trimmedCount)
    }
}
