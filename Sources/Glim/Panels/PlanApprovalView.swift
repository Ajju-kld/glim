import GlimCore
import SwiftUI

/// "Approve this plan?" — every step with its app's tier. Approve is click-only on purpose.
struct PlanApprovalView: View {
    let plan: ScreenedPlan
    let onDecision: @MainActor (Bool) -> Void
    private let deadline: Date

    init(plan: ScreenedPlan, timeout: Duration, onDecision: @escaping @MainActor (Bool) -> Void) {
        self.plan = plan
        self.onDecision = onDecision
        deadline = Date.now.addingTimeInterval(TimeInterval(timeout.components.seconds))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PanelStyle.sectionSpacing) {
            VStack(alignment: .leading, spacing: 4) {
                Label("Approve this plan?", systemImage: "list.bullet.clipboard")
                    .font(.title3.weight(.semibold))
                Text("“\(plan.goal)”")
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            VStack(alignment: .leading, spacing: 10) {
                ForEach(plan.steps, id: \.number) { step in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(step.number)")
                            .font(.caption.weight(.bold).monospacedDigit())
                            .frame(width: 22, height: 22)
                            .background(.quaternary, in: .circle)
                        Text(step.action.summary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        TierBadge(tier: step.tier)
                    }
                }
            }
            .padding(PanelStyle.sectionSpacing)
            .glassEffect(.regular, in: .rect(cornerRadius: PanelStyle.cornerRadius))
            HStack {
                CountdownText(deadline: deadline)
                Spacer()
                ClickOnlyButton(title: "Cancel") { onDecision(false) }
                ClickOnlyButton(title: "Approve") { onDecision(true) }
                    .buttonStyle(.glassProminent)
            }
        }
        .padding(PanelStyle.padding)
        .frame(width: PanelStyle.width)
    }
}
