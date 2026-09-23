import GlimCore
import SwiftUI

/// Connects the pill to the app model.
struct NotchPillHost: View {
    @Environment(AppModel.self) private var model
    let notchSize: CGSize
    let mergesWithNotch: Bool

    var body: some View {
        NotchPillView(
            status: model.pillStatus, notchSize: notchSize, mergesWithNotch: mergesWithNotch,
            onStop: { model.stopEverything() })
    }
}

/// The notch pill. It springs out of the notch when Glim listens, shows the torus orb and one
/// line of status, and shrinks back into the notch when the request is over.
struct NotchPillView: View {
    /// Tunable: the spring that grows the pill out of the notch — a little bounce.
    private static let growSpring = Animation.spring(response: 0.46, dampingFraction: 0.64)
    /// Tunable: the spring that tucks the pill back into the notch — no bounce.
    private static let shrinkSpring = Animation.spring(response: 0.36, dampingFraction: 0.92)
    /// Tunable: the spring for size changes between states, such as words arriving.
    private static let resizeSpring = Animation.spring(response: 0.4, dampingFraction: 0.72)
    /// Tunable: bottom corner radius when open, and when tucked into the notch.
    private static let openCornerRadius: CGFloat = 26
    private static let tuckedCornerRadius: CGFloat = 10
    /// Tunable: the orb's size inside the pill.
    private static let orbSize: CGFloat = 50

    let status: PillStatus
    let notchSize: CGSize
    let mergesWithNotch: Bool
    let onStop: () -> Void

    /// The last status that wasn't hidden, so the content stays put while the pill shrinks.
    @State private var shownStatus = PillStatus.done(message: "")
    @State private var isOpen = false

    var body: some View {
        let pillSize = isOpen ? PillLayout.size(for: shownStatus, notchSize: notchSize) : notchSize
        let shoulders = mergesWithNotch ? 2 * NotchPillShape.shoulderSize : 0
        let shape = NotchPillShape(
            bottomCornerRadius: isOpen ? Self.openCornerRadius : Self.tuckedCornerRadius,
            mergesWithNotch: mergesWithNotch)
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                shape.fill(.black)
                content
                    .padding(.top, notchSize.height)
                    .padding(.horizontal, NotchPillShape.shoulderSize)
                    .opacity(isOpen ? 1 : 0)
                    .blur(radius: isOpen ? 0 : 6)
            }
            .frame(width: pillSize.width + shoulders, height: pillSize.height)
            .clipShape(shape)
            .overlay(
                shape.stroke(accent.opacity(isOpen ? 0.45 : 0), lineWidth: 1)
            )
            .shadow(color: accent.opacity(isOpen ? 0.5 : 0), radius: 16, y: 2)
            .animation(Self.resizeSpring, value: pillSize)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: status, initial: true) { _, newStatus in
            follow(newStatus)
        }
    }

    private func follow(_ newStatus: PillStatus) {
        guard newStatus != .hidden else {
            withAnimation(Self.shrinkSpring) { isOpen = false }
            return
        }
        shownStatus = newStatus
        if !isOpen {
            withAnimation(Self.growSpring) { isOpen = true }
        }
    }

    // MARK: - Content

    private var content: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                GlimOrbView(mood: shownStatus.orbMood ?? .done)
                    .frame(width: Self.orbSize, height: Self.orbSize)
                VStack(alignment: .leading, spacing: 1) {
                    if detail == nil {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    } else {
                        Text(title)
                            .font(.system(size: 10.5, weight: .bold))
                            .tracking(0.8)
                            .textCase(.uppercase)
                            .foregroundStyle(accent)
                            .contentTransition(.numericText())
                    }
                    if let detail {
                        Text(detail)
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .truncationMode(.head)
                            .contentTransition(.opacity)
                    }
                }
                .animation(.smooth(duration: 0.25), value: title)
                Spacer(minLength: 0)
                if shownStatus.offersStop {
                    stopButton
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, 16)
            .frame(maxHeight: .infinity)
            if case .acting(let stepNumber, let totalSteps, _) = shownStatus {
                stepProgress(done: stepNumber, of: totalSteps)
            }
        }
        .frame(height: PillLayout.contentHeight)
        .animation(Self.resizeSpring, value: shownStatus.offersStop)
    }

    private var stopButton: some View {
        Button(action: onStop) {
            Image(systemName: "stop.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(.red.gradient, in: .circle)
        }
        .buttonStyle(.plain)
        .help("Stop Glim (\(HotkeyCombo.killSwitch.displayName))")
    }

    private func stepProgress(done stepNumber: Int, of totalSteps: Int) -> some View {
        GeometryReader { geometry in
            Capsule()
                .fill(accent.gradient)
                .frame(
                    width: geometry.size.width * CGFloat(stepNumber) / CGFloat(max(totalSteps, 1))
                )
                .animation(Self.resizeSpring, value: stepNumber)
        }
        .frame(height: 3)
        .padding(.horizontal, 20)
        .padding(.bottom, 6)
    }

    // MARK: - Words and colors

    private var title: String {
        switch shownStatus {
        case .listening: "Listening"
        case .thinking: "Thinking"
        case .waitingForYou: "Needs you"
        case .acting(let stepNumber, let totalSteps, _): "Step \(stepNumber) of \(totalSteps)"
        case .done(let message): message
        case .stopped: "Stopped"
        case .hidden: ""
        }
    }

    private var detail: String? {
        switch shownStatus {
        case .listening(let transcript, _): transcript.isEmpty ? "Say what you want…" : transcript
        case .thinking: "Planning your request"
        case .waitingForYou: "Check the panel on screen"
        case .acting(_, _, let summary): summary
        case .stopped(let reason): reason
        case .done, .hidden: nil
        }
    }

    private var accent: Color {
        switch shownStatus {
        case .listening: .cyan
        case .thinking: .purple
        case .waitingForYou: .orange
        case .acting, .done: .green
        case .stopped: .red
        case .hidden: .clear
        }
    }
}
