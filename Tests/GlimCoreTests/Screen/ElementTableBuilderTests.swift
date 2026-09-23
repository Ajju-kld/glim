import Testing

@testable import GlimCore

extension AccessibilityNode {
    static func fixture(
        handleIndex: Int = 0,
        role: String,
        subrole: String? = nil,
        title: String? = nil,
        elementDescription: String? = nil,
        placeholder: String? = nil,
        value: String? = nil,
        isEnabled: Bool = true,
        width: Double = 40,
        height: Double = 20,
        children: [AccessibilityNode] = []
    ) -> AccessibilityNode {
        AccessibilityNode(
            handleIndex: handleIndex, role: role, subrole: subrole, title: title,
            elementDescription: elementDescription, placeholder: placeholder, helpText: nil,
            identifier: nil, value: value, isEnabled: isEnabled, width: width, height: height,
            children: children)
    }
}

struct ElementTableBuilderTests {
    let builder = ElementTableBuilder()

    /// The traffic-light buttons close, minimize or zoom the window; Glim never offers them.
    @Test func windowTitleBarButtonsAreLeftOut() {
        let window = AccessibilityNode.fixture(
            role: "AXWindow", title: "Spotify",
            children: [
                .fixture(
                    handleIndex: 1, role: "AXButton", subrole: "AXCloseButton", title: "close"),
                .fixture(
                    handleIndex: 2, role: "AXButton", subrole: "AXZoomButton",
                    elementDescription: "this button also has an action to zoom the window"),
                .fixture(
                    handleIndex: 3, role: "AXButton", subrole: "AXMinimizeButton", title: "min"),
                .fixture(
                    handleIndex: 4, role: "AXButton", subrole: "AXFullScreenButton", title: "full"),
                .fixture(handleIndex: 5, role: "AXButton", title: "Play"),
            ])

        #expect(builder.build(from: window).elements.map(\.label) == ["Play"])
    }

    /// A greyed-out control is never offered, but its name is kept so Glim can say why the
    /// plan's control can't be clicked (Notes' New Note in the All iCloud view).
    @Test func disabledControlsAreNamedButNotOffered() {
        let window = AccessibilityNode.fixture(
            role: "AXWindow", title: "Notes",
            children: [
                .fixture(handleIndex: 1, role: "AXButton", title: "New Note", isEnabled: false),
                .fixture(handleIndex: 2, role: "AXButton", title: "Format"),
                .fixture(
                    handleIndex: 3, role: "AXButton", subrole: "AXZoomButton", title: "zoom",
                    isEnabled: false),
            ])

        let table = builder.build(from: window)

        #expect(table.elements.map(\.label) == ["Format"])
        #expect(table.disabledControlLabels == ["New Note"])
    }

    /// Controls cut by the table limit are named, so the log shows whether the planned one
    /// was read at all.
    @Test func controlsCutByTheLimitAreNamed() {
        let buttons = (0...ScreenReadingLimits.maximumListedElements).map { index in
            AccessibilityNode.fixture(
                handleIndex: 10 + index, role: "AXButton", title: "Button \(index + 1)")
        }
        let window = AccessibilityNode.fixture(role: "AXWindow", children: buttons)

        let table = builder.build(from: window)

        #expect(
            table.leftOutControlLabels == [
                "Button \(ScreenReadingLimits.maximumListedElements + 1)"
            ])
    }

    /// Icon buttons with no name can't be offered; the read check counts them.
    @Test func unnamedButtonsAreCounted() {
        let window = AccessibilityNode.fixture(
            role: "AXWindow", title: "Notes",
            children: [
                .fixture(handleIndex: 1, role: "AXButton"),
                .fixture(handleIndex: 2, role: "AXButton"),
                .fixture(handleIndex: 3, role: "AXButton", title: "Format"),
                .fixture(handleIndex: 4, role: "AXButton", width: 0),
            ])

        #expect(builder.build(from: window).unlabelledControlCount == 2)
    }

    @Test func unnamedTextAreaIsListedAsUntitled() {
        let window = AccessibilityNode.fixture(
            role: "AXWindow", title: "Notes",
            children: [.fixture(handleIndex: 1, role: "AXTextArea")])

        let table = builder.build(from: window)

        #expect(table.elements.map(\.label) == ["Untitled text area"])
    }

    @Test func unnamedButtonIsStillLeftOut() {
        let window = AccessibilityNode.fixture(
            role: "AXWindow", title: "Notes", children: [.fixture(handleIndex: 1, role: "AXButton")]
        )

        #expect(builder.build(from: window).elements.isEmpty)
    }

    /// Notes lists its folders and every note before its toolbar. With more controls than the
    /// table holds, buttons and fields come before list rows, so New Note is still offered.
    @Test func buttonsAndFieldsAreKeptBeforeRowsWhenTheTableIsFull() {
        let rows = (0..<ScreenReadingLimits.maximumListedElements).map { index in
            AccessibilityNode.fixture(
                handleIndex: 10 + index, role: "AXRow", title: "Note \(index + 1)")
        }
        let window = AccessibilityNode.fixture(
            role: "AXWindow", title: "Notes",
            children: [
                .fixture(handleIndex: 1, role: "AXGroup", children: rows),
                .fixture(handleIndex: 2, role: "AXButton", title: "New Note"),
                .fixture(handleIndex: 3, role: "AXTextArea", elementDescription: "Note body"),
            ])

        let table = builder.build(from: window)

        #expect(table.elements.count == ScreenReadingLimits.maximumListedElements)
        #expect(table.wasTruncated)
        #expect(table.elements.map(\.label).suffix(2) == ["New Note", "Note body"])
        #expect(table.elements.map(\.number) == Array(1...table.elements.count))
        let newNote = table.elements.first { $0.label == "New Note" }
        #expect(newNote.flatMap { table.handleIndexByElementNumber[$0.number] } == 2)
    }

    @Test func actionableLabelledControlsAreNumberedInReadingOrder() {
        let window = AccessibilityNode.fixture(
            role: "AXWindow", title: "Notes",
            children: [
                .fixture(handleIndex: 1, role: "AXButton", title: "New Note"),
                .fixture(
                    handleIndex: 2, role: "AXGroup",
                    children: [
                        .fixture(
                            handleIndex: 3, role: "AXTextArea", elementDescription: "Note body")
                    ]),
                .fixture(handleIndex: 4, role: "AXStaticText", value: "Groceries"),
            ])

        let table = builder.build(from: window)

        #expect(table.elements.map(\.label) == ["New Note", "Note body"])
        #expect(table.elements.map(\.number) == [1, 2])
        #expect(table.handleIndexByElementNumber == [1: 1, 2: 3])
    }

    @Test func passwordDisabledHiddenAndUnlabelledControlsAreLeftOut() {
        let window = AccessibilityNode.fixture(
            role: "AXWindow",
            children: [
                .fixture(handleIndex: 1, role: "AXSecureTextField", title: "Password"),
                .fixture(
                    handleIndex: 2, role: "AXTextField", subrole: "AXSecureTextField", title: "PIN"),
                .fixture(handleIndex: 3, role: "AXButton", title: "Save", isEnabled: false),
                .fixture(handleIndex: 4, role: "AXButton", title: "Ghost", width: 0, height: 0),
                .fixture(handleIndex: 5, role: "AXButton"),
                .fixture(handleIndex: 6, role: "AXButton", title: "   "),
                .fixture(handleIndex: 7, role: "AXButton", title: "OK"),
            ])

        #expect(builder.build(from: window).elements.map(\.label) == ["OK"])
    }

    @Test func buttonWithoutItsOwnLabelUsesItsText() {
        let window = AccessibilityNode.fixture(
            role: "AXWindow",
            children: [
                .fixture(
                    handleIndex: 1, role: "AXButton",
                    children: [.fixture(handleIndex: 2, role: "AXStaticText", value: "Continue")])
            ])

        #expect(builder.build(from: window).elements.first?.label == "Continue")
    }

    @Test func placeholderLabelsATextField() {
        let window = AccessibilityNode.fixture(
            role: "AXWindow",
            children: [.fixture(handleIndex: 1, role: "AXTextField", placeholder: "Search")])

        #expect(builder.build(from: window).elements.first?.label == "Search")
    }

    @Test func listIsCappedAtTheElementLimit() {
        let buttons = (1...120).map {
            AccessibilityNode.fixture(handleIndex: $0, role: "AXButton", title: "Button \($0)")
        }
        let window = AccessibilityNode.fixture(role: "AXWindow", children: buttons)

        let table = builder.build(from: window)

        #expect(table.elements.count == ScreenReadingLimits.maximumListedElements)
        #expect(table.wasTruncated)
    }

    @Test func readableTextCollectsVisibleTextAndIsCapped() {
        let longText = String(repeating: "word ", count: 2_000)
        let window = AccessibilityNode.fixture(
            role: "AXWindow", title: "Mail",
            children: [
                .fixture(handleIndex: 1, role: "AXStaticText", value: "Inbox"),
                .fixture(
                    handleIndex: 2, role: "AXTextArea", elementDescription: "Body", value: longText),
            ])

        let table = builder.build(from: window)

        #expect(table.readableText.hasPrefix("Inbox\n"))
        #expect(table.readableText.count <= ScreenReadingLimits.maximumReadableTextLength)
    }

    @Test func thinScreensAskForAScreenshot() {
        let window = AccessibilityNode.fixture(
            role: "AXWindow", children: [.fixture(handleIndex: 1, role: "AXButton", title: "Play")])

        #expect(builder.build(from: window).needsScreenshotToAnswerQuestions)
    }
}
