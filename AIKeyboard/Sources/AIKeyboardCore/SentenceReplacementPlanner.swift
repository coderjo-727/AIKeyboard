public struct SentenceReplacementPlan: Sendable, Equatable {
    public let deletionCount: Int
    public let insertionText: String

    public init(deletionCount: Int, insertionText: String) {
        self.deletionCount = deletionCount
        self.insertionText = insertionText
    }
}

public enum SentenceReplacementPlanner {
    public static func plan(for analysis: CorrectionAnalysis?) -> SentenceReplacementPlan? {
        guard
            let analysis,
            let suggestion = analysis.suggestion
        else {
            return nil
        }

        let sentence = analysis.activeSentence.text
        let cursorOffset = analysis.activeSentence.cursorOffset
        guard cursorOffset >= 0, cursorOffset <= sentence.count else {
            return nil
        }

        let preservedSuffix = String(sentence.dropFirst(cursorOffset))
        guard suggestion.corrected.hasSuffix(preservedSuffix) else {
            return nil
        }

        let insertionText: String
        if preservedSuffix.isEmpty {
            insertionText = suggestion.corrected
        } else {
            let endIndex = suggestion.corrected.index(
                suggestion.corrected.endIndex,
                offsetBy: -preservedSuffix.count
            )
            insertionText = String(suggestion.corrected[..<endIndex])
        }

        return SentenceReplacementPlan(
            deletionCount: cursorOffset,
            insertionText: insertionText
        )
    }
}
