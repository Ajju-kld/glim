import Foundation

/// How big the orb is, how fast its colours flow and how much its edge ripples, for each mood. Pure math, so the
/// animation can be tested without drawing.
public enum OrbMotion {
    /// Tunable: one spring beat while Glim is processing — a quick swell that settles.
    public static let springBeatSeconds = 1.1
    /// Tunable: how far the orb springs out while planning.
    private static let thinkingSpringAmplitude = 0.22
    /// Tunable: how far the orb springs out while acting.
    private static let actingSpringAmplitude = 0.12
    /// Tunable: how quickly a spring beat settles.
    private static let springDamping = 5.0
    /// Tunable: how fast a spring beat wobbles, in radians per second.
    private static let springAngularFrequency = 11.0
    /// Tunable: how much a loud voice swells the orb.
    private static let voiceSwell = 0.22
    /// Tunable: one slow breath while waiting for the person.
    private static let breathSeconds = 2.4
    /// Tunable: how much the orb breathes while waiting.
    private static let breathAmplitude = 0.05

    /// The orb's scale (1 = resting size) for `mood` at `time` seconds.
    public static func scale(for mood: OrbMood, at time: Double) -> Double {
        switch mood {
        case .listening(let level): 1 + voiceSwell * clamped(level)
        case .thinking: springBeat(at: time, amplitude: thinkingSpringAmplitude)
        case .acting: springBeat(at: time, amplitude: actingSpringAmplitude)
        case .waiting: 1 + breathAmplitude * sin(2 * .pi * time / breathSeconds)
        case .done, .alert: 1
        }
    }

    /// How fast the orb's colours flow, in mesh-seconds per second.
    public static func spinSpeed(for mood: OrbMood) -> Double {
        switch mood {
        case .listening(let level): 1.2 + 1.8 * clamped(level)
        case .thinking: 3.2
        case .acting: 2.2
        case .waiting: 0.6
        case .done: 0.4
        case .alert: 0.2
        }
    }

    /// How lively the orb's edge is, 0 (a perfect circle) to 1 (full ripple).
    public static func ripple(for mood: OrbMood) -> Double {
        switch mood {
        case .listening(let level): 0.25 + 0.75 * clamped(level)
        case .thinking: 0.7
        case .acting: 0.45
        case .waiting: 0.2
        case .done: 0.05
        case .alert: 0.3
        }
    }

    /// A damped wobble that starts and ends at 1, repeating every beat.
    private static func springBeat(at time: Double, amplitude: Double) -> Double {
        let beatTime = time - springBeatSeconds * (time / springBeatSeconds).rounded(.down)
        return 1
            + amplitude * exp(-springDamping * beatTime) * sin(springAngularFrequency * beatTime)
    }

    private static func clamped(_ level: Double) -> Double {
        min(max(level, 0), 1)
    }
}
