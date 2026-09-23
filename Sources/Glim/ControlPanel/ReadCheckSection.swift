import GlimCore
import SwiftUI

/// Reads every open app's window and shows what Glim can see in each, so apps it can't work
/// in show up before a task fails there.
struct ReadCheckSection: View {
    /// Tunable: width of each count column, so rows line up.
    private static let countColumnWidth: CGFloat = 76

    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Read check").font(.headline)
                    Text(
                        "Reads the window of every open app, without clicking or switching, and shows how many controls Glim can see."
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if model.isReadCheckRunning {
                    ProgressView().controlSize(.small)
                }
                Button("Check open apps") {
                    Task { await model.runReadCheck() }
                }
                .disabled(!model.canRunReadCheck)
            }
            if !model.readCheckResults.isEmpty {
                resultsTable
            }
        }
        .padding(14)
        .panelSurface(cornerRadius: 16)
    }

    private var resultsTable: some View {
        VStack(spacing: 6) {
            HStack {
                Text("App").frame(maxWidth: .infinity, alignment: .leading)
                countHeader("Controls")
                countHeader("Greyed")
                countHeader("No name")
                Text("Result").frame(width: 150, alignment: .leading)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            ForEach(model.readCheckResults) { result in
                row(for: result)
            }
        }
    }

    private func countHeader(_ title: String) -> some View {
        Text(title).frame(width: Self.countColumnWidth, alignment: .trailing)
    }

    private func row(for result: ReadCheckResult) -> some View {
        let counts = Self.counts(of: result.outcome)
        return HStack {
            Text(result.appName).frame(maxWidth: .infinity, alignment: .leading)
            countCell(counts.map { "\($0.listed)\($0.wasCutOff ? "+" : "")" })
            countCell(counts.map { "\($0.greyedOut)" })
            countCell(counts.map { "\($0.unnamed)" })
            Label(Self.verdict(of: result.outcome), systemImage: Self.symbol(of: result.outcome))
                .foregroundStyle(Self.color(of: result.outcome))
                .frame(width: 150, alignment: .leading)
                .help(Self.detail(of: result.outcome))
        }
        .font(.callout)
    }

    private func countCell(_ text: String?) -> some View {
        Text(text ?? "–")
            .monospacedDigit()
            .frame(width: Self.countColumnWidth, alignment: .trailing)
    }

    private static func counts(of outcome: ReadCheckOutcome) -> ControlCounts? {
        switch outcome {
        case .readable(let counts), .thin(let counts), .nothingReadable(let counts): counts
        case .couldNotRead, .skipped: nil
        }
    }

    private static func verdict(of outcome: ReadCheckOutcome) -> String {
        switch outcome {
        case .readable: "Readable"
        case .thin: "Thin"
        case .nothingReadable: "Nothing readable"
        case .couldNotRead: "Couldn't read"
        case .skipped: "Skipped"
        }
    }

    private static func detail(of outcome: ReadCheckOutcome) -> String {
        switch outcome {
        case .readable: "Glim can see this window's controls."
        case .thin:
            "Fewer than \(ReadCheck.thinControlLimit) controls: Glim may see only part of this window."
        case .nothingReadable: "This window shows Glim no controls it can click."
        case .couldNotRead(let reason): reason
        case .skipped(let reason): "Not read: \(reason)."
        }
    }

    private static func symbol(of outcome: ReadCheckOutcome) -> String {
        switch outcome {
        case .readable: "checkmark.circle.fill"
        case .thin: "exclamationmark.triangle.fill"
        case .nothingReadable, .couldNotRead: "xmark.circle.fill"
        case .skipped: "minus.circle"
        }
    }

    private static func color(of outcome: ReadCheckOutcome) -> Color {
        switch outcome {
        case .readable: .green
        case .thin: .orange
        case .nothingReadable, .couldNotRead: .red
        case .skipped: .secondary
        }
    }
}
