import Foundation
import Testing

@testable import GlimCore

/// Runs Glim's real prompts and schemas against the local Ollama. Opt-in, because it needs the
/// model installed: `GLIM_LIVE_OLLAMA=1 swift test --filter LivePlannerTests`.
@Suite(
    .serialized,
    .enabled(
        if: ProcessInfo.processInfo.environment["GLIM_LIVE_OLLAMA"] == "1", "Set GLIM_LIVE_OLLAMA=1"
    ))
struct LivePlannerTests {
    let planner = Planner(
        languageModel: OllamaClient(
            transport: PolicyEnforcingTransport(
                base: URLSessionTransport(), policy: NetworkPolicy(isJevEnabled: false)),
            modelName: ProcessInfo.processInfo.environment["GLIM_MODEL"]
                ?? GlimSettings.defaultPlannerModelName))

    let context = PlanningContext(
        goal: "open notes and write buy milk",
        frontAppName: "Finder", windowTitle: "Downloads", elementLabels: ["New Folder", "Search"],
        installedAppNames: ["Notes", "TextEdit", "Safari", "Music"], runningAppNames: ["Finder"])

    @Test func plansATaskWithTheRightApp() async throws {
        let started = ContinuousClock.now
        let result = try await planner.makePlan(for: context)
        print("LIVE plan (\(ContinuousClock.now - started)): \(result)")

        guard case .task(let plan) = result else {
            Issue.record("Expected a task, got \(result)")
            return
        }
        #expect(plan.steps.contains { $0.appName == "Notes" })
        #expect(
            plan.steps.contains {
                $0.approvedText?.localizedCaseInsensitiveContains("buy milk") == true
            })
    }

    @Test func recognizesAQuestion() async throws {
        let questionContext = PlanningContext(
            goal: "what's on my screen", frontAppName: "Notes", windowTitle: "Groceries",
            elementLabels: ["New Note", "Search"], installedAppNames: ["Notes"],
            runningAppNames: ["Notes"])

        let result = try await planner.makePlan(for: questionContext)
        print("LIVE question: \(result)")

        #expect(result == .question)
    }

    @Test func picksTheMatchingButton() async throws {
        let elements = [
            UIElementSnapshot(number: 1, role: "AXButton", label: "Delete"),
            UIElementSnapshot(number: 2, role: "AXButton", label: "New Note"),
            UIElementSnapshot(number: 3, role: "AXTextField", label: "Search"),
        ]
        let started = ContinuousClock.now
        let choice = try await planner.pickTarget(
            for: .click(appName: "Notes", target: "New Note"), goal: context.goal, among: elements)
        print("LIVE pick (\(ContinuousClock.now - started)): \(choice)")

        #expect(choice == .element(elements[1], pickedBy: .exactLabel))
    }

    @Test(arguments: [
        ("put safari on the left and minimize music", ["Safari", "Music"]),
        ("play music", ["Music"]),
        ("open textedit and type hello world", ["TextEdit"]),
    ])
    func generalizesBeyondThePromptExample(goal: String, expectedApps: [String]) async throws {
        let otherContext = PlanningContext(
            goal: goal, frontAppName: "Finder", windowTitle: "Downloads",
            elementLabels: ["New Folder"],
            installedAppNames: ["Notes", "TextEdit", "Safari", "Music"],
            runningAppNames: ["Finder", "Safari", "Music"])

        let result = try await planner.makePlan(for: otherContext)
        print("LIVE \(goal): \(result)")

        guard case .task(let plan) = result else {
            Issue.record("Expected a task for “\(goal)”, got \(result)")
            return
        }
        for appName in expectedApps {
            #expect(plan.steps.contains { $0.appName == appName }, "missing \(appName)")
        }
    }
}
