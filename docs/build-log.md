# Build Log

One entry per step: what was done, why, commands run, and real output.

## 2026-09-23 — Step 0: Brainstorm and design spec

**What:** Researched existing voice/computer-use projects and the Laya decision model, then
agreed a design through Q&A. Wrote the design spec.

**Why:** No existing project met all requirements (local Ollama, native Swift, kill switch,
safe by design), so we are building one.

**Key decisions** (full list in `docs/specs/2026-09-23-design.md` §2):

- Single menu-bar app with Hardened Runtime. Full App Sandbox is impossible because the sandbox
  blocks the Accessibility API needed to click/type in other apps; safety is enforced in code.
- Push-to-talk only (⌃⌥V). Kill switch ⌃⌥⌘K.
- Plan approved by you, then step-by-step execution through a safety gate.
- Forbidden actions (delete, pay, sign out, …) are always blocked; any guard hit shows a popup.
- Model: `qwen3-vl:8b` on local Ollama.

**Commands:**

```
$ mkdir -p mac-voice-assistant/docs/{specs,plans} && git init -b main
Initialized empty Git repository in .../mac-voice-assistant/.git/
```

**Environment found:** Apple M2, 16 GB, macOS 26.6.2 · Xcode 26.3 · Swift 6.2.4 ·
`swift format` 6.2.3 · Apple Development cert present · Ollama 0.6.8 (Homebrew, needs upgrade)
with only `nomic-embed-text` installed.

## 2026-09-23 — Step 1: Senior-dev review, grilling, spec v2

**What:** Reviewed spec v1 as a senior dev, found holes, and resolved 23 design questions one by
one. Renamed the project **Glim** (folder `mac-voice-assistant/` → `glim/`). Rewrote the spec.
Recorded every question and answer.

**Why:** v1 had gaps: the app blocklist failed open (IDEs with built-in terminals were not
blocked), `Don't Save` / `Replace` / `Allow` were not forbidden, the kill switch died with the
app, and nothing checked that the clicked element matched the approved plan.

**Main changes** (full list in `docs/decisions/2026-09-23-design-questions-and-answers.md`):

- Four trust tiers, default-deny: Never-touch · Read-only · Supervised · Full control.
- Plan-match check, human-takeover auto-stop, watchdog process owning ⌃⌥⌘K.
- Laya (local service now, CoreML later) and opt-in Jev as second-opinion checkers; a
  disagreement counts only when the checker is confident; checker offline → confirm every step.
- Everything editable; loosening needs Touch ID; settings sealed with an HMAC.
- UI: notch pill for status, centered panels for decisions, Liquid Glass control panel.
- Code standards section enforced by `swift format lint --strict`.

**Commands:**

```
$ mv mac-voice-assistant glim && mkdir -p glim/docs/decisions
$ # bundle IDs for default tiers read from each app's Info.plist with PlistBuddy
```

**Lesson:** in zsh, `path` is tied to `$PATH`; naming a loop variable `path` broke `head` and
every lookup. Use descriptive names like `app_path`.

## 2026-09-23 — Task 1: Package scaffold and action vocabulary

**What:** `Package.swift` (Swift 6 mode, macOS 26, `GlimCore` + tests), `.swift-format`
(generated from `swift format dump-configuration`, then line length 100, 4 spaces, and the six
required rules switched on), `scripts/check.sh` (build → test → strict lint) and
`scripts/format.sh`. Action vocabulary: `ActionKind`, `AllowedKey`, `ScrollDirection`,
`WindowPreset`, `StepAction`, `Plan`, `ProposedAction`, `AppIdentity`, `UIElementSnapshot`.

**Why:** Every later unit speaks this vocabulary. `StepAction` makes impossible actions
unrepresentable: there is no case for deleting files or running scripts. `AllowedKey` has no
Delete key. `UIElementSnapshot.describingTexts` leaves out the value, because a field's content
may be written by someone else and must not change the risk verdict.

**TDD:** tests written first; `swift build` failed with "target 'GlimCore' ... is empty";
after implementing, 9 tests (18 cases) passed.

**Gates:** `scripts/check.sh` → `All gates passed.`

## 2026-09-23 — Task 2: Trust tiers and app trust policy

**What:** `TrustTier` (Never-touch < Read-only < Supervised < Full control, `Comparable`),
`TierPermission`, `AppTrustPolicy` with default-deny lookup and the §8.2 permission matrix.

**Why:** Default-deny (B-Q1): unknown apps are read-only. `highestTierForUnverifiedApps` caps
any app whose signature failed validation at read-only, so an impostor using
`com.apple.Notes` gains nothing, while an impostor of a never-touch app stays never-touch
(review focus 3).

**TDD:** failed with "cannot find 'TrustTier' in scope"; then 6 tests incl. a 25-case
permission matrix passed.

**Gates:** `All gates passed.` (15 tests)

## 2026-09-23 — Task 3: Safety limits, risk word lists, safe defaults

**What:** `SafetyLimits` (20 actions, 3 tries, 0.25 s spacing, 180 s timeout, 3 unchanged,
500 characters), `RiskWordLists`, `SafetyDefaults` (the Forbidden/Confirm phrases and the four
tier lists with real bundle IDs read from this Mac), `SafetyPolicy.safeDefaults`.

**Why:** One named home for every business rule, each with a doc comment saying business rule
or tunable. Tier lists are applied most-restrictive-last, and a test proves no app is listed
twice.

**TDD:** failed with "cannot find 'SafetyPolicy' in scope"; then 27 tests passed.

**Gates:** `All gates passed.`

## 2026-09-23 — Task 4: Risk classifier

**What:** `RiskLevel` and `RiskClassifier`: whole-word, case-insensitive phrase matching across
every text describing a control; Forbidden wins over Confirm.

**Why:** Labels come in many spellings. Normalizing drops apostrophes ("Don’t Save" = "Dont
Save") and turns hyphens, tabs, ellipses and non-breaking spaces into single spaces, so
"SIGN-OUT" and "Sign Out" are still forbidden (review focus 1), while "Deleted Items",
"Sender" and "Postpone" stay safe. Blank phrases in an edited list are ignored so they can't
match everything.

**TDD:** failed with "cannot find type 'RiskLevel' in scope"; then 35 tests passed.

**Gates:** `All gates passed.`

## 2026-09-23 — Tasks 5 and 6: Plan matcher and action limiter

**What:** `PlanMatcher` (the chosen element must share a meaningful word with the approved
target; filler words like "the", "button", "click" are ignored; simple plural folding).
`LimitViolation` + `ActionLimiter` (timeout → actions → tries → no-change streak → spacing,
with `waitBeforeNextAction` so the runner waits instead of failing).

**Why:** B-Q4: a tricked pick like "Archive" for "New Note" must ask the person. Targets with no
meaningful words fail closed (review focus 5). The limiter takes time as a parameter so tests
are exact and never sleep.

**TDD:** failed with "cannot find 'PlanMatcher' / 'ActionLimiter' in scope"; then 52 tests passed.

**Gates:** `All gates passed.`

## 2026-09-23 — Task 7: Safety gate

**What:** `SafetyGate.evaluate(_:)` → `allow` / `needsConfirmation([reasons])` / `deny(violation)`,
plus `GateContext`, `SafetyState`, `ScreenedStep`, `GuardViolation` (with popup title and
explanation), `ConfirmationReason`, `GateDecision`, `TextSafety`.

**Why:** This is the "AI proposes, code decides" core (§9.2). Check order: kill switch →
watchdog → tier permission → same kind and same app as the approved step → element is from the
fresh table → not a password field → typed text exactly as approved, ≤ 500 characters, no
line breaks or control characters → limits → forbidden phrases. Then confirmation reasons
accumulate: confirm phrase, Return key, plan mismatch, checker concerns, supervised app or quit.

**Found while building:** typed text containing `\n` would act like Return and send a chat
message without the Return confirmation. Added the `unsafeText` guard (and updated spec §9.2).
Emoji with zero-width joiners stay allowed (review focus 2).

**TDD:** tests failed to compile ("cannot infer contextual base … 'unsafeText'"); then all 27
gate tests passed, 79 in total.

**Gates:** `All gates passed.`

## 2026-09-23 — Tasks 8 and 9: Plan screener and kill switch

**What:** `PlanScreener` → `readyForApproval(ScreenedPlan)` or `rejected(violation, stepNumber:)`;
`ScreenedPlan`, `PlanScreeningOutcome`. `KillSwitch` (a `Mutex`-guarded, sticky trip with
handlers run outside the lock), `TripReason`, `TripHandlerToken`.

**Why:** A plan containing a step that would be denied is never shown for approval (spec §9.2):
unknown app, tier forbids the step, forbidden target words, typed line breaks or overlong text,
an empty plan, or more steps than the action limit. The kill switch trips exactly once even
with 100 concurrent trips; handlers may read the switch without deadlocking;
`ensureArmed()` is what the executor calls before every OS call.

**TDD:** failed to compile (types missing); then 100 tests passed.

**Gates:** `All gates passed.`

## 2026-09-23 — Tasks 10 and 11: Network policy and audit log

**What:** `NetworkEndpoint` (Ollama `127.0.0.1:11434`, Laya `127.0.0.1:8791`, Jev
`api.typesafe.ai:443`), `NetworkPolicy.validate(_:)`, `NetworkPolicyError`. `AuditLog` actor
(JSON Lines, `audit-YYYY-MM-DD-NNN.jsonl` by UTC day and part), `AuditEvent`, `AuditEventKind`,
`AuditRetention.standard` (7 days, 5 MB total, 1 MB per file), `AuditLogError`.

**Why:** Glim can't be sandboxed, so the network allowlist is enforced in code. Tests reject
`localhost`, other ports, http for Jev, look-alike hosts, `user@host` tricks and `file://`.
The audit log answers "why did it do that?" (B-Q10); retention runs after every append.

**Fixes during the task:** a local `events` variable shadowed the `events(in:)` method →
renamed to `decodedEvents(in:)`. `#expect(try await ….isEmpty)` doesn't compile inside the
macro → assign to a local first.

**TDD:** failed with "cannot find 'AuditLog' in scope"; then 113 tests passed.

**Gates:** `All gates passed.`

## 2026-09-23 — Tasks 12 and 13: Settings, loosening classifier, sealed store

**What:** `GlimSettings`, `JevSettings` (off; messaging excluded), `SafetyLimitName`,
`SettingsLoosening`, `SafetyChangeClassifier`. `SettingsStore` actor with an HMAC-SHA256 seal
(`SettingsSeal`, `SealedSettingsFile`), `SealKeyProviding` and `OwnerAuthenticating` protocols,
`SettingsLoadOutcome`, `SettingsStoreError`.

**Why:** B-Q13/13b: everything is editable, but loosening needs Touch ID. The classifier lists
each loosening: removed phrases (a change of case alone isn't one), apps moved to a less
restrictive tier (removing an app from the list counts, relative to the default tier), a raised
default tier, loosened limits, enabling Jev, removing a Jev exclusion. The seal stops someone
editing `settings.json` directly to skip Touch ID; a missing, empty, non-JSON, edited or
foreign-key file loads safe defaults and is audited (review focus 4). After the owner prompt
the store re-checks that nothing changed meanwhile (actor reentrancy).

**TDD:** failed to compile (types missing); then 136 tests passed.

**Gates:** `All gates passed.`

## 2026-09-23 — Task 14: SAFETY.md — Part 1 complete

**What:** `docs/SAFETY.md` explains the safety model in plain words: plan approval, trust tiers,
word lists, the per-step checks, second opinions, the kill switch and watchdog, what Glim
cannot do, Touch ID for loosening, and the audit log.

**Part 1 result:** the whole safety core is pure, tested Swift with no permissions needed —
136 tests across 14 suites, strict lint clean.

## 2026-09-23 — Task 15: HTTP transport and Ollama client

**What:** `JSONValue` (literal-friendly JSON for schemas and bodies), `HTTPTransport`,
`URLSessionTransport` (ephemeral session; refuses every redirect via a task delegate),
`PolicyEnforcingTransport` (validates each request against `NetworkPolicy` and rejects a
response that came from a different address), `LanguageModel`, `LanguageModelRequest`,
`LanguageModelError` (with the exact fix command), `OllamaClient` (`/api/chat` with
`stream: false`, `think: false`, `format` = JSON schema, temperature 0, 60 s timeout;
`/api/tags` for the setup check).

**Why:** One choke point for all traffic. Redirects are refused because a 307 would re-send the
request body to wherever the server points, outside the allowlist.

**Not unit-tested:** the redirect-refusing delegate needs a real server. The post-response address
check that backs it up is tested.

**TDD:** failed with "cannot find type 'OllamaClient' in scope"; then 147 tests passed.

**Gates:** `All gates passed.`

## 2026-09-23 — Task 16: Planner

**What:** `Planner` (`makePlan`, `pickTarget`, `answerQuestion`), `PlanningContext` (labels
only), `PlannerResult`, `TargetChoice`, `PlannerError`, `PlannerSchemas` (JSON schemas built
from the enums, so the model can only name allowed actions, keys, directions and presets),
`PlannerPrompts`, `PlanAnswer` (decoded JSON → typed `StepAction` with per-field checks), and
`ElementRoles` (clickable and text-entry roles; password fields excluded).

**Why:** The model answers in schema-constrained JSON, then code validates it again: unknown
actions like `runShell`, missing or blank apps, a `delete` key and free-form window coordinates
all become model errors (re-asked, counted as a try). Extra fields such as `"command":"rm -rf ~"`
are ignored. Target picks can only name a *compatible* element from the fresh table; the prompt
lists only those elements, labels only, never field values.

**TDD:** failed to compile (types missing); then 161 tests passed.

**Gates:** `All gates passed.`

## 2026-09-23 — Tasks 17 and 18: Checkers and consensus

**What:** `TargetChecker`, `TargetReviewRequest`, `CheckerVerdict`, `SystemOneWireFormat`,
`CandidateShortlist`, `SystemOneTargetReviewer`, `LayaChecker` (local `127.0.0.1:8791`),
`JevChecker` (pinned `jev-1.13.0`, bearer key, excluded apps), `CheckerTuning` (0.60 threshold,
20-candidate shortlist, 10 s timeout), `CheckerConsensus` (checkers run concurrently),
`CheckerOutcome`, `CheckerConsensusResult`.

**Why:** B-Q15–Q17, B-Q23. A checker's disagreement counts only when it is confident; an unsure
checker abstains, so Laya's ~63% accuracy doesn't flood you with popups. More than 20 candidates
→ shortlist by word overlap, and a pick outside the shortlist abstains without a network call.
Jev never sees excluded (messaging) apps, needs a key, and is blocked by the network policy
unless enabled — each case is tested to send nothing. Offline → `checkerOffline` concern.

**TDD:** failed with "cannot find type 'LayaChecker' in scope"; then 177 tests passed.

**Gates:** `All gates passed.`

## 2026-09-23 — Task 19: Laya service scripts — Part 2 complete

**What:** `scripts/start-laya.sh` (pinned commit `bafba59…`, refuses a mismatch; source, venv
and `HF_HOME` model cache all inside `services/laya/`; binds `127.0.0.1:8791`) and
`services/laya/README.md` with review notes. `.gitignore` covers the downloaded parts.

**Why:** Spec §9.5 requires a pinned, reviewed install. Reviewed `serve.py`: binds loopback,
4 MB body cap, no shell in the server path, no CORS, outbound HTTP only in the unused remote
backend. **Not run overnight** — it downloads third-party code and a model; the owner should
re-check the pin (commands in the README) and run it.

**Check:** `bash -n scripts/start-laya.sh` → syntax ok.

## 2026-09-23 — Task 20: App identity verification, catalog, resolver

**What:** `CodeSignatureVerifier` (Security framework), `SignatureVerifying`, `AppCatalog` +
live `WorkspaceAppCatalog`, `InstalledApp`, `RunningApp`, `AppResolver`, `ResolvedApp`.

**Why:** A *valid* signature isn't enough — an ad-hoc-signed impostor is valid too. The
verifier requires `identifier "<bundle id>" and anchor apple` for `com.apple.*` and
`anchor apple generic` otherwise, so an app must be signed by an Apple-issued certificate
under its own identifier. Bundle identifiers with characters that could change the
requirement's meaning are rejected. Running apps are checked through the kernel-tracked
process signature; installed apps statically without re-hashing resources.

**Real-system tests (no permission needed):** Calculator is trusted as `com.apple.calculator`
and rejected when it claims `com.apple.Notes`.

**Consequence:** Testbed built with ad-hoc signing is capped at read-only; sign it with the
Apple Development identity to test clicks (see README).

**TDD:** failed with "cannot find type 'AppResolver' in scope"; then 191 tests passed.

**Gates:** `All gates passed.`

## 2026-09-23 — Task 21: Accessibility reader and element table

**What:** `AccessibilityNode` (value tree), `ElementTableBuilder` (pure), `ElementTable`,
`ScreenSnapshot`, `ScreenReading`, `ScreenReadingError`, `ScreenReadingLimits` (depth 25,
2,000 nodes, 80 listed, 4,000 readable characters, 1.5 s walk, 1 s per-app timeout), and the live
`AccessibilityService` actor.

**Why:** All `AXUIElement` handles stay inside one actor; the rest of Glim sees plain values and
element numbers. The builder lists only enabled, visible, labelled click/type targets, falls back
to a button's inner text or a field's placeholder for labels, and never includes password
fields, not even in the readable text. Attributes are fetched in one round trip per node.
Electron apps get `AXManualAccessibility` so their controls appear; `AXEnhancedUserInterface`
is deliberately not set because it disturbs window positioning in some apps.

**Live tests:** a real-window test runs only when the test runner has Accessibility permission
(skipped overnight); the "not trusted → clear error" path is tested now.

**TDD:** failed with "cannot find 'ScreenReadingLimits' in scope"; then 200 tests passed.

**Gates:** `All gates passed.`

## 2026-09-23 — Task 22: Screen capture

**What:** `ScreenshotCapturing`, `WindowScreenshotter` (ScreenCaptureKit single-window capture,
fitted to 1,280 px on the longest side, PNG-encoded in memory), `PixelSize`.

**Why:** The vision fallback for questions on screens with little accessible text (spec §10).
Screenshots never touch the disk (§9.7). Screen Recording is preflighted and requested only on
first need; tests construct the screenshotter with `mayPromptForPermission: false` so they
can never pop a system prompt.

**TDD:** failed with "cannot find 'WindowScreenshotter' in scope"; then 204 tests passed
(PNG signature, size fitting, and "permission missing → clear error" without prompting).

**Gates:** `All gates passed.`

## 2026-09-23 — Task 23: Executor

**What:** `ActionPerforming`, `ExecutableAction`, `ExecutionError`, `LiveExecutor`,
`SyntheticInput` (Unicode typing in ≤ 20-unit chunks that never split a character, allowed-key
codes, scroll), `WindowFrameCalculator` (presets, AppKit → Accessibility coordinates),
`ScreenGeometry`, and `AccessibilityService+Actions` (press, focus, window frame, minimize,
restore).

**Why (safety details):**
- Events go to the target process with `postToPid`, never the global stream, so a sudden focus
  change can't redirect keystrokes, and they don't count as hardware input (the basis of the
  takeover monitor).
- Before pressing or typing, the live element is re-checked against its snapshot (role, subrole,
  title, description, not a password field) — a control that changed since it was read is
  refused.
- Typing re-checks the kill switch and keyboard focus before every chunk.
- Quitting uses `terminate()` (the app may ask to save), never `forceTerminate()`.
- Typing never sets `AXValue`, which would overwrite existing text.

**TDD:** failed to compile (types missing); then 217 tests passed (window presets incl. menu bar
and Dock offsets, chunking with emoji joiners, key codes, kill switch stops before any action).
Live pressing and typing need Accessibility permission → covered by the manual test script.

**Gates:** `All gates passed.`

## 2026-09-23 — Task 24: Takeover monitor and watchdog link

**What:** `HumanInputClock` + live `HardwareInputClock` (`CGEventSource.secondsSinceLastEventType`
on `.hidSystemState`), `TakeoverMonitor` (settle delay 1 s, poll 50 ms), `WatchdogSignal`,
`WatchdogLink` (Darwin notifications via libnotify, process liveness via `kill(pid, 0)`),
`WatchdogStopResponder`.

**Spike S2 resolved by design:** Glim posts its events straight to the target process, so they
never enter the hardware input state; only a real person resets that clock. No Input Monitoring
permission needed. A 1-second settle delay ignores the hand still moving after clicking Approve.

**Why the link carries no data:** anyone on the Mac can post a Darwin notification, so the
signals can only *stop* Glim, never make it act.

**Fix during the task:** libnotify lives in its own `notify` module (not `Darwin`).

**TDD:** failed to compile (types missing); then 226 tests passed, including a real round trip
of Darwin notifications (unique name prefix per test) and the stop → acknowledge handshake.

**Gates:** `All gates passed.`

## 2026-09-23 — Task 25: Voice input and output

**What:** `SpokenCommandMatcher`, `AudioLevel`, `VoiceEvent`, `VoiceInputError`,
`PushToTalkTranscribing` + live `SpeechAnalyzerTranscriber` (macOS 26 `SpeechAnalyzer` /
`SpeechTranscriber`, progressive transcription, `en-US`, on-device), `AudioTapProcessor`
(microphone → analyzer format + waveform level), `Narrating` + `SpeechNarrator`
(`AVSpeechSynthesizer`, mutable).

**Why:** Push-to-talk (A-Q4): the microphone runs only between `startListening` and
`stopListening`; cancel discards everything. While a task runs, any "stop"/"cancel" stops it;
when idle only a bare stop command counts, so "stop the music" is still a request. The first
use downloads Apple's on-device English model — macOS does this, not Glim.

**API check:** the `SpeechAnalyzer` signatures were read from the macOS 26 SDK's
`.swiftinterface`, not guessed.

**Fix during the task:** the converter's input block is `@Sendable`, so a captured `var`
warned under strict concurrency → replaced with a one-shot supplier (build is warning-free).

**TDD:** failed with "cannot find 'SpokenCommandMatcher' in scope"; then 234 tests passed. The
live microphone path needs Microphone and Speech Recognition permission → manual test script.

**Gates:** `All gates passed.`

## 2026-09-23 — Task 26: Task runner — Part 3 complete

**What:** `TaskRunner` (+ `TaskRunner+Steps`), `TaskRunnerDependencies`, `TaskEvent`,
`TaskOutcome`, `ConfirmationRequest`, `PersonDecisions`, `RunnerTiming`, `TakeoverSupervisor`,
internal `RunnerStop`, and the audit event kinds the runner writes. Target picking got a
`retryNote` so a retry tells the model why its last pick was rejected (temperature 0 would
otherwise repeat it).

**Flow:** transcript → bare "stop" trips the kill switch → labels-only snapshot of the front app
(never for never-touch apps) → plan or question. Questions: text, or a screenshot when the text
is thin → spoken answer, no actions. Tasks: screen → approval panel → per step: resolve the app,
fresh snapshot, pick (up to 3 tries with feedback), checkers, gate → deny stops / confirm asks
(takeover monitor paused while the panel is open; Stop trips the kill switch) → execute →
verify change.

**Deliberate refinement of spec §8 step 4:** Glim never repeats an action automatically when
nothing visibly changed — a repeated click could send a message twice. Unchanged steps count
toward the "3 in a row" limit instead.

**Fail closed:** if the audit log can't be written, the task stops.

**Test fix:** one runner test first failed because the fake executor tripped a different
`KillSwitch` than the runner's — a harness bug, fixed by sharing one switch.

**TDD:** failed with "cannot find type 'TaskOutcome' in scope"; then 252 tests passed — 17
runner scenarios: answered, screenshot fallback, never-touch not read, completed, rejected
before approval, cancelled, runtime forbidden pick, confirm allow/deny, kill switch mid-task,
retries exhausted, watchdog missing, checker disagreement, Ollama down, spoken stop, no-change
limit, audit trail.

**Gates:** `All gates passed.`

## 2026-09-23 — Task 27: GlimWatchdog helper

**What:** `GlimWatchdog` executable (`WatchdogController`, `main.swift`), plus tested core pieces:
`StopEscalator` (request → wait 0.5 s → SIGKILL on silence), `AcknowledgementWaiter` (armed before
the request, so an instant or stale acknowledgement is handled correctly), `HotkeyCombo`
(⌃⌥⌘K, ⌃⌥V) and `GlobalHotkey` (Carbon `RegisterEventHotKey`, press and release, no permission).

**Spike S1 resolved:** a plain helper executable registers the Carbon global hotkey. Smoke
test: the watchdog posted `dev.straxs.Glim.watchdog.ready` (sent only after registration
succeeds), stayed alive while its parent ran, and exited when the parent exited.

**Fixes during the task:** `Mutex` is non-copyable, so it can't be captured in the notification
closure → flags moved into a small `Sendable` reference type.

**Honest note:** the smoke test briefly wrote its notification output to `/tmp` (deleted right
after); later checks use the session scratchpad.

**TDD:** failed with "cannot find 'StopEscalator' / 'HotkeyCombo' in scope"; then 261 tests
passed.

**Gates:** `All gates passed.`

## 2026-09-23 — Tasks 29–31: Glim app — model, menu bar, notch pill, panels, control panel

**What:** the `Glim` executable target.
- `AppModel` (`@Observable`, main actor): settings, push-to-talk (⌃⌥V press/release → on-device
  transcript → task), kill-switch wiring (trip → cancel task, stop mic and voice, dismiss panels,
  guard popup, audit), watchdog state, action-mode rules (watchdog ready + English interface;
  otherwise every app is capped at read-only).
- `LiveServices`, `RunnerFactory` (policy-enforcing transport → Ollama, Laya, and Jev only when
  enabled), `WatchdogSupervisor` (launches `Contents/Helpers/GlimWatchdog`, listens for
  ready/hotkeyFailed, checks liveness every second), `GlimStorage`.
- Notch pill: borderless **non-activating** panel merged with the notch (floating at top-center
  without one), waveform while listening, pulse while acting, ■ to stop, red glow when stopped.
  Status logic lives in the tested `PillStatus` reducer.
- Decision panels: plan approval, confirmation (app, control, exact text, every reason) and the
  red guard popup — centered, non-activating so the target app stays frontmost, Approve/Allow
  by click only, Escape cancels, 60-second auto-cancel with a countdown.
- Control panel (sidebar + Liquid Glass cards): Dashboard (armed/STOP/health/today), Apps & Trust
  (drag between four tiers, context menu, search), Safety Rules (phrase lists, limit steppers,
  reset), AI Models (Ollama status and model, Laya status, Jev toggle with privacy notice and
  Keychain key), Permissions (status + System Settings links), Activity Log (search, clear).
- Live glue in `GlimCore`: `KeychainSealKeyProvider`, `KeychainSecretStore`,
  `DeviceOwnerAuthenticator` (Touch ID / password).

**Design check (apple-ui-design):** system fonts, 8-point spacing, one primary action per panel,
glass cards, subtle animations, dark-mode friendly.

**Found while building:** blocking only the main thread would not prove the watchdog's
force-quit, because the stop handshake answers from a background queue. The debug "Simulate
freeze" suspends the whole process (`SIGSTOP`) instead.

**Not unit-tested:** SwiftUI/AppKit views and Keychain/LocalAuthentication glue (a Keychain test
would write outside the repo). Their logic lives in tested `GlimCore` types; the manual test
script covers the rest.

**Gates:** `swift build` — no errors, no warnings. `All gates passed.` (265 tests)

## 2026-09-23 — Task 32: Bundling and signing

**What:** `Resources/Glim-Info.plist` (`dev.straxs.Glim`, `LSUIElement`, macOS 26, microphone and
speech usage strings), `Resources/Testbed-Info.plist`, `Resources/Glim.entitlements` (only
`com.apple.security.device.audio-input`), `scripts/build-app.sh` (release build → `build/Glim.app`
with `Contents/Helpers/GlimWatchdog`, and `build/Testbed.app`; signs inside-out with Hardened
Runtime; identity = `$GLIM_SIGNING_IDENTITY`, else the first Apple Development identity, else
ad-hoc), `scripts/run.sh`.

**Verified overnight (ad-hoc, so no keychain prompt could block):**
- `codesign --verify --deep --strict` passes for both apps.
- Flags `adhoc,runtime` (Hardened Runtime on); entitlements show only audio input.
- Helper identifier `dev.straxs.Glim.Watchdog`.
- An ad-hoc Testbed fails `identifier "dev.straxs.Glim.Testbed" and anchor apple generic`, so
  Glim treats it as read-only, as documented. Build with your Apple Development identity to
  test clicking in Testbed.

**Fix:** the release build showed a "mutated after capture by sendable closure" warning in
`DecisionPresenter` → a small holder object; debug and release builds are now warning-free.

**Not done overnight:** launching the app. It would create Keychain items and Application
Support files outside the repo, and needs you to grant permissions.

## 2026-09-23 — Task 33: README, animated notch pill, manual tests — Part 4 complete

**What:** `README.md` (hero animation, examples, flow diagram in Mermaid, trust tiers, kill switch,
privacy, quick start, pill states, development, documents, uninstall, FAQ, credits),
`docs/assets/glim-pill.svg` (pure SMIL animation, no scripts: the pill grows from the notch,
listens with a live waveform while the words type out, acts in green, says Done — looping), and
`docs/manual-tests.md` (T1–T10 covering all eight success criteria plus Touch ID and tamper
detection, with a results table).

**Checks:** `xmllint --noout` passes; a rendered still frame was reviewed. That review led to
removing the Apple-logo glyph (it doesn't render outside Apple fonts) and left-anchoring the
menu-bar text.

## 2026-09-23 — Independent code review and fixes

**Review:** a fresh reviewer read every source file, ran the gates, and reported **no Critical
issues**, seven Important and about twenty Minor. Verdict: "With fixes". Every Important finding
was checked against the code and confirmed, then fixed test-first:

| # | Finding | Fix (commit) |
|---|---|---|
| 1 | Settings tightened mid-task didn't reach the running task | Runner re-reads settings each step, combined strictly with its starting policy (`e6015c8`) |
| 2 | No re-check after the up-to-60 s confirmation; shallow element check | Fresh snapshot + same control + gate re-run after "Allow once"; live identity check recomputes the label (`63c839c`, `6c6a4f5`) |
| 3 | Kill switch not checked at the OS call; per-app AX timeout didn't cover children | Checked right before every AX write and `postToPid`; timeout set on the system-wide element (`6333105`) |
| 4 | Panels took keyboard focus → Approve reachable by keyboard | Never key; real mouse click only; 0.8 s arming delay (`eb25690`) |
| 5 | Return never checked against Forbidden words | Reads focused control + default button; Forbidden denies; confirmation names it (`63c839c`) |
| 6 | Mic could stay on after releasing the talk key during startup | `ListeningSessionGate` cancels a start in progress (`e1b0c71`) |
| 7 | Cloud models (Ollama `-cloud`) would leak through 127.0.0.1 | Model change needs Touch ID; cloud names refused by settings and client (`eae1d9a`) |

**Minors fixed:** accent/width folding and every default phrase tested; invisible formatting
characters refused; checkers never see the typed text; the run-time app is checked before its
screen is read; opening requires a verified signature; app actions verified (opening, switching,
quitting); screen read failures audited; damaged audit lines skipped; a stop never shows a
misleading "Ollama isn't running"; one shared, proxy-free network session; watchdog "ready"
trusted only from our helper; serialized settings edits; settings reset shown as a popup; scroll
at the window centre; docs aligned (spec §18, SAFETY.md, README, manual tests T11).

**A real bug found by a new test:** the takeover monitor measured from when its task first ran,
so input in a scheduling gap right after approval could be missed. The start instant is now
captured when watching is requested, and the API requires it.

**Flakiness removed:** two timing-based tests became deterministic (they wait for the trip,
bounded at 2 s). The full suite ran 15 times in a row with no failures.

**Deferred (spec §18 "Known gaps"):** checker-offline badge, Jev 401 key flag, settings rollback
protection, Laya dependency pinning, homoglyph folding.

**Gates:** `All gates passed.` — 314 tests in 53 suites; strict lint clean; debug and release
builds warning-free.

## 2026-09-23 — App icons

**Glim:** a dark indigo squircle with the black notch pill, its cyan orb and waveform, and a ✦
sparkle (`Resources/AppIcon/glim-icon.svg`).

**Testbed:** a warm amber practice target with a ✦ (`Resources/AppIcon/testbed-icon.svg`), so
the practice app is never mistaken for Glim in the Dock or app switcher.

`scripts/make-icon.sh` renders each SVG to an iconset (16–512 pt, @1x and @2x) with
`scripts/render-icon.swift`, then packs it with `iconutil` into `Resources/Glim.icns` and
`Resources/Testbed.icns`. `scripts/build-app.sh` copies them into each bundle as
`AppIcon.icns` (`CFBundleIconFile = AppIcon`). `scripts/run.sh` now quits running copies first
so the fresh build (and icon) is the one that opens.

**Gates:** `All gates passed.` — 322 tests in 56 suites; strict lint clean.

## 2026-09-23 — Speed: from 22 s to about 4 s per plan

The owner reported ~10 s waits. Measured before changing anything:

- **Ollama's log:** the first request took 21.5 s, of which **12.7 s was loading the model**
  (Ollama unloads it after 5 idle minutes; only 4.7 GB of memory was free). Two later requests
  ran 43 s and 60 s (the timeout).
- **Root cause of the slow and odd plans:** `JSONValue.object` wrapped a Swift `Dictionary`,
  so the schema's field order was random on every launch, and `JSONEncoder` reorders keys
  anyway. Ollama makes the model write fields in schema order. With `action` after `app`, or
  `steps` before `kind`, qwen3-vl looped (`openApp`, `switchApp`, `openApp`…) for 190–270+
  tokens: a two-step answer became a runaway that hit the 60 s timeout, and plans came out as
  lone `speak` steps or repeated steps. Reproduced in a scratch benchmark by scrambling key
  order.

Fixes:

| Change | Effect (warm model, M2 16 GB) |
|---|---|
| `JSONValue` objects keep written order; `jsonData()` writes them in order; the Ollama client builds its body from it; every step variant starts with `action` | No loops; live tests pass 3 runs in a row (they failed 2–3 of 6 before) |
| `keep_alive: 30m` on every request, and `loadModel()` at launch and when the talk key is pressed | The 12.7 s load overlaps the person talking instead of following it |
| Planning prompt lists apps first and the request last | Ollama reuses its cached reading of the prompt start: prompt reading 3 s → 0.3–0.8 s |
| A step whose target is exactly one control's label is picked by code | Saves one model call (~1.5 s) per click or type step |
| Schema caps steps at the action limit and text at the typing limit (`maxItems`, `maxLength`, which Ollama enforces) | A runaway stops at the limits instead of the timeout |
| STOP during planning is logged as "cancelled", not "Ollama isn't running" | Correct audit log |

Benchmark of 8 real-world requests: 40.4 s → 25.0 s from prompt order alone; the live suite
(6 model calls) went from 17–40 s to 13.1 s. `qwen3-vl:4b` was also measured: no faster
(it writes twice the tokens) and worse plans, so 8b stays and 4b was removed.

**Gates:** `All gates passed.` — 337 tests in 56 suites; live suite 4/4 three times.

## 2026-09-23 — Low-risk plans start without asking

The owner asked Glim not to ask approval for everything (decision C-2). `LowRiskPlanRule`
decides whether a screened plan may skip the Approve panel: every step's tier allows it without
confirmation, no Return key, no Confirm phrase in a target, and typed text is something the
person said. `SafetyPolicy.autoRunsLowRiskPlans` (default on) controls it: combined strictly
mid-task, turning it on is a Touch ID loosening, and settings sealed before it existed still
load. Safety Rules has the switch. The runner audits "Started without asking: every step is
low-risk." Every step still goes through the full gate while running.

Tests: 12 rule cases, combination, loosening, back-compatible decoding, and two runner cases
(low-risk plan runs with no panel; a Send plan still shows the panel with auto-run on). The
runner tests' base policy keeps auto-run off so they keep checking the panel.

**Gates:** `All gates passed.` — 350 tests in 57 suites.

## 2026-09-23 — The notch grows a torus-ring orb

The owner asked for the notch to grow, a torus-ring orb while speaking, a spring while
processing, and a shrink when done (decision C-3).

- **Pure, tested parts in GlimCore/Presentation:** `OrbMood` (one per pill state),
  `OrbMotion` (scale, spin speed and tube thickness per mood; a damped spring beat every
  1.1 s while planning or acting; swelling with the voice level), `TorusGeometry` (rings that
  circle the torus axis and roll through the tube, projected at a 41° tilt, sorted back to
  front), `PillLayout` (hidden = exactly the notch; compact while listening silently; full
  width with words or work) and `PillStatus.offersStop`.
- **Views:** `TorusOrbView` draws the rings in a `Canvas` with a blurred glow and a halo, and
  keeps its turn continuous when the speed changes (`OrbSpin`). `NotchPillShape` is flush with
  the screen top with concave shoulders, so the pill reads as the notch itself growing.
  `NotchPillView` springs open from the notch, springs between sizes, shows a step progress
  bar, and shrinks back without bounce. The controller hides the window only after the shrink,
  and lets clicks pass through unless ■ Stop is showing. `VoiceWaveformView` was removed.
- **Checked visually** with a scratch renderer outside the repo that snapshots all seven states.
  The first torus (tube rings at a 60° tilt) read as a coil with a spike; it was redrawn as
  rolling rings, and the glow thinned so the hole stays dark.

**Gates:** `All gates passed.` — 363 tests in 62 suites.

## 2026-09-23 — Control panel redesign

The owner said the control panel didn't look good (decision C-3). The stock split view with
glass cards on a flat background was replaced by:

- a **dark indigo backdrop** with two soft glows in Glim's colors;
- a **custom sidebar**: the live torus orb and "Glim · Armed/Stopped" as the brand, icon-badge
  rows with hover and selection, and a red **Stop ⌃⌥⌘K** capsule always at the bottom;
- a **page header** (large title and one line) on every page;
- **cards** as translucent surfaces with a light top edge and a tinted icon badge (red for
  Forbidden, orange for Confirm, green for Approvals…). Liquid Glass stays on buttons: behind
  text, glass picked dark text on the dark backdrop, which is unreadable;
- a **dashboard** with a hero (large orb, "Ready when you are" or the stop reason and
  Re-arm), "Try saying" chips, a grid of health tiles, and today's tasks with ✓/✗.

Also fixed: the dashboard hid a failure to read the audit log (it showed "no tasks"); it now
says it could not read the log. Checked with a scratch renderer outside the repo.

**Gates:** `All gates passed.` — 363 tests in 62 suites.

## 2026-09-23 — Ask only before danger; crash, Notes and speed fixes

- **Crash when the pill or panel appeared:** both crash reports showed AppKit's "too many
  Update Constraints passes" exception thrown from `NSHostingView.updateWindowContentSizeExtrema`.
  The orbs animate every frame, and a hosting view that sizes its window re-runs layout during
  layout. The pill's hosting view and the control panel's hosting controller now have
  `sizingOptions = []`; the pill window has a fixed frame and the panel a `contentMinSize`.
  Could not be reproduced in a scratch harness; Glim stayed up after relaunch.
- **Ask only before dangerous steps (decision C-4):** the switch (renamed from
  `autoRunsLowRiskPlans` to `asksOnlyBeforeDangerousSteps`) now skips the plan panel entirely,
  and `SafetyGate` keeps only reasons where `ConfirmationReason.isDangerous`. `LowRiskPlanRule`
  was removed. Tests: gate (doubts don't ask; danger still asks; cautious gate keeps every
  reason) and runner (Send asks at the step, no plan panel).
- **"Notes has no open window":** opening or switching to a running app now reopens it through
  `NSWorkspace.openApplication`, like a Dock click, so it shows a window; the step then waits up
  to 3 s for the window. Tests: a window that appears late, and one that never does.
- **Speed:** settle after each action 400 → 250 ms; app and window polling 250 → 100 ms.

**Gates:** `All gates passed.` — 358 tests in 61 suites.

## 2026-09-23 — Crash on the talk key, take two; Dock icon; last-crash card

The first fix (`sizingOptions = []`) was not enough: Glim still crashed 0.4–0.5 s after every
press of ⌃⌥V (three more reports). The system log (read with `/usr/bin/log` — plain `log` is a
zsh builtin here, which hid every earlier log search) showed SwiftUI's
`NSHostingView.updateAnimatedWindowSize` / `updateTransform` re-running window layout from
inside layout on a borderless window as the pill first appeared. A scratch harness with the real
model and controller did not crash, so the fix removes the mechanism instead:
`WindowContainerView` holds the hosting view as a subview, so SwiftUI never sizes or moves the
window; the pill's view is built once per notch; the control panel uses the same container.

The notch hides Glim's menu-bar icon on a full menu bar, so Glim now also has a **Dock icon**;
clicking it opens the control panel. The dashboard shows the **last crash** (time, exception
type) with "Show report".

**Gates:** `All gates passed.` — 358 tests in 61 suites.

## 2026-09-23 — Wrong click in Notes

The owner's log: plan "Click “New Note” in Notes", but Glim pressed "Notes, 125 notes" (a
folder row), which failed with AX error -25205. Two causes, both fixed with tests first:

- **The toolbar never made the table.** The walk lists controls in reading order and stops at
  80; Notes' folders and 125 note rows came first. When a window has more controls than fit,
  buttons and fields are now kept before rows and cells (still numbered in reading order).
- **The mismatch got through.** With "ask only before dangerous steps" on, plan mismatches no
  longer asked the person, so the model's wrong pick was clicked. Now a pick that doesn't match
  the plan's wording is never clicked: it goes back to the model with a note, and repeated
  misses block the step (the tries limit). Asking the person remains the behaviour when the
  switch is off.

**Gates:** `All gates passed.` — 360 tests in 61 suites.

## 2026-09-23 — Unnamed fields, takeover switch, faster steps, editable Apps & Trust

- **Typing failed after New Note** ("Element 0 is not one of the listed controls"): Notes' note
  body has no name, so it was never listed. Unnamed text fields are now listed as "Untitled
  text area/field" (never their contents), and a typing step with one field on screen types
  there without a model call. Tests: builder, planner, runner.
- **"Stop when I touch the keyboard or mouse"** is now a switch in Safety Rules (default on;
  turning it off needs Touch ID; strict combination keeps it on if either policy wants it).
- **Faster steps:** the window read after a step is reused by the next step in the same app,
  saving one full window walk (up to 1.5 s in big windows like Notes) per step.
- **Apps & Trust** is one searchable list with a tier menu on every app, filter tabs with
  counts, and "Default tier" / "Not installed" hints — replacing four long drag-and-drop columns.
- **Narrow windows:** Safety Rules' phrase cards stack when narrow, and phrases are compact
  chips with a remove button. The shared `FlowLayout` no longer reports an infinite width.

**Gates:** `All gates passed.` — 367 tests in 61 suites; suite run 5× without a flake.

## 2026-09-23 — Notes and Spotify: finding the real button

Owner's logs: Notes clicked "Notes, 126 notes" again, and Spotify's plan "Click Play button"
kept picking the window's zoom button until the mismatch guard stopped it.

- **Windows are read level by level** (`BreadthFirstWalk`). The depth-first walk spent its
  2,000-node / 1.5 s budget inside long lists (every note, every track) and never reached the
  toolbar. Breadth-first, controls near the top of the tree are always read first. Tests: a
  deep list and a shallow toolbar button under a tight budget, order, depth limit.
- **Title-bar buttons are never offered** (close, minimize, zoom, full screen), so the model
  can't pick "this button also has an action to zoom the window".
- **Stricter plan match:** one side must contain all the other's meaningful words. Sharing one
  word ("note") no longer makes "Notes, 126 notes" match "New Note".
- **Readable log:** task outcomes are worded ("blocked at step 2: …") instead of Swift dumps.

**Gates:** `All gates passed.` — 373 tests in 62 suites.
