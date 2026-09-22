import SwiftUI

/// A harmless practice app for proving Glim's guards before trusting it with real apps.
@main
struct TestbedApp: App {
    var body: some Scene {
        WindowGroup("Testbed") {
            TestbedView()
        }
        .windowResizability(.contentSize)
    }
}
