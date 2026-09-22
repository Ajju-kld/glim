import GlimCore
import SwiftUI

/// The planner model, the local Laya checker, and the optional Jev cloud checker.
struct AIModelsPage: View {
    @Environment(AppModel.self) private var model
    @State private var plannerModelName = ""
    @State private var ollamaStatus = ServiceHealth.Status.checking
    @State private var layaStatus = ServiceHealth.Status.checking
    @State private var jevAPIKey = ""
    @State private var hasSavedJevKey = KeychainSecretStore().hasJevAPIKey()
    @State private var keyMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GlassCard(title: "Planner — Ollama on this Mac", systemImage: "cpu") {
                StatusRow(
                    name: "Status", detail: ollamaStatus.detail, isHealthy: ollamaStatus.isHealthy)
                HStack {
                    TextField("Model", text: $plannerModelName)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 240)
                    Button("Save") {
                        let chosenModel = plannerModelName
                        model.changeSettings { $0.plannerModelName = chosenModel }
                        Task {
                            ollamaStatus = await ServiceHealth.ollamaStatus(
                                modelName: chosenModel, transport: model.services.transport)
                        }
                    }
                }
                Text(
                    "Needs a recent Ollama: `brew upgrade ollama`, then `ollama pull \(GlimSettings.defaultPlannerModelName)`. If steps feel slow, try `qwen3-vl:4b`."
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            }
            GlassCard(title: "Laya checker — local", systemImage: "checkmark.shield") {
                StatusRow(
                    name: "Status", detail: layaStatus.detail, isHealthy: layaStatus.isHealthy)
                Text(
                    "A second opinion on every click, running on 127.0.0.1:8791. Start it with `scripts/start-laya.sh` (see services/laya/README.md). If it's offline, every click and typing step asks you."
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            }
            GlassCard(title: "Jev checker — TypeSafe cloud", systemImage: "cloud") {
                Toggle(
                    "Use Jev as an extra checker",
                    isOn: Binding(
                        get: { model.settings.jev.isEnabled },
                        set: { isEnabled in
                            model.changeSettings { $0.jev.isEnabled = isEnabled }
                        }))
                Label(
                    "When on, your spoken goal, the app name, the window title and button labels are sent to TypeSafe's servers in the US. Never screenshots or screen text, and never for excluded apps. Turning it on needs Touch ID.",
                    systemImage: "exclamationmark.shield"
                )
                .font(.callout)
                .foregroundStyle(.orange)
                HStack {
                    SecureField(
                        hasSavedJevKey ? "Key saved in Keychain" : "TypeSafe API key",
                        text: $jevAPIKey
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 320)
                    Button("Save key") { saveJevKey() }
                        .disabled(jevAPIKey.isEmpty)
                    if hasSavedJevKey {
                        Button("Remove key", role: .destructive) { removeJevKey() }
                    }
                }
                if let keyMessage {
                    Text(keyMessage).font(.caption).foregroundStyle(.secondary)
                }
                Text(
                    "Never sent to Jev: "
                        + model.settings.jev.excludedBundleIdentifiers.sorted().joined(
                            separator: ", ")
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .task {
            plannerModelName = model.settings.plannerModelName
            async let ollama = ServiceHealth.ollamaStatus(
                modelName: model.settings.plannerModelName, transport: model.services.transport)
            async let laya = ServiceHealth.layaStatus(transport: model.services.transport)
            ollamaStatus = await ollama
            layaStatus = await laya
        }
    }

    private func saveJevKey() {
        do {
            try KeychainSecretStore().saveJevAPIKey(jevAPIKey)
            jevAPIKey = ""
            hasSavedJevKey = true
            keyMessage = "Saved in your Keychain."
        } catch {
            keyMessage = "Could not save the key: \(error)"
        }
    }

    private func removeJevKey() {
        do {
            try KeychainSecretStore().deleteJevAPIKey()
            hasSavedJevKey = false
            keyMessage = "Key removed."
        } catch {
            keyMessage = "Could not remove the key: \(error)"
        }
    }
}
