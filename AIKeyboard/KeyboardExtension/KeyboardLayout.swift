import Foundation

struct KeyboardLayout {
    struct Key: Equatable {
        enum Role: Equatable {
            case input(String)
            case backspace
            case shift
            case modeChange(String)
            case keyboardSwitch
            case space
            case `return`
        }

        let title: String
        let role: Role
        let widthMultiplier: Double

        init(title: String, role: Role, widthMultiplier: Double = 1.0) {
            self.title = title
            self.role = role
            self.widthMultiplier = widthMultiplier
        }
    }

    let rows: [[Key]]

    static let qwertyPrototype = KeyboardLayout(rows: [])

    func resolvedRows(for state: KeyboardState) -> [[Key]] {
        switch state.inputMode {
        case .alphabetic:
            return alphabeticRows(uppercased: state.isUppercased, shiftState: state.shiftState)
        case .numericSymbols:
            return symbolRows()
        }
    }

    private func alphabeticRows(
        uppercased: Bool,
        shiftState: KeyboardState.ShiftState
    ) -> [[Key]] {
        [
            letterRow("q w e r t y u i o p", uppercased: uppercased),
            letterRow("a s d f g h j k l", uppercased: uppercased),
            [
                Key(title: shiftTitle(for: shiftState), role: .shift, widthMultiplier: 1.35),
                key("z", uppercased: uppercased),
                key("x", uppercased: uppercased),
                key("c", uppercased: uppercased),
                key("v", uppercased: uppercased),
                key("b", uppercased: uppercased),
                key("n", uppercased: uppercased),
                key("m", uppercased: uppercased),
                Key(title: "⌫", role: .backspace, widthMultiplier: 1.35),
            ],
            [
                Key(title: "123", role: .modeChange("123")),
                Key(title: "next", role: .keyboardSwitch),
                Key(title: "space", role: .space, widthMultiplier: 6.2),
                Key(title: "return", role: .return, widthMultiplier: 1.65),
            ],
        ]
    }

    private func symbolRows() -> [[Key]] {
        [
            symbolRow("1 2 3 4 5 6 7 8 9 0"),
            symbolRow("- / : ; ( ) $ & @ \""),
            [
                Key(title: "#+=", role: .shift, widthMultiplier: 1.35),
                Key(title: ".", role: .input(".")),
                Key(title: ",", role: .input(",")),
                Key(title: "?", role: .input("?")),
                Key(title: "!", role: .input("!")),
                Key(title: "'", role: .input("'")),
                Key(title: "\"", role: .input("\"")),
                Key(title: "⌫", role: .backspace, widthMultiplier: 1.35),
            ],
            [
                Key(title: "ABC", role: .modeChange("ABC")),
                Key(title: "next", role: .keyboardSwitch),
                Key(title: "space", role: .space, widthMultiplier: 5.4),
                Key(title: ".", role: .input("."), widthMultiplier: 1.15),
                Key(title: "return", role: .return, widthMultiplier: 1.65),
            ],
        ]
    }

    private func letterRow(_ values: String, uppercased: Bool) -> [Key] {
        values.split(separator: " ").map { key(String($0), uppercased: uppercased) }
    }

    private func symbolRow(_ values: String) -> [Key] {
        values.split(separator: " ").map { Key(title: String($0), role: .input(String($0))) }
    }

    private func key(_ value: String, uppercased: Bool) -> Key {
        let display = uppercased ? value.uppercased() : value.lowercased()
        return Key(title: display, role: .input(value))
    }

    private func shiftTitle(for shiftState: KeyboardState.ShiftState) -> String {
        switch shiftState {
        case .lowered:
            return "shift.off"
        case .raised:
            return "shift.on"
        case .capsLocked:
            return "caps.on"
        }
    }
}
