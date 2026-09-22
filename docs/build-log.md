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
