import AppKit
import SwiftUI

/// A centered floating panel for decisions. It is non-activating and never takes keyboard
/// focus, so the app Glim is working in stays frontmost, and nothing typed — including keyboard
/// navigation — can reach its buttons. Only a mouse click can.
@MainActor
final class DecisionPanel {
    private let panel: NSPanel

    init<Content: View>(content: Content) {
        panel = NSPanel(
            contentRect: .zero,
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered, defer: false)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .modalPanel
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.becomesKeyOnlyIfNeeded = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        let hostingView = ClickThroughHostingView(rootView: content)
        panel.contentView = hostingView
        panel.setContentSize(hostingView.fittingSize)
    }

    func show() {
        panel.center()
        panel.orderFrontRegardless()
    }

    func close() {
        panel.orderOut(nil)
        panel.close()
    }
}
