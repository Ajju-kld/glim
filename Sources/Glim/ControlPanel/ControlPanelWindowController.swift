import AppKit
import SwiftUI

/// Opens the control panel window from anywhere (menu, guard popup's "View log").
@MainActor
final class ControlPanelWindowController {
    private static let defaultSize = CGSize(width: 960, height: 640)
    /// Tunable: the smallest the window may be resized to while the sidebar and cards fit.
    private static let minimumSize = CGSize(width: 820, height: 540)
    private static let autosaveName = "GlimControlPanel"

    private let model: AppModel
    private var window: NSWindow?

    init(model: AppModel) {
        self.model = model
    }

    func show() {
        let controlPanelWindow = window ?? makeWindow()
        window = controlPanelWindow
        controlPanelWindow.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate()
    }

    private func makeWindow() -> NSWindow {
        let hostingController = NSHostingController(rootView: ControlPanelView().environment(model))
        // The orbs animate every frame; if the view also set the window's size limits, AppKit
        // would re-run layout during layout and crash. The limits are set here instead.
        hostingController.sizingOptions = []
        let newWindow = NSWindow(contentViewController: hostingController)
        newWindow.title = "Glim"
        newWindow.styleMask = [
            .titled, .closable, .miniaturizable, .resizable, .fullSizeContentView,
        ]
        newWindow.titlebarAppearsTransparent = true
        newWindow.titleVisibility = .hidden
        newWindow.appearance = NSAppearance(named: .darkAqua)
        newWindow.contentMinSize = Self.minimumSize
        newWindow.setContentSize(Self.defaultSize)
        newWindow.isReleasedWhenClosed = false
        newWindow.setFrameAutosaveName(Self.autosaveName)
        newWindow.center()
        return newWindow
    }
}
