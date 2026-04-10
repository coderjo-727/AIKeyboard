import Foundation

public struct CorrectionAnalysis: Sendable, Equatable {
    public let activeSentence: ActiveSentence
    public let suggestion: CorrectionSuggestion?
    public let diff: [DiffSegment]

    public init(
        activeSentence: ActiveSentence,
        suggestion: CorrectionSuggestion?,
        diff: [DiffSegment]
    ) {
        self.activeSentence = activeSentence
        self.suggestion = suggestion
        self.diff = diff
    }
}

public enum SimpleCorrectionEngine {
    public static func analyze(context: TextContext) -> CorrectionAnalysis {
        let activeSentence = SentenceExtractor.extractActiveSentence(from: context)
        let shouldAddTerminalPunctuation = contextSupportsTerminalPunctuation(
            context: context,
            activeSentence: activeSentence
        )
        let rawSuggestion = suggestCorrection(
            for: activeSentence.text,
            shouldAddTerminalPunctuation: shouldAddTerminalPunctuation
        )
        let suggestion = shouldSurfaceSuggestion(
            rawSuggestion,
            context: context,
            activeSentence: activeSentence
        ) ? rawSuggestion : nil
        let diff = suggestion.map {
            DiffRenderer.render(original: $0.original, corrected: $0.corrected)
        } ?? []

        return CorrectionAnalysis(
            activeSentence: activeSentence,
            suggestion: suggestion,
            diff: diff
        )
    }

    public static func suggestCorrection(for sentence: String) -> CorrectionSuggestion? {
        suggestCorrection(for: sentence, shouldAddTerminalPunctuation: true)
    }

    private static func suggestCorrection(
        for sentence: String,
        shouldAddTerminalPunctuation: Bool
    ) -> CorrectionSuggestion? {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let corrected = applyRules(
            to: trimmed,
            shouldAddTerminalPunctuation: shouldAddTerminalPunctuation
        )
        let suggestion = CorrectionSuggestion(
            original: trimmed,
            corrected: corrected,
            confidence: confidenceScore(original: trimmed, corrected: corrected)
        )

        guard CorrectionGuard.isEligible(suggestion: suggestion) else {
            return nil
        }

        return suggestion
    }

    private static func applyRules(
        to sentence: String,
        shouldAddTerminalPunctuation: Bool
    ) -> String {
        var corrected = sentence
        var madeMeaningfulChange = false

        let replacements: [(pattern: String, replacement: String)] = [
            (#"\bteh\b"#, "the"),
            (#"\bi has\b"#, "I have"),
            (#"\bi am\b"#, "I am"),
            (#"\bi\b"#, "I"),
            (#"\ba apple\b"#, "an apple"),
            (#"\bu\b"#, "you"),
            (#"\bur\b"#, "your"),
            (#"\bdont\b"#, "don't"),
            (#"\bcant\b"#, "can't"),
        ]

        for rule in replacements {
            let next = replacingMatches(
                in: corrected,
                pattern: rule.pattern,
                replacement: rule.replacement
            )
            if next != corrected {
                madeMeaningfulChange = true
            }
            corrected = next
        }

        corrected = collapseRepeatedSpaces(in: corrected)

        guard madeMeaningfulChange else {
            return sentence
        }

        corrected = uppercaseSentenceStart(in: corrected)
        if shouldAddTerminalPunctuation {
            corrected = ensureSentencePunctuation(in: corrected)
        }

        return corrected
    }

    private static func shouldSurfaceSuggestion(
        _ suggestion: CorrectionSuggestion?,
        context: TextContext,
        activeSentence: ActiveSentence
    ) -> Bool {
        guard suggestion != nil else {
            return false
        }

        let wordCount = activeSentence.text.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).count
        guard wordCount >= 2 else {
            return false
        }

        return !isCursorInsideWord(context: context)
    }

    private static func isCursorInsideWord(context: TextContext) -> Bool {
        guard
            let last = context.beforeInput.last,
            let first = context.afterInput.first
        else {
            return false
        }

        return last.isLetterOrNumber && first.isLetterOrNumber
    }

    private static func contextSupportsTerminalPunctuation(
        context: TextContext,
        activeSentence: ActiveSentence
    ) -> Bool {
        guard let last = activeSentence.text.last, !".!?".contains(last) else {
            return false
        }

        if let trailingFirst = activeSentence.trailingContext.first {
            return trailingFirst.isWhitespace || ".!?".contains(trailingFirst)
        }

        guard let beforeLast = context.beforeInput.last else {
            return false
        }

        return beforeLast.isWhitespace || beforeLast.isNewline
    }

    private static func replacingMatches(
        in text: String,
        pattern: String,
        replacement: String
    ) -> String {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return text
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: replacement)
    }

    private static func collapseRepeatedSpaces(in text: String) -> String {
        text.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
    }

    private static func uppercaseSentenceStart(in text: String) -> String {
        guard let first = text.first else {
            return text
        }
        return first.uppercased() + text.dropFirst()
    }

    private static func ensureSentencePunctuation(in text: String) -> String {
        guard let last = text.last, !".!?".contains(last) else {
            return text
        }
        return text + "."
    }

    private static func confidenceScore(original: String, corrected: String) -> Double {
        if original == corrected {
            return 0.0
        }

        let diff = DiffRenderer.render(original: original, corrected: corrected)
        let changedSegments = diff.filter { $0.kind != .unchanged }
        let replacementCount = changedSegments.reduce(into: 0) { count, segment in
            let touchedWords = segment.original.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).count
                + segment.replacement.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).count
            count += touchedWords > 0 ? 1 : 0
        }

        switch replacementCount {
        case 0:
            return 0.86
        case 1:
            return 0.96
        case 2:
            return 0.92
        case 3:
            return 0.88
        default:
            return 0.82
        }
    }
}

private extension Character {
    var isLetterOrNumber: Bool {
        isLetter || isNumber
    }
}
