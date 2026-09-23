import AppKit
import GlimCore
import SwiftUI

/// A panel button that responds only to a real mouse click, and only after the panel has been
/// visible for ``ClickOnlyRule/armingDelay``.
struct ClickOnlyButton: View {
    let title: String
    var role: ButtonRole?
    let action: @MainActor () -> Void
    @State private var isArmed = false

    var body: some View {
        Button(title, role: role) {
            guard isArmed, ClickOnlyRule.isMouseClick(NSApplication.shared.currentEvent?.type)
            else {
                return
            }
            action()
        }
        .disabled(!isArmed)
        .focusable(false)
        .task {
            do {
                try await Task.sleep(for: ClickOnlyRule.armingDelay)
            } catch {
                return
            }
            isArmed = true
        }
    }
}

/// Hosting view whose buttons work on the first click even though the window isn't key —
/// Glim's panels never take keyboard focus.
final class ClickThroughHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}
