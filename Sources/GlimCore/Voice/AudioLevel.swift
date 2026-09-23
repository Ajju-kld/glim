import Foundation

/// Converts microphone samples into a 0…1 level for the notch pill's waveform.
public enum AudioLevel {
    /// Tunable: anything quieter than this reads as silence.
    static let silenceFloorDecibels: Float = -50

    /// The loudness of `samples` on a 0…1 scale, using decibels so quiet speech still shows.
    public static func normalizedLevel(ofSamples samples: [Float]) -> Float {
        guard !samples.isEmpty else {
            return 0
        }
        let meanSquare = samples.reduce(0) { $0 + $1 * $1 } / Float(samples.count)
        let rootMeanSquare = meanSquare.squareRoot()
        guard rootMeanSquare > 0 else {
            return 0
        }
        let decibels = 20 * log10(rootMeanSquare)
        let level = (decibels - silenceFloorDecibels) / -silenceFloorDecibels
        return min(max(level, 0), 1)
    }
}
