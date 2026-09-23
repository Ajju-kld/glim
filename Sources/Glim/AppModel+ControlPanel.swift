import AppKit
import GlimCore

/// Loads the control panel's slow data (app scan, icons, crash reports, service health) off the
/// main thread and keeps it in the model, so switching pages shows the last values at once and
/// refreshes them in the background.
extension AppModel {
    /// Rescans the Applications folders and fetches icons only for apps not seen before.
    func refreshInstalledApps() async {
        guard !isScanningInstalledApps else {
            return
        }
        isScanningInstalledApps = true
        defer { isScanningInstalledApps = false }
        let scannedApps = await Task.detached(priority: .userInitiated) {
            WorkspaceAppCatalog().installedApps()
        }.value
        let knownIconPaths = Set(appIconsByPath.keys)
        let newIconPaths = scannedApps.map { $0.url.path(percentEncoded: false) }
            .filter { !knownIconPaths.contains($0) }
        if !newIconPaths.isEmpty {
            let newIcons = await Task.detached(priority: .userInitiated) {
                Dictionary(
                    newIconPaths.map { ($0, NSWorkspace.shared.icon(forFile: $0)) },
                    uniquingKeysWith: { first, _ in first })
            }.value
            appIconsByPath.merge(newIcons, uniquingKeysWith: { _, newest in newest })
        }
        if scannedApps != installedApps {
            installedApps = scannedApps
        }
    }

    /// Checks Ollama (with the chosen model) and Laya, keeping the last answer on screen until
    /// the new one arrives.
    func refreshServiceHealth() async {
        async let ollama = ServiceHealth.ollamaStatus(
            modelName: settings.plannerModelName, transport: services.transport)
        async let laya = ServiceHealth.layaStatus(transport: services.transport)
        ollamaStatus = await ollama
        layaStatus = await laya
    }

    /// Checks only Ollama, after the planner model changes.
    func refreshOllamaStatus(modelName: String) async {
        ollamaStatus = await ServiceHealth.ollamaStatus(
            modelName: modelName, transport: services.transport)
    }

    /// Reads the newest crash report on a background thread.
    func refreshLastCrash() async {
        let crashResult = await Task.detached(priority: .utility) {
            Result { try CrashReports.latest() }
        }.value
        switch crashResult {
        case .success(let crash):
            lastCrash = crash
            crashReadError = nil
        case .failure(let error):
            crashReadError = "Could not read crash reports: \(error.localizedDescription)"
        }
    }

    /// Loads the tasks that finished today, newest first.
    func refreshTodaysTasks() async {
        do {
            let startOfToday = Calendar.current.startOfDay(for: .now)
            todaysTasks = try await services.auditLog.readAllEvents()
                .filter { $0.kind == .taskFinished && $0.timestamp >= startOfToday }
                .reversed()
            todaysTasksError = nil
        } catch {
            todaysTasksError = "Could not read today's activity: \(error.localizedDescription)"
        }
    }
}
