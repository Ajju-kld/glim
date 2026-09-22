import GlimCore
import SwiftUI

/// The menu-bar menu: talk, stop, re-arm, and the way into the control panel.
struct MenuBarContent: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Button("Open Control Panel") {
            model.openControlPanel()
        }
        .keyboardShortcut(",")
        Button(
            model.isListening
                ? "Stop Listening" : "Talk (or hold \(HotkeyCombo.pushToTalk.displayName))"
        ) {
            model.toggleListeningFromMenu()
        }
        .disabled(!model.isArmed)
        Divider()
        Button("STOP  \(HotkeyCombo.killSwitch.displayName)", role: .destructive) {
            model.stopEverything()
        }
        if !model.isArmed {
            Button("Re-arm") {
                model.rearm()
            }
        }
        Toggle(
            "Mute narration",
            isOn: Binding(
                get: { model.settings.isNarrationMuted },
                set: { isMuted in
                    model.changeSettings { $0.isNarrationMuted = isMuted }
                }))
        #if DEBUG
            Divider()
            Button("Simulate freeze (then press ⌃⌥⌘K)") {
                model.simulateFreezeForWatchdogTest()
            }
        #endif
        Divider()
        Button("Quit Glim") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
