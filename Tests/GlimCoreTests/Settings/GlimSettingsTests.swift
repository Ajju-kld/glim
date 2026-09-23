import Foundation
import Testing

@testable import GlimCore

struct GlimSettingsTests {
    @Test func savingLayaExamplesIsOffByDefault() {
        #expect(!GlimSettings.safeDefaults.savesLayaExamples)
    }

    /// Settings saved before the switch existed still load, with the switch off.
    @Test func settingsSavedBeforeTheSwitchLoadWithItOff() throws {
        var saved =
            try JSONSerialization.jsonObject(
                with: JSONEncoder().encode(GlimSettings.safeDefaults)) as? [String: Any] ?? [:]
        saved.removeValue(forKey: "savesLayaExamples")

        let loaded = try JSONDecoder().decode(
            GlimSettings.self, from: JSONSerialization.data(withJSONObject: saved))

        #expect(!loaded.savesLayaExamples)
        #expect(loaded.plannerModelName == GlimSettings.safeDefaults.plannerModelName)
    }

    @Test func switchSurvivesSaving() throws {
        var settings = GlimSettings.safeDefaults
        settings.savesLayaExamples = true

        let loaded = try JSONDecoder().decode(
            GlimSettings.self, from: JSONEncoder().encode(settings))

        #expect(loaded.savesLayaExamples)
    }
}
