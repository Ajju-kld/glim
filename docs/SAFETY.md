# How Glim Keeps You Safe

Glim can click, type and open apps on your Mac. That is powerful, so every part of it is built
around one rule:

> **The AI proposes. Code decides. You approve.**

The AI model never touches your Mac directly. It can only *suggest* steps, and every suggestion
passes through checks written in plain Swift code — code you can read, and that is tested by
more than a hundred automated tests.

## 1. You approve the plan first

When you say "open Notes and write buy milk", Glim shows the plan before doing anything:

```
1  Open Notes
2  Click “New Note” in Notes
3  Type “buy milk” into “note body” in Notes
        [Cancel]   [Approve]
```

Nothing happens until you click **Approve** (never by voice, so a video playing in the
background can't approve anything). If you don't answer within 60 seconds, the plan is cancelled.

The text to type is fixed at this moment. Later, while the task runs, the AI only chooses
*where* to type — never *what*.

## 2. Every app has a trust tier

| Tier | What Glim may do | Examples |
|---|---|---|
| 🚫 **Never-touch** | Nothing — not even open or read it | Passwords, Keychain, AnyDesk, iPhone Mirroring, MetaTrader, security prompts, Glim itself |
| 👀 **Read-only** | Open, switch, read, move/minimize windows. No clicking or typing | Terminal, Warp, browsers, System Settings, **every app not listed** |
| 🧑‍✈️ **Supervised** | Click and type, but **every single step asks you** | VS Code, Cursor, Xcode, Claude, ChatGPT, Docker |
| ✅ **Full control** | Runs the plan you approved; risky steps still ask | Notes, TextEdit, Calendar, Music, Mail, Messages, WhatsApp, Slack |

New apps start as read-only (default-deny). An app pretending to be another app — same name,
but its code signature doesn't check out — never gets more than read-only.

## 3. Dangerous words are blocked, risky words ask

Before every click, Glim reads the button's label, description and tooltip.

- 🚫 **Forbidden — always blocked:** delete, remove, trash, erase, empty, wipe, format,
  uninstall, reset, discard, clear all, clear history, don't save, replace, overwrite, revert,
  buy, pay, purchase, order, checkout, transfer, subscribe, unsubscribe, cancel subscription,
  sign out, log out, deactivate, change password, allow, always allow, install, trust, block.
- ⚠️ **Confirm — asks you:** send, submit, post, share, reply, forward, accept, agree, close,
  quitting an app, pressing Return.

Matching understands real-world spellings: "Don’t Save", "Move to Trash…" and "SIGN-OUT" are all
caught, while harmless look-alikes such as "Deleted Items" or "Sender" are not.

Buttons with no label at all (like an icon-only trash can) are never offered to the AI. Glim
has no Delete key and no keyboard shortcuts it can press.

## 4. The checks on every single step

For each step, fresh from the screen, Glim's safety gate checks — in this order — and stops at
the first problem:

1. The kill switch is armed and the watchdog is running.
2. The app's tier allows this kind of action.
3. The action is exactly the kind you approved, in the app you approved.
4. The chosen button really is on screen right now.
5. It is not a password field.
6. The text is exactly what you approved, at most 500 characters, and has **no line breaks or
   tabs** (a typed line break would act like pressing Return — in a chat app, that sends).
7. Limits: at most 20 actions per task, 3 tries per step, a quarter-second between actions,
   3 minutes per task, and 3 actions in a row that change nothing on screen.
8. No forbidden word.

Then it collects reasons to ask you: a risky word, pressing Return, a button that doesn't match
the plan ("Plan said *New Note*, AI chose *Archive*"), a second-opinion checker that disagrees
or is offline, a supervised app, or quitting an app. All reasons are shown together in one panel.

Any denial shows a red popup saying which guard fired and what the AI tried, and **stops the
task**. A blocked action never gets a second try.

## 5. Second opinions

A second model double-checks every click the main model picks:

- **Laya** runs locally on your Mac.
- **Jev** runs in TypeSafe's cloud — **off by default**. If you turn it on, only your goal, the app
  name, window title and button labels are sent (never screenshots), and never for messaging
  apps.

If a checker is confident the main model picked the wrong button, Glim asks you. If a checker is
offline, every click and typing step asks you.

## 6. The kill switch

Stop Glim instantly, any of these ways:

- Press **⌃⌥⌘K** anywhere.
- Click the ■ in the notch pill, or **STOP** in the menu.
- Say "stop" or "cancel" while holding the talk key.
- Click **Cancel** or **Stop** in any Glim panel.
- **Just touch your keyboard or mouse** while Glim is acting — it hands control back to you.

⌃⌥⌘K is owned by a separate tiny watchdog program. If Glim itself freezes, the watchdog
force-quits it within half a second. Without a running watchdog, Glim refuses to act at all.

Last resort: Force Quit (⌥⌘⎋), or run `pkill -x Glim` in Terminal.

After a stop, Glim stays stopped until you click **Re-arm**.

## 7. What Glim cannot do at all

There is no code in Glim that can:

- run shell commands, AppleScript, JavaScript or any script;
- delete, move or write your files (it writes only its own settings and log);
- connect to the internet — only to `127.0.0.1` (Ollama and Laya on your Mac), plus TypeSafe's
  Jev address if you turn Jev on;
- save screenshots to disk;
- send telemetry.

## 8. Changing the rules

Every list and limit is editable in the control panel. Making anything **less** safe — removing
a forbidden word, moving an app to a more trusting tier, raising a limit, turning on Jev —
needs your **Touch ID or Mac password**. Making things safer never asks.

The settings file is sealed with a secret key kept in your Keychain. If anyone edits the file
directly, Glim notices and falls back to the safe defaults.

## 9. The audit log

Glim records what you said, the plans, every check and every action in a local log
(`~/Library/Application Support/Glim/`). It keeps 7 days, at most 5 MB, and the control panel
has a **Clear log** button.
