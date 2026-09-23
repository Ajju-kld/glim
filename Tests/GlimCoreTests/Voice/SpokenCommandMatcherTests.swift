import Testing

@testable import GlimCore

struct SpokenCommandMatcherTests {
    @Test(arguments: ["stop", "Stop.", "cancel", "CANCEL!", "stop glim", "Glim, stop"])
    func stopWordsAloneAreStopCommandsEvenWhenIdle(transcript: String) {
        #expect(SpokenCommandMatcher.isStopCommand(transcript, whileTaskIsRunning: false))
    }

    @Test(arguments: ["stop the music", "cancel my meeting", "open the stopwatch", ""])
    func requestsThatMentionStoppingAreTasksWhenIdle(transcript: String) {
        #expect(!SpokenCommandMatcher.isStopCommand(transcript, whileTaskIsRunning: false))
    }

    @Test(arguments: ["wait stop", "no no cancel that", "please stop now"])
    func anyStopWordStopsARunningTask(transcript: String) {
        #expect(SpokenCommandMatcher.isStopCommand(transcript, whileTaskIsRunning: true))
    }

    @Test func similarWordsDoNotStopARunningTask() {
        #expect(!SpokenCommandMatcher.isStopCommand("open the stopwatch", whileTaskIsRunning: true))
    }
}
