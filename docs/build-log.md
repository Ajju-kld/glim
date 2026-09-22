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
