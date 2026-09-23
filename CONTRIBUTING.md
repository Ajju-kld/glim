# Contributing to Glim

Thanks for helping. Glim acts on people's Macs, so the bar is: small, tested, and never less
safe than before.

## Set up

- Apple Silicon Mac, **macOS 26**, **Xcode 26** (Swift 6).
- [Ollama](https://ollama.com) with the planner model: `ollama pull qwen3-vl:4b`
  (`qwen3-vl:8b` plans better if your Mac has the memory to spare).
- Optional: the local Laya checker — `scripts/start-laya.sh` (needs Homebrew Python 3.11 or
  newer; read [services/laya/README.md](services/laya/README.md) first).

```sh
scripts/run.sh --testbed   # build, sign and open Glim and the Testbed practice app
```

Try changes on **Testbed** first ([docs/manual-tests.md](docs/manual-tests.md)), not in apps
with your real data.

## The gate

Every change must pass:

```sh
scripts/check.sh    # swift build → Swift tests → Laya training tests → strict swift-format lint
scripts/format.sh   # apply the house style (100-column lines)
```

The Laya training tests run only when `services/laya/.venv` exists. Tests that need a live
Ollama are off unless you set `GLIM_LIVE_OLLAMA=1`.

## How the code is written

- **Tests first.** Write the failing test, then the code. `GlimCore` holds the logic behind
  protocols and is tested with fakes (Swift Testing); `Glim`, `GlimWatchdog` and `Testbed` stay
  thin.
- **Swift 6, strict concurrency, no third-party Swift packages.**
- **Names in full.** Descriptive, multi-word names; no single letters or cryptic
  abbreviations.
- **No magic numbers.** Name each constant and say what it is in its comment: `Tunable:`
  (safe to adjust), `Business rule:` (a decision), or `Placeholder:`.
- **Errors are handled, never swallowed.** No empty `catch`, no leftover debug logging, no
  commented-out code. Every public declaration has a documentation comment (the lint enforces
  it).
- **Plain words.** Messages the person sees say what happened and what to do, without jargon.

## Safety-sensitive changes

Changes in `Safety/`, `Trust/`, `Network/`, `Execution/` or the runner must keep or tighten
what [docs/SAFETY.md](docs/SAFETY.md) promises. Never loosen a default without an issue
discussing it first. If behaviour changes, update `docs/SAFETY.md` in the same pull request.
Security problems go through [SECURITY.md](SECURITY.md), not public issues.

## Privacy

Never commit screen contents, Activity Log files, Laya examples or screenshots with personal
data. Test fixtures use made-up names and made-up password-like strings.

## Pull requests

- One focused change per pull request, with what changed, why, and how you tested it (paste
  the `scripts/check.sh` result).
- Record notable changes in [docs/build-log.md](docs/build-log.md).

## Bug reports

Include your macOS version, the app Glim was acting in, what you said, and the Activity Log
lines (with personal text removed). The `stepTiming` and `controlsOffered` lines are the most
useful.

By contributing you agree that your work is released under the [MIT License](LICENSE).
