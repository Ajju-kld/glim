import AppKit

// No Dock icon and no menu bar: the watchdog only listens for ⌃⌥⌘K.
let application = NSApplication.shared
application.setActivationPolicy(.prohibited)
let watchdogController = WatchdogController()
watchdogController.start()
application.run()
