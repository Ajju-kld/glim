import CryptoKit
import Foundation
import Testing

@testable import GlimCore

struct SettingsStoreTests {
    let sealKey = SymmetricKey(size: .bits256)

    struct StoreUnderTest {
        let store: SettingsStore
        let authenticator: ScriptedOwnerAuthenticator
        let auditLog: AuditLog
        let settingsFileURL: URL
    }

    func makeStore(
        in directory: URL, ownerAnswer: Bool = true, key: SymmetricKey? = nil
    ) -> StoreUnderTest {
        let authenticator = ScriptedOwnerAuthenticator(answer: ownerAnswer)
        let auditLog = AuditLog(directory: directory.appending(path: "audit"))
        let settingsFileURL = directory.appending(path: "settings.json")
        let store = SettingsStore(
            fileURL: settingsFileURL,
            sealKeyProvider: FixedSealKeyProvider(key: key ?? sealKey),
            ownerAuthenticator: authenticator,
            auditLog: auditLog)
        return StoreUnderTest(
            store: store, authenticator: authenticator, auditLog: auditLog,
            settingsFileURL: settingsFileURL)
    }

    func tightened(_ settings: GlimSettings) -> GlimSettings {
        var tightenedSettings = settings
        tightenedSettings.safetyPolicy.riskWords.forbidden.append("archive")
        return tightenedSettings
    }

    @Test func missingFileCreatesSafeDefaults() async throws {
        try await withTemporaryDirectory { directory in
            let subject = makeStore(in: directory)

            let outcome = try await subject.store.load()

            #expect(outcome == .createdWithSafeDefaults)
            #expect(await subject.store.current == .safeDefaults)
            #expect(
                FileManager.default.fileExists(
                    atPath: subject.settingsFileURL.path(percentEncoded: false)))
        }
    }

    @Test func savedSettingsSurviveAReload() async throws {
        try await withTemporaryDirectory { directory in
            let firstLaunch = makeStore(in: directory)
            _ = try await firstLaunch.store.load()
            try await firstLaunch.store.update(to: tightened(.safeDefaults))

            let secondLaunch = makeStore(in: directory)
            let outcome = try await secondLaunch.store.load()

            #expect(outcome == .loaded)
            #expect(await secondLaunch.store.current == tightened(.safeDefaults))
        }
    }

    @Test func editingTheFileOutsideGlimResetsToSafeDefaults() async throws {
        try await withTemporaryDirectory { directory in
            let firstLaunch = makeStore(in: directory)
            _ = try await firstLaunch.store.load()
            try await firstLaunch.store.update(to: tightened(.safeDefaults))
            let fileText = try String(contentsOf: firstLaunch.settingsFileURL, encoding: .utf8)
            let editedText = fileText.replacingOccurrences(of: "archive", with: "archivx")
            try editedText.write(to: firstLaunch.settingsFileURL, atomically: true, encoding: .utf8)

            let secondLaunch = makeStore(in: directory)
            let outcome = try await secondLaunch.store.load()

            #expect(outcome == .resetBecauseSealInvalid)
            #expect(await secondLaunch.store.current == .safeDefaults)
        }
    }

    @Test func fileSealedWithAnotherKeyResetsToSafeDefaults() async throws {
        try await withTemporaryDirectory { directory in
            _ = try await makeStore(in: directory).store.load()

            let otherKeyStore = makeStore(in: directory, key: SymmetricKey(size: .bits256))
            let outcome = try await otherKeyStore.store.load()

            #expect(outcome == .resetBecauseSealInvalid)
        }
    }

    @Test(arguments: ["", "not json at all", "{\"settingsJSON\": 42}"])
    func damagedFileResetsToSafeDefaults(fileText: String) async throws {
        try await withTemporaryDirectory { directory in
            let subject = makeStore(in: directory)
            try fileText.write(to: subject.settingsFileURL, atomically: true, encoding: .utf8)

            let outcome = try await subject.store.load()

            #expect(outcome == .resetBecauseCorrupted)
            #expect(await subject.store.current == .safeDefaults)
        }
    }

    @Test func looseningWithoutOwnerConfirmationIsRefused() async throws {
        try await withTemporaryDirectory { directory in
            let subject = makeStore(in: directory, ownerAnswer: false)
            _ = try await subject.store.load()
            var loosened = GlimSettings.safeDefaults
            loosened.safetyPolicy.riskWords.forbidden.removeAll { $0 == "delete" }

            await #expect(
                throws: SettingsStoreError.ownerNotConfirmed([.removedForbiddenPhrase("delete")])
            ) {
                try await subject.store.update(to: loosened)
            }
            #expect(await subject.store.current == .safeDefaults)
            let reloaded = makeStore(in: directory)
            _ = try await reloaded.store.load()
            #expect(await reloaded.store.current == .safeDefaults)
        }
    }

    @Test func looseningWithOwnerConfirmationIsSaved() async throws {
        try await withTemporaryDirectory { directory in
            let subject = makeStore(in: directory, ownerAnswer: true)
            _ = try await subject.store.load()
            var loosened = GlimSettings.safeDefaults
            loosened.jev.isEnabled = true

            try await subject.store.update(to: loosened)

            #expect(await subject.store.current.jev.isEnabled)
            #expect(subject.authenticator.reasons.count == 1)
        }
    }

    @Test func tighteningNeverAsksTheOwner() async throws {
        try await withTemporaryDirectory { directory in
            let subject = makeStore(in: directory, ownerAnswer: false)
            _ = try await subject.store.load()

            try await subject.store.update(to: tightened(.safeDefaults))

            #expect(subject.authenticator.reasons.isEmpty)
            #expect(await subject.store.current == tightened(.safeDefaults))
        }
    }

    @Test func resetAsksTheOwnerWhenItLoosens() async throws {
        try await withTemporaryDirectory { directory in
            let subject = makeStore(in: directory, ownerAnswer: true)
            _ = try await subject.store.load()
            try await subject.store.update(to: tightened(.safeDefaults))

            try await subject.store.resetToSafeDefaults()

            #expect(await subject.store.current == .safeDefaults)
            #expect(subject.authenticator.reasons.count == 1)
        }
    }

    @Test func changesAreWrittenToTheAuditLog() async throws {
        try await withTemporaryDirectory { directory in
            let subject = makeStore(in: directory)
            _ = try await subject.store.load()

            try await subject.store.update(to: tightened(.safeDefaults))

            let kinds = try await subject.auditLog.readAllEvents().map(\.kind)
            #expect(kinds == [.settingsChanged])
        }
    }

    @Test func tamperResetIsWrittenToTheAuditLog() async throws {
        try await withTemporaryDirectory { directory in
            let subject = makeStore(in: directory)
            try "garbage".write(to: subject.settingsFileURL, atomically: true, encoding: .utf8)

            _ = try await subject.store.load()

            let kinds = try await subject.auditLog.readAllEvents().map(\.kind)
            #expect(kinds == [.settingsReset])
        }
    }
}
