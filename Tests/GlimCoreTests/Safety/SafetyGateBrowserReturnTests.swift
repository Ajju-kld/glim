import Testing

@testable import GlimCore

/// Return in a browser's own address bar opens a web address or a search, and can't send or
/// submit anything, so it doesn't ask. Return anywhere in a web page still asks.
struct SafetyGateBrowserReturnTests {
    let gate: SafetyGate = {
        var policy = SafetyPolicy.safeDefaults
        policy.appTrust.tiersByBundleIdentifier[AppIdentity.chrome.bundleIdentifier] =
            .fullControl
        return SafetyGate(policy: policy)
    }()

    func pressReturn(
        in app: AppIdentity, activates targetTexts: [String] = ["Address and search bar"],
        staysInAddressBar: Bool
    ) -> GateContext {
        makeGateContext(
            step: .pressKey(appName: app.displayName, key: .returnKey),
            stepApp: app,
            proposedAction: ProposedAction(kind: .pressKey, targetApp: app, key: .returnKey),
            returnKeyTargetTexts: targetTexts,
            returnKeyStaysInBrowserAddressBar: staysInAddressBar)
    }

    @Test func returnInTheBrowsersAddressBarRunsWithoutAsking() {
        #expect(gate.evaluate(pressReturn(in: .chrome, staysInAddressBar: true)) == .allow)
    }

    @Test func returnInsideAWebPageStillAsks() {
        #expect(
            gate.evaluate(pressReturn(in: .chrome, staysInAddressBar: false))
                == .needsConfirmation([.pressReturn(activates: "Address and search bar")]))
    }

    /// Only known browsers have an address bar; anywhere else Return may send a message.
    @Test func appThatIsNotABrowserStillAsks() {
        let gate = SafetyGate(policy: .safeDefaults)

        #expect(
            gate.evaluate(
                pressReturn(in: .messages, activates: ["Message"], staysInAddressBar: true))
                == .needsConfirmation([.pressReturn(activates: "Message")]))
    }

    /// The gate names the first thing Return activates, as it does everywhere.
    @Test func riskyWordsStillAskInTheAddressBar() {
        let context = pressReturn(
            in: .chrome, activates: ["Address and search bar", "Send"], staysInAddressBar: true)

        #expect(
            gate.evaluate(context)
                == .needsConfirmation([
                    .riskyWord(matchedPhrase: "send", elementLabel: "Address and search bar")
                ]))
    }
}
