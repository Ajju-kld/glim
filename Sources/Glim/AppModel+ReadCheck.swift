import GlimCore
import os

extension AppModel {
    private static let readCheckLogger = Logger(subsystem: "dev.straxs.Glim", category: "ReadCheck")

    /// Whether the read check may start: never during a task, which reads the same windows.
    var canRunReadCheck: Bool {
        !isTaskRunning && !isReadCheckRunning
    }

    /// Reads every open app's window and logs the counts to the Activity Log.
    func runReadCheck() async {
        guard canRunReadCheck else {
            return
        }
        isReadCheckRunning = true
        defer { isReadCheckRunning = false }
        let check = ReadCheck(
            reader: services.accessibility, trust: settings.safetyPolicy.appTrust)
        let results = await check.run(on: services.appResolver.runningApps())
        readCheckResults = results
        do {
            try await services.auditLog.append(.readCheck, summary: ReadCheck.summary(of: results))
        } catch {
            Self.readCheckLogger.error(
                "Could not log the read check: \(error.localizedDescription, privacy: .public)")
        }
    }
}
