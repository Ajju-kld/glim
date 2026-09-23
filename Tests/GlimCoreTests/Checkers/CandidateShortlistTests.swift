import Testing

@testable import GlimCore

struct CandidateShortlistTests {
    /// "song" is in every playlist row, so it says little; "next" is in one control, so it
    /// decides. Spotify's Next was crowded out when every shared word counted the same.
    @Test func rareSharedWordOutranksACommonOne() {
        let labels = (1...40).map { "Liked Songs Playlist \($0)" } + ["Next"]

        let relevant = CandidateShortlist.relevantLabels(
            labels, to: "change the song and play the next one", limit: 5)

        #expect(relevant.first == "Next")
    }

    @Test func shortlistPutsTheRareMatchFirst() {
        let rows = (1...40).map { number in
            UIElementSnapshot.fixture(number: number, label: "Liked Songs Playlist \(number)")
        }
        let nextButton = UIElementSnapshot.fixture(number: 41, label: "Next")

        let shortlist = CandidateShortlist.shortlist(
            rows + [nextButton], targetDescription: "next song", limit: 5)

        #expect(shortlist.first == nextButton)
    }

    @Test func labelsSharingNoWordFallBackToListOrder() {
        let relevant = CandidateShortlist.relevantLabels(
            ["Alpha", "Beta", "Gamma"], to: "open settings", limit: 2)

        #expect(relevant == ["Alpha", "Beta"])
    }
}
