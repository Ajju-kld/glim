/// Finds apps by the names the planner uses and verifies their signatures.
public struct AppResolver: Sendable {
    private static let bundleExtension = ".app"

    private let catalog: any AppCatalog
    private let verifier: any SignatureVerifying

    /// Creates a resolver over `catalog`, verifying with `verifier`.
    public init(catalog: any AppCatalog, verifier: any SignatureVerifying) {
        self.catalog = catalog
        self.verifier = verifier
    }

    /// Finds an app by name, preferring a running one, then an installed one.
    public func resolve(appNamed name: String) -> ResolvedApp? {
        resolveRunning(appNamed: name) ?? resolveInstalled(appNamed: name)
    }

    /// Finds a running app by name.
    public func resolveRunning(appNamed name: String) -> ResolvedApp? {
        let wantedName = Self.normalized(name)
        guard
            let runningApp = catalog.runningApps().first(where: {
                Self.normalized($0.name) == wantedName
            })
        else {
            return nil
        }
        return resolved(runningApp)
    }

    /// Finds an installed app by display name or file name.
    public func resolveInstalled(appNamed name: String) -> ResolvedApp? {
        let wantedName = Self.normalized(name)
        let installedApp = catalog.installedApps().first { installedApp in
            Self.normalized(installedApp.name) == wantedName
                || Self.normalized(installedApp.fileName) == wantedName
        }
        guard let installedApp else {
            return nil
        }
        let identity = AppIdentity(
            bundleIdentifier: installedApp.bundleIdentifier,
            displayName: installedApp.name,
            hasValidSignature: verifier.hasTrustedSignature(
                bundleIdentifier: installedApp.bundleIdentifier, bundleURL: installedApp.url,
                processIdentifier: nil))
        return ResolvedApp(identity: identity, bundleURL: installedApp.url, processIdentifier: nil)
    }

    /// The frontmost app, if any.
    public func frontmostApp() -> ResolvedApp? {
        catalog.runningApps().first(where: \.isFrontmost).map(resolved)
    }

    /// Installed app names for the planner, sorted and without duplicates.
    public func installedAppNames() -> [String] {
        Array(Set(catalog.installedApps().map(\.name))).sorted()
    }

    /// Running app names for the planner, sorted and without duplicates.
    public func runningAppNames() -> [String] {
        Array(Set(catalog.runningApps().map(\.name))).sorted()
    }

    private func resolved(_ runningApp: RunningApp) -> ResolvedApp {
        let identity = AppIdentity(
            bundleIdentifier: runningApp.bundleIdentifier,
            displayName: runningApp.name,
            hasValidSignature: verifier.hasTrustedSignature(
                bundleIdentifier: runningApp.bundleIdentifier, bundleURL: runningApp.bundleURL,
                processIdentifier: runningApp.processIdentifier))
        return ResolvedApp(
            identity: identity, bundleURL: runningApp.bundleURL,
            processIdentifier: runningApp.processIdentifier)
    }

    static func normalized(_ name: String) -> String {
        var trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmedName.hasSuffix(bundleExtension) {
            trimmedName.removeLast(bundleExtension.count)
        }
        return trimmedName
    }
}
