import AppKit
import GlimCore
import Observation
import os

/// The single source of truth for Glim's interface. Views read it; they never hold logic.
@MainActor
@Observable
final class AppModel {
    private static let logger = Logger(subsystem: "dev.straxs.Glim", category: "AppModel")
    /// Tunable: how long "Done" stays in the pill.
    private static let doneStatusDuration = Duration.seconds(2)
    /// Tunable: how long a stop reason stays in the pill.
    private static let stoppedStatusDuration = Duration.seconds(5)

    private(set) var pillStatus = PillStatus.hidden {
        didSet { pillController?.show(pillStatus) }
    }
    private(set) var tripReason: TripReason?
    private(set) var settings = GlimSettings.safeDefaults {
        didSet { settingsBox.update(settings) }
    }
    let settingsBox = SettingsBox()
    private(set) var watchdogState = WatchdogSupervisor.State.starting
    private(set) var isTaskRunning = false
    private(set) var isListening = false
    private(set) var settingsMessage: String?
    var selectedPage = ControlPanelPage.dashboard

    let services = LiveServices()
    let watchdogSupervisor = WatchdogSupervisor()
    let narrator = SpeechNarrator()
    private(set) var decisionPresenter: DecisionPresenter?
    private var pillController: NotchPillController?
    private var controlPanelController: ControlPanelWindowController?
    private var pushToTalkHotkey: GlobalHotkey?
    private var stopResponder: WatchdogStopResponder?
    private var runningTask: Task<Void, Never>?
    private var listeningTask: Task<Void, Never>?
    private var pillResetTask: Task<Void, Never>?
    private var settingsChangeTask: Task<Void, Never>?

    var isArmed: Bool {
        tripReason == nil
    }

    /// Word lists are English, so clicking and typing need an English interface (spec §9.9).
    var isEnglishInterface: Bool {
        Locale.preferredLanguages.first?.hasPrefix("en") ?? false
    }

    var isActionModeAvailable: Bool {
        watchdogState == .ready && isEnglishInterface
    }

    var menuBarSymbolName: String {
        if !isArmed { return "exclamationmark.octagon.fill" }
        if isListening { return "waveform" }
        if isTaskRunning { return "bolt.fill" }
        return "sparkle"
    }

    // MARK: - Launch

    func start() async {
        decisionPresenter = DecisionPresenter(model: self)
        pillController = NotchPillController(model: self)
        controlPanelController = ControlPanelWindowController(model: self)
        watchKillSwitch()
        startWatchdog()
        registerPushToTalk()
        await loadSettings()
        preloadPlannerModel()
    }

    private func watchKillSwitch() {
        _ = services.killSwitch.addTripHandler { [weak self] reason in
            Task { @MainActor in self?.killSwitchTripped(reason) }
        }
        do {
            stopResponder = try WatchdogStopResponder(
                link: WatchdogLink(), killSwitch: services.killSwitch)
        } catch {
            Self.logger.error(
                "Could not listen for the watchdog's stop request: \(String(describing: error), privacy: .public)"
            )
        }
    }

    private func startWatchdog() {
        watchdogSupervisor.onStateChange = { [weak self] state in
            self?.watchdogState = state
        }
        watchdogSupervisor.start()
        watchdogState = watchdogSupervisor.state
    }

    private func registerPushToTalk() {
        let hotkey = GlobalHotkey(
            combo: .pushToTalk,
            onPress: { [weak self] in self?.beginListening() },
            onRelease: { [weak self] in self?.endListening() })
        do {
            try hotkey.register()
            pushToTalkHotkey = hotkey
        } catch {
            settingsMessage = "⌃⌥V is taken by another app. Use the menu bar's Talk button instead."
        }
    }

    private func loadSettings() async {
        do {
            let outcome = try await services.settingsStore.load()
            settings = await services.settingsStore.current
            switch outcome {
            case .resetBecauseSealInvalid:
                settingsMessage =
                    "Settings were changed outside Glim, so safe defaults were restored."
            case .resetBecauseCorrupted:
                settingsMessage = "Settings were damaged, so safe defaults were restored."
            case .loaded, .createdWithSafeDefaults:
                break
            }
        } catch {
            settings = .safeDefaults
            settingsMessage = "Could not load settings (\(error)); using safe defaults."
        }
        narrator.isMuted = settings.isNarrationMuted
    }

    // MARK: - Talking

    func toggleListeningFromMenu() {
        isListening ? endListening() : beginListening()
    }

    private func beginListening() {
        guard !isListening else { return }
        isListening = true
        narrator.stopSpeaking()
        preloadPlannerModel()
        let showsTranscript = !isTaskRunning
        listeningTask = Task { [services] in
            do throws(VoiceInputError) {
                let events = try await services.transcriber.startListening()
                for await event in events where showsTranscript {
                    self.pillStatus = self.pillStatus.applying(event)
                }
            } catch .cancelledBeforeReady {
                // The talk key was released before the microphone was ready; nothing to show.
            } catch {
                self.isListening = false
                self.showPillMessage(.stopped(reason: error.explanation))
            }
        }
    }

    private func endListening() {
        guard isListening else { return }
        isListening = false
        Task { [services] in
            let transcript: String
            do throws(VoiceInputError) {
                transcript = try await services.transcriber.stopListening()
            } catch {
                self.showPillMessage(.stopped(reason: error.explanation))
                return
            }
            self.handle(transcript: transcript)
        }
    }

    private func handle(transcript: String) {
        if isTaskRunning {
            if SpokenCommandMatcher.isStopCommand(transcript, whileTaskIsRunning: true) {
                services.killSwitch.trip(.spokenStop)
            }
            return
        }
        guard !transcript.isEmpty else {
            narrator.say("Didn't catch that.")
            pillStatus = .hidden
            return
        }
        guard isArmed else {
            showPillMessage(.stopped(reason: "Glim is stopped. Click Re-arm first."))
            return
        }
        startTask(transcript: transcript)
    }

    /// Loads the planner model while the person is still talking. A model Ollama has unloaded
    /// takes 10+ seconds to load, which would otherwise all be spent after they finish.
    private func preloadPlannerModel() {
        let client = OllamaClient(
            transport: PolicyEnforcingTransport(
                base: services.transport, policy: NetworkPolicy(isJevEnabled: false)),
            modelName: settings.plannerModelName)
        Task {
            do throws(LanguageModelError) {
                try await client.loadModel()
            } catch {
                // Planning reports the same problem to the person with its fix.
                Self.logger.error(
                    "Could not preload the planner model: \(error.explanation, privacy: .public)")
            }
        }
    }

    // MARK: - Tasks

    private func startTask(transcript: String) {
        guard let decisionPresenter else { return }
        let runner = RunnerFactory.makeRunner(
            settings: settings, settingsBox: settingsBox,
            isActionModeAllowed: isActionModeAvailable,
            services: services,
            decisions: decisionPresenter, narrator: narrator,
            watchdogHealth: watchdogSupervisor.health)
        let (events, eventContinuation) = AsyncStream<TaskEvent>.makeStream()
        isTaskRunning = true
        pillResetTask?.cancel()
        runningTask = Task {
            async let outcome = runner.run(transcript: transcript) { event in
                eventContinuation.yield(event)
            }
            for await event in events {
                self.pillStatus = self.pillStatus.applying(event)
                if case .finished = event { break }
            }
            self.taskFinished(await outcome)
            eventContinuation.finish()
        }
    }

    private func taskFinished(_ outcome: TaskOutcome) {
        isTaskRunning = false
        runningTask = nil
        switch outcome {
        case .blocked(let violation, let stepNumber):
            decisionPresenter?.showGuardPopup(
                title: violation.title, explanation: violation.explanation, stepNumber: stepNumber)
        case .failed(let message):
            decisionPresenter?.showGuardPopup(
                title: "Glim couldn't finish", explanation: message, stepNumber: nil)
        case .stopped, .completed, .answered, .cancelled:
            break
        }
        schedulePillReset()
    }

    // MARK: - Kill switch

    func stopEverything() {
        services.killSwitch.trip(.stopButton)
    }

    func rearm() {
        services.killSwitch.rearm()
        tripReason = nil
        pillStatus = .hidden
        Task { [services] in
            do {
                try await services.auditLog.append(
                    .killSwitchRearmed, summary: "The person re-armed Glim.")
            } catch {
                Self.logger.error(
                    "Could not audit re-arm: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func killSwitchTripped(_ reason: TripReason) {
        tripReason = reason
        runningTask?.cancel()
        narrator.stopSpeaking()
        isListening = false
        listeningTask?.cancel()
        Task { [services] in await services.transcriber.cancelListening() }
        decisionPresenter?.dismissAll()
        decisionPresenter?.showGuardPopup(
            title: "Glim stopped", explanation: reason.explanation, stepNumber: nil)
        pillStatus = .stopped(reason: reason.explanation)
        Task { [services] in
            do {
                try await services.auditLog.append(.killSwitchTripped, summary: reason.explanation)
            } catch {
                Self.logger.error(
                    "Could not audit the kill switch: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    // MARK: - Settings

    /// Applies `change` to the latest settings, one change at a time, so quick clicks (or a
    /// pending Touch ID prompt) can't overwrite each other. Loosening changes ask for Touch ID.
    func changeSettings(_ change: @escaping @MainActor (inout GlimSettings) -> Void) {
        let previousChange = settingsChangeTask
        settingsChangeTask = Task {
            await previousChange?.value
            var newSettings = self.settings
            change(&newSettings)
            await self.apply(newSettings)
        }
    }

    func resetToSafeDefaults() {
        let previousChange = settingsChangeTask
        settingsChangeTask = Task {
            await previousChange?.value
            do {
                try await self.services.settingsStore.resetToSafeDefaults()
                self.settings = await self.services.settingsStore.current
                self.settingsMessage = "Safe defaults restored."
            } catch {
                self.settingsMessage = "Not reset: \(error)"
            }
        }
    }

    private func apply(_ newSettings: GlimSettings) async {
        do {
            try await services.settingsStore.update(to: newSettings)
            settings = await services.settingsStore.current
            narrator.isMuted = settings.isNarrationMuted
            settingsMessage = nil
        } catch .ownerNotConfirmed {
            settingsMessage = "Not changed: loosening safety needs Touch ID or your password."
        } catch .plannerModelNotLocal(let modelName) {
            settingsMessage = "Not changed: \(modelName) is not a local model."
        } catch {
            settingsMessage = "Not changed: \(error)"
        }
    }

    // MARK: - Windows

    func openControlPanel(on page: ControlPanelPage? = nil) {
        if let page {
            selectedPage = page
        }
        controlPanelController?.show()
    }

    private func showPillMessage(_ status: PillStatus) {
        pillStatus = status
        schedulePillReset()
    }

    private func schedulePillReset() {
        let delay = pillStatus.isAlert ? Self.stoppedStatusDuration : Self.doneStatusDuration
        pillResetTask?.cancel()
        pillResetTask = Task {
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }
            if !self.isTaskRunning, !self.isListening, self.isArmed {
                self.pillStatus = .hidden
            }
        }
    }
}
