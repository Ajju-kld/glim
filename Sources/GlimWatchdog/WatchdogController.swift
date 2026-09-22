import AppKit
import GlimCore

/// The tiny helper process that owns ⌃⌥⌘K.
///
/// It is launched by Glim, exits when Glim exits, and on ⌃⌥⌘K asks Glim to stop — force-quitting
/// it if it doesn't acknowledge within half a second, so the kill switch works even when Glim
/// itself is frozen.
@MainActor
final class WatchdogController {
    private static let orphanedParentProcessIdentifier: pid_t = 1

    private let link = WatchdogLink()
    private let glimProcessIdentifier = getppid()
    private var killHotkey: GlobalHotkey?
    private var glimExitSource: DispatchSourceProcess?
    private var acknowledgementWaiter: AcknowledgementWaiter?

    func start() {
        guard glimProcessIdentifier > Self.orphanedParentProcessIdentifier else {
            exit(EXIT_FAILURE)
        }
        exitWhenGlimExits()
        do {
            acknowledgementWaiter = try AcknowledgementWaiter(link: link)
        } catch {
            link.post(.hotkeyFailed)
            exit(EXIT_FAILURE)
        }
        let hotkey = GlobalHotkey(combo: .killSwitch) { [weak self] in
            self?.killHotkeyPressed()
        }
        do {
            try hotkey.register()
        } catch {
            link.post(.hotkeyFailed)
            exit(EXIT_FAILURE)
        }
        killHotkey = hotkey
        link.post(.watchdogReady)
    }

    private func killHotkeyPressed() {
        guard let acknowledgementWaiter else {
            return
        }
        let link = self.link
        let glimProcessIdentifier = self.glimProcessIdentifier
        Task {
            _ = await StopEscalator().stop(
                requestStop: {
                    acknowledgementWaiter.arm()
                    link.post(.stopRequested)
                },
                waitForAcknowledgement: { timeout in
                    await acknowledgementWaiter.waitForAcknowledgement(within: timeout)
                },
                forceStop: {
                    kill(glimProcessIdentifier, SIGKILL)
                })
        }
    }

    private func exitWhenGlimExits() {
        let exitSource = DispatchSource.makeProcessSource(
            identifier: glimProcessIdentifier, eventMask: .exit, queue: .main)
        exitSource.setEventHandler {
            exit(EXIT_SUCCESS)
        }
        exitSource.resume()
        glimExitSource = exitSource
    }
}
