import Foundation
import Testing

@testable import GlimCore

/// After a click or Return in a web browser the next page loads for a moment; the next step
/// must read the loaded page, not the one Glim saw right after acting.
struct PageLoadSettleTests {
    static let chrome = "com.google.Chrome"
    static let browserApp = ResolvedApp(
        identity: AppIdentity(
            bundleIdentifier: chrome, displayName: "Google Chrome", hasValidSignature: true),
        bundleURL: nil, processIdentifier: 700)

    static func screen(_ pageText: String, title: String = "Google") -> ScreenSnapshot {
        ScreenSnapshot(
            app: browserApp, windowTitle: title,
            table: ElementTable(
                elements: [UIElementSnapshot.fixture(number: 1, label: pageText)],
                handleIndexByElementNumber: [1: 1], readableText: pageText, wasTruncated: false))
    }

    @Test(arguments: [
        StepAction.click(appName: "Google Chrome", target: "first search result"),
        StepAction.pressKey(appName: "Google Chrome", key: .returnKey),
    ])
    func clickOrReturnInABrowserWaitsForThePage(action: StepAction) {
        #expect(PageLoadSettle.waitsForPage(after: action, inAppWithBundleIdentifier: Self.chrome))
    }

    @Test(arguments: ["com.apple.Safari", "org.mozilla.firefox", "com.brave.Browser"])
    func otherBrowsersWaitToo(bundleIdentifier: String) {
        let pressReturn = StepAction.pressKey(appName: "Browser", key: .returnKey)

        #expect(
            PageLoadSettle.waitsForPage(
                after: pressReturn, inAppWithBundleIdentifier: bundleIdentifier))
    }

    @Test(arguments: [
        StepAction.typeText(appName: "Google Chrome", target: "search bar", text: "weather"),
        StepAction.pressKey(appName: "Google Chrome", key: .tab),
        StepAction.scroll(appName: "Google Chrome", direction: .down),
    ])
    func stepsThatDontLoadAPageDontWait(action: StepAction) {
        #expect(!PageLoadSettle.waitsForPage(after: action, inAppWithBundleIdentifier: Self.chrome))
    }

    @Test func appsThatArentBrowsersDontWait() {
        let click = StepAction.click(appName: "Testbed", target: "New Item")

        #expect(
            !PageLoadSettle.waitsForPage(
                after: click, inAppWithBundleIdentifier: "dev.straxs.Glim.Testbed"))
    }

    @Test func firstReadIsNeverSettled() {
        #expect(
            !PageLoadSettle.hasSettled(
                Self.screen("results"), previous: nil, before: Self.screen("search box")))
    }

    @Test func pageStillShowingWhatWasThereBeforeIsNotSettled() {
        let before = Self.screen("search box")

        #expect(!PageLoadSettle.hasSettled(before, previous: before, before: before))
    }

    @Test func pageStillChangingIsNotSettled() {
        #expect(
            !PageLoadSettle.hasSettled(
                Self.screen("results, more loading"), previous: Self.screen("results"),
                before: Self.screen("search box")))
    }

    @Test func newPageReadTwiceAlikeHasSettled() {
        #expect(
            PageLoadSettle.hasSettled(
                Self.screen("results"), previous: Self.screen("results"),
                before: Self.screen("search box")))
    }

    @Test func newTitleAloneCountsAsANewPage() {
        #expect(
            PageLoadSettle.hasSettled(
                Self.screen("same", title: "Results"),
                previous: Self.screen("same", title: "Results"),
                before: Self.screen("same", title: "Google")))
    }
}
