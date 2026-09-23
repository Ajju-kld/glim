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
            displayName: Self.withoutInvisibleMarks(installedApp.name),
            hasValidSignature: verifier.hasTrustedSignature(
                bundleIdentifier: installedApp.bundleIdentifier, bundleURL: installedApp.url,
                processIdentifier: nil))
        return ResolvedApp(identity: identity, bundleURL: installedApp.url, processIdentifier: nil)
    }

    /// The frontmost app, if any.
    public func frontmostApp() -> ResolvedApp? {
        catalog.runningApps().first(where: \.isFrontmost).map(resolved)
    }

    /// Every running app with a Dock icon, sorted by name.
    public func runningApps() -> [ResolvedApp] {
        catalog.runningApps()
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            .map(resolved)
    }

    /// Installed app names for the planner, sorted and without duplicates.
    public func installedAppNames() -> [String] {
        Array(Set(catalog.installedApps().map { Self.withoutInvisibleMarks($0.name) })).sorted()
    }

    /// Running app names for the planner, sorted and without duplicates.
    public func runningAppNames() -> [String] {
        Array(Set(catalog.runningApps().map { Self.withoutInvisibleMarks($0.name) })).sorted()
    }

    private func resolved(_ runningApp: RunningApp) -> ResolvedApp {
        let identity = AppIdentity(
            bundleIdentifier: runningApp.bundleIdentifier,
            displayName: Self.withoutInvisibleMarks(runningApp.name),
            hasValidSignature: verifier.hasTrustedSignature(
                bundleIdentifier: runningApp.bundleIdentifier, bundleURL: runningApp.bundleURL,
                processIdentifier: runningApp.processIdentifier))
        return ResolvedApp(
            identity: identity, bundleURL: runningApp.bundleURL,
            processIdentifier: runningApp.processIdentifier)
    }

    /// `name` without invisible formatting characters, such as the left-to-right mark WhatsApp
    /// puts before its name. They carry no meaning in a name and stop plain names matching.
    static func withoutInvisibleMarks(_ name: String) -> String {
        String(
            String.UnicodeScalarView(
                name.unicodeScalars.filter { $0.properties.generalCategory != .format }))
    }

    static func normalized(_ name: String) -> String {
        var trimmedName = withoutInvisibleMarks(name)
            .trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmedName.hasSuffix(bundleExtension) {
            trimmedName.removeLast(bundleExtension.count)
        }
        return trimmedName
    }
}
