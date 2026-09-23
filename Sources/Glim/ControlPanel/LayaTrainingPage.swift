import GlimCore
import SwiftUI

/// Saving switch, progress toward the training minimum, and one example at a time to review.
struct LayaTrainingPage: View {
    @Environment(AppModel.self) private var model
    @State private var isConfirmingDelete = false

    var body: some View {
        let summary = LayaExampleSummary(examples: model.layaExamples)
        VStack(alignment: .leading, spacing: 14) {
            savingSection
            progressSection(summary)
            if let example = model.nextUnreviewedLayaExample {
                ReviewCard(example: example)
            } else {
                Text(
                    model.layaExamples.isEmpty
                        ? "No examples yet. Turn saving on and use Glim with Laya running."
                        : "Every saved example is reviewed."
                )
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(24)
                .panelSurface(cornerRadius: 16)
            }
            if let message = model.layaTrainingMessage {
                Text(message).font(.callout).foregroundStyle(.red)
            }
        }
        .task { await model.refreshLayaExamples() }
        .confirmationDialog(
            "Delete every saved Laya example?", isPresented: $isConfirmingDelete
        ) {
            Button("Delete all examples", role: .destructive) {
                Task { await model.deleteAllLayaExamples() }
            }
        }
    }

    private var savingSection: some View {
        Toggle(
            isOn: Binding(
                get: { model.settings.savesLayaExamples },
                set: { model.setSavesLayaExamples($0) })
        ) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Save Laya examples")
                Text(
                    "Keeps each step Laya checked on this Mac, with password-like words hidden. Nothing is uploaded."
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .toggleStyle(.switch)
        .padding(14)
        .panelSurface(cornerRadius: 16)
    }

    private func progressSection(_ summary: LayaExampleSummary) -> some View {
        HStack(alignment: .top, spacing: 24) {
            stat("Saved", "\(summary.savedCount)")
            stat(
                "Reviewed",
                "\(summary.reviewedCount) / \(LayaExampleSummary.minimumReviewedExamples)")
            stat("Apps", "\(summary.appNames.count) / \(LayaExampleSummary.minimumApps)")
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text(
                    summary.meetsTrainingMinimum
                        ? "Ready: run scripts/train-laya.sh"
                        : "Training needs more reviewed examples."
                )
                .font(.callout)
                .foregroundStyle(summary.meetsTrainingMinimum ? .green : .secondary)
                Button("Delete all examples…", role: .destructive) { isConfirmingDelete = true }
                    .disabled(model.layaExamples.isEmpty)
            }
        }
        .padding(14)
        .panelSurface(cornerRadius: 16)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.weight(.semibold)).monospacedDigit()
        }
    }
}

/// One example: what was asked, what the planner and Laya said, and the owner's answer.
private struct ReviewCard: View {
    @Environment(AppModel.self) private var model
    let example: LayaExample

    private var sortedOptions: [(number: String, text: String)] {
        example.question.options
            .map { (number: $0.key, text: $0.value) }
            .sorted { (Int($0.number) ?? 0) < (Int($1.number) ?? 0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(example.question.step).font(.headline)
            Text("In \(example.question.app)\(windowSuffix) · goal: \(example.question.goal)")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("Laya \(example.layaVerdict)")
                .font(.callout)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(sortedOptions, id: \.number) { option in
                    optionRow(option)
                }
            }
            HStack {
                Button("Planner's pick was right") {
                    review(correctOption: example.plannerPick)
                }
                .keyboardShortcut(.defaultAction)
                Button("Skip") { review(correctOption: nil) }
            }
        }
        .padding(14)
        .panelSurface(cornerRadius: 16)
    }

    private var windowSuffix: String {
        example.question.windowTitle.map { " — “\($0)”" } ?? ""
    }

    private func optionRow(_ option: (number: String, text: String)) -> some View {
        let isPlannerPick = option.number == example.plannerPick
        return HStack {
            Text("[\(option.number)] \(option.text)")
                .fontWeight(isPlannerPick ? .semibold : .regular)
            if isPlannerPick {
                Text("planner's pick").font(.caption).foregroundStyle(.orange)
            }
            Spacer()
            if !isPlannerPick {
                Button("This one") { review(correctOption: option.number) }
                    .controlSize(.small)
            }
        }
    }

    private func review(correctOption: String?) {
        Task { await model.reviewLayaExample(example, correctOption: correctOption) }
    }
}
