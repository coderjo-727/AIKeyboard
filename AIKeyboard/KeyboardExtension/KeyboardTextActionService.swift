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
    static func handleKeyTap(
        role: KeyboardLayout.Key.Role,
        state: KeyboardState,
        using proxy: KeyboardTextDocumentProxy
    ) {
        switch role {
        case .backspace:
            proxy.deleteBackward()
        case .space:
            insertSpace(using: proxy)
        case .return:
            proxy.insertText("\n")
        case .input(let value):
            let text = state.transformedText(value)
            insert(text, using: proxy)
        case .shift, .modeChange, .keyboardSwitch:
            break
        }
    }

    @MainActor
    private static func insertSpace(using proxy: KeyboardTextDocumentProxy) {
        let beforeInput = proxy.documentContextBeforeInput ?? ""
        guard !beforeInput.isEmpty else {
            proxy.insertText(" ")
            return
        }

        if shouldApplyDoubleSpacePeriod(beforeInput: beforeInput) {
            proxy.deleteBackward()
            proxy.insertText(". ")
            return
        }

        guard beforeInput.last?.isWhitespace != true else {
            return
        }

        proxy.insertText(" ")
    }

    @MainActor
    private static func insert(_ text: String, using proxy: KeyboardTextDocumentProxy) {
        if isPunctuation(text) {
            if proxy.documentContextBeforeInput?.last?.isWhitespace == true {
                proxy.deleteBackward()
            }
            proxy.insertText(text)
            return
        }

        proxy.insertText(text)
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
}
