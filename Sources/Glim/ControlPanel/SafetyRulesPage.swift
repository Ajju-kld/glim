import GlimCore
import SwiftUI

/// Forbidden and Confirm phrases, numeric limits, and "Reset to safe defaults".
struct SafetyRulesPage: View {
    @Environment(AppModel.self) private var model
    @State private var newForbiddenPhrase = ""
    @State private var newConfirmPhrase = ""
    @State private var isConfirmingReset = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(
                "Removing a phrase or raising a limit makes Glim less safe, so it needs Touch ID. Adding phrases or tightening limits applies right away."
            )
            .foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 16) {
                phraseCard(
                    title: "Forbidden — always blocked", systemImage: "nosign", tint: .red,
                    phrases: model.settings.safetyPolicy.riskWords.forbidden,
                    newPhrase: $newForbiddenPhrase
                ) { settings, phrases in
                    settings.safetyPolicy.riskWords.forbidden = phrases
                }
                phraseCard(
                    title: "Confirm — asks you", systemImage: "hand.raised", tint: .orange,
                    phrases: model.settings.safetyPolicy.riskWords.confirm,
                    newPhrase: $newConfirmPhrase
                ) { settings, phrases in
                    settings.safetyPolicy.riskWords.confirm = phrases
                }
            }
            GlassCard(title: "Limits", systemImage: "gauge.with.needle") {
                limitStepper("Actions per task", value: \.maximumActionsPerTask, range: 1...100)
                limitStepper("Tries per step", value: \.maximumTriesPerStep, range: 1...10)
                limitStepper(
                    "Actions in a row with no visible change",
                    value: \.maximumConsecutiveUnchangedActions, range: 1...10)
                limitStepper(
                    "Longest typed text (characters)", value: \.maximumTypedTextLength,
                    range: 10...5_000, step: 50)
                secondsStepper(
                    "Task time limit (seconds)", value: \.taskTimeoutSeconds, range: 30...900,
                    step: 30)
                secondsStepper(
                    "Pause between actions (seconds)", value: \.minimumSecondsBetweenActions,
                    range: 0...2, step: 0.05)
            }
            Button("Reset to safe defaults…", role: .destructive) {
                isConfirmingReset = true
            }
            .confirmationDialog(
                "Restore every safety setting to its default?", isPresented: $isConfirmingReset
            ) {
                Button("Reset", role: .destructive) {
                    Task { await model.resetToSafeDefaults() }
                }
            }
        }
    }

    private func phraseCard(
        title: String,
        systemImage: String,
        tint: Color,
        phrases: [String],
        newPhrase: Binding<String>,
        store: @escaping (inout GlimSettings, [String]) -> Void
    ) -> some View {
        GlassCard(title: title, systemImage: systemImage) {
            ForEach(phrases, id: \.self) { phrase in
                HStack {
                    Text(phrase)
                    Spacer()
                    Button {
                        var newSettings = model.settings
                        store(&newSettings, phrases.filter { $0 != phrase })
                        Task { await model.apply(newSettings) }
                    } label: {
                        Image(systemName: "minus.circle.fill").foregroundStyle(tint)
                    }
                    .buttonStyle(.plain)
                    .help("Remove “\(phrase)” (needs Touch ID)")
                }
            }
            HStack {
                TextField("Add a phrase", text: newPhrase)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { add(newPhrase, to: phrases, store: store) }
                Button("Add") { add(newPhrase, to: phrases, store: store) }
                    .disabled(newPhrase.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func add(
        _ newPhrase: Binding<String>, to phrases: [String],
        store: @escaping (inout GlimSettings, [String]) -> Void
    ) {
        let phrase = newPhrase.wrappedValue.trimmingCharacters(in: .whitespaces).lowercased()
        guard !phrase.isEmpty, !phrases.contains(phrase) else {
            return
        }
        var newSettings = model.settings
        store(&newSettings, phrases + [phrase])
        newPhrase.wrappedValue = ""
        Task { await model.apply(newSettings) }
    }

    private func limitStepper(
        _ title: String, value keyPath: WritableKeyPath<SafetyLimits, Int>, range: ClosedRange<Int>,
        step: Int = 1
    ) -> some View {
        Stepper(
            value: Binding(
                get: { model.settings.safetyPolicy.limits[keyPath: keyPath] },
                set: { newValue in
                    var newSettings = model.settings
                    newSettings.safetyPolicy.limits[keyPath: keyPath] = newValue
                    Task { await model.apply(newSettings) }
                }),
            in: range, step: step
        ) {
            HStack {
                Text(title)
                Spacer()
                Text("\(model.settings.safetyPolicy.limits[keyPath: keyPath])").monospacedDigit()
            }
        }
    }

    private func secondsStepper(
        _ title: String, value keyPath: WritableKeyPath<SafetyLimits, Double>,
        range: ClosedRange<Double>,
        step: Double
    ) -> some View {
        Stepper(
            value: Binding(
                get: { model.settings.safetyPolicy.limits[keyPath: keyPath] },
                set: { newValue in
                    var newSettings = model.settings
                    newSettings.safetyPolicy.limits[keyPath: keyPath] = newValue
                    Task { await model.apply(newSettings) }
                }),
            in: range, step: step
        ) {
            HStack {
                Text(title)
                Spacer()
                Text(
                    model.settings.safetyPolicy.limits[keyPath: keyPath],
                    format: .number.precision(.fractionLength(0...2))
                )
                .monospacedDigit()
            }
        }
    }
}
