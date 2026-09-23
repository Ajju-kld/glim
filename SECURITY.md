# Security policy

Glim clicks and types in other apps on a Mac, so a flaw in its safety gate can do real
damage. Please report anything that lets Glim do more than it should — privately.

## How to report

Use **GitHub's private vulnerability reporting**: open the repository's **Security** tab and
choose **Report a vulnerability**. Please don't open a public issue or pull request for a
security problem.

Include:

- your macOS version and the Glim commit you tested,
- the steps to reproduce, and what you expected instead,
- the Activity Log lines around it — with any personal text (note titles, names, messages)
  removed first.

This is a small open-source project maintained in spare time. You'll get a reply as soon as
the maintainer can; please allow time for a fix before telling anyone else.

## What counts

Anything that breaks a promise in [docs/SAFETY.md](docs/SAFETY.md), for example:

- Glim acting without the approval it should ask for, or on a step that wasn't in the plan
- bypassing an app's trust tier, the forbidden words, the limits, or the kill switch
- touching a never-touch app (Passwords, Keychain, security prompts) or typing into a
  password field
- text shown on screen steering Glim into actions (prompt injection that gets past the gate)
- data leaving the Mac outside the network allowlist (`127.0.0.1`, plus Jev only when you turn
  it on)
- password-like text written to the Activity Log or to Laya training examples unmasked

## What doesn't

- The AI model choosing a wrong step that the gate then blocks or asks you about — that's the
  gate working; a plain bug report is welcome.
- Attacks that need an already compromised Mac or administrator access.
- Problems in Ollama, the Laya service (`localdecide`) or the Laya models — please report
  those to their own projects.

## Supported versions

Only the latest commit on `main` is supported; there are no released versions yet.
