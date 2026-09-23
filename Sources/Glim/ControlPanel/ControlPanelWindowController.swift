import AppKit
import SwiftUI

/// Opens the control panel window from anywhere (menu, guard popup's "View log").
@MainActor
final class ControlPanelWindowController {
    private static let defaultSize = CGSize(width: 960, height: 640)
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
        let newWindow = NSWindow(contentViewController: hostingController)
        newWindow.title = "Glim"
        newWindow.styleMask = [
            .titled, .closable, .miniaturizable, .resizable, .fullSizeContentView,
        ]
        newWindow.setContentSize(Self.defaultSize)
        newWindow.isReleasedWhenClosed = false
        newWindow.setFrameAutosaveName(Self.autosaveName)
        newWindow.center()
        return newWindow
    }
}
