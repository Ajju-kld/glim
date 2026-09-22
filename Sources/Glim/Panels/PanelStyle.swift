import GlimCore
import SwiftUI

/// Shared layout values for Glim's panels (8-point rhythm).
enum PanelStyle {
    static let width: CGFloat = 460
    static let padding: CGFloat = 24
    static let sectionSpacing: CGFloat = 16
    static let cornerRadius: CGFloat = 14

    static func color(for tier: TrustTier?) -> Color {
        switch tier {
        case .fullControl: .green
        case .supervised: .orange
        case .readOnly: .blue
        case .neverTouch: .red
        case nil: .secondary
        }
    }
}

/// A small coloured capsule naming an app's trust tier.
struct TierBadge: View {
    let tier: TrustTier?

    var body: some View {
        Text(tier?.displayName ?? "Glim")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(PanelStyle.color(for: tier))
            .background(PanelStyle.color(for: tier).opacity(0.15), in: .capsule)
    }
}

/// "Cancels in 42 s", counting down to the decision timeout.
struct CountdownText: View {
    let deadline: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let secondsLeft = max(0, Int(deadline.timeIntervalSince(timeline.date).rounded(.up)))
            Text("Cancels in \(secondsLeft) s")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}
