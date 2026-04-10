public enum DiffChangeKind: String, Sendable {
    case unchanged
    case insertion
    case deletion
    case replacement
}

public struct DiffSegment: Sendable, Equatable {
    public let kind: DiffChangeKind
    public let original: String
    public let replacement: String

    public init(kind: DiffChangeKind, original: String, replacement: String) {
        self.kind = kind
        self.original = original
        self.replacement = replacement
    }
}

public enum DiffRenderer {
    public static func render(original: String, corrected: String) -> [DiffSegment] {
        let originalTokens = tokenize(original)
        let correctedTokens = tokenize(corrected)
        let operations = lcsOperations(original: originalTokens, corrected: correctedTokens)
        return coalesce(operations)
    }

    private static func tokenize(_ text: String) -> [String] {
        guard !text.isEmpty else { return [] }

        var tokens: [String] = []
        var current = ""
        var currentType: TokenType?

        for character in text {
            let type = TokenType(character: character)
            if currentType == type || currentType == nil {
                current.append(character)
                currentType = type
                continue
            }

            tokens.append(current)
            current = String(character)
            currentType = type
        }

        if !current.isEmpty {
            tokens.append(current)
        }
        return tokens
    }

    private static func lcsOperations(original: [String], corrected: [String]) -> [DiffSegment] {
        let rowCount = original.count + 1
        let columnCount = corrected.count + 1
        var dp = Array(
            repeating: Array(repeating: 0, count: columnCount),
            count: rowCount
        )

        for i in stride(from: original.count - 1, through: 0, by: -1) {
            for j in stride(from: corrected.count - 1, through: 0, by: -1) {
                if original[i] == corrected[j] {
                    dp[i][j] = dp[i + 1][j + 1] + 1
                } else {
                    dp[i][j] = max(dp[i + 1][j], dp[i][j + 1])
                }
            }
        }

        var i = 0
        var j = 0
        var segments: [DiffSegment] = []

        while i < original.count, j < corrected.count {
            if original[i] == corrected[j] {
                segments.append(
                    DiffSegment(
                        kind: .unchanged,
                        original: original[i],
                        replacement: corrected[j]
                    )
                )
                i += 1
                j += 1
            } else if dp[i + 1][j] >= dp[i][j + 1] {
                segments.append(
                    DiffSegment(
                        kind: .deletion,
                        original: original[i],
                        replacement: ""
                    )
                )
                i += 1
            } else {
                segments.append(
                    DiffSegment(
                        kind: .insertion,
                        original: "",
                        replacement: corrected[j]
                    )
                )
                j += 1
            }
        }

        while i < original.count {
            segments.append(
                DiffSegment(
                    kind: .deletion,
                    original: original[i],
                    replacement: ""
                )
            )
            i += 1
        }

        while j < corrected.count {
            segments.append(
                DiffSegment(
                    kind: .insertion,
                    original: "",
                    replacement: corrected[j]
                )
            )
            j += 1
        }

        return segments
    }

    private static func coalesce(_ segments: [DiffSegment]) -> [DiffSegment] {
        var result: [DiffSegment] = []
        var index = 0

        while index < segments.count {
            let segment = segments[index]

            if segment.kind == .deletion {
                var original = segment.original
                var replacement = ""
                var nextIndex = index + 1

                while nextIndex < segments.count, segments[nextIndex].kind == .deletion {
                    original += segments[nextIndex].original
                    nextIndex += 1
                }

                while nextIndex < segments.count, segments[nextIndex].kind == .insertion {
                    replacement += segments[nextIndex].replacement
                    nextIndex += 1
                }

                result.append(
                    DiffSegment(
                        kind: replacement.isEmpty ? .deletion : .replacement,
                        original: original,
                        replacement: replacement
                    )
                )
                index = nextIndex
                continue
            }

            if segment.kind == .insertion {
                var replacement = segment.replacement
                var nextIndex = index + 1
                while nextIndex < segments.count, segments[nextIndex].kind == .insertion {
                    replacement += segments[nextIndex].replacement
                    nextIndex += 1
                }

                result.append(
                    DiffSegment(
                        kind: .insertion,
                        original: "",
                        replacement: replacement
                    )
                )
                index = nextIndex
                continue
            }

            if let last = result.last, last.kind == .unchanged {
                result[result.count - 1] = DiffSegment(
                    kind: .unchanged,
                    original: last.original + segment.original,
                    replacement: last.replacement + segment.replacement
                )
            } else {
                result.append(segment)
            }
            index += 1
        }

        return result
    }
}

private enum TokenType: Equatable {
    case word
    case whitespace
    case punctuation

    init(character: Character) {
        if character.isWhitespace || character.isNewline {
            self = .whitespace
        } else if character.isLetter || character.isNumber || character == "'" {
            self = .word
        } else {
            self = .punctuation
        }
    }
}
