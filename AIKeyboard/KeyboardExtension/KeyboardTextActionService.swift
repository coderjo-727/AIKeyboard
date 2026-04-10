import UIKit

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
    static func makeContext(for proxy: KeyboardTextDocumentProxy) -> TextContext {
        let beforeInput = proxy.documentContextBeforeInput ?? ""
        let afterInput = proxy.documentContextAfterInput ?? ""

        if beforeInput.isEmpty && afterInput.isEmpty {
            return TextContext(beforeInput: "i has a apple", afterInput: "")
        }

        return TextContext(beforeInput: beforeInput, afterInput: afterInput)
    }

    static func canApplySuggestion(_ analysis: CorrectionAnalysis?) -> Bool {
        SentenceReplacementPlanner.plan(for: analysis) != nil
    }

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

    static func handleKeyTap(
        role: KeyboardLayout.Key.Role,
        state: KeyboardState,
        using proxy: KeyboardTextDocumentProxy
    ) {
        switch role {
        case .backspace:
            proxy.deleteBackward()
        case .space:
            proxy.insertText(" ")
        case .return:
            proxy.insertText("\n")
        case .input(let value):
            let text = state.transformedText(value)
            let prefix = needsLeadingSpace(
                before: proxy.documentContextBeforeInput,
                inserting: text
            ) ? " " : ""
            let suffix = text == "." || text == "," || text == "!" || text == "?" || text == ":" || text == ";" ? "" : " "
            proxy.insertText(prefix + text + suffix)
        case .shift, .modeChange, .keyboardSwitch:
            break
        }
    }

    private static func needsLeadingSpace(before text: String?, inserting token: String) -> Bool {
        guard token != ".", let last = text?.last else {
            return false
        }

        return !last.isWhitespace && !".!?".contains(last)
    }
}
