/// The numbered controls of one window, plus its readable text.
public struct ElementTable: Sendable, Equatable {
    /// Controls the model may choose from, numbered from 1.
    public let elements: [UIElementSnapshot]
    /// Maps each element number to the reader's live handle.
    public let handleIndexByElementNumber: [Int: Int]
    /// Visible text in reading order, for answering questions only.
    public let readableText: String
    /// Whether controls were left out because the list hit its limit.
    public let wasTruncated: Bool

    /// Creates a table.
    public init(
        elements: [UIElementSnapshot],
        handleIndexByElementNumber: [Int: Int],
        readableText: String,
        wasTruncated: Bool
    ) {
        self.elements = elements
        self.handleIndexByElementNumber = handleIndexByElementNumber
        self.readableText = readableText
        self.wasTruncated = wasTruncated
    }

    /// Whether the window is too thin in text for a text-only answer (spec §10).
    public var needsScreenshotToAnswerQuestions: Bool {
        elements.count < ScreenReadingLimits.minimumLabelledElementsForTextOnly
            || readableText.count < ScreenReadingLimits.minimumReadableCharactersForTextOnly
    }
}
