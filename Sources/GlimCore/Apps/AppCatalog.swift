/// Lists installed and running apps.
public protocol AppCatalog: Sendable {
    /// Apps found in the standard Applications folders.
    func installedApps() -> [InstalledApp]
    /// Running apps with a Dock icon.
    func runningApps() -> [RunningApp]
}
