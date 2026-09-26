import GlimCore
import SwiftUI

/// The menu-bar menu: talk, stop, re-arm, and the way into the control panel.
struct MenuBarContent: View {
    @Environment(AppModel.self) private var model
    @AppStorage(SpeechNarrator.voiceIdentifierKey) private var voiceIdentifier = ""
    @AppStorage(SpeechNarrator.rateKey) private var narrationRate = SpeechNarrator.defaultRate

    /// Tunable: the speed presets offered in the menu (0.0 slowest … 1.0 fastest).
    private static let slowNarrationRate = 0.40
    private static let normalNarrationRate = 0.50
    private static let veryFastNarrationRate = 0.65
    /// A short line that sounds like real narration, for trying a voice.
    private static let voicePreviewLine = "Hi, I'm Glim. Opening Notes."

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
        Button(
            model.screenChat.isActive
                ? "End Screen Chat"
                : "Screen Chat (or hold \(HotkeyCombo.screenChat.displayName))"
        ) {
            model.toggleScreenChat()
        }
        .disabled(!model.isArmed && !model.screenChat.isActive)
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
        Menu("Voice") {
            Picker("Voice", selection: $voiceIdentifier) {
                Text("Best installed voice").tag("")
                ForEach(SpeechNarrator.availableVoices()) { voice in
                    Text(voice.title).tag(voice.id)
                }
            }
            .pickerStyle(.inline)
            Divider()
            Picker("Speed", selection: $narrationRate) {
                Text("Slow").tag(Self.slowNarrationRate)
                Text("Normal").tag(Self.normalNarrationRate)
                Text("Fast").tag(SpeechNarrator.defaultRate)
                Text("Very fast").tag(Self.veryFastNarrationRate)
            }
            .pickerStyle(.inline)
            Divider()
            Button("Preview voice") {
                model.narrator.say(Self.voicePreviewLine)
            }
        }
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
