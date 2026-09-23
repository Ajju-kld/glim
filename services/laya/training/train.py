"""Scores Laya on the owner's reviewed examples, trains a new checkpoint, and promotes it only
if it is better. Run through scripts/train-laya.sh, which keeps everything offline."""

import argparse
import sys
from pathlib import Path

import laya_mlx
from laya_mlx.agent import resolve_model

from training import checkpoints
from training.examples import (
    DEFAULT_EXAMPLES_PATH,
    choice_question,
    load_reviewed_examples,
    split_examples,
    training_minimum_problem,
)
from training.metrics import score_examples, should_promote
from training.trainer import EPOCHS, save_checkpoint, train

PUBLISHED_MODEL = "cklxx/laya-browser"
PUBLISHED_SUBFOLDER = "v10s"


def source_checkpoint() -> Path:
    """The active trained checkpoint, or the published model from the local cache."""
    return checkpoints.active_checkpoint() or resolve_model(
        PUBLISHED_MODEL, subfolder=PUBLISHED_SUBFOLDER)


def predictor(agent):
    def predict(example: dict) -> dict[str, float]:
        state, questions = choice_question(example)
        return agent.system_one(state, questions)["answers"]["target"]["probabilities"]
    return predict


def main(arguments: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="train-laya", description=__doc__)
    parser.add_argument("--examples", type=Path, default=DEFAULT_EXAMPLES_PATH)
    parser.add_argument("--epochs", type=int, default=EPOCHS)
    parser.add_argument("--score-only", action="store_true", help="score the active model, don't train")
    parser.add_argument("--rollback", action="store_true", help="go back to the published model")
    options = parser.parse_args(arguments)

    if options.rollback:
        checkpoints.clear_active_checkpoint()
        print("Rolled back: Laya uses the published model. Restart Laya to apply.")
        return 0

    examples = load_reviewed_examples(options.examples)
    if not examples:
        print(f"No reviewed examples in {options.examples}. Review some on Glim's Laya Training page.")
        return 1
    training_examples, test_examples = split_examples(examples)
    source = source_checkpoint()
    print(f"Active model: {source}")

    current_score = score_examples(test_examples, predictor(laya_mlx.load(source)))
    print(f"Current Laya:  {current_score.describe()}")

    problem = training_minimum_problem(examples)
    if options.score_only or problem:
        if problem:
            print(f"Not training: {problem}")
        return 0

    agent = laya_mlx.load(source, dtype="float32")
    losses = train(agent, training_examples, epochs=options.epochs)
    print(f"Trained on {len(training_examples)} examples; loss {losses[0]:.3f} → {losses[-1]:.3f}")
    candidate_score = score_examples(test_examples, predictor(agent))
    print(f"New Laya:      {candidate_score.describe()}")

    checkpoint = save_checkpoint(
        agent, source, checkpoints.CHECKPOINTS_DIRECTORY,
        note={"trained_from": str(source), "examples": len(training_examples), "epochs": options.epochs})
    if should_promote(current_score, candidate_score):
        checkpoints.set_active_checkpoint(checkpoints.CHECKPOINTS_DIRECTORY, checkpoint)
        print(f"Promoted {checkpoint.name}. Restart Laya (scripts/start-laya.sh) to use it.")
    else:
        print(f"Kept the current model; the new one is saved in {checkpoint} but not used.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
