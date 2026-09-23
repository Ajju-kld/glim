import AppKit
import GlimCore
import SwiftUI

/// Owns the pill's borderless, non-activating panel. It never takes keyboard focus, so it can't
/// disturb typing in the app Glim is working in.
@MainActor
final class NotchPillController {
    /// Tunable: how long the shrink-into-the-notch animation gets before the window hides.
    private static let shrinkDuration = Duration.milliseconds(450)

    private let panel: NSPanel
    private let model: AppModel
    private var hideTask: Task<Void, Never>?
    /// The notch the current pill view was built for; the view is rebuilt only if it changes.
    private var builtForGeometry: NotchGeometry?

    init(model: AppModel) {
        self.model = model
        panel = NSPanel(
            contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered,
            defer: true)
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [
            .canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle,
        ]
    }

    /// Shows `status`. Hiding lets the pill shrink back into the notch first; clicks pass
    /// through the window unless it offers ■ to stop.
    func show(_ status: PillStatus) {
        hideTask?.cancel()
        panel.ignoresMouseEvents = !status.offersStop
        guard status != .hidden else {
            hideAfterShrinking()
            return
        }
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            return
        }
        let geometry = NotchGeometry(screen: screen)
        if builtForGeometry?.notchSize != geometry.notchSize
            || builtForGeometry?.hasNotch != geometry.hasNotch
        {
            panel.contentView = WindowContainerView.hosting(
                NotchPillHost(notchSize: geometry.notchSize, mergesWithNotch: geometry.hasNotch)
                    .environment(model),
                size: geometry.frame.size)
            builtForGeometry = geometry
        }
        if panel.frame != geometry.frame {
            panel.setFrame(geometry.frame, display: false)
        }
        panel.orderFrontRegardless()
    }

    private func hideAfterShrinking() {
        guard panel.isVisible else {
            return
        }
        hideTask = Task { [panel] in
            do {
                try await Task.sleep(for: Self.shrinkDuration)
            } catch {
                // Cancelled because the pill is showing again, so it must stay on screen.
                return
            }
            panel.orderOut(nil)
        }
    }
}
