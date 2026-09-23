"""How well a model second-guesses the planner, and whether a new checkpoint is better."""

from dataclasses import dataclass
from typing import Callable

# Tunable, the same as CheckerTuning.disagreementConfidenceThreshold in GlimCore: a
# disagreement counts only at this probability or above.
DISAGREEMENT_CONFIDENCE_THRESHOLD = 0.60


@dataclass(frozen=True)
class Score:
    """None means there were no examples to measure that rate on."""

    catch_rate: float | None
    false_alarm_rate: float | None
    accuracy: float | None
    example_count: int

    def describe(self) -> str:
        def percent(value):
            return "n/a" if value is None else f"{value:.0%}"
        return (
            f"caught {percent(self.catch_rate)} of wrong picks, "
            f"{percent(self.false_alarm_rate)} false alarms, "
            f"top-1 {percent(self.accuracy)} ({self.example_count} test examples)"
        )


def _rate(hits: int, total: int) -> float | None:
    return hits / total if total else None


def score_examples(
    examples: list[dict],
    predict: Callable[[dict], dict[str, float]],
    confidence_threshold: float = DISAGREEMENT_CONFIDENCE_THRESHOLD,
) -> Score:
    """Scores `predict`, which maps an example to its option probabilities."""
    wrong_picks = caught = right_picks = false_alarms = correct_answers = 0
    for example in examples:
        probabilities = predict(example)
        choice = max(probabilities, key=probabilities.get)
        correct_option = example["review"]["correctOption"]
        planner_pick = example["plannerPick"]
        disagrees_confidently = (
            choice != planner_pick and probabilities[choice] >= confidence_threshold
        )
        correct_answers += choice == correct_option
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
    )


def should_promote(current: Score, candidate: Score) -> bool:
    """A candidate replaces the current model only if it catches more wrong picks without more
    false alarms. With no wrong picks in the test set to catch, higher accuracy decides."""
    if (candidate.false_alarm_rate or 0.0) > (current.false_alarm_rate or 0.0):
        return False
    if current.catch_rate is not None and candidate.catch_rate is not None:
        return candidate.catch_rate > current.catch_rate
    return (candidate.accuracy or 0.0) > (current.accuracy or 0.0)
