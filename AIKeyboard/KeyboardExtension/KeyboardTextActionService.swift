import UIKit

@MainActor
protocol KeyboardTextDocumentProxy: AnyObject {
    var documentContextBeforeInput: String? { get }
    var documentContextAfterInput: String? { get }
    func insertText(_ text: String)
    func deleteBackward()
}

final class KeyboardTextDocumentProxyAdapter: KeyboardTextDocumentProxy {
    private let proxy: UITextDocumentProxy

    init(proxy: UITextDocumentProxy) {
        self.proxy = proxy
    }

    var documentContextBeforeInput: String? {
        proxy.documentContextBeforeInput
    }

    var documentContextAfterInput: String? {
        proxy.documentContextAfterInput
    }

    func insertText(_ text: String) {
        proxy.insertText(text)
    }

    func deleteBackward() {
        proxy.deleteBackward()
    }
}

enum KeyboardTextActionService {
    struct KeyActionResult: Equatable {
        let didMutateText: Bool
        let insertedSentenceBoundary: Bool
        let textMutationCount: Int

        static let noTextChange = KeyActionResult(
            didMutateText: false,
            insertedSentenceBoundary: false,
            textMutationCount: 0
        )

        static func textChange(
            insertedSentenceBoundary: Bool = false,
            textMutationCount: Int = 1
        ) -> KeyActionResult {
            KeyActionResult(
                didMutateText: true,
                insertedSentenceBoundary: insertedSentenceBoundary,
                textMutationCount: textMutationCount
            )
        }
    }

    @MainActor
    static func makeContext(for proxy: KeyboardTextDocumentProxy) -> TextContext {
        let beforeInput = proxy.documentContextBeforeInput ?? ""
        let afterInput = proxy.documentContextAfterInput ?? ""
        return TextContext(beforeInput: beforeInput, afterInput: afterInput)
    }

    static func canApplySuggestion(_ analysis: CorrectionAnalysis?) -> Bool {
        SentenceReplacementPlanner.plan(for: analysis) != nil
    }

    @MainActor
    static func applySuggestion(
        _ analysis: CorrectionAnalysis?,
        to proxy: KeyboardTextDocumentProxy
    ) -> Bool {
        guard let plan = SentenceReplacementPlanner.plan(for: analysis) else {
            return false
        }

        for _ in 0..<plan.deletionCount {
            proxy.deleteBackward()
        }
        proxy.insertText(plan.insertionText)
        return true
    }

    @MainActor
    @discardableResult
    static func handleKeyTap(
        role: KeyboardLayout.Key.Role,
        state: KeyboardState,
        using proxy: KeyboardTextDocumentProxy
    ) -> KeyActionResult {
        switch role {
        case .backspace:
            proxy.deleteBackward()
            return .textChange()
        case .space:
            return insertSpace(using: proxy)
        case .return:
            proxy.insertText("\n")
            return .textChange(insertedSentenceBoundary: true)
        case .input(let value):
            let text = state.transformedText(value)
            return insert(text, using: proxy)
        case .shift, .modeChange, .keyboardSwitch:
            return .noTextChange
        }
    }

    @MainActor
    private static func insertSpace(using proxy: KeyboardTextDocumentProxy) -> KeyActionResult {
        let beforeInput = proxy.documentContextBeforeInput ?? ""
        guard !beforeInput.isEmpty else {
            proxy.insertText(" ")
            return .textChange()
        }

        if shouldApplyDoubleSpacePeriod(beforeInput: beforeInput) {
            proxy.deleteBackward()
            proxy.insertText(". ")
            return .textChange(insertedSentenceBoundary: true, textMutationCount: 2)
        }

        guard beforeInput.last?.isWhitespace != true else {
            return .noTextChange
        }

        proxy.insertText(" ")
        return .textChange()
    }

    @MainActor
    private static func insert(_ text: String, using proxy: KeyboardTextDocumentProxy) -> KeyActionResult {
        if isPunctuation(text) {
            var mutationCount = 1
            if proxy.documentContextBeforeInput?.last?.isWhitespace == true {
                proxy.deleteBackward()
                mutationCount += 1
            }
            proxy.insertText(text)
            return .textChange(
                insertedSentenceBoundary: isSentenceEndingPunctuation(text),
                textMutationCount: mutationCount
            )
        }

        proxy.insertText(text)
        return .textChange()
    }

    private static func shouldApplyDoubleSpacePeriod(beforeInput: String) -> Bool {
        guard beforeInput.last == " " else {
            return false
        }

        let trimmed = beforeInput.dropLast()
        guard let previous = trimmed.last else {
            return false
        }

        return previous.isLetter || previous.isNumber
    }

    private static func isPunctuation(_ text: String) -> Bool {
        [".", ",", "!", "?", ":", ";", "'", "\""].contains(text)
    }

    private static func isSentenceEndingPunctuation(_ text: String) -> Bool {
        [".", "!", "?"].contains(text)
    }
}
