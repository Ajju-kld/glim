import GlimCore
import SwiftUI

/// "Allow this step?" — the app, the control (or, for a click found by sight, the screenshot
/// with the spot marked), the exact text, and every reason Glim is asking.
struct ConfirmationView: View {
    let request: ConfirmationRequest
    let onDecision: @MainActor (Bool) -> Void
    private let deadline: Date

    init(
        request: ConfirmationRequest, timeout: Duration,
        onDecision: @escaping @MainActor (Bool) -> Void
    ) {
        self.request = request
        self.onDecision = onDecision
        deadline = Date.now.addingTimeInterval(TimeInterval(timeout.components.seconds))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PanelStyle.sectionSpacing) {
            Label("Allow this step?", systemImage: "hand.raised.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.orange)
            Text(request.step.action.summary)
                .font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                GridRow {
                    Text("App").foregroundStyle(.secondary)
                    HStack {
                        Text(request.appName)
                        TierBadge(tier: request.step.tier)
                    }
                }
                if let elementLabel = request.elementLabel {
                    GridRow {
                        Text("Control").foregroundStyle(.secondary)
                        Text("“\(elementLabel)”")
                    }
                }
                if let visualClick = request.visualClick {
                    GridRow {
                        Text("Seen").foregroundStyle(.secondary)
                        Text("“\(visualClick.target.description)”")
                    }
                }
                if let textToType = request.textToType {
                    GridRow(alignment: .top) {
                        Text("Text").foregroundStyle(.secondary)
                        Text(textToType)
                            .font(.body.monospaced())
                            .textSelection(.enabled)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.quaternary, in: .rect(cornerRadius: 8))
                    }
                }
            }
            if let visualClick = request.visualClick {
                VisualClickPreview(visualClick: visualClick)
            }
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(request.reasons.enumerated()), id: \.offset) { _, reason in
                    Label(reason.explanation, systemImage: "exclamationmark.triangle.fill")
                        .symbolRenderingMode(.multicolor)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(PanelStyle.sectionSpacing)
            .glassEffect(.regular, in: .rect(cornerRadius: PanelStyle.cornerRadius))
            HStack {
                CountdownText(deadline: deadline)
                Spacer()
                ClickOnlyButton(title: "Stop", role: .destructive) { onDecision(false) }
                ClickOnlyButton(title: "Allow once") { onDecision(true) }
                    .buttonStyle(.glassProminent)
            }
        }
        .padding(PanelStyle.padding)
        .frame(width: PanelStyle.width)
    }
}
