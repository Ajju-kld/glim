# How Glim Keeps You Safe

Glim can click, type and open apps on your Mac. That is powerful, so every part of it is built
around one rule:

> **The AI proposes. Code decides. You approve.**

The AI model never touches your Mac directly. It can only *suggest* steps, and every suggestion
passes through checks written in plain Swift code — code you can read, and that is tested by
more than a hundred automated tests.

## 1. Glim asks only before dangerous steps

When you say "open Notes and write buy milk", Glim starts at once and the notch shows each
step as it runs — touch the keyboard or mouse, or press ⌃⌥⌘K, to stop it.

Glim stops and asks you, at that moment, only before a step that:

- clicks a control whose name has a Confirm word (send, submit, post, share, reply, forward,
  accept, agree, close);
- presses Return (which can send) — except in a web browser's own address bar, where Return
  only opens an address or a search (see below);
- quits an app;
- acts in a **supervised** app (VS Code, Cursor, Xcode, Claude, ChatGPT…).

Forbidden steps (delete, buy, sign out, allow…) are never asked about — they are always blocked.

You can turn off "Ask only before dangerous steps" in **Safety Rules**. Then every plan waits
for your Approve first, and Glim also asks when the AI's pick differs from the plan's wording
or when the Laya/Jev checkers disagree or are offline. Turning it back on needs Touch ID.

With the switch off, a plan looks like this:

```
1  Open Notes
2  Click “New Note” in Notes
3  Type “buy milk” into “note body” in Notes
        [Cancel]   [Approve]
```

Nothing happens until you **click** Approve. Not by voice (so a video playing in the background
can't approve anything), and not by keyboard: Glim's panels never take keyboard focus, so nothing
you type — not even keyboard navigation — can reach their buttons. The buttons also ignore clicks
for the first 0.8 seconds, so a click you were already making can't land on Approve. If you don't
answer within 60 seconds, the plan is cancelled.

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

**Screen chat (hold ⌃⌥S) sees the whole screen — except never-touch apps.** While the screen edge
glows, a question is answered from a picture of the whole main display. Never-touch apps (and
Glim's own windows) are removed by macOS's screen capture itself, so their pixels never reach
Glim or the AI; the front app's text is added only if that app may be read. Nothing is read
while the glow is off, screenshots stay in memory, and the Activity Log records the session
starting and ending and each question, never screen text. Commands given during screen chat run
as ordinary tasks, with every check and confirmation below. The planner still never sees screen
content: in screen chat it sees your own earlier requests, never Glim's answers.

## 3. Dangerous words are blocked, risky words ask

Before every click, Glim reads the button's label, description and tooltip.

**Clicks found by sight always ask.** When an app shows Glim no usable control for a click
(or none of them fits the step), the local model looks at a screenshot of the app's window and
points at a spot. Glim can't read a label there, so it shows you the screenshot with the spot
marked and what the model says is there, and clicks only if you allow it — even with "Ask only
before dangerous steps" on. It never clicks by sight in a window's title bar, never types by
sight, and stops if the window moved after the screenshot. The same forbidden and risky words
are checked on what the model says it sees.

- 🚫 **Forbidden — always blocked:** delete, remove, trash, erase, empty, wipe, format,
  uninstall, reset, discard, clear all, clear history, don't save, replace, overwrite, revert,
  buy, pay, purchase, order, checkout, transfer, subscribe, unsubscribe, cancel subscription,
  sign out, log out, deactivate, change password, allow, always allow, install, trust, block.
- ⚠️ **Confirm — asks you:** send, submit, post, share, reply, forward, accept, agree, close,
  quitting an app, pressing Return.

Matching understands real-world spellings: "Don’t Save", "Move to Trash…", "SIGN-OUT", "Délete"
and full-width "ｄｅｌｅｔｅ" are all caught, while harmless look-alikes such as "Deleted Items" or
"Sender" are not.

**Return is checked too.** Before pressing Return, Glim reads what it would activate — the
focused control and the window's default button — and applies the same rules: a Forbidden word
blocks it, and the confirmation names the control ("Pressing Return would activate “Send”").

**Return in a browser's address bar doesn't ask.** In a known web browser (Chrome-family,
Safari, Firefox) with Full control, Return in the browser's own address bar only opens an
address or a search, so Glim presses it without asking. Glim decides this from *where* the
focused control sits, never from its name: it must be a text field with no web page above it in
the window. A text box on a web page — even one named "Address and search bar" — still asks,
and so does anything Glim can't read clearly. Confirm and Forbidden words in what Return
activates still apply.

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

Typed text may also not contain invisible formatting characters (like bidi overrides or zero-width
spaces), which could make the approval panel show something different from what gets typed.

**Right before acting**, Glim re-reads the control and checks it is still exactly the one it
read — same role, same label, same description — and checks the kill switch one last time,
immediately before the actual click or keystroke.

**After you confirm**, Glim looks at the screen again (you may have taken up to a minute), finds
the same control, and runs every check again. If anything changed that you didn't see, it stops
instead of acting on something new.

Then it collects reasons to ask you: a risky word, pressing Return, a button that doesn't match
the plan ("Plan said *New Note*, AI chose *Archive*"), a second-opinion checker that disagrees
or is offline, a supervised app, or quitting an app. All reasons are shown together in one panel.

Any denial shows a red popup saying which guard fired and what the AI tried, and **stops the
task**. A blocked action never gets a second try.

## 5. Second opinions

A second model double-checks every click the main model picks from a window's controls
(a click found by sight isn't sent to them — it always asks you instead):

- **Laya** runs locally on your Mac.
- **Jev** runs in TypeSafe's cloud — **off by default**. If you turn it on, your goal, the app
  name, window title and the labels of the candidate controls are sent — never screenshots,
  never field contents, never the text you're about to type, and never anything from messaging
  apps. A label can be the words a control shows (a list row is labelled by its text).

With "Ask only before dangerous steps" off: if a checker is confident the main model picked
the wrong button, Glim asks you, and if a checker is offline, every click and typing step asks
you. With it on (the default), their verdicts are recorded in the Activity Log instead.

## 6. The kill switch

Stop Glim instantly, any of these ways:

- Press **⌃⌥⌘K** anywhere.
- Click the ■ in the notch pill, or **STOP** in the menu.
- Say "stop" or "cancel" while holding the talk key.
- Click **Stop** in a confirmation panel (Cancel on a plan just cancels that plan).
- **Just touch your keyboard or mouse** while Glim is acting — it hands control back to you.
  (Input in the first second after you click Approve or Allow is ignored, so a hand still moving
  after the click doesn't count.)

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
a forbidden word, moving an app to a more trusting tier, raising a limit, turning on Jev,
changing the AI model — needs your **Touch ID or Mac password**. Making things safer never asks,
and it applies **immediately, even to a task that's already running**. Cloud AI models are
refused outright, because they would send your screen off the Mac while looking local.

The settings file is sealed with a secret key kept in your Keychain. If anyone edits the file
directly, Glim notices and falls back to the safe defaults.

## 9. The audit log

Glim records what you said, the plans, every check and every action in a local log
(`~/Library/Application Support/Glim/`). It keeps 7 days, at most 5 MB, and the control panel
has a **Clear log** button.
