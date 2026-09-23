import Testing

@testable import GlimCore

struct PillStatusTests {
    let step = ScreenedStep(
        number: 1, action: .openApp(appName: "Notes"), app: .notes, tier: .fullControl)

    @Test func voiceEventsShowListening() {
        let afterLevel = PillStatus.hidden.applying(.level(0.4))
        let afterTranscript = afterLevel.applying(.transcript("open notes"))

        #expect(afterTranscript == .listening(transcript: "open notes", level: 0.4))
    }

    @Test(arguments: [
        (TaskEvent.thinking, PillStatus.thinking),
        (.awaitingPlanApproval(ScreenedPlan(goal: "g", steps: [])), .waitingForYou),
        (
            .acting(stepNumber: 2, totalSteps: 3, summary: "Click “New Note” in Notes"),
            .acting(stepNumber: 2, totalSteps: 3, summary: "Click “New Note” in Notes")
        ),
        (.finished(.completed), .done(message: "Done")),
        (.finished(.answered("Two notes.")), .done(message: "Answered")),
        (.finished(.cancelled), .hidden),
        (
            .finished(.stopped(.humanTookOver)),
            .stopped(reason: "You took over the keyboard or mouse.")
        ),
        (.finished(.blocked(.emptyPlan, stepNumber: nil)), .stopped(reason: "Empty plan")),
        (.finished(.failed("Ollama isn't running.")), .stopped(reason: "Ollama isn't running.")),
    ])
    func taskEventsMapToPillStatus(event: TaskEvent, expectedStatus: PillStatus) {
        #expect(PillStatus.thinking.applying(event) == expectedStatus)
    }

    @Test func confirmationShowsWaitingForYou() {
        let request = ConfirmationRequest(
            step: step, appName: "Notes", elementLabel: nil, textToType: nil, reasons: [])

        #expect(
            PillStatus.acting(stepNumber: 1, totalSteps: 1, summary: "x").applying(
                .awaitingConfirmation(request)) == .waitingForYou)
    }

    @Test func onlyStoppedIsAnAlert() {
        #expect(PillStatus.stopped(reason: "x").isAlert)
        #expect(!PillStatus.done(message: "Done").isAlert)
    }
}
