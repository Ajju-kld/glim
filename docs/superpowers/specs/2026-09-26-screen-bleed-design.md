# Screen bleed — screen chat with a glowing edge

Date: 2026-09-26 · Status: approved by the owner in conversation, implemented the same day.

## What the owner asked for

"A feature called screen bleed, where light bleeds around the screen, Glim reads the screen and
you can ask questions, just like Gemini." Decisions, all from the owner:

| Question | Answer |
|---|---|
| How it starts and stops | **Session mode**, changed after the first try to **hold ⌃⌥S to ask** (like ⌃⌥V): the first hold turns the glow on, each hold asks, follow-ups remember the conversation, about a minute of quiet (or STOP, or the menu) ends it |
| Captions | Added after the first try: your words at the bottom of the screen while you speak, then Glim's answer |
| What Glim reads | **The whole screen, with private apps cut out**: never-touch apps (and Glim itself) are removed from the screenshot before the model sees it; the front app's text is added for accuracy |
| Tasks during a session | **Answer and do**: commands run as normal Glim tasks through the same safety gate |
| Look | **Glim's orb colours** by default, following the orb's moods; **changeable in settings**, including **custom colours**, and the chosen theme is saved |

## Safety

- **The planner still never sees screen content** (rule B-Q8). In a session it sees the owner's
  own earlier requests, never Glim's answers (which are built from screen text). A reference
  such as "open the second one" becomes a vague target ("the second result") that the existing
  target picker resolves among the controls on screen; the picker can only choose a control.
- Never-touch apps are excluded from the display capture by ScreenCaptureKit, not blacked out
  afterwards, so their pixels never reach Glim. Glim's own windows (the glow, the pill) are
  excluded too.
- Screenshots stay in memory only. Nothing is read while the glow is off. The Activity Log
  records the session starting and ending and each question, never screen text.
- Every task confirmation, limit and block works exactly as outside a session.

## Design

| Piece | Module | Role |
|---|---|---|
| `GlowTheme` (`GlowStyle`: orb colours, rainbow, single colour, custom) | GlimCore | the saved look; colours per mood; custom colours bounded to 2–4 |
| `OrbPalette` | GlimCore | the orb's mood colours, shared by the orb and the glow |
| `ScreenChatSession` | GlimCore | on/off, quiet timeout, turns; earlier *requests* for the planner, earlier *turns* for answering |
| `ScreenChatPrivacy` | GlimCore | which apps a display capture leaves out |
| `DisplayScreenshotter` (on `ScreenshotCapturing`) | GlimCore | whole-display capture excluding those apps, fitted to 1,280 px |
| Conversation in `LanguageModelRequest` / `OllamaClient` | GlimCore | chat layout with the screenshot first, then earlier turns, then the new question, so Ollama reuses its cached reading of an unchanged screenshot |
| `TaskRunner.run(transcript:conversation:)` | GlimCore | passes earlier requests to planning; answers session questions from the display capture and earlier turns |
| ⌃⌥S `HotkeyCombo.screenChat` | GlimCore / Glim | hold to ask: turns the session on if needed and listens; release asks |
| `EdgeGlowController` + `EdgeGlowLayerView` | Glim | click-through overlays (glow and caption bar) over every Space and full-screen app, hidden from screen capture. The ring is painted once into a mask; Core Animation turns the conic gradient and pulses it, so no per-frame work runs on the main thread. `EdgeGlowAppearance` (GlimCore) changes only on a mood, theme or 0.1-step voice-level change, and only then is the window touched |
| Appearance page | Glim | style picker, single colour, custom colours, live preview |

## Speed

A first question with a screenshot costs about 10 s with `qwen3-vl:4b` on the owner's M2. The
screenshot is placed first in the conversation, so a follow-up on an unchanged screen reuses
Ollama's cached image (measured: 17 s → 0.1 s for a repeated image read).

## Testing

Unit tests for the theme (saving, old settings, not a safety loosening, colours per mood), the
session (toggle, quiet timeout, turns, planner sees requests only), the excluded apps, the chat
message layout, and the runner (earlier requests in planning, never answers; session questions
use the display capture). A live Ollama test for a follow-up. A hand test for the glow in
normal and full-screen apps with Passwords open.
