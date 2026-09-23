import Synchronization
import Testing

@testable import GlimCore

struct ControlsWaitTests {
    @Test func readsAgainUntilTheValueIsReady() async {
        let readCount = Mutex(0)

        let value = await ControlsWait.poll(
            until: .now + .seconds(2), every: .milliseconds(1),
            read: {
                readCount.withLock { count in
                    count += 1
                    return count
                }
            },
            isReady: { $0 >= 3 })

        #expect(value == 3)
    }

    @Test func givesUpAtTheDeadlineWithTheLastRead() async {
        let readCount = Mutex(0)

        let value = await ControlsWait.poll(
            until: .now + .milliseconds(30), every: .milliseconds(5),
            read: {
                readCount.withLock { count in
                    count += 1
                    return count
                }
            },
            isReady: { _ in false })

        #expect(value > 1)
        #expect(value < 20)
    }

    @Test func readyFirstReadIsNotRepeated() async {
        let readCount = Mutex(0)

        _ = await ControlsWait.poll(
            until: .now + .seconds(2), every: .milliseconds(1),
            read: {
                readCount.withLock { count in
                    count += 1
                    return count
                }
            },
            isReady: { _ in true })

        #expect(readCount.withLock { $0 } == 1)
    }
}
