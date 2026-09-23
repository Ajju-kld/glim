import Foundation
import GlimCore

extension AppModel {
    /// The oldest example the owner hasn't reviewed or skipped yet.
    var nextUnreviewedLayaExample: LayaExample? {
        layaExamples.first { $0.review == nil }
    }

    func refreshLayaExamples() async {
        do {
            layaExamples = try await services.layaExamples.allExamples()
            layaTrainingMessage = nil
        } catch {
            layaTrainingMessage = error.explanation
        }
    }

    /// Records which option was right (nil skips the example), then shows the next one.
    func reviewLayaExample(_ example: LayaExample, correctOption: String?) async {
        do {
            try await services.layaExamples.saveReview(
                LayaReview(correctOption: correctOption, reviewedAt: Date()),
                forExampleID: example.id)
        } catch {
            layaTrainingMessage = error.explanation
            return
        }
        await refreshLayaExamples()
    }

    func deleteAllLayaExamples() async {
        do {
            try await services.layaExamples.deleteAll()
        } catch {
            layaTrainingMessage = error.explanation
            return
        }
        await refreshLayaExamples()
    }

    func setSavesLayaExamples(_ isOn: Bool) {
        changeSettings { settings in
            settings.savesLayaExamples = isOn
        }
    }
}
