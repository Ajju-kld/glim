# See and click — design

Decision C-6: when an app gives Glim no usable control for a click step, qwen3-vl looks at a
screenshot of the app's front window and picks a point. Every such click asks the person
first, because the safety gate cannot check a label it never read.

## Scope

- **Click steps only.** Typing, Return and scrolling keep needing an accessibility control.
  Typing into a field found by sight would let the model choose where approved text lands
  with no field to check, so it stays out.
- **Fallback only.** The accessibility path runs first, unchanged. Sight is used when:
  - the window gave no controls at all (today: `noControlsRead`), or
  - the model reported that no offered control matches the step (today: `unknownTarget`).
- **Not used** for a disabled planned control or a title-bar button. Those stops stay as they
  are, so sight never works around a greyed-out button or the window buttons Glim never offers.

## Flow

1. The runner captures the front window with `WindowScreenshotter`. It keeps the PNG and the
   window's frame in global screen points at the moment of capture (`WindowCapture`). Both
   stay in memory only.
2. `Planner.locateByImage(step:goal:screenshot:)` sends the image to qwen3-vl with a JSON
   schema: `found`, `x`, `y` (0–1000 across the image, qwen3-vl's native grounding scale),
   `description` (what is at that point, in a few words) and `reason`. `found: false` stops
   the step with `unknownTarget`, as today.
3. The point becomes a `VisualTarget`: the capture frame, the 0–1000 point, the global screen
   point and the model's description.
4. The gate judges a `ProposedAction` carrying the visual target instead of an element:
   - **Deny** `visualTargetOutsideWindow` when the point is outside the window, or inside
     the title-bar strip at the top of the window (the window buttons live there).
   - **Risk words** are checked on the planned target and the model's description, as a
     label would be. A forbidden phrase denies the click, as it would for a label.
   - **Always ask:** `visualClick(description:)`. It is a danger reason, so it still asks
     with "Ask only before dangerous steps" on.
   - The tier rules are unchanged: a click the tier forbids is forbidden by sight too.
5. The confirmation panel shows the screenshot with a marker on the point, the model's
   description and the planned target. One click allows this one click only.
6. The executor re-reads the window frame right before clicking. If the window moved,
   resized or went away, the step stops (`windowMovedSinceCapture`). Otherwise it posts a
   left mouse down and up at the point to the app's process, only while the kill switch is
   armed, marked as Glim's own events, like the existing keyboard and scroll events.
7. Change check: the window is captured again and compared with the first capture. Any
   difference counts as a change. If the capture fails, the step counts as unchanged.
8. Audit: "Clicked by sight at (x, y) of 1000 in <App>: “<description>”". The Laya and Jev
   checkers are not asked, because they answer only about labelled options.

## Tunables

- Title-bar strip that is never clicked: 28 points.
- How far the window may move before the click is refused: 2 points.

## Failure handling

| Case | Result |
|---|---|
| No Screen Recording permission | Step stops with the existing permission error |
| Model says not found | `unknownTarget`, as today |
| Point outside the window or in the title bar | Denied: `visualTargetOutsideWindow` |
| Window moved between capture and click | Stopped: `windowMovedSinceCapture` |
| Person says no | Task stops, as for any confirmation |
