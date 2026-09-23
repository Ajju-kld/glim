import Foundation
import Synchronization

@testable import GlimCore

/// Returns the same table on every read; with `changesEveryRead`, the readable text changes
/// each time so the runner sees that the screen changed after an action.
final class ScriptedScreenReader: ScreenReading {
    private let currentTable: Mutex<ElementTable>
    private let changesEveryRead: Bool
    private let returnTargetTexts: [String]
    private let readCount = Mutex(0)
    private let readApps = Mutex<[String]>([])
    private let readsWithoutWindow: Int

    /// Creates a reader that returns `table`.
    ///
    /// - Parameters:
    ///   - table: The controls every read returns.
    ///   - changesEveryRead: Whether each read looks different, so actions count as changes.
    ///   - returnTargetTexts: What pressing Return would activate.
    ///   - readsWithoutWindow: How many reads report no window before one appears, as when an
    ///     app that was running with no windows is reopened.
    init(
        table: ElementTable, changesEveryRead: Bool = true, returnTargetTexts: [String] = [],
        readsWithoutWindow: Int = 0
    ) {
        currentTable = Mutex(table)
        self.changesEveryRead = changesEveryRead
        self.returnTargetTexts = returnTargetTexts
        self.readsWithoutWindow = readsWithoutWindow
    }

    /// Simulates the screen changing, for example while a panel waits for the person.
    func replaceTable(with newTable: ElementTable) {
        currentTable.withLock { $0 = newTable }
    }

    func returnKeyTargetTexts(in app: ResolvedApp) async -> [String] {
        returnTargetTexts
    }

    var appsRead: [String] {
        readApps.withLock { $0 }
    }

    func snapshotFrontWindow(of app: ResolvedApp) async throws(ScreenReadingError) -> ScreenSnapshot
    {
        readApps.withLock { $0.append(app.identity.displayName) }
        let readNumber = readCount.withLock { count in
            count += 1
            return count
        }
        guard readNumber > readsWithoutWindow else {
            throw .noWindow(appName: app.identity.displayName)
        }
        let table = currentTable.withLock { $0 }
        let readableText =
            changesEveryRead ? "\(table.readableText) read \(readNumber)" : table.readableText
        let tableForThisRead = ElementTable(
            elements: table.elements, handleIndexByElementNumber: table.handleIndexByElementNumber,
            readableText: readableText, wasTruncated: table.wasTruncated,
            disabledControlLabels: table.disabledControlLabels,
            unlabelledControlCount: table.unlabelledControlCount,
            leftOutControlLabels: table.leftOutControlLabels)
        return ScreenSnapshot(
            app: app, windowTitle: "\(app.identity.displayName) window", table: tableForThisRead)
    }
}

final class RecordingScreenshotter: ScreenshotCapturing {
    private let captureCount = Mutex(0)

    var captures: Int {
        captureCount.withLock { $0 }
    }

    func capturePNG(of app: ResolvedApp) async throws(ScreenReadingError) -> Data {
        captureCount.withLock { $0 += 1 }
        return Data([0x89, 0x50, 0x4E, 0x47])
    }
}

final class RecordingExecutor: ActionPerforming {
    private let performedActions = Mutex<[ExecutableAction]>([])
    private let killSwitchToTripOnFirstAction: KillSwitch?
    private let afterEachAction: (@Sendable () async -> Void)?

    init(
        killSwitchToTripOnFirstAction: KillSwitch? = nil,
        afterEachAction: (@Sendable () async -> Void)? = nil
    ) {
        self.killSwitchToTripOnFirstAction = killSwitchToTripOnFirstAction
        self.afterEachAction = afterEachAction
    }

    var performed: [ExecutableAction] {
        performedActions.withLock { $0 }
    }

    func perform(_ action: ExecutableAction) async throws(ExecutionError) {
        performedActions.withLock { $0.append(action) }
        killSwitchToTripOnFirstAction?.trip(.killHotkey)
        await afterEachAction?()
    }
}

final class ScriptedDecisions: PersonDecisions {
    private let approvesPlans: Bool
    private let confirmAnswers: Mutex<[Bool]>
    private let whileConfirming: (@Sendable () -> Void)?
    private let recordedPlans = Mutex<[ScreenedPlan]>([])
    private let recordedConfirmations = Mutex<[ConfirmationRequest]>([])

    init(
        approvesPlans: Bool = true, confirmAnswers: [Bool] = [],
        whileConfirming: (@Sendable () -> Void)? = nil
    ) {
        self.approvesPlans = approvesPlans
        self.confirmAnswers = Mutex(confirmAnswers)
        self.whileConfirming = whileConfirming
    }

    var plansShown: [ScreenedPlan] {
        recordedPlans.withLock { $0 }
    }

    var confirmationsShown: [ConfirmationRequest] {
        recordedConfirmations.withLock { $0 }
    }

    func approvePlan(_ plan: ScreenedPlan) async -> Bool {
        recordedPlans.withLock { $0.append(plan) }
        return approvesPlans
    }

    func confirmAction(_ request: ConfirmationRequest) async -> Bool {
        recordedConfirmations.withLock { $0.append(request) }
        whileConfirming?()
        return confirmAnswers.withLock { answers in answers.isEmpty ? false : answers.removeFirst()
        }
    }
}

final class RecordingNarrator: Narrating {
    private let spokenLines = Mutex<[String]>([])

    var lines: [String] {
        spokenLines.withLock { $0 }
    }

    func say(_ text: String) async {
        spokenLines.withLock { $0.append(text) }
    }

    func stopSpeaking() async {}
}

/// Collects every event the runner emits.
final class EventRecorder: Sendable {
    private let recordedEvents = Mutex<[TaskEvent]>([])

    var events: [TaskEvent] {
        recordedEvents.withLock { $0 }
    }

    func record(_ event: TaskEvent) {
        recordedEvents.withLock { $0.append(event) }
    }
}

/// A settings value the test can change while a task runs.
final class ChangingPolicy: Sendable {
    private let policy: Mutex<SafetyPolicy>

    init(_ initialPolicy: SafetyPolicy) {
        policy = Mutex(initialPolicy)
    }

    var current: SafetyPolicy {
        policy.withLock { $0 }
    }

    func update(_ change: (inout SafetyPolicy) -> Void) {
        policy.withLock { change(&$0) }
    }
}

/// Collects the training examples a runner hands its saver.
final class SavedExamples: Sendable {
    private let saved = Mutex<[LayaExample]>([])

    var examples: [LayaExample] { saved.withLock { $0 } }

    func append(_ example: LayaExample) {
        saved.withLock { $0.append(example) }
    }
}
