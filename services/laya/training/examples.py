"""Reviewed Laya examples saved by Glim, the train/test split, and the training minimum."""

import hashlib
import json
from pathlib import Path

# Business rules, the same as LayaExampleSummary in GlimCore.
MINIMUM_REVIEWED_EXAMPLES = 200
MINIMUM_APPS = 5
# Business rule: one example in this many is held back for testing and never trained on.
TEST_SHARE_DENOMINATOR = 5

# Glim's `pickedBy` value when Laya itself chose the control (LayaPicker in GlimCore).
PICKED_BY_LAYA = "laya"
# Tunable: when the owner confirms a pick Laya made itself, the example repeats what Laya already
# believed, so it counts this much in the loss instead of fully.
LAYA_SELF_CONFIRMED_WEIGHT = 0.5

DEFAULT_EXAMPLES_PATH = (
    Path.home() / "Library/Application Support/Glim/LayaExamples/examples.jsonl"
)


def load_reviewed_examples(path: Path) -> list[dict]:
    """Examples the owner marked with a correct option; skipped and unreviewed ones are left out."""
    if not path.exists():
        return []
    examples = [json.loads(line) for line in path.read_text().splitlines() if line.strip()]
    return [
        example for example in examples
        if (example.get("review") or {}).get("correctOption") is not None
    ]


def is_test_example(example: dict) -> bool:
    """Decided by a hash of the id, so an example stays on the same side across runs."""
    digest = hashlib.sha256(example["id"].encode()).digest()
    return int.from_bytes(digest[:8], "big") % TEST_SHARE_DENOMINATOR == 0


def split_examples(examples: list[dict]) -> tuple[list[dict], list[dict]]:
    """(training examples, test examples)."""
    training = [example for example in examples if not is_test_example(example)]
    testing = [example for example in examples if is_test_example(example)]
    return training, testing


def training_minimum_problem(examples: list[dict]) -> str | None:
    """Why there isn't enough reviewed data to train yet, or None when there is."""
    if len(examples) < MINIMUM_REVIEWED_EXAMPLES:
        return (
            f"Only {len(examples)} reviewed examples; training needs "
            f"{MINIMUM_REVIEWED_EXAMPLES}."
        )
    app_count = len({example["question"]["app"] for example in examples})
    if app_count < MINIMUM_APPS:
        return f"Examples come from {app_count} apps; training needs {MINIMUM_APPS} apps."
    return None


def training_weight(example: dict) -> float:
    """How much the example counts in the loss. Examples saved before Glim recorded `pickedBy`
    count fully."""
    confirmed_own_pick = (
        example.get("pickedBy") == PICKED_BY_LAYA
        and example["review"]["correctOption"] == example["plannerPick"]
    )
    return LAYA_SELF_CONFIRMED_WEIGHT if confirmed_own_pick else 1.0


def choice_question(example: dict) -> tuple[dict, dict]:
    """(state, questions) exactly as Glim sends them to Laya."""
    question = example["question"]
    state = {
        "goal": question["goal"],
        "step": question["step"],
        "action": question["action"],
        "app": question["app"],
        "windowTitle": question.get("windowTitle"),
    }
    questions = {
        "target": {
            "type": "choice",
            "instructions": question["instructions"],
            "criteria": question["options"],
        }
    }
    return state, questions
