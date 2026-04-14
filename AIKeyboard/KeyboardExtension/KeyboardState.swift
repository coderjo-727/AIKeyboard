import Foundation

struct KeyboardState: Equatable {
    enum InputMode: Equatable {
        case alphabetic
        case numericSymbols
    }

    enum ShiftState: Equatable {
        case lowered
        case raised
        case capsLocked
    }

    private(set) var inputMode: InputMode = .alphabetic
    private(set) var shiftState: ShiftState = .lowered

    var isUppercased: Bool {
        shiftState != .lowered
    }

    mutating func handleTap(for role: KeyboardLayout.Key.Role) {
        switch role {
        case .shift:
            toggleShift()
        case .modeChange:
            toggleInputMode()
        case .input(let value):
            if isSentenceEndingPunctuation(value) {
                shiftState = .raised
            } else if inputMode == .alphabetic, value.rangeOfCharacter(from: .letters) != nil, shiftState == .raised {
                shiftState = .lowered
            }
        case .space, .return, .backspace, .keyboardSwitch:
            break
        }
    }

    mutating func syncWithDocumentContext(beforeInput: String) {
        guard shouldRaiseAfterSentenceBoundary(beforeInput: beforeInput) else {
            return
        }

        shiftState = .raised
    }

    func transformedText(_ text: String) -> String {
        guard inputMode == .alphabetic else {
            return text
        }

        return isUppercased ? text.uppercased() : text.lowercased()
    }

    private mutating func toggleShift() {
        guard inputMode == .alphabetic else {
            return
        }

        switch shiftState {
        case .lowered:
            shiftState = .raised
        case .raised:
            shiftState = .capsLocked
        case .capsLocked:
            shiftState = .lowered
        }
    }

    private mutating func toggleInputMode() {
        switch inputMode {
        case .alphabetic:
            inputMode = .numericSymbols
            shiftState = .lowered
        case .numericSymbols:
            inputMode = .alphabetic
        }
    }

    private func isSentenceEndingPunctuation(_ value: String) -> Bool {
        [".", "!", "?"].contains(value)
    }

    private func shouldRaiseAfterSentenceBoundary(beforeInput: String) -> Bool {
        let trimmed = beforeInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.last else {
            return false
        }

        return ".!?".contains(last)
    }
}
