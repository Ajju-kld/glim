import Foundation

/// Apps built on Chromium, which hide their controls from the Accessibility API until asked.
///
/// Each kind listens for a different signal: Electron for `AXManualAccessibility`, apps
/// embedding Chromium (Spotify) for `AXEnhancedUserInterface`, and Chrome-family browsers wake
/// when their role is read.
public enum ChromiumKind: Sendable, Equatable {
    case electron
    case chromiumEmbedded
    case chromeBrowser

    private static let electronFrameworkName = "Electron Framework.framework"
    private static let embeddedFrameworkName = "Chromium Embedded Framework.framework"

    /// Business rule: Chrome-family browsers found on the owner's Mac or common elsewhere.
    static let chromeBrowserBundleIdentifiers: Set<String> = [
        "com.google.Chrome", "com.google.Chrome.beta", "com.google.Chrome.dev",
        "com.google.Chrome.canary", "org.chromium.Chromium", "com.brave.Browser",
        "com.microsoft.edgemac", "company.thebrowser.Browser", "com.vivaldi.Vivaldi",
        "com.operasoftware.Opera", "ai.perplexity.comet",
    ]

    /// The kind of `bundleURL`'s app, or nil for an app that isn't built on Chromium.
    public static func detect(
        bundleURL: URL?,
        bundleIdentifier: String,
        frameworkExists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }
    ) -> ChromiumKind? {
        if chromeBrowserBundleIdentifiers.contains(bundleIdentifier) {
            return .chromeBrowser
        }
        guard let bundleURL else {
            return nil
        }
        let frameworksURL = bundleURL.appending(
            path: "Contents/Frameworks", directoryHint: .isDirectory)
        if frameworkExists(frameworksURL.appending(path: electronFrameworkName)) {
            return .electron
        }
        if frameworkExists(frameworksURL.appending(path: embeddedFrameworkName)) {
            return .chromiumEmbedded
        }
        return nil
    }
}
