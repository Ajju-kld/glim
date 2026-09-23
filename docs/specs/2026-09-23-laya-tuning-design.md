# Laya tuning for Mac apps — design

Date: 2026-09-23 · Status: approved by the owner ("build it")

## Why

Laya is Glim's local second-opinion checker. Its published checkpoint (`cklxx/laya-browser`
v10s) was fine-tuned on web pages; Mac app controls ("Notes, 126 notes (Cell)", "Now playing
view") are outside what it saw. The upstream notes say a base checkpoint is near chance on a new
domain and fine-tuning is the fix. The goal is a **better second opinion**: catch more wrong
picks, raise fewer false alarms. Laya stays a checker; it never picks for Glim.

## Owner decisions

| Question | Answer |
|---|---|
| What should a tuned Laya do? | Better second opinion (stays a checker). |
| Where does training run? | On this Mac with MLX; data never leaves the Mac. |
| Where do labels come from? | Glim's own runs, reviewed by the owner. |
| Training approach | A: train the decision head, keep the encoder frozen. |

## Pieces

### 1. Collect (Swift, GlimCore + Glim)

- Every step where Laya answered (agrees, disagrees or abstains; not when unreachable) saves a
  `LayaExample`: goal, step summary (never typed text), action, app name, window title, the
  exact options Laya was shown (`number → "label (Role)"`), the planner's pick, and Laya's
  verdict in words (agrees / disagrees with its option and probability / abstains).
- Saved as one JSON line per example in
  `~/Library/Application Support/Glim/LayaExamples/examples.jsonl`. Nothing is uploaded.
- **Off by default.** A switch on the Laya Training page turns saving on; turning it on is
  logged. A "Delete all examples" button empties the file.
- **Masking:** before saving, any word that looks like a secret — 8 or more characters with
  no spaces mixing all four of lowercase, uppercase, digits and symbols
  (`Qx7.pL2@vN9^k`) — is replaced with `[hidden]`. Password fields never reach the table.

### 2. Review (Swift, Glim control panel)

- A "Laya Training" page shows unreviewed examples one at a time: the step, the options, the
  planner's pick and Laya's pick.
- The owner marks: **planner was right**, **another option was right** (click it), or
  **skip**. The review is written back to the example (`correctOption`, `reviewedAt`).
- Counts shown: saved, reviewed, apps covered, and whether the training minimum is met.

### 3. Score (Python, `services/laya/training/`)

- Reads reviewed examples. A deterministic split by a hash of the example id puts 20 % in the
  **test set**, never trained on.
- For each test example the model answers the same `choice` question Glim sends. Metrics:
  - **catch rate** — of examples where the planner's pick was wrong, how often the model
    confidently disagreed (probability ≥ Glim's `disagreementConfidenceThreshold`, 0.60).
  - **false-alarm rate** — of examples where the planner was right, how often the model
    confidently disagreed.
  - **top-1 accuracy** — the model's choice equals the reviewed correct option.

### 4. Train (Python + MLX)

- Loads the active checkpoint with `laya_mlx`, freezes the encoder, and trains the decision
  head, type embedding, scorer and act head with cross-entropy on the correct option.
- Writes a new checkpoint to `services/laya/checkpoints/<timestamp>/` (weights, copied
  encoder config, tokenizer and config with a `glim_training` note). The published model in
  `model-cache/` is never modified.
- Minimum data: 200 reviewed examples from at least 5 apps. Below that, `train-laya.sh`
  refuses and prints the current score only.

### 5. Promote and roll back

- A new checkpoint becomes active only if, on the test set, its catch rate is higher and its
  false-alarm rate is not higher than the active one's. When the test set has no wrong picks
  to catch, higher top-1 accuracy (still without more false alarms) decides.
- The active checkpoint is recorded in `services/laya/checkpoints/active.json`. No file means
  the published v10s.
- `services/laya/glim_serve.py` starts the Laya service with the active checkpoint;
  `scripts/start-laya.sh` runs it. `scripts/train-laya.sh --rollback` removes `active.json`.

## Update — Laya also picks (decision C-7)

`LayaPicker` now lets a confident Laya (≥ 0.80) choose the control before the language model is
asked, so the data and the score also serve that job:

- The picker's question carries the app name and window title, like the checker's and the
  saved examples', so training and use see the same inputs.
- Each example records `pickedBy` (`exactLabel`, `onlyField`, `planMatch`, `laya`,
  `languageModel`; absent in older examples). The review page marks Laya's own picks. A Laya
  pick the owner only confirmed counts half in the loss, so Laya doesn't mostly learn from
  agreeing with itself.
- The score adds **pick coverage** (share of test examples Laya would pick at ≥ 0.80) and
  **pick precision** (share of those that are right). Promotion also requires pick precision
  not to drop.

## Unchanged safety

Laya's answer can still only add a confirmation, never remove one. Training data is local,
masked and deletable. Nothing in this pipeline sends data off the Mac.

## Testing

- Swift: example building (options match what Laya was shown), masking, store append/read/
  review/delete, collection only when switched on and only when Laya answered, review counts.
- Python (`unittest`, no new dependencies): example loading and filtering, deterministic split,
  metric maths, the promotion rule, checkpoint writing, and a tiny training run on a small
  random head that must lower its loss.

## Out of scope

Training the encoder (approach B); any cloud GPU.
