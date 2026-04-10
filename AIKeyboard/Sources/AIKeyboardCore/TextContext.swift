public struct TextContext: Sendable, Equatable {
    public let beforeInput: String
    public let afterInput: String

    public init(beforeInput: String, afterInput: String) {
        self.beforeInput = beforeInput
        self.afterInput = afterInput
    }
}

public struct ActiveSentence: Sendable, Equatable {
    public let text: String
    public let leadingContext: String
    public let trailingContext: String
    public let cursorOffset: Int

    public init(
        text: String,
        leadingContext: String,
        trailingContext: String,
        cursorOffset: Int
    ) {
        self.text = text
        self.leadingContext = leadingContext
        self.trailingContext = trailingContext
        self.cursorOffset = cursorOffset
    }
}
