import Foundation
import Testing

@testable import GlimCore

struct AcknowledgementWaiterTests {
    let link = WatchdogLink(namePrefix: "dev.straxs.GlimTests.\(UUID().uuidString)")

    @Test func acknowledgementArrivingAfterArmingIsSeen() async throws {
        let waiter = try AcknowledgementWaiter(link: link)
        waiter.arm()

        link.post(.stopAcknowledged)

        #expect(await waiter.waitForAcknowledgement(within: .milliseconds(500)))
        waiter.stop()
    }

    @Test func silenceTimesOut() async throws {
        let waiter = try AcknowledgementWaiter(link: link)
        waiter.arm()

        #expect(!(await waiter.waitForAcknowledgement(within: .milliseconds(50))))
        waiter.stop()
    }

    @Test func staleAcknowledgementBeforeArmingIsIgnored() async throws {
        let waiter = try AcknowledgementWaiter(link: link)
        link.post(.stopAcknowledged)
        try await Task.sleep(for: .milliseconds(50))

        waiter.arm()

        #expect(!(await waiter.waitForAcknowledgement(within: .milliseconds(50))))
        waiter.stop()
    }
}
