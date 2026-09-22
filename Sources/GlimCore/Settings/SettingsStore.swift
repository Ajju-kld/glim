import CryptoKit
import Foundation

/// Loads, seals and saves settings; asks the owner before any change that loosens safety.
///
/// The settings file carries an HMAC seal keyed by a Keychain secret. A file that is missing,
/// damaged, or edited outside Glim is replaced with safe defaults, so editing the file directly
/// can never bypass Touch ID.
public actor SettingsStore {
    private enum SettingsFileProblem: Error {
        case unreadable
        case malformed(reason: String)
        case sealInvalid
    }

    /// The settings in effect.
    public private(set) var current: GlimSettings = .safeDefaults

    private let fileURL: URL
    private let sealKeyProvider: any SealKeyProviding
    private let ownerAuthenticator: any OwnerAuthenticating
    private let auditLog: AuditLog
    private let encoder: JSONEncoder
    private let decoder = JSONDecoder()

    /// Creates a store for the settings file at `fileURL`.
    public init(
        fileURL: URL,
        sealKeyProvider: any SealKeyProviding,
        ownerAuthenticator: any OwnerAuthenticating,
        auditLog: AuditLog
    ) {
        self.fileURL = fileURL
        self.sealKeyProvider = sealKeyProvider
        self.ownerAuthenticator = ownerAuthenticator
        self.auditLog = auditLog
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        self.encoder = encoder
    }

    /// Loads settings at launch, falling back to safe defaults when the file is missing,
    /// damaged or tampered with.
    public func load() async throws(SettingsStoreError) -> SettingsLoadOutcome {
        guard FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) else {
            try save(.safeDefaults)
            current = .safeDefaults
            return .createdWithSafeDefaults
        }
        switch readSealedSettings(with: try sealKey()) {
        case .success(let settings):
            current = settings
            return .loaded
        case .failure(let problem):
            try save(.safeDefaults)
            current = .safeDefaults
            let outcome: SettingsLoadOutcome
            let reason: String
            switch problem {
            case .sealInvalid:
                outcome = .resetBecauseSealInvalid
                reason = "The settings file was changed outside Glim."
            case .unreadable:
                outcome = .resetBecauseCorrupted
                reason = "The settings file could not be read."
            case .malformed(let decodingReason):
                outcome = .resetBecauseCorrupted
                reason = "The settings file is damaged: \(decodingReason)"
            }
            try await audit(.settingsReset, summary: "Settings reset to safe defaults. \(reason)")
            return outcome
        }
    }

    /// Applies new settings, asking the owner first if the change loosens anything.
    public func update(to newSettings: GlimSettings) async throws(SettingsStoreError) {
        try await apply(newSettings, auditKind: .settingsChanged)
    }

    /// Restores safe defaults; asks the owner first if that loosens stricter custom settings.
    public func resetToSafeDefaults() async throws(SettingsStoreError) {
        try await apply(.safeDefaults, auditKind: .settingsReset)
    }

    private func apply(
        _ newSettings: GlimSettings, auditKind: AuditEventKind
    ) async throws(SettingsStoreError) {
        let settingsBeforeChange = current
        let loosenings = SafetyChangeClassifier.loosenings(
            from: settingsBeforeChange, to: newSettings)
        if !loosenings.isEmpty {
            let reason = loosenings.map(\.explanation).joined(separator: "; ")
            guard await ownerAuthenticator.confirmOwner(reason: "Glim wants to \(reason)") else {
                throw .ownerNotConfirmed(loosenings)
            }
            // The actor may have handled another change while waiting for the owner.
            guard current == settingsBeforeChange else {
                throw .settingsChangedDuringConfirmation
            }
        }
        try save(newSettings)
        current = newSettings
        let loosenedText =
            loosenings.isEmpty ? "none" : loosenings.map(\.explanation).joined(separator: "; ")
        try await audit(auditKind, summary: "Settings saved.", details: ["loosened": loosenedText])
    }

    // MARK: - File

    private func readSealedSettings(
        with key: SymmetricKey
    ) -> Result<GlimSettings, SettingsFileProblem> {
        guard
            let fileData = FileManager.default.contents(atPath: fileURL.path(percentEncoded: false))
        else {
            return .failure(.unreadable)
        }
        let sealedFile: SealedSettingsFile
        do {
            sealedFile = try decoder.decode(SealedSettingsFile.self, from: fileData)
        } catch {
            return .failure(.malformed(reason: error.localizedDescription))
        }
        let settingsData = Data(sealedFile.settingsJSON.utf8)
        guard SettingsSeal.isValid(sealedFile.seal, for: settingsData, with: key) else {
            return .failure(.sealInvalid)
        }
        do {
            return .success(try decoder.decode(GlimSettings.self, from: settingsData))
        } catch {
            return .failure(.malformed(reason: error.localizedDescription))
        }
    }

    private func save(_ settings: GlimSettings) throws(SettingsStoreError) {
        let key = try sealKey()
        let fileData: Data
        do {
            let settingsData = try encoder.encode(settings)
            let sealedFile = SealedSettingsFile(
                settingsJSON: String(decoding: settingsData, as: UTF8.self),
                seal: SettingsSeal.seal(settingsData, with: key))
            fileData = try encoder.encode(sealedFile)
        } catch {
            throw .cannotSave(reason: "Could not encode settings: \(error.localizedDescription)")
        }
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fileData.write(to: fileURL, options: .atomic)
        } catch {
            throw .cannotSave(reason: error.localizedDescription)
        }
    }

    private func sealKey() throws(SettingsStoreError) -> SymmetricKey {
        do {
            return try sealKeyProvider.sealKey()
        } catch {
            throw .sealKeyUnavailable(reason: error.localizedDescription)
        }
    }

    private func audit(
        _ kind: AuditEventKind, summary: String, details: [String: String] = [:]
    ) async throws(SettingsStoreError) {
        do {
            try await auditLog.append(kind, summary: summary, details: details)
        } catch {
            throw .auditFailed(reason: error.localizedDescription)
        }
    }
}
