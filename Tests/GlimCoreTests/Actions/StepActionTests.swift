import Testing

@testable import GlimCore

struct StepActionTests {
    @Test func typeTextCarriesAppTargetAndApprovedText() {
        let step = StepAction.typeText(appName: "Notes", target: "note body", text: "buy milk")

        #expect(step.kind == .typeText)
        #expect(step.appName == "Notes")
        #expect(step.targetDescription == "note body")
        #expect(step.approvedText == "buy milk")
    }

    @Test func speakTouchesNoApp() {
        let step = StepAction.speak(text: "Done")

        #expect(step.kind == .speak)
        #expect(step.appName == nil)
        #expect(step.targetDescription == nil)
        #expect(step.approvedText == nil)
    }

    @Test func onlyTypeTextHasApprovedText() {
        let stepsWithoutText: [StepAction] = [
            .openApp(appName: "Notes"),
            .click(appName: "Notes", target: "New Note"),
            .pressKey(appName: "Notes", key: .tab),
            .moveWindow(appName: "Notes", preset: .leftHalf),
        ]

        #expect(stepsWithoutText.allSatisfy { $0.approvedText == nil })
    }

    @Test(arguments: [
        (StepAction.openApp(appName: "Notes"), "Open Notes"),
        (.quitApp(appName: "Slack"), "Quit Slack"),
        (.click(appName: "Notes", target: "New Note"), "Click “New Note” in Notes"),
        (
            .typeText(appName: "Notes", target: "note body", text: "buy milk"),
            "Type “buy milk” into “note body” in Notes"
        ),
        (.pressKey(appName: "Messages", key: .returnKey), "Press Return in Messages"),
        (.scroll(appName: "Safari", direction: .down), "Scroll down in Safari"),
        (.moveWindow(appName: "Safari", preset: .rightHalf), "Move Safari window: right half"),
        (.minimizeWindow(appName: "Slack"), "Minimize Slack"),
        (.restoreWindow(appName: "Slack"), "Restore Slack"),
        (.speak(text: "Done"), "Say “Done”"),
    ])
    func summaryReadsLikeAPlanLine(step: StepAction, expectedSummary: String) {
        #expect(step.summary == expectedSummary)
    }

    @Test func onlyClickAndTypeTextNeedATargetElement() {
        let kindsNeedingElements = ActionKind.allCases.filter(\.needsTargetElement)

        #expect(kindsNeedingElements == [.click, .typeText])
    }
}
