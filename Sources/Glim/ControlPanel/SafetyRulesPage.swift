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
                "Removing a phrase or raising a limit makes Glim less safe, so it needs Touch ID. Adding phrases or tightening limits applies right away — even to a task that is running."
            )
            .foregroundStyle(.secondary)
            GlassCard(title: "Approvals", systemImage: "checkmark.shield", tint: .green) {
                Toggle(isOn: autoRunBinding) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Start low-risk plans without asking")
                        Text(
                            "Opening apps, arranging windows, and clicking or typing what you said in full-control apps. Supervised apps, quitting, Return, risky words and text you didn't say still ask."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
            }
            HStack(alignment: .top, spacing: 16) {
                phraseCard(
                    title: "Forbidden — always blocked", systemImage: "nosign", tint: .red,
                    phrases: \.safetyPolicy.riskWords.forbidden, newPhrase: $newForbiddenPhrase)
                phraseCard(
                    title: "Confirm — asks you", systemImage: "hand.raised", tint: .orange,
                    phrases: \.safetyPolicy.riskWords.confirm, newPhrase: $newConfirmPhrase)
            }
            GlassCard(title: "Limits", systemImage: "gauge.with.needle", tint: .purple) {
                limitStepper("Actions per task", value: \.maximumActionsPerTask, range: 1...100)
                limitStepper("Tries per step", value: \.maximumTriesPerStep, range: 1...10)
                limitStepper(
                    "Actions in a row with no visible change",
                    value: \.maximumConsecutiveUnchangedActions,
                    range: 1...10)
                limitStepper(
                    "Longest typed text (characters)", value: \.maximumTypedTextLength,
                    range: 10...5_000,
                    step: 50)
                secondsStepper(
                    "Task time limit (seconds)", value: \.taskTimeoutSeconds, range: 30...900,
                    step: 30)
                secondsStepper(
                    "Pause between actions (seconds)", value: \.minimumSecondsBetweenActions,
                    range: 0...2,
                    step: 0.05)
            }
            Button("Reset to safe defaults…", role: .destructive) {
                isConfirmingReset = true
            }
            .confirmationDialog(
                "Restore every safety setting to its default?", isPresented: $isConfirmingReset
            ) {
                Button("Reset", role: .destructive) {
                    model.resetToSafeDefaults()
                }
            }
        }
    }

    /// Turning this on needs Touch ID; if the prompt is cancelled the switch springs back.
    private var autoRunBinding: Binding<Bool> {
        Binding(
            get: { model.settings.safetyPolicy.autoRunsLowRiskPlans },
            set: { newValue in
                model.changeSettings { $0.safetyPolicy.autoRunsLowRiskPlans = newValue }
            })
    }

    private func phraseCard(
        title: String,
        systemImage: String,
        tint: Color,
        phrases phrasesKeyPath: WritableKeyPath<GlimSettings, [String]>,
        newPhrase: Binding<String>
    ) -> some View {
        GlassCard(title: title, systemImage: systemImage, tint: tint) {
            ForEach(model.settings[keyPath: phrasesKeyPath], id: \.self) { phrase in
                HStack {
                    Text(phrase)
                    Spacer()
                    Button {
                        model.changeSettings {
                            $0[keyPath: phrasesKeyPath].removeAll { $0 == phrase }
                        }
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
                    .onSubmit { add(newPhrase, to: phrasesKeyPath) }
                Button("Add") { add(newPhrase, to: phrasesKeyPath) }
                    .disabled(newPhrase.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func add(
        _ newPhrase: Binding<String>, to phrasesKeyPath: WritableKeyPath<GlimSettings, [String]>
    ) {
        let phrase = newPhrase.wrappedValue.trimmingCharacters(in: .whitespaces).lowercased()
        guard !phrase.isEmpty else {
            return
        }
        newPhrase.wrappedValue = ""
        model.changeSettings { settings in
            if !settings[keyPath: phrasesKeyPath].contains(phrase) {
                settings[keyPath: phrasesKeyPath].append(phrase)
            }
        }
    }

    private func limitStepper(
        _ title: String, value keyPath: WritableKeyPath<SafetyLimits, Int>, range: ClosedRange<Int>,
        step: Int = 1
    ) -> some View {
        Stepper(
            value: Binding(
                get: { model.settings.safetyPolicy.limits[keyPath: keyPath] },
                set: { newValue in
                    model.changeSettings { $0.safetyPolicy.limits[keyPath: keyPath] = newValue }
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
                    model.changeSettings { $0.safetyPolicy.limits[keyPath: keyPath] = newValue }
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
