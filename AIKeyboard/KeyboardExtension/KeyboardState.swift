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
            if inputMode == .alphabetic, value.rangeOfCharacter(from: .letters) != nil, shiftState == .raised {
                shiftState = .lowered
            }
        case .space, .return, .backspace, .keyboardSwitch:
            break
        }
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
}
