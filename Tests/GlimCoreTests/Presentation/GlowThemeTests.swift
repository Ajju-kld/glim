import Foundation
import Testing

@testable import GlimCore

/// The screen glow's look: Glim's orb colours by default, or a preset or the owner's own
/// colours, saved with the settings.
struct GlowThemeTests {
    static let red = GlowColour(red: 1, green: 0, blue: 0)
    static let green = GlowColour(red: 0, green: 1, blue: 0)
    static let blue = GlowColour(red: 0, green: 0, blue: 1)
    static let white = GlowColour(red: 1, green: 1, blue: 1)
    static let black = GlowColour(red: 0, green: 0, blue: 0)

    @Test func glowUsesTheOrbColoursByDefault() {
        #expect(GlimSettings.safeDefaults.glowTheme.style == .orbColours)
        #expect(
            GlowTheme.standard.colours(for: .thinking) == OrbPalette.colours(for: .thinking))
    }

    @Test func orbColoursFollowTheMood() {
        #expect(
            GlowTheme.standard.colours(for: .thinking)
                != GlowTheme.standard.colours(for: .acting))
    }

    @Test func singleColourIsTheChosenColour() {
        var theme = GlowTheme.standard
        theme.style = .singleColour
        theme.singleColour = Self.green

        #expect(theme.colours(for: .listening(level: 0.5)) == [Self.green])
    }

    @Test func customThemeUsesTheOwnersColours() {
        var theme = GlowTheme.standard
        theme.style = .custom
        theme.customColours = [Self.red, Self.blue, Self.green]

        #expect(theme.colours(for: .thinking) == [Self.red, Self.blue, Self.green])
    }

    @Test func rainbowHasManyColours() {
        var theme = GlowTheme.standard
        theme.style = .rainbow

        #expect(theme.colours(for: .acting).count >= 5)
    }

    /// A stop or block always glows red, whatever the theme, so it can't be missed.
    @Test(arguments: GlowStyle.allCases)
    func alertIsAlwaysRed(style: GlowStyle) {
        var theme = GlowTheme.standard
        theme.style = style

        #expect(theme.colours(for: .alert) == OrbPalette.colours(for: .alert))
    }

    @Test func customColoursAreKeptBetweenTwoAndFour() {
        let tooFew = GlowTheme(
            style: .custom, singleColour: Self.red, customColours: [Self.red])
        let tooMany = GlowTheme(
            style: .custom, singleColour: Self.red,
            customColours: [Self.red, Self.green, Self.blue, Self.white, Self.black])

        #expect(tooFew.customColours.count == GlowTheme.minimumCustomColours)
        #expect(tooMany.customColours == [Self.red, Self.green, Self.blue, Self.white])
    }

    @Test func colourChannelsStayInRange() {
        let colour = GlowColour(red: 1.4, green: -0.2, blue: 0.5)

        #expect(colour == GlowColour(red: 1, green: 0, blue: 0.5))
    }

    @Test func chosenThemeSurvivesSaving() throws {
        var settings = GlimSettings.safeDefaults
        settings.glowTheme = GlowTheme(
            style: .custom, singleColour: Self.blue, customColours: [Self.red, Self.green])

        let loaded = try JSONDecoder().decode(
            GlimSettings.self, from: JSONEncoder().encode(settings))

        #expect(loaded.glowTheme == settings.glowTheme)
    }

    /// Settings saved before the glow existed still load, with the orb colours.
    @Test func settingsSavedBeforeTheGlowLoadWithTheOrbColours() throws {
        var saved =
            try JSONSerialization.jsonObject(
                with: JSONEncoder().encode(GlimSettings.safeDefaults)) as? [String: Any] ?? [:]
        saved.removeValue(forKey: "glowTheme")

        let loaded = try JSONDecoder().decode(
            GlimSettings.self, from: JSONSerialization.data(withJSONObject: saved))

        #expect(loaded.glowTheme == .standard)
    }

    /// The glow's look changes nothing about safety, so it saves without Touch ID.
    @Test func changingTheGlowIsNotASafetyLoosening() {
        var changed = GlimSettings.safeDefaults
        changed.glowTheme.style = .rainbow

        #expect(SafetyChangeClassifier.loosenings(from: .safeDefaults, to: changed).isEmpty)
    }
}
