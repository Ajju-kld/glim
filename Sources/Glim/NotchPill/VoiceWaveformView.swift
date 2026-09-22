import SwiftUI

/// Bars that dance with the microphone level while the talk key is held.
struct VoiceWaveformView: View {
    private static let barCount = 5
    private static let minimumBarFraction: CGFloat = 0.18
    /// Tunable: how fast the bars ripple.
    private static let rippleSpeed = 9.0

    let level: Float

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { geometry in
                HStack(alignment: .center, spacing: 2) {
                    ForEach(0..<Self.barCount, id: \.self) { barIndex in
                        Capsule()
                            .fill(.cyan)
                            .frame(
                                height: barHeight(
                                    barIndex: barIndex, time: time, maximum: geometry.size.height))
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    private func barHeight(barIndex: Int, time: TimeInterval, maximum: CGFloat) -> CGFloat {
        let ripple = (sin(time * Self.rippleSpeed + Double(barIndex)) + 1) / 2
        let fraction =
            Self.minimumBarFraction + (1 - Self.minimumBarFraction) * CGFloat(level)
            * CGFloat(ripple)
        return max(maximum * fraction, 2)
    }
}
