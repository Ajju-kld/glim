import Testing

@testable import GlimCore

struct SafetyGateTests {
    let gate = SafetyGate(policy: .safeDefaults)
    let newNoteButton = UIElementSnapshot.fixture(number: 1, label: "New Note")
    let noteBody = UIElementSnapshot.fixture(number: 2, role: "AXTextArea", label: "Note body")

    func clickNewNote(
        in app: AppIdentity = .notes,
        element: UIElementSnapshot? = nil,
        currentElements: [UIElementSnapshot]? = nil,
        limitViolation: LimitViolation? = nil,
        checkerConcerns: [ConfirmationReason] = [],
        safetyState: SafetyState = .allClear
    ) -> GateContext {
        let chosenElement = element ?? newNoteButton
        return makeGateContext(
            step: .click(appName: app.displayName, target: "New Note"),
            stepApp: app,
            proposedAction: ProposedAction(
                kind: .click, targetApp: app, targetElement: chosenElement),
            currentElements: currentElements ?? [chosenElement],
            limitViolation: limitViolation,
            checkerConcerns: checkerConcerns,
            safetyState: safetyState)
    }

    func typeIntoNote(approvedText: String, typedText: String) -> GateContext {
        makeGateContext(
            step: .typeText(appName: "Notes", target: "note body", text: approvedText),
            proposedAction: ProposedAction(
                kind: .typeText, targetApp: .notes, targetElement: noteBody, text: typedText),
            currentElements: [noteBody])
    }

    // MARK: - Allowed

    @Test func approvedClickOnMatchingSafeButtonIsAllowed() {
        #expect(gate.evaluate(clickNewNote()) == .allow)
    }

    @Test func approvedTextIsAllowed() {
        #expect(
            gate.evaluate(typeIntoNote(approvedText: "buy milk", typedText: "buy milk")) == .allow)
    }

    @Test func emojiWithJoinersIsAllowed() {
        let family = "👨‍👩‍👧 dinner at 7"

        #expect(gate.evaluate(typeIntoNote(approvedText: family, typedText: family)) == .allow)
    }

    @Test func movingAReadOnlyAppWindowIsAllowed() {
        let context = makeGateContext(
            step: .moveWindow(appName: "Terminal", preset: .leftHalf),
            stepApp: .terminal,
            proposedAction: ProposedAction(kind: .moveWindow, targetApp: .terminal))

        #expect(gate.evaluate(context) == .allow)
    }

    // MARK: - Denied, in check order

    @Test func trippedKillSwitchDeniesEverything() {
        let context = clickNewNote(
            safetyState: SafetyState(isKillSwitchArmed: false, isWatchdogAlive: true))

        #expect(gate.evaluate(context) == .deny(.killSwitchTripped))
    }

    @Test func missingWatchdogDeniesEverything() {
        let context = clickNewNote(
            safetyState: SafetyState(isKillSwitchArmed: true, isWatchdogAlive: false))

        #expect(gate.evaluate(context) == .deny(.watchdogMissing))
    }

    @Test func clickInReadOnlyAppIsDenied() {
        #expect(
            gate.evaluate(clickNewNote(in: .terminal))
                == .deny(.blockedByTier(appName: "Terminal", tier: .readOnly, action: .click)))
    }

    @Test func neverTouchAppIsDenied() {
        #expect(
            gate.evaluate(clickNewNote(in: .passwords))
                == .deny(.blockedByTier(appName: "Passwords", tier: .neverTouch, action: .click)))
    }

    @Test func impostorAppIsTreatedAsReadOnly() {
        #expect(
            gate.evaluate(clickNewNote(in: .impostorNotes))
                == .deny(.blockedByTier(appName: "Notes", tier: .readOnly, action: .click)))
    }

    @Test func differentKindThanApprovedIsDenied() {
        let context = makeGateContext(
            step: .click(appName: "Notes", target: "New Note"),
            proposedAction: ProposedAction(kind: .pressKey, targetApp: .notes, key: .tab))

        #expect(
            gate.evaluate(context)
                == .deny(
                    .notInPlan(planned: "Click “New Note” in Notes", proposed: "press key in Notes")
                ))
    }

    @Test func actingInADifferentAppThanApprovedIsDenied() {
        let context = makeGateContext(
            step: .click(appName: "Notes", target: "New Note"),
            stepApp: .notes,
            proposedAction: ProposedAction(
                kind: .click, targetApp: .testbed, targetElement: newNoteButton),
            currentElements: [newNoteButton])

        #expect(
            gate.evaluate(context)
                == .deny(
                    .notInPlan(planned: "Click “New Note” in Notes", proposed: "click in Testbed")))
    }

    @Test func elementMissingFromTheFreshTableIsDenied() {
        let staleElement = UIElementSnapshot.fixture(number: 9, label: "New Note")

        #expect(
            gate.evaluate(clickNewNote(element: staleElement, currentElements: [newNoteButton]))
                == .deny(.unknownTarget(description: "New Note")))
    }

    @Test func passwordFieldIsDenied() {
        let passwordField = UIElementSnapshot.fixture(role: "AXSecureTextField", label: "New Note")

        #expect(
            gate.evaluate(clickNewNote(element: passwordField))
                == .deny(.secureField(elementLabel: "New Note")))
    }

    @Test func textDifferentFromApprovedIsDenied() {
        #expect(
            gate.evaluate(typeIntoNote(approvedText: "buy milk", typedText: "buy milk now"))
                == .deny(.textMismatch))
    }

    @Test func textLongerThanTheLimitIsDenied() {
        let longText = String(
            repeating: "a", count: SafetyLimits.safeDefaults.maximumTypedTextLength + 1)

        #expect(
            gate.evaluate(typeIntoNote(approvedText: longText, typedText: longText))
                == .deny(.textTooLong(limit: SafetyLimits.safeDefaults.maximumTypedTextLength)))
    }

    @Test(arguments: ["buy milk\n", "line one\rline two", "tab\there", "line\u{2028}separator"])
    func textThatActsLikeAKeyPressIsDenied(text: String) {
        #expect(
            gate.evaluate(typeIntoNote(approvedText: text, typedText: text)) == .deny(.unsafeText))
    }

    @Test func reachedLimitIsDenied() {
        let context = clickNewNote(limitViolation: .tooManyActions(limit: 20))

        #expect(gate.evaluate(context) == .deny(.limitReached(.tooManyActions(limit: 20))))
    }

    @Test func forbiddenLabelIsDenied() {
        let deleteButton = UIElementSnapshot.fixture(label: "Delete Note")

        #expect(
            gate.evaluate(clickNewNote(element: deleteButton))
                == .deny(.forbiddenAction(matchedPhrase: "delete", elementLabel: "Delete Note")))
    }

    @Test func forbiddenWordHiddenInTheDescriptionIsDenied() {
        let iconButton = UIElementSnapshot.fixture(
            label: "New Note", elementDescription: "Move to Trash")

        #expect(
            gate.evaluate(clickNewNote(element: iconButton))
                == .deny(.forbiddenAction(matchedPhrase: "trash", elementLabel: "New Note")))
    }

    @Test func tierIsCheckedBeforeRiskWords() {
        let deleteButton = UIElementSnapshot.fixture(label: "Delete")

        #expect(
            gate.evaluate(clickNewNote(in: .terminal, element: deleteButton))
                == .deny(.blockedByTier(appName: "Terminal", tier: .readOnly, action: .click)))
    }

    // MARK: - Needs confirmation

    @Test func confirmWordAsksThePerson() {
        let sendButton = UIElementSnapshot.fixture(label: "Send")
        let context = makeGateContext(
            step: .click(appName: "Messages", target: "Send"),
            stepApp: .messages,
            proposedAction: ProposedAction(
                kind: .click, targetApp: .messages, targetElement: sendButton),
            currentElements: [sendButton])

        #expect(
            gate.evaluate(context)
                == .needsConfirmation([.riskyWord(matchedPhrase: "send", elementLabel: "Send")]))
    }

    @Test func pressingReturnAsksThePerson() {
        let context = makeGateContext(
            step: .pressKey(appName: "Messages", key: .returnKey),
            stepApp: .messages,
            proposedAction: ProposedAction(kind: .pressKey, targetApp: .messages, key: .returnKey))

        #expect(gate.evaluate(context) == .needsConfirmation([.pressReturn]))
    }

    @Test func offScriptElementAsksThePerson() {
        let archiveButton = UIElementSnapshot.fixture(label: "Archive")

        #expect(
            gate.evaluate(clickNewNote(element: archiveButton))
                == .needsConfirmation([.planMismatch(planned: "New Note", chosen: "Archive")]))
    }

    @Test func checkerConcernsAreShownToThePerson() {
        let concern = ConfirmationReason.checkerDisagrees(
            checkerName: "Laya", checkerChoice: "Archive")

        #expect(
            gate.evaluate(clickNewNote(checkerConcerns: [concern]))
                == .needsConfirmation([concern]))
    }

    @Test func supervisedAppAsksForEveryStep() {
        #expect(
            gate.evaluate(clickNewNote(in: .cursor))
                == .needsConfirmation([.supervisedApp(appName: "Cursor")]))
    }

    @Test func quittingAnAppAsksThePerson() {
        let context = makeGateContext(
            step: .quitApp(appName: "Notes"),
            proposedAction: ProposedAction(kind: .quitApp, targetApp: .notes))

        #expect(gate.evaluate(context) == .needsConfirmation([.quitApp(appName: "Notes")]))
    }

    @Test func confirmationReasonsAccumulateInOrder() {
        let sendButton = UIElementSnapshot.fixture(label: "Send")
        let concern = ConfirmationReason.checkerOffline(checkerName: "Laya")
        let context = makeGateContext(
            step: .click(appName: "Cursor", target: "Run"),
            stepApp: .cursor,
            proposedAction: ProposedAction(
                kind: .click, targetApp: .cursor, targetElement: sendButton),
            currentElements: [sendButton],
            checkerConcerns: [concern])

        #expect(
            gate.evaluate(context)
                == .needsConfirmation([
                    .riskyWord(matchedPhrase: "send", elementLabel: "Send"),
                    .planMismatch(planned: "Run", chosen: "Send"),
                    concern,
                    .supervisedApp(appName: "Cursor"),
                ]))
    }
}
