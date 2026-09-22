import GlimCore
import SwiftUI

/// The pill's content: an indicator, one line of status, and ■ to stop while Glim works.
struct NotchPillView: View {
    private static let bottomCornerRadius: CGFloat = 22
    private static let indicatorSize: CGFloat = 22

    @Environment(AppModel.self) private var model
    let notchHeight: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: notchHeight)
            HStack(spacing: 12) {
                indicator
                    .frame(width: Self.indicatorSize, height: Self.indicatorSize)
                Text(statusText)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.head)
                    .foregroundStyle(.white)
                    .contentTransition(.opacity)
                Spacer(minLength: 0)
                if showsStopButton {
                    Button {
                        model.stopEverything()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(.red.opacity(0.85), in: .circle)
                    }
                    .buttonStyle(.plain)
                    .help("Stop Glim (\(HotkeyCombo.killSwitch.displayName))")
                }
            }
            .padding(.horizontal, 20)
            .frame(height: NotchGeometry.contentHeight)
        }
        .background(pillShape.fill(.black))
        .overlay(
            pillShape.strokeBorder(
                glowColor.opacity(model.pillStatus.isAlert ? 0.9 : 0.35), lineWidth: 1.5)
        )
        .shadow(color: glowColor.opacity(0.45), radius: 14)
        .animation(.smooth(duration: 0.3), value: model.pillStatus)
    }

    private var pillShape: some InsettableShape {
        UnevenRoundedRectangle(
            topLeadingRadius: notchHeight > 0 ? 0 : Self.bottomCornerRadius,
            bottomLeadingRadius: Self.bottomCornerRadius,
            bottomTrailingRadius: Self.bottomCornerRadius,
            topTrailingRadius: notchHeight > 0 ? 0 : Self.bottomCornerRadius,
            style: .continuous)
    }

    @ViewBuilder
    private var indicator: some View {
        switch model.pillStatus {
        case .listening(_, let level):
            VoiceWaveformView(level: level)
        case .thinking:
            ProgressView()
                .controlSize(.small)
                .tint(.white)
        case .waitingForYou:
            Image(systemName: "hand.raised.fill").foregroundStyle(.orange)
        case .acting:
            Image(systemName: "bolt.fill").foregroundStyle(.green)
                .symbolEffect(.pulse)
        case .done:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .stopped:
            Image(systemName: "exclamationmark.octagon.fill").foregroundStyle(.red)
        case .hidden:
            EmptyView()
        }
    }

    private var statusText: String {
        switch model.pillStatus {
        case .listening(let transcript, _): transcript.isEmpty ? "Listening…" : transcript
        case .thinking: "Planning…"
        case .waitingForYou: "Waiting for you"
        case .acting(let stepNumber, let totalSteps, let summary):
            "\(stepNumber)/\(totalSteps)  \(summary)"
        case .done(let message): message
        case .stopped(let reason): reason
        case .hidden: ""
        }
    }

    private var showsStopButton: Bool {
        switch model.pillStatus {
        case .thinking, .waitingForYou, .acting: true
        case .listening, .done, .stopped, .hidden: false
        }
    }

    private var glowColor: Color {
        switch model.pillStatus {
        case .listening: .cyan
        case .thinking: .purple
        case .waitingForYou: .orange
        case .acting, .done: .green
        case .stopped: .red
        case .hidden: .clear
        }
    }
}
