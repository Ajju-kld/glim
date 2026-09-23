import GlimCore
import SwiftUI

/// Shows the plan approval, confirmation and guard panels, and answers the runner's questions.
/// Approval is by mouse click only; silence for 60 seconds cancels (spec §16, item 6).
@MainActor
final class DecisionPresenter: PersonDecisions {
    /// Business rule: an unanswered panel cancels after this long.
    static let decisionTimeout = Duration.seconds(60)

    private weak var model: AppModel?
    private var pendingDecisions: [PendingDecision] = []
    private var guardPanels: [DecisionPanel] = []

    init(model: AppModel) {
        self.model = model
    }

    func approvePlan(_ plan: ScreenedPlan) async -> Bool {
        await decide { resolve in
            PlanApprovalView(plan: plan, timeout: Self.decisionTimeout, onDecision: resolve)
        }
    }

    func confirmAction(_ request: ConfirmationRequest) async -> Bool {
        await decide { resolve in
            ConfirmationView(request: request, timeout: Self.decisionTimeout, onDecision: resolve)
        }
    }

    func showGuardPopup(title: String, explanation: String, stepNumber: Int?) {
        let panelHolder = DecisionPanelHolder()
        let popup = GuardPopupView(
            title: title, explanation: explanation, stepNumber: stepNumber,
            onViewLog: { [weak self] in
                self?.closeGuardPanel(panelHolder.panel)
                self?.model?.openControlPanel(on: .activityLog)
            },
            onDismiss: { [weak self] in
                self?.closeGuardPanel(panelHolder.panel)
            })
        let guardPanel = DecisionPanel(content: popup)
        panelHolder.panel = guardPanel
        guardPanels.append(guardPanel)
        guardPanel.show()
    }

    /// Answers every open decision with "no" and closes the panels (kill switch).
    func dismissAll() {
        for pendingDecision in pendingDecisions {
            pendingDecision.resolve(false)
        }
        pendingDecisions.removeAll()
        for guardPanel in guardPanels {
            guardPanel.close()
        }
        guardPanels.removeAll()
    }

    private func closeGuardPanel(_ panel: DecisionPanel?) {
        guard let panel else {
            return
        }
        panel.close()
        guardPanels.removeAll { $0 === panel }
    }

    private func decide<Content: View>(
        _ makeContent: (@escaping @MainActor (Bool) -> Void) -> Content
    ) async -> Bool {
        await withCheckedContinuation { continuation in
            let panelHolder = DecisionPanelHolder()
            let pendingDecision = PendingDecision(continuation: continuation) {
                panelHolder.panel?.close()
            }
            let decisionPanel = DecisionPanel(
                content: makeContent { answer in pendingDecision.resolve(answer) })
            panelHolder.panel = decisionPanel
            pendingDecisions.append(pendingDecision)
            decisionPanel.show()
            Task { @MainActor [weak self] in
                do {
                    try await Task.sleep(for: Self.decisionTimeout)
                } catch {
                    return
                }
                pendingDecision.resolve(false)
                self?.pendingDecisions.removeAll { $0.isResolved }
            }
        }
    }
}

/// Lets a panel's own buttons close it: the closures are built before the panel exists.
@MainActor
private final class DecisionPanelHolder {
    var panel: DecisionPanel?
}
