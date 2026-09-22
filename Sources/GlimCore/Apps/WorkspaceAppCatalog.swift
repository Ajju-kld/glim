import AppKit
import os

/// The live catalog: bundles in the standard Applications folders, and running apps from
/// `NSWorkspace`.
public struct WorkspaceAppCatalog: AppCatalog {
    private static let applicationDirectories = [
        URL(filePath: "/Applications", directoryHint: .isDirectory),
        URL(filePath: "/System/Applications", directoryHint: .isDirectory),
        URL(filePath: "/System/Applications/Utilities", directoryHint: .isDirectory),
        FileManager.default.homeDirectoryForCurrentUser.appending(
            path: "Applications", directoryHint: .isDirectory),
    ]
    private static let bundlePathExtension = "app"
    private static let logger = Logger(subsystem: "dev.straxs.Glim", category: "AppCatalog")

    /// Creates the live catalog.
    public init() {}

    /// Scans the Applications folders (one level deep) for app bundles.
    public func installedApps() -> [InstalledApp] {
        Self.applicationDirectories.flatMap { directory in
            // A missing folder (such as ~/Applications) simply has no apps.
            guard FileManager.default.fileExists(atPath: directory.path(percentEncoded: false))
            else {
                return [InstalledApp]()
            }
            let bundleURLs: [URL]
            do {
                bundleURLs = try FileManager.default.contentsOfDirectory(
                    at: directory, includingPropertiesForKeys: nil)
            } catch {
                Self.logger.error(
                    "Could not list \(directory.path(percentEncoded: false), privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
                return [InstalledApp]()
            }
            return
                bundleURLs
                .filter { $0.pathExtension == Self.bundlePathExtension }
                .compactMap(Self.installedApp(at:))
        }
    }

    /// Running apps that have a Dock icon.
    public func runningApps() -> [RunningApp] {
        NSWorkspace.shared.runningApplications.compactMap { application in
            guard application.activationPolicy == .regular,
                let bundleIdentifier = application.bundleIdentifier
            else {
                return nil
            }
            return RunningApp(
                name: application.localizedName ?? bundleIdentifier,
                bundleIdentifier: bundleIdentifier,
                processIdentifier: application.processIdentifier,
                isFrontmost: application.isActive,
                bundleURL: application.bundleURL)
        }
    }

    private static func installedApp(at bundleURL: URL) -> InstalledApp? {
        guard let bundle = Bundle(url: bundleURL), let bundleIdentifier = bundle.bundleIdentifier
        else {
            return nil
        }
        let fileName = bundleURL.deletingPathExtension().lastPathComponent
        let displayName =
            bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? fileName
        return InstalledApp(
            name: displayName, fileName: fileName, bundleIdentifier: bundleIdentifier,
            url: bundleURL)
    }
}
