import AppKit

/// Performs allowed actions on the real Mac.
///
/// The kill switch is checked immediately before every operating-system call, including
/// between every chunk of typed text, and typing stops the moment focus leaves the chosen field.
public struct LiveExecutor: ActionPerforming {
    private let accessibility: AccessibilityService
    private let killSwitch: KillSwitch

    /// Creates an executor that acts through `accessibility` and obeys `killSwitch`.
    public init(accessibility: AccessibilityService, killSwitch: KillSwitch) {
        self.accessibility = accessibility
        self.killSwitch = killSwitch
    }

    /// Performs one allowed action.
    public func perform(_ action: ExecutableAction) async throws(ExecutionError) {
        try ensureArmed()
        let appName = action.app.identity.displayName
        switch action.step {
        case .openApp:
            try await openApp(action.app)
        case .speak:
            throw .unsupportedAction(.speak)
        case .switchApp, .quitApp, .click, .typeText, .pressKey, .scroll, .moveWindow,
            .minimizeWindow, .restoreWindow:
            guard let processIdentifier = action.app.processIdentifier else {
                throw .appNotRunning(appName: appName)
            }
            try await performInRunningApp(
                action, processIdentifier: processIdentifier, appName: appName)
        }
    }

    private func performInRunningApp(
        _ action: ExecutableAction, processIdentifier: pid_t, appName: String
    ) async throws(ExecutionError) {
        switch action.step {
        case .switchApp:
            try await activate(processIdentifier: processIdentifier, appName: appName)
        case .quitApp:
            try await terminate(processIdentifier: processIdentifier, appName: appName)
        case .click:
            let element = try targetElement(of: action)
            try await accessibility.press(
                elementNumber: element.number, expected: element,
                processIdentifier: processIdentifier, killSwitch: killSwitch)
        case .typeText(_, _, let text):
            try await type(
                text, into: try targetElement(of: action), processIdentifier: processIdentifier)
        case .pressKey(_, let key):
            try ensureArmed()
            try SyntheticInput.postKey(key, to: processIdentifier, killSwitch: killSwitch)
        case .scroll(_, let direction):
            try ensureArmed()
            let windowFrame = try await accessibility.focusedWindowFrame(
                processIdentifier: processIdentifier, appName: appName)
            try SyntheticInput.postScroll(
                direction, at: CGPoint(x: windowFrame.midX, y: windowFrame.midY),
                to: processIdentifier, killSwitch: killSwitch)
        case .moveWindow(_, let preset):
            try await moveWindow(of: processIdentifier, appName: appName, to: preset)
        case .minimizeWindow:
            try ensureArmed()
            try await accessibility.minimizeFocusedWindow(
                processIdentifier: processIdentifier, appName: appName, killSwitch: killSwitch)
        case .restoreWindow:
            try ensureArmed()
            try await accessibility.restoreMinimizedWindow(
                processIdentifier: processIdentifier, appName: appName, killSwitch: killSwitch)
        case .openApp, .speak:
            throw .unsupportedAction(action.step.kind)
        }
    }

    // MARK: - Apps

    private func openApp(_ app: ResolvedApp) async throws(ExecutionError) {
        if let processIdentifier = app.processIdentifier {
            try await activate(
                processIdentifier: processIdentifier, appName: app.identity.displayName)
            return
        }
        guard let bundleURL = app.bundleURL else {
            throw .appDidNotOpen(
                appName: app.identity.displayName, reason: "Its location is unknown.")
        }
        try ensureArmed()
        do {
            _ = try await NSWorkspace.shared.openApplication(
                at: bundleURL, configuration: NSWorkspace.OpenConfiguration())
        } catch {
            throw .appDidNotOpen(
                appName: app.identity.displayName, reason: error.localizedDescription)
        }
    }

    @MainActor
    private func activate(processIdentifier: pid_t, appName: String) throws(ExecutionError) {
        try ensureArmed()
        guard let application = NSRunningApplication(processIdentifier: processIdentifier),
            application.activate()
        else {
            throw .activationFailed(appName: appName)
        }
    }

    /// Asks the app to quit normally, so it can offer to save. Never force-quits.
    @MainActor
    private func terminate(processIdentifier: pid_t, appName: String) throws(ExecutionError) {
        try ensureArmed()
        guard let application = NSRunningApplication(processIdentifier: processIdentifier),
            application.terminate()
        else {
            throw .quitRefused(appName: appName)
        }
    }

    // MARK: - Typing

    private func type(
        _ text: String, into element: UIElementSnapshot, processIdentifier: pid_t
    ) async throws(ExecutionError) {
        try ensureArmed()
        try await accessibility.focusTextField(
            elementNumber: element.number, expected: element, processIdentifier: processIdentifier,
            killSwitch: killSwitch)
        let chunks = SyntheticInput.utf16Chunks(
            of: text, maximumUnitsPerChunk: SyntheticInput.maximumUnitsPerKeyEvent)
        for chunk in chunks {
            try ensureArmed()
            let focusIsOnTarget = await accessibility.focusedElementIs(
                elementNumber: element.number, processIdentifier: processIdentifier)
            guard focusIsOnTarget else {
                throw .focusNotOnTarget(label: element.label)
            }
            try SyntheticInput.postText(chunk, to: processIdentifier, killSwitch: killSwitch)
            try await pause(for: SyntheticInput.pauseBetweenChunks)
        }
    }

    // MARK: - Windows

    private func moveWindow(
        of processIdentifier: pid_t, appName: String, to preset: WindowPreset
    ) async throws(ExecutionError) {
        try ensureArmed()
        let currentFrame = try await accessibility.focusedWindowFrame(
            processIdentifier: processIdentifier, appName: appName)
        let geometry = await ScreenGeometry.current()
        guard let visibleFrame = geometry.visibleFrame(containingAccessibilityFrame: currentFrame)
        else {
            throw .windowUnavailable(appName: appName)
        }
        let targetFrame = WindowFrameCalculator.accessibilityFrame(
            for: preset, visibleFrame: visibleFrame,
            primaryScreenHeight: geometry.primaryScreenHeight,
            currentSize: currentFrame.size)
        try ensureArmed()
        try await accessibility.setFocusedWindowFrame(
            targetFrame, processIdentifier: processIdentifier, appName: appName,
            killSwitch: killSwitch)
    }

    // MARK: - Helpers

    private func targetElement(of action: ExecutableAction) throws(ExecutionError)
        -> UIElementSnapshot
    {
        guard let element = action.targetElement else {
            throw .missingTarget
        }
        return element
    }

    private func ensureArmed() throws(ExecutionError) {
        guard killSwitch.isArmed, !Task.isCancelled else {
            throw .stopped
        }
    }

    private func pause(for duration: Duration) async throws(ExecutionError) {
        do {
            try await Task.sleep(for: duration)
        } catch {
            throw .stopped
        }
    }
}
