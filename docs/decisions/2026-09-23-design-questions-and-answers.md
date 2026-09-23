# Glim — Design Questions and Answers

Every question asked while designing Glim, the options offered, the recommendation, and the
answer given. Answers are recorded as chosen; free-text notes are quoted exactly as typed.

- **Dates:** 2026-09-22 → 2026-09-23
- **Result:** `docs/specs/2026-09-23-design.md`

---

## Part 0 — Starting requests (verbatim)

1. "check what is laya recently become deccision model can we make any personal voice and screen
   reading asistant for the mac to open and control the laptop"
2. "i want to use the my voice check any github built that"
3. "can it view the screen and do task"
4. "create a folder here and create that project for me which should safe and use ollama here okay
   and it should bear a kill switch and use native code use swift and document eachstep as you do
   and please ensure it is sandboxed or safe to use"

### Research that shaped the design

| Finding | Effect on design |
|---|---|
| Laya (Convai, Apache-2.0, released ~2026-09-19) is a 421M/322M *decision* model: picks from options with probabilities, cannot write text, cannot see images | Can only be a checker/picker, never the planner |
| Base Laya picks the right UI control ~10% of the time among ~45; browser-tuned `cklxx/laya-browser` v10s reaches 0.63 top-1 | Use v10s; its vote counts only when confident (B-Q23) |
| Laya runs today as a local Python service (`localdecide serve`, 127.0.0.1, no auth); CoreML ports exist but only for base weights | Service in v1, CoreML in v2 (B-Q21) |
| Jev (TypeSafe) is a hosted API: `POST https://api.typesafe.ai/v1/systemone`, Bearer key, US servers, no training on customer data, ~$0.042 per million input tokens, early access, zero-retention only for enterprise | Opt-in, off by default (B-Q16) |
| Existing GitHub projects (macos-use, jarvis, jev-voice, Samuel, SpectraVoice, UI-TARS-desktop) each miss at least one of: local, voice, screen, open apps, multi-step, safety | Build our own |
| App Sandbox blocks the Accessibility API needed to control other apps | Hardened Runtime + safety enforced in code (A-Q2) |

---

## Part A — Brainstorming (2026-09-22)

### A-Q1 · v1 scope
**Asked:** Which jobs should v1 do? Options: open/switch/quit apps · click + type in apps ·
read screen aloud / answer · multi-step tasks.
**Answer:** All four, plus (typed) "move windows".

### A-Q2 · Safety architecture
**Asked:** Full App Sandbox is impossible (it forbids the Accessibility API). Options:
(1) single app + safety gates, (2) split: sandboxed brain + unsandboxed helper.
**Recommended:** Single app + safety gates.
**Answer:** Single app + safety gates.

### A-Q3 · Autonomy
**Asked:** When should it stop and ask? Options: approve plan + confirm risky · confirm every
step · only confirm risky.
**Recommended:** Approve plan, confirm risky.
**Answer:** Approve plan, confirm risky.

### A-Q4 · Activation
**Asked:** How do you start it listening? Options: push-to-talk hotkey · wake word · both.
**Recommended:** Push-to-talk.
**Answer:** Push-to-talk hotkey.

### A-Q5 · Planner
**Asked:** How should the planner handle screens that change mid-task? Options: plan steps then
pick live · full plan with exact clicks upfront · pure step loop.
**Recommended:** Plan steps, then pick live.
**Answer:** Plan steps, then pick live.

### A-Q6 · Design section 1 (architecture and components)
**Answer:** Looks right, continue.

### A-Q7 · Design section 2 (safety model and kill switch)
**Answer:** Change something — "dont allow dangerous command like deleting if safe gaude limit
touch show a popup".
**Resulting change:** Three risk tiers (Forbidden = always blocked, Confirm, Safe); every guard
hit shows a popup and stops the task. Revised section → **Looks right, continue.**

### A-Q8 · Design section 3 (data flow, errors, testing, docs)
**Answer:** Looks right, write spec.

---

## Part B — Senior-dev grilling (2026-09-23)

Request (verbatim): "review the spec and question and grill me deeper like a senior dev and make
sure the code should be self readable and keep standard" — then "ask one by one".

### B-Q1 · App trust model
**Problem found:** The blocklist fails open — VS Code, Xcode, Cursor and Warp have built-in
terminals and were not blocked.
**Options:** Allowlist, default-deny · blocklist + add IDEs.
**Recommended:** Allowlist, default-deny.
**Answer:** Allowlist, default-deny.

### B-Q2 · Which app groups start with full control
**Options (multi-select):** Notes & writing · Calendar & office · Media · Messaging (not
recommended).
**Answer:** All four, plus (typed) "moving windows side minimizing and doing multipel thing as a
plan".
**Resulting change:** Messaging gets full control (Send / Return still confirm). New window
actions: minimize and restore; window moves can target any running app; multi-step window
arrangements.

### B-Q3 · Never-touch list
**Options:** Strict core list · strict + dev & AI apps.
**Recommended:** Strict core list.
**Answer:** Strict core list — note: "need dev and ai apps also".

### B-Q3b · Dev and AI apps (clarifying the note)
**Options:** Supervised (confirm every step) · read-only is enough · full control like Notes.
**Recommended:** Supervised.
**Answer:** Supervised: confirm every step. Terminals stay read-only by default.

### B-Q4 · Chosen element must match the plan
**Problem found:** Plan says "click New Note", a tricked model could pick "Archive" (not a
forbidden word) and nothing caught it.
**Options:** mismatch → confirm popup · mismatch → deny + stop · no check.
**Recommended:** Confirm popup.
**Answer:** Mismatch → confirm popup.

### B-Q5 · Human takeover
**Options:** any human input stops it · only clicks/keys · no auto-stop.
**Recommended:** Any human input stops it.
**Answer:** Yes, any human input stops it.

### B-Q6 · Kill switch strength
**Problem found:** An in-app hotkey dies if the app freezes.
**Options:** in-app + separate watchdog · in-app only.
**Recommended:** In-app + watchdog.
**Answer:** In-app + separate watchdog.

### B-Q7 · Word lists
**Options:** add all (new Forbidden + new Confirm) · add Forbidden only.
**Recommended:** Add all.
**Answer:** Add all.

### B-Q8 · What the planner may see
**Options:** labels only · full screen text.
**Recommended:** Labels only.
**Answer:** Labels only.

### B-Q9 · Code standards
**Options:** accept as written · change something.
**Recommended:** Accept.
**Answer:** Accept as written. (Full rules in spec §14.)

### B-Q10 · Audit log privacy
**Options:** full log, 7-day auto-delete · mask typed text · keep forever.
**Recommended:** Full log, 7-day auto-delete.
**Answer:** Full log, 7-day auto-delete.

### B-Q11 · Safety testbed app
**Options:** build Testbed.app · test on real apps.
**Recommended:** Build it.
**Answer:** Yes, build Testbed.app.

### B-Q12 · Speed vs smarts
**Options:** start 8b, measure · speed first 4b · two models.
**Recommended:** Start 8b, measure.
**Answer:** Start 8b, measure, then decide.

### B-Q13 · Which safety lists are editable
**Options:** core locked, tiers editable · everything editable · everything locked.
**Recommended:** Core locked, tiers editable.
**Answer:** Everything editable.

### B-Q13b · Protecting edits that loosen safety
**Options:** Touch ID to loosen · confirm dialog only · no extra guard.
**Recommended:** Touch ID to loosen.
**Answer:** Touch ID to loosen.

### B-Q14 · Technical defaults (15 items)
**Answer:** Accept all. (Listed in spec §16.)

### B-Q15 · Laya
User asked (verbatim): "does it use laya or jev also that we see".
**Options:** v1 Ollama only with Laya slot ready · Laya as second opinion · Laya as main picker.
**Recommended:** v1 Ollama only, Laya slot ready.
**Answer:** Laya as second opinion.

### B-Q16 · Jev
User said (verbatim): "also jev".
**Privacy warning given:** Jev sends goal, app name, window title and control labels to TypeSafe
(US). Paid key.
**Options:** opt-in extra checker, off by default · Jev replaces Laya · Jev as main picker.
**Recommended:** Opt-in, off by default.
**Answer:** Opt-in extra checker, OFF by default.

### B-Q17 · Checker unavailable
**Options:** fall back to confirm-every-step · action mode off · continue without checker.
**Recommended:** Fall back to confirm-every-step.
**Answer:** Fall back to confirm-every-step.

### Mockups offer
**Asked:** Show orb/control-panel mockups in a browser tab?
**Answer (verbatim):** "not in the browswer as widet" → the orb is a native desktop widget;
sketches stay in the terminal.

### B-Q18 · Where the orb appears
User asked (verbatim): "also need control pannel a beatiful control pane and orb widget when
press and hold speaks it appears".
**Options:** bottom-center above the Dock · notch pill (Dynamic Island) · next to the cursor.
**Recommended:** Bottom-center.
**Answer:** Notch pill (Dynamic Island).

### B-Q19 · Pill vs panels for decisions
**Options:** all in the expanding pill · pill for status, panels for decisions.
**Recommended:** All in the pill.
**Answer:** Pill for status, panels for decisions.

### B-Q20 · Control panel style
**Options:** sidebar + dashboard (Liquid Glass) · single dashboard page · menu-bar dropdown only.
**Recommended:** Sidebar + dashboard.
**Answer:** Sidebar + dashboard, Liquid Glass.

### B-Q21 · How Laya runs
**Options:** local service now (counts only when sure) · CoreML in-app · service now, CoreML
later · drop Laya.
**Recommended:** Local service now, counts only when sure.
**Answer:** Service now, CoreML later.

### B-Q22 · Name
User asked (verbatim): "also need a good readme for this folder a unique one show this orb also
and give a good name".
**Options:** Glim · Notchling · Mote · Wisp.
**Recommended:** Glim.
**Answer:** Glim.

### B-Q23 · When a checker's disagreement counts
**Options:** only when the checker is confident · every disagreement.
**Recommended:** Only when confident.
**Answer:** Only when Laya is confident. (Same rule for Jev.)

### Final confirmation
**Asked:** Is the summary the full shared understanding?
**Answer:** Yes, update the spec. Then (verbatim): "doucment thsee questions you asked and also
the answers i given okay" → this document.

## After first use (2026-09-23)

### C-1 · Speed
User said (verbatim): "why is it taking 10 sedconsd can we make it fast".
**Decision (measured, no question needed):** fix the causes found in Ollama's log and a
benchmark: keep the model loaded and preload it, fix the schema field order that made the model
loop, put stable prompt parts first, pick exactly-labelled targets in code. Keep
`qwen3-vl:8b` (4b was measured: no faster, worse plans). See the build log.

### C-2 · Fewer approvals
User said (verbatim): "and dont ask approvla for everything please".
**Decision:** a plan whose every step is low-risk starts without the Approve panel
(`LowRiskPlanRule`), on by default. Low-risk means: the app's tier allows the step without
confirmation (no supervised apps, no quitting), no Return key, no Confirm phrase in a target,
and any text to type is something the person said. Everything else still shows the plan, and
every step still passes the full safety gate while running, so a risky control found on screen
still asks. Changes B-Q3 ("approve plan, confirm risky") for low-risk plans only. Turning the
switch back on after turning it off needs Touch ID, like any loosening.

### C-3 · Notch orb and control panel
User said (verbatim): "can you update ui the notch should grow and also it should be a orb i
dont see that here the torus ring orb when speeking . and when doing thing it spring when
processing and shrink when processing is done" and "also change the ui of the control pane it
doesnt look good".
**Decision:** the pill grows out of the notch with a spring, shows an animated torus-ring orb
while listening (reacting to the voice level), springs while planning and acting, and shrinks
back into the notch when done. The control panel gets a visual redesign.

### C-4 · Ask only for dangerous things
User said (verbatim): "can we make even faster without approving only need approval for
dangerous things".
**Decision:** replaces C-2. With "Ask only before dangerous steps" on (default), no plan panel
at all; Glim asks at the step only for danger: a Confirm phrase, Return, quitting an app, or a
supervised app (the owner's own tier choice from B-Q5). Doubts about the AI — a pick that
differs from the plan's wording, a checker that disagrees or is offline — no longer ask; they
are logged. Forbidden steps are still blocked. Changes B-Q3 and the checker-offline rule
(B-Q17) while the switch is on; turning the switch off restores both.

### C-5 · Replace the planner model?
User said (verbatim): "delte the old ollama model and download new".
Asked: which model replaces `qwen3-vl:8b`, and, after the build log showed `qwen3-vl:4b` had
already been measured here (no faster, worse plans), whether to still switch.
**Decision:** keep `qwen3-vl:8b` as the planner; nothing is deleted and 4b is not installed.

### C-6 · Visual ability
User said (verbatim): "need visual ability also".
Asked: what vision should add, given qwen3-vl already reads a screenshot for questions when an
app shows too little text.
**Decision:** see and click. For apps with no usable accessibility controls, qwen3-vl looks at
a screenshot of the front window and picks a point to click. Every such click asks for
confirmation, because the safety gate cannot check a label it never read.

### C-7 · Laya training data now that Laya also picks
User said (verbatim): "yes fix all teh steps", after being shown three gaps in the training
data once Laya started picking controls (LayaPicker).
**Decision:**
1. The picker asks Laya with the app name and window title, exactly as the checker and the
   saved examples do, so Laya is trained and asked on the same inputs.
2. Every example records who picked the control (`pickedBy`: exact label, only field, plan
   match, Laya or the language model). Review marks Laya's own picks, and in training a Laya
   pick the owner merely confirmed counts half (`LAYA_SELF_CONFIRMED_WEIGHT`).
3. Scoring adds pick coverage and pick precision at the picker's 0.80 threshold; a checkpoint
   whose confident picks are right less often is never promoted.
4. Glim sends Laya one throwaway question at launch, so the first real pick doesn't hit the
   3-second timeout while Laya loads (measured: 3.4 s cold, 50–105 ms warm).

### C-8 · Use qwen3-vl:4b for now
User said (verbatim): "the lighter qwen3-vl:4b  can we use this model for now  after that i will
do it and also update the docs and devdocs".
Context: the audit log showed planning slowing from 5–7 s to 50–59 s over a day. Measured on
the owner's M2 / 16 GB: 9.9 GB of swap in use, about 80,000 pages a second compressed and
decompressed while idle, and `qwen3-vl:8b` at 3–6 tokens a second.
**Decision:** `qwen3-vl:4b` becomes the default planner for now, and `qwen3-vl:8b` is deleted
from this Mac (owner, verbatim: "delete that model"). It can be pulled again and chosen on the
AI Models page. This revisits C-5, which kept 8b because 4b
was measured no faster and worse at planning on a Mac that was not short of memory. The owner
will free memory (restart, fewer big apps) and may switch back.
