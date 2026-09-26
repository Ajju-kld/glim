import Foundation
import Testing

@testable import GlimCore

struct ChromiumKindTests {
    static let bundleURL = URL(filePath: "/Applications/Some.app")

    static func frameworksPresent(_ names: Set<String>) -> @Sendable (URL) -> Bool {
        { url in names.contains(url.lastPathComponent) }
    }

    @Test func electronFrameworkMeansElectron() {
        let kind = ChromiumKind.detect(
            bundleURL: Self.bundleURL, bundleIdentifier: "com.tinyspeck.slackmacgap",
            frameworkExists: Self.frameworksPresent(["Electron Framework.framework"]))

        #expect(kind == .electron)
    }

    @Test func embeddedFrameworkMeansChromiumEmbedded() {
        let kind = ChromiumKind.detect(
            bundleURL: Self.bundleURL, bundleIdentifier: "com.spotify.client",
            frameworkExists: Self.frameworksPresent(["Chromium Embedded Framework.framework"]))

        #expect(kind == .chromiumEmbedded)
    }

    @Test(arguments: ["com.google.Chrome", "ai.perplexity.comet", "com.brave.Browser"])
    func knownBrowserIsChromeBrowser(bundleIdentifier: String) {
        let kind = ChromiumKind.detect(
            bundleURL: Self.bundleURL, bundleIdentifier: bundleIdentifier,
            frameworkExists: Self.frameworksPresent([]))

        #expect(kind == .chromeBrowser)
    }

    @Test func nativeAppIsNotChromium() {
        let kind = ChromiumKind.detect(
            bundleURL: Self.bundleURL, bundleIdentifier: "com.apple.Notes",
            frameworkExists: Self.frameworksPresent([]))

        #expect(kind == nil)
    }

    @Test func appWithoutABundleIsNotChromium() {
        let kind = ChromiumKind.detect(
            bundleURL: nil, bundleIdentifier: "dev.example.tool",
            frameworkExists: Self.frameworksPresent(["Electron Framework.framework"]))

        #expect(kind == nil)
    }

    /// Apps embedding Chromium ignore the accessibility switch, so Glim starts them with the
    /// flag that builds their tree from launch.
    @Test func chromiumEmbeddedAppsLaunchWithAccessibilityOn() {
        #expect(ChromiumKind.chromiumEmbedded.launchArguments == ["--force-renderer-accessibility"])
    }

    @Test(arguments: [ChromiumKind.electron, .chromeBrowser])
    func otherKindsLaunchNormally(kind: ChromiumKind) {
        #expect(kind.launchArguments.isEmpty)
    }

    /// Opened from the Dock, Spotify starts without the flag; the log says how to fix that.
    @Test func chromiumEmbeddedAppWithNoControlsExplainsTheFix() {
        #expect(
            ChromiumKind.chromiumEmbedded.noControlsNote(appName: "Spotify")
                == " Spotify only shows its controls when Glim opens it: quit Spotify, then ask Glim to open it."
        )
    }

    @Test(arguments: [ChromiumKind.electron, .chromeBrowser])
    func otherKindsHaveNoNote(kind: ChromiumKind) {
        #expect(kind.noControlsNote(appName: "Slack").isEmpty)
    }
}
