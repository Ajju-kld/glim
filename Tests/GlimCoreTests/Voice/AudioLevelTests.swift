import Testing

@testable import GlimCore

struct AudioLevelTests {
    @Test func silenceIsZero() {
        #expect(AudioLevel.normalizedLevel(ofSamples: [0, 0, 0, 0]) == 0)
    }

    @Test func fullScaleIsOne() {
        #expect(AudioLevel.normalizedLevel(ofSamples: [1, -1, 1, -1]) == 1)
    }

    @Test func quietSpeechIsInBetween() {
        let level = AudioLevel.normalizedLevel(ofSamples: [0.05, -0.05, 0.05, -0.05])

        #expect(level > 0.3 && level < 0.9)
    }

    @Test func noSamplesIsZero() {
        #expect(AudioLevel.normalizedLevel(ofSamples: []) == 0)
    }
}
