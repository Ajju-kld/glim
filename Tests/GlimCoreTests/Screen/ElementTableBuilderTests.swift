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
