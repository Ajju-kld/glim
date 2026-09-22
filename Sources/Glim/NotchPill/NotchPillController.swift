import AppKit
import GlimCore
import SwiftUI

/// Owns the pill's borderless, non-activating panel. It never takes keyboard focus, so it can't
/// disturb typing in the app Glim is working in.
@MainActor
final class NotchPillController {
    private let panel: NSPanel
    private let model: AppModel

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

    func show(_ status: PillStatus) {
        guard status != .hidden else {
            panel.orderOut(nil)
            return
        }
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            return
        }
        let geometry = NotchGeometry(screen: screen)
        if panel.contentView == nil || panel.frame != geometry.frame {
            panel.contentView = NSHostingView(
                rootView: NotchPillView(notchHeight: geometry.notchHeight).environment(model))
            panel.setFrame(geometry.frame, display: true)
        }
        panel.orderFrontRegardless()
    }
}
