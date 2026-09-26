import Testing

@testable import GlimCore

/// What the screen glow looks like for each mood. The glow's window redraws only when this
/// changes, so tiny voice-level changes must not change it.
struct EdgeGlowMotionTests {
    @Test func louderVoiceGlowsBrighter() {
        let quiet = EdgeGlowAppearance(theme: .standard, mood: .listening(level: 0.1))
        let loud = EdgeGlowAppearance(theme: .standard, mood: .listening(level: 0.9))

        #expect(loud.brightness > quiet.brightness)
    }

    /// The voice level changes many times a second; only a clear step changes the glow.
    @Test func smallVoiceChangesDontChangeTheGlow() {
        #expect(
            EdgeGlowAppearance(theme: .standard, mood: .listening(level: 0.51))
                == EdgeGlowAppearance(theme: .standard, mood: .listening(level: 0.54)))
    }

    @Test func thinkingAndActingPulse() {
        #expect(EdgeGlowAppearance(theme: .standard, mood: .thinking).pulses)
        #expect(EdgeGlowAppearance(theme: .standard, mood: .acting).pulses)
        #expect(!EdgeGlowAppearance(theme: .standard, mood: .listening(level: 0.5)).pulses)
        #expect(!EdgeGlowAppearance(theme: .standard, mood: nil).pulses)
    }

    @Test func stopGlowsFullyInRed() {
        let alert = EdgeGlowAppearance(theme: .standard, mood: .alert)

        #expect(alert.brightness == 1)
        #expect(alert.colours == OrbPalette.colours(for: .alert))
    }

    @Test func idleSessionUsesTheListeningColoursAtRest() {
        let resting = EdgeGlowAppearance(theme: .standard, mood: nil)

        #expect(resting.colours == OrbPalette.colours(for: .listening(level: 0)))
        #expect(resting.brightness == EdgeGlowMotion.restingBrightness)
    }

    @Test(arguments: [
        OrbMood.listening(level: 1), .listening(level: 7), .thinking, .acting, .waiting, .done,
        .alert,
    ])
    func brightnessAndPulseStayInRange(mood: OrbMood) {
        let appearance = EdgeGlowAppearance(theme: .standard, mood: mood)

        #expect((0...1).contains(appearance.brightness))
        if appearance.pulses {
            #expect((0...1).contains(appearance.brightness + EdgeGlowMotion.pulseDepth))
        }
    }

    @Test func themeColoursAreUsed() {
        var theme = GlowTheme.standard
        theme.style = .singleColour
        theme.singleColour = GlowColour(red: 0, green: 1, blue: 0)

        #expect(
            EdgeGlowAppearance(theme: theme, mood: .thinking).colours == [
                GlowColour(red: 0, green: 1, blue: 0)
            ])
    }

    @Test func colourRingTurnsSlowly() {
        #expect(EdgeGlowMotion.secondsPerTurn > 5)
    }
}
