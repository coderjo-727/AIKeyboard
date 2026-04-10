public struct CorrectionSuggestion: Sendable, Equatable {
    public let original: String
    public let corrected: String
    public let confidence: Double

    public var fingerprint: String {
        let normalizedOriginal = original.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedCorrected = corrected.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(normalizedOriginal)->\(normalizedCorrected)"
    }

    public init(original: String, corrected: String, confidence: Double) {
        self.original = original
        self.corrected = corrected
        self.confidence = confidence
    }
}

public enum CorrectionGuard {
    public static func isEligible(
        suggestion: CorrectionSuggestion,
        minimumConfidence: Double = 0.85
    ) -> Bool {
        guard suggestion.confidence >= minimumConfidence else {
            return false
        }

        guard suggestion.original != suggestion.corrected else {
            return false
        }

        let segments = DiffRenderer.render(
            original: suggestion.original,
            corrected: suggestion.corrected
        )

        let changedSegments = segments.filter { $0.kind != .unchanged }
        guard !changedSegments.isEmpty else {
            return false
        }

        let changedWordCount = changedSegments.reduce(into: 0) { count, segment in
            count += max(
                wordCount(in: segment.original),
                wordCount(in: segment.replacement)
            )
        }

        let totalWordCount = max(
            wordCount(in: suggestion.original),
            wordCount(in: suggestion.corrected)
        )

        guard totalWordCount > 0 else {
            return false
        }

        let ratio = Double(changedWordCount) / Double(totalWordCount)
        let maximumRatio = totalWordCount <= 4 ? 0.8 : 0.6

        return ratio <= maximumRatio
    }

    private static func wordCount(in text: String) -> Int {
        text.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).count
    }
}
