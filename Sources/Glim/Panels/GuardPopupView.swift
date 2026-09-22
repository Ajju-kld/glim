import SwiftUI

/// The red popup shown whenever a guard stops a task or the kill switch trips.
struct GuardPopupView: View {
    let title: String
    let explanation: String
    let stepNumber: Int?
    let onViewLog: @MainActor () -> Void
    let onDismiss: @MainActor () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PanelStyle.sectionSpacing) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.octagon.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.red)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                    if let stepNumber {
                        Text("Step \(stepNumber) · the task was stopped")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Text(explanation)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("View log") { onViewLog() }
                Button("OK") { onDismiss() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.glassProminent)
            }
        }
        .padding(PanelStyle.padding)
        .frame(width: PanelStyle.width)
        .overlay(alignment: .top) {
            Rectangle().fill(.red.gradient).frame(height: 4)
        }
    }
}
