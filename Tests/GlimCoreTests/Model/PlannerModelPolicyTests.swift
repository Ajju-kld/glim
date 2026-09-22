import CryptoKit
import Foundation
import Testing

@testable import GlimCore

struct PlannerModelPolicyTests {
    @Test(arguments: [
        "qwen3-vl:8b", "qwen3-vl:4b", "llama3.2-vision:11b", "hf.co/someone/model-GGUF:Q4_K_M",
    ])
    func localModelNamesAreAllowed(modelName: String) {
        #expect(PlannerModelPolicy.isLocalModelName(modelName))
    }

    @Test(arguments: [
        "gpt-oss:120b-cloud", "qwen3-coder:480b-cloud", "deepseek:cloud", "Kimi-CLOUD", "", "  ",
        "http://evil/model", "two words",
    ])
    func cloudOrMalformedNamesAreRefused(modelName: String) {
        #expect(!PlannerModelPolicy.isLocalModelName(modelName))
    }

    @Test func changingTheModelIsALoosening() {
        var changedSettings = GlimSettings.safeDefaults
        changedSettings.plannerModelName = "qwen3-vl:4b"

        #expect(
            SafetyChangeClassifier.loosenings(from: .safeDefaults, to: changedSettings)
                == [.plannerModelChanged(from: "qwen3-vl:8b", to: "qwen3-vl:4b")])
    }

    @Test func ollamaClientRefusesACloudModelWithoutSendingAnything() async {
        let fakeTransport = FakeHTTPTransport(replies: [])
        let client = OllamaClient(transport: fakeTransport, modelName: "gpt-oss:120b-cloud")

        await #expect(throws: LanguageModelError.modelNotAllowed(modelName: "gpt-oss:120b-cloud")) {
            _ = try await client.respond(
                to: LanguageModelRequest(systemPrompt: "s", userPrompt: "u", responseSchema: [:]))
        }
        #expect(fakeTransport.sentRequests.isEmpty)
    }

    @Test func settingsRefuseACloudModel() async throws {
        try await withTemporaryDirectory { directory in
            let store = SettingsStore(
                fileURL: directory.appending(path: "settings.json"),
                sealKeyProvider: FixedSealKeyProvider(key: .init(size: .bits256)),
                ownerAuthenticator: ScriptedOwnerAuthenticator(answer: true),
                auditLog: AuditLog(directory: directory.appending(path: "audit")))
            _ = try await store.load()
            var cloudSettings = GlimSettings.safeDefaults
            cloudSettings.plannerModelName = "gpt-oss:120b-cloud"

            await #expect(
                throws: SettingsStoreError.plannerModelNotLocal(modelName: "gpt-oss:120b-cloud")
            ) {
                try await store.update(to: cloudSettings)
            }
            #expect(await store.current == .safeDefaults)
        }
    }
}
