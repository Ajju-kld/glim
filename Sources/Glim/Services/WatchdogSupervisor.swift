import AppKit
import GlimCore
import Synchronization

/// Whether the watchdog is running and owns ⌃⌥⌘K — readable from any thread by the runner.
final class WatchdogHealth: Sendable {
    private let isAliveFlag = Mutex(false)

    var isAlive: Bool {
        isAliveFlag.withLock { $0 }
    }

    func update(isAlive: Bool) {
        isAliveFlag.withLock { $0 = isAlive }
    }
}

/// Launches the watchdog helper, listens for its signals, and checks every second that it is
/// still running. Without a ready watchdog, Glim refuses to act (spec §9.9).
@MainActor
final class WatchdogSupervisor {
    enum State: Equatable {
        case starting
        case ready
        case hotkeyFailed
        case notRunning(reason: String)
    }

    private static let helperName = "GlimWatchdog"
    private static let livenessCheckInterval: TimeInterval = 1

    let health = WatchdogHealth()
    private(set) var state = State.starting {
        didSet {
            health.update(isAlive: state == .ready)
            onStateChange?(state)
        }
    }
    var onStateChange: ((State) -> Void)?

    private let link = WatchdogLink()
    private var helperProcess: Process?
    private var observations: [WatchdogLink.Observation] = []
    private var livenessTimer: Timer?

    func start() {
        do {
            observations = [
                try link.observe(.watchdogReady) {
                    Task { @MainActor [weak self] in self?.helperReportedReady() }
                },
                try link.observe(.hotkeyFailed) {
                    Task { @MainActor [weak self] in self?.state = .hotkeyFailed }
                },
            ]
        } catch {
            state = .notRunning(reason: "Could not listen for the watchdog: \(error)")
            return
        }
        guard let helperURL = Self.helperURL() else {
            state = .notRunning(reason: "The watchdog helper is missing from the app bundle.")
            return
        }
        let process = Process()
        process.executableURL = helperURL
        process.terminationHandler = { _ in
            Task { @MainActor [weak self] in
                self?.state = .notRunning(reason: "The watchdog stopped.")
            }
        }
        do {
            try process.run()
        } catch {
            state = .notRunning(
                reason: "The watchdog could not start: \(error.localizedDescription)")
            return
        }
        helperProcess = process
        livenessTimer = Timer.scheduledTimer(
            withTimeInterval: Self.livenessCheckInterval, repeats: true
        ) { _ in
            Task { @MainActor [weak self] in self?.checkLiveness() }
        }
    }

    /// Anyone can post "ready", so it only counts while Glim's own helper process is running.
    private func helperReportedReady() {
        guard let helperProcess, helperProcess.isRunning,
            WatchdogLink.isProcessAlive(helperProcess.processIdentifier)
        else {
            return
        }
        state = .ready
    }

    private func checkLiveness() {
        guard let helperProcess, helperProcess.isRunning,
            WatchdogLink.isProcessAlive(helperProcess.processIdentifier)
        else {
            if state == .ready || state == .starting {
                state = .notRunning(reason: "The watchdog stopped.")
            }
            return
        }
    }

    /// Inside the app bundle the helper lives in `Contents/Helpers`; during development it sits
    /// next to the Glim executable in `.build`.
    private static func helperURL() -> URL? {
        let bundledHelper = Bundle.main.bundleURL
            .appending(path: "Contents/Helpers/\(helperName)", directoryHint: .notDirectory)
        if FileManager.default.isExecutableFile(atPath: bundledHelper.path(percentEncoded: false)) {
            return bundledHelper
        }
        guard let executableURL = Bundle.main.executableURL else {
            return nil
        }
        let siblingHelper = executableURL.deletingLastPathComponent()
            .appending(path: helperName, directoryHint: .notDirectory)
        return FileManager.default.isExecutableFile(
            atPath: siblingHelper.path(percentEncoded: false))
            ? siblingHelper : nil
    }
}
