import Foundation
import GlimCore
import os

/// Builds a task runner from the current settings, wiring the live Mac services together.
@MainActor
enum RunnerFactory {
    nonisolated private static let logger = Logger(
        subsystem: "dev.straxs.Glim", category: "RunnerFactory")

    /// Saves each step Laya reviewed when the owner turned saving on; nil otherwise.
    private static func layaExampleSaver(isSaving: Bool, store: LayaExampleStore)
        -> (@Sendable (LayaExample) async -> Void)?
    {
        guard isSaving else {
            return nil
        }
        return { example in
            do throws(LayaExampleStoreError) {
                try await store.append(example)
            } catch {
                logger.error(
                    "Could not save a Laya example: \(error.explanation, privacy: .public)")
            }
        }
    }

    static func makeRunner(
        settings: GlimSettings,
        settingsBox: SettingsBox,
        isActionModeAllowed: Bool,
        services: LiveServices,
        decisions: any PersonDecisions,
        narrator: any Narrating,
        watchdogHealth: WatchdogHealth
    ) -> TaskRunner {
        let transport = PolicyEnforcingTransport(
            base: services.transport,
            policy: NetworkPolicy(isJevEnabled: settings.jev.isEnabled))
        var checkers: [any TargetChecker] = [LayaChecker(transport: transport)]
        if settings.jev.isEnabled {
            let secretStore = KeychainSecretStore()
            checkers.append(
                JevChecker(
                    transport: transport, apiKey: { try secretStore.jevAPIKey() },
                    excludedBundleIdentifiers: settings.jev.excludedBundleIdentifiers))
        }
        let dependencies = TaskRunnerDependencies(
            planner: Planner(
                languageModel: OllamaClient(
                    transport: transport, modelName: settings.plannerModelName),
                fastPicker: LayaPicker(transport: transport)),
            screenReader: services.accessibility,
            screenshotter: WindowScreenshotter(),
            appResolver: services.appResolver,
            checkerConsensus: CheckerConsensus(checkers: checkers),
            executor: LiveExecutor(
                accessibility: services.accessibility, killSwitch: services.killSwitch),
            decisions: decisions,
            narrator: narrator,
            killSwitch: services.killSwitch,
            auditLog: services.auditLog,
            takeoverMonitor: TakeoverMonitor(
                killSwitch: services.killSwitch, inputClock: HardwareInputClock()),
            safetyPolicyProvider: {
                let policy = settingsBox.settings.safetyPolicy
                return isActionModeAllowed ? policy : readOnlyEverywhere(policy)
            },
            isWatchdogAlive: { watchdogHealth.isAlive },
            layaExampleSaver: layaExampleSaver(
                isSaving: settings.savesLayaExamples, store: services.layaExamples),
            ownBundleIdentifiers: Set([Bundle.main.bundleIdentifier].compactMap { $0 }))
        return TaskRunner(dependencies: dependencies)
    }

    /// With action mode off (non-English interface), every app is capped at read-only: questions
    /// and window arrangement still work, clicking and typing don't.
    nonisolated private static func readOnlyEverywhere(_ policy: SafetyPolicy) -> SafetyPolicy {
        var cappedPolicy = policy
        cappedPolicy.appTrust.tiersByBundleIdentifier = policy.appTrust.tiersByBundleIdentifier
            .mapValues { min($0, .readOnly) }
        cappedPolicy.appTrust.defaultTier = min(policy.appTrust.defaultTier, .readOnly)
        return cappedPolicy
    }
}
