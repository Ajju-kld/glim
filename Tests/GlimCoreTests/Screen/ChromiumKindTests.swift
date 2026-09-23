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
}
