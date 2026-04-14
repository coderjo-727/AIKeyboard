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

public struct RuleBasedCorrectionProvider: CorrectionProvider {
    public init() {}

    public func suggestCorrection(for request: CorrectionProviderRequest) async throws -> CorrectionSuggestion? {
        Self.localSuggestion(for: request)
    }

    public static func suggestCorrection(for sentence: String) -> CorrectionSuggestion? {
        suggestCorrection(for: sentence, shouldAddTerminalPunctuation: true)
    }

    static func localSuggestion(for request: CorrectionProviderRequest) -> CorrectionSuggestion? {
        suggestCorrection(
            for: request.sentence,
            shouldAddTerminalPunctuation: request.shouldAddTerminalPunctuation
        )
    }

    static func suggestCorrection(
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
            (#"\badn\b"#, "and"),
            (#"\brecieve\b"#, "receive"),
            (#"\brecieved\b"#, "received"),
            (#"\brecieving\b"#, "receiving"),
            (#"\bseperate\b"#, "separate"),
            (#"\bdefinately\b"#, "definitely"),
            (#"\bthier\b"#, "their"),
            (#"\boccured\b"#, "occurred"),
            (#"\buntill\b"#, "until"),
            (#"\bwierd\b"#, "weird"),
            (#"\bfreind\b"#, "friend"),
            (#"\benviroment\b"#, "environment"),
            (#"\bgoverment\b"#, "government"),
            (#"\bbecuase\b"#, "because"),
            (#"\bacheive\b"#, "achieve"),
            (#"\barguement\b"#, "argument"),
            (#"\bcalender\b"#, "calendar"),
            (#"\bconcious\b"#, "conscious"),
            (#"\bembarass\b"#, "embarrass"),
            (#"\bexistance\b"#, "existence"),
            (#"\bforiegn\b"#, "foreign"),
            (#"\bgrammer\b"#, "grammar"),
            (#"\bhappend\b"#, "happened"),
            (#"\bindependant\b"#, "independent"),
            (#"\bliason\b"#, "liaison"),
            (#"\bneccessary\b"#, "necessary"),
            (#"\brelevent\b"#, "relevant"),
            (#"\bsuccesful\b"#, "successful"),
            (#"\bsuprise\b"#, "surprise"),
            (#"\btommorow\b"#, "tomorrow"),
            (#"\badress\b"#, "address"),
            (#"\bbeleive\b"#, "believe"),
            (#"\bi has\b"#, "I have"),
            (#"\bi am\b"#, "I am"),
            (#"\bes\b"#, "is"),
            (#"\bim\b"#, "I'm"),
            (#"\bive\b"#, "I've"),
            (#"\bid\b"#, "I'd"),
            (#"\bill\b"#, "I'll"),
            (#"\bi\b"#, "I"),
            (#"\ba apple\b"#, "an apple"),
            (#"\bjym\b"#, "Jim"),
            (#"\bu\b"#, "you"),
            (#"\bur\b"#, "your"),
            (#"\bdont\b"#, "don't"),
            (#"\bcant\b"#, "can't"),
            (#"\bwont\b"#, "won't"),
            (#"\bshouldnt\b"#, "shouldn't"),
            (#"\bcouldnt\b"#, "couldn't"),
            (#"\bwouldnt\b"#, "wouldn't"),
            (#"\btheyre\b"#, "they're"),
            (#"\byoure\b"#, "you're"),
            (#"\bthats\b"#, "that's"),
            (#"\bheres\b"#, "here's"),
            (#"\bits a\b"#, "it's a"),
            (#"\bweve\b"#, "we've"),
            (#"\btheyll\b"#, "they'll"),
            (#"\ba hour\b"#, "an hour"),
            (#"\ban university\b"#, "a university"),
            (#"\bcould of\b"#, "could have"),
            (#"\bshould of\b"#, "should have"),
            (#"\bwould of\b"#, "would have"),
            (#"\bsuppose to\b"#, "supposed to"),
            (#"\buse to\b"#, "used to"),
            (#"\bthere is many\b"#, "there are many"),
            (#"\bthis are\b"#, "these are"),
            (#"\bme and him\b"#, "he and I"),
            (#"\bbetween you and I\b"#, "between you and me"),
            (#"\bmore better\b"#, "better"),
            (#"\breturn back\b"#, "return"),
            (#"\brepeat again\b"#, "repeat"),
            (#"\byour welcome\b"#, "you're welcome"),
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

public enum SimpleCorrectionEngine {
    public static func analyze(context: TextContext) -> CorrectionAnalysis {
        CorrectionPipeline.analyzeLocally(context: context)
    }

    public static func suggestCorrection(for sentence: String) -> CorrectionSuggestion? {
        RuleBasedCorrectionProvider.localSuggestion(
            for: CorrectionProviderRequest(
                sentence: sentence,
                shouldAddTerminalPunctuation: true
            )
        )
    }
}
