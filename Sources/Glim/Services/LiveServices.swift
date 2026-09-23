import GlimCore

/// The long-lived services shared by every request.
@MainActor
struct LiveServices {
    let killSwitch = KillSwitch()
    let auditLog = AuditLog(directory: GlimStorage.auditDirectory)
    let layaExamples = LayaExampleStore(directory: GlimStorage.layaExamplesDirectory)
    let accessibility = AccessibilityService()
    let appResolver = AppResolver(catalog: WorkspaceAppCatalog(), verifier: CodeSignatureVerifier())
    let transcriber = SpeechAnalyzerTranscriber()
    /// One network session for the whole app.
    let transport = URLSessionTransport()
    let settingsStore: SettingsStore

    init() {
        settingsStore = SettingsStore(
            fileURL: GlimStorage.settingsFileURL,
            sealKeyProvider: KeychainSealKeyProvider(),
            ownerAuthenticator: DeviceOwnerAuthenticator(),
            auditLog: auditLog)
    }
}
