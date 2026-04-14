import UIKit

struct KeyboardPreviewViewState {
    let caption: String
    let previewText: NSAttributedString?
    let previewFallback: String?
    let expandedBody: String
    let diffSegments: [DiffSegment]
    let canExpand: Bool
    let canApply: Bool
    let applyBlockedReason: String?

    func renderSignature(
        source: CorrectionRuntimeResult.Source,
        isExpanded: Bool
    ) -> String {
        let preview = previewText?.string ?? previewFallback ?? ""
        let diffSignature = diffSegments
            .map { "\($0.kind.rawValue):\($0.original)->\($0.replacement)" }
            .joined(separator: "|")
        return [
            caption,
            preview,
            expandedBody,
            diffSignature,
            String(canExpand),
            String(canApply),
            applyBlockedReason ?? "",
            "\(source)",
            String(isExpanded),
        ].joined(separator: "\u{1F}")
    }

    static func make(from analysis: CorrectionAnalysis?) -> KeyboardPreviewViewState {
        guard let analysis, let suggestion = analysis.suggestion else {
            return KeyboardPreviewViewState(
                caption: "Smart Preview",
                previewText: nil,
                previewFallback: "",
                expandedBody: "Typing stays untouched until the correction is conservative and clearly sentence-scoped.",
                diffSegments: [],
                canExpand: false,
                canApply: false,
                applyBlockedReason: nil
            )
        }

        let canApply = SentenceReplacementPlanner.plan(for: analysis) != nil
        return KeyboardPreviewViewState(
            caption: "Active sentence",
            previewText: makePreviewText(from: analysis.diff),
            previewFallback: nil,
            expandedBody: """
            Original
            \(analysis.activeSentence.text)

            Suggested
            \(suggestion.corrected)
            """,
            diffSegments: analysis.diff.filter { $0.kind != .unchanged },
            canExpand: true,
            canApply: canApply,
            applyBlockedReason: canApply
                ? nil
                : "Move the cursor to the end of the suggestion or after unchanged punctuation to apply safely."
        )
    }

    private static func makePreviewText(from segments: [DiffSegment]) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for segment in segments {
            switch segment.kind {
            case .unchanged:
                result.append(NSAttributedString(string: segment.replacement, attributes: [
                    .foregroundColor: UIColor.label,
                    .font: UIFont.preferredFont(forTextStyle: .subheadline),
                ]))
            case .replacement:
                result.append(NSAttributedString(string: segment.replacement, attributes: [
                    .foregroundColor: UIColor.label,
                    .font: UIFont.preferredFont(forTextStyle: .subheadline),
                    .backgroundColor: UIColor.systemGreen.withAlphaComponent(0.18),
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                    .underlineColor: UIColor(red: 0.13, green: 0.44, blue: 0.30, alpha: 1.0),
                ]))
            case .insertion:
                result.append(NSAttributedString(string: segment.replacement, attributes: [
                    .foregroundColor: UIColor.label,
                    .font: UIFont.preferredFont(forTextStyle: .subheadline),
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                    .underlineColor: UIColor(red: 0.13, green: 0.44, blue: 0.30, alpha: 1.0),
                ]))
            case .deletion:
                result.append(NSAttributedString(string: segment.original, attributes: [
                    .foregroundColor: UIColor.secondaryLabel,
                    .font: UIFont.preferredFont(forTextStyle: .subheadline),
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                ]))
            }
        }

        return result
    }
}
