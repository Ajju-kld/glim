"""How well a model second-guesses the planner and picks controls itself, and whether a new
checkpoint is better."""

from dataclasses import dataclass
from typing import Callable

# Tunable, the same as CheckerTuning.disagreementConfidenceThreshold in GlimCore: a
# disagreement counts only at this probability or above.
DISAGREEMENT_CONFIDENCE_THRESHOLD = 0.60
# Tunable, the same as LayaPicker.defaultConfidenceThreshold in GlimCore: Laya's pick replaces the
# language model's only at this probability or above.
PICK_CONFIDENCE_THRESHOLD = 0.80


@dataclass(frozen=True)
class Score:
    """None means there were no examples to measure that rate on."""

    catch_rate: float | None
    false_alarm_rate: float | None
    accuracy: float | None
    example_count: int
    # Share of examples Laya would pick for Glim, and how often those picks are right.
    pick_coverage: float | None = None
    pick_precision: float | None = None

    def describe(self) -> str:
        def percent(value):
            return "n/a" if value is None else f"{value:.0%}"
        return (
            f"caught {percent(self.catch_rate)} of wrong picks, "
            f"{percent(self.false_alarm_rate)} false alarms, "
            f"top-1 {percent(self.accuracy)}, "
            f"picks {percent(self.pick_coverage)} of steps with {percent(self.pick_precision)} right "
            f"({self.example_count} test examples)"
        )


def _rate(hits: int, total: int) -> float | None:
    return hits / total if total else None


def score_examples(
    examples: list[dict],
    predict: Callable[[dict], dict[str, float]],
    confidence_threshold: float = DISAGREEMENT_CONFIDENCE_THRESHOLD,
    pick_threshold: float = PICK_CONFIDENCE_THRESHOLD,
) -> Score:
    """Scores `predict`, which maps an example to its option probabilities."""
    wrong_picks = caught = right_picks = false_alarms = correct_answers = 0
    confident_picks = confident_right_picks = 0
    for example in examples:
        probabilities = predict(example)
        choice = max(probabilities, key=probabilities.get)
        correct_option = example["review"]["correctOption"]
        planner_pick = example["plannerPick"]
        disagrees_confidently = (
            choice != planner_pick and probabilities[choice] >= confidence_threshold
        )
        correct_answers += choice == correct_option
        if probabilities[choice] >= pick_threshold:
            confident_picks += 1
            confident_right_picks += choice == correct_option
        if planner_pick == correct_option:
            right_picks += 1
            false_alarms += disagrees_confidently
        else:
            wrong_picks += 1
            caught += disagrees_confidently
    return Score(
        catch_rate=_rate(caught, wrong_picks),
        false_alarm_rate=_rate(false_alarms, right_picks),
        accuracy=_rate(correct_answers, len(examples)),
        example_count=len(examples),
        pick_coverage=_rate(confident_picks, len(examples)),
        pick_precision=_rate(confident_right_picks, confident_picks),
    )


def should_promote(current: Score, candidate: Score) -> bool:
    """A candidate replaces the current model only if it catches more wrong picks without more
    false alarms, and its own confident picks are not less often right. With no wrong picks in
    the test set to catch, higher accuracy decides."""
    if (candidate.false_alarm_rate or 0.0) > (current.false_alarm_rate or 0.0):
        return False
    if (
        current.pick_precision is not None
        and candidate.pick_precision is not None
        and candidate.pick_precision < current.pick_precision
    ):
        return False
    if current.catch_rate is not None and candidate.catch_rate is not None:
        return candidate.catch_rate > current.catch_rate
    return (candidate.accuracy or 0.0) > (current.accuracy or 0.0)
