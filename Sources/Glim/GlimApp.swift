import AppKit
import SwiftUI

/// Glim lives in the menu bar; the notch pill, panels and control panel are its windows.
@main
struct GlimApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent()
                .environment(appDelegate.model)
        } label: {
            Image(systemName: appDelegate.model.menuBarSymbolName)
        }
    }
}

/// Starts Glim's services as soon as the app launches, before any menu is opened.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { await model.start() }
    }

    /// Chromium apps Glim woke keep building accessibility trees until told to stop.
    func applicationWillTerminate(_ notification: Notification) {
        model.services.accessibility.wakeUp.releaseAll()
    }

    /// Clicking Glim's Dock icon opens the control panel, so Glim is reachable even when the
    /// notch hides its menu-bar icon.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool)
        -> Bool
    {
        model.openControlPanel()
        return false
    }
}
