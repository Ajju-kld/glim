import Foundation
import Testing

@testable import GlimCore

/// In a web browser, the step after a click or Return must see the page that loaded, not the
/// window as it was a moment after acting.
extension TaskRunnerTests {
    static let chromeBundleIdentifier = "com.google.Chrome"
    static let chromeApp = RunningApp(
        name: "Google Chrome", bundleIdentifier: chromeBundleIdentifier, processIdentifier: 600,
        isFrontmost: true, bundleURL: URL(filePath: "/Applications/Google Chrome.app"))
    static let addressBar = UIElementSnapshot.fixture(
        number: 1, role: "AXTextField", label: "Address and search bar")
    static let firstResultLink = UIElementSnapshot.fixture(
        number: 2, role: "AXLink", label: "Harvard University")

    static let searchPageTable = ElementTable(
        elements: [addressBar], handleIndexByElementNumber: [1: 1],
        readableText: "Search Google or type a URL", wasTruncated: false)
    /// The page half-drawn: the search box is gone but no results are listed yet.
    static let loadingPageTable = ElementTable(
        elements: [addressBar], handleIndexByElementNumber: [1: 1],
        readableText: "Loading", wasTruncated: false)
    static let resultsPageTable = ElementTable(
        elements: [addressBar, firstResultLink], handleIndexByElementNumber: [1: 1, 2: 2],
        readableText: "Harvard University. Official website.", wasTruncated: false)

    static let searchThenOpenResultPlan =
        #"{"kind":"task","steps":[{"action":"pressKey","app":"Google Chrome","key":"returnKey"},"#
        + #"{"action":"click","app":"Google Chrome","target":"Harvard University"}]}"#

    static let pressReturnInChromePlan =
        #"{"kind":"task","steps":[{"action":"pressKey","app":"Google Chrome","key":"returnKey"}]}"#

    static var browserTiming: RunnerTiming {
        RunnerTiming(
            settleAfterAction: .zero, appLaunchTimeout: .milliseconds(50),
            appLaunchPollInterval: .milliseconds(5), windowWaitTimeout: .seconds(1),
            pageSettleTimeout: .seconds(1), pageSettlePollInterval: .milliseconds(1))
    }

    static var chromeFullControlPolicy: ChangingPolicy {
        var policy = testPolicy
        policy.appTrust.tiersByBundleIdentifier[chromeBundleIdentifier] = .fullControl
        return ChangingPolicy(policy)
    }

    @Test func stepAfterReturnInABrowserPicksFromTheLoadedPage() async throws {
        try await withTemporaryDirectory { directory in
            // Reads: for planning, before Return, the re-check after the person allows it,
            // right after pressing (the page half-drawn), then the results page as it settles.
            let pageLoad = [
                Self.searchPageTable, Self.searchPageTable, Self.searchPageTable,
                Self.loadingPageTable, Self.resultsPageTable, Self.resultsPageTable,
            ]
            let harness = Harness(
                model: FakeLanguageModel(answers: [.success(Self.searchThenOpenResultPlan)]),
                screenReader: ScriptedScreenReader(
                    table: Self.searchPageTable, returnTargetTexts: ["Address and search bar"],
                    tableSequence: pageLoad),
                executor: RecordingExecutor(),
                decisions: ScriptedDecisions(approvesPlans: true, confirmAnswers: [true]),
                auditLog: AuditLog(directory: directory))

            let outcome = await harness.run(
                "search and open the first result",
                runner: harness.makeRunner(
                    frontmostBundleIdentifier: Self.chromeBundleIdentifier,
                    policy: Self.chromeFullControlPolicy, timing: Self.browserTiming,
                    extraRunningApps: [Self.chromeApp]))

            #expect(outcome == .completed)
            #expect(harness.executor.performed.count == 2)
            #expect(harness.executor.performed.last?.targetElement == Self.firstResultLink)
        }
    }

    @Test func returnInTheAddressBarRunsWithoutAskingAndReturnInAPageAsks() async throws {
        for focusIsAddressBar in [true, false] {
            try await withTemporaryDirectory { directory in
                let harness = Harness(
                    model: FakeLanguageModel(answers: [.success(Self.pressReturnInChromePlan)]),
                    screenReader: ScriptedScreenReader(
                        table: Self.searchPageTable, returnTargetTexts: ["Address and search bar"],
                        focusIsBrowserAddressBar: focusIsAddressBar),
                    executor: RecordingExecutor(),
                    decisions: ScriptedDecisions(approvesPlans: true, confirmAnswers: [true]),
                    auditLog: AuditLog(directory: directory))

                let outcome = await harness.run(
                    "search",
                    runner: harness.makeRunner(
                        frontmostBundleIdentifier: Self.chromeBundleIdentifier,
                        policy: Self.chromeFullControlPolicy, timing: Self.browserTiming,
                        extraRunningApps: [Self.chromeApp]))

                #expect(outcome == .completed)
                #expect(harness.decisions.confirmationsShown.isEmpty == focusIsAddressBar)
            }
        }
    }
}
