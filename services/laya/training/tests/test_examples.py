import json
import tempfile
import unittest
from pathlib import Path

from training.examples import (
    LAYA_SELF_CONFIRMED_WEIGHT,
    load_reviewed_examples,
    split_examples,
    training_minimum_problem,
    training_weight,
)


def example(example_id, app="Notes", correct="1", planner_pick="1", picked_by=None):
    item = {
        "id": example_id,
        "createdAt": "2026-09-23T08:00:00Z",
        "question": {
            "goal": "add a note",
            "step": "Click “New Note” in Notes",
            "action": "click",
            "app": app,
            "windowTitle": "Notes",
            "instructions": "Which numbered control performs this step: Click “New Note” in Notes?",
            "options": {"1": "New Note (Button)", "2": "Archive (Button)"},
        },
        "plannerPick": planner_pick,
        "layaVerdict": "agrees",
        "review": None if correct == "unreviewed" else {"correctOption": correct, "reviewedAt": "2026-09-23T09:00:00Z"},
    }
    if picked_by is not None:
        item["pickedBy"] = picked_by
    return item


class LoadingTests(unittest.TestCase):
    def test_only_examples_with_a_correct_option_are_used(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "examples.jsonl"
            lines = [example("a"), example("b", correct=None), example("c", correct="unreviewed")]
            path.write_text("\n".join(json.dumps(line) for line in lines) + "\n")

            reviewed = load_reviewed_examples(path)

        self.assertEqual([item["id"] for item in reviewed], ["a"])

    def test_missing_file_means_no_examples(self):
        self.assertEqual(load_reviewed_examples(Path("/nonexistent/examples.jsonl")), [])


class SplitTests(unittest.TestCase):
    def test_split_is_stable_and_holds_back_about_a_fifth(self):
        examples = [example(f"id-{number}") for number in range(500)]

        first_train, first_test = split_examples(examples)
        second_train, second_test = split_examples(list(reversed(examples)))

        self.assertEqual({item["id"] for item in first_test}, {item["id"] for item in second_test})
        self.assertEqual(len(first_train) + len(first_test), 500)
        self.assertTrue(70 <= len(first_test) <= 130)


class MinimumTests(unittest.TestCase):
    def test_too_few_examples_are_refused(self):
        examples = [example(f"id-{number}", app=f"App {number % 5}") for number in range(20)]

        self.assertIn("200", training_minimum_problem(examples))

    def test_too_few_apps_are_refused(self):
        examples = [example(f"id-{number}") for number in range(200)]

        self.assertIn("5 apps", training_minimum_problem(examples))

    def test_enough_examples_from_enough_apps_pass(self):
        examples = [example(f"id-{number}", app=f"App {number % 5}") for number in range(200)]

        self.assertIsNone(training_minimum_problem(examples))


class TrainingWeightTests(unittest.TestCase):
    def test_laya_confirming_its_own_pick_counts_less(self):
        self_confirmed = example("a", correct="1", planner_pick="1", picked_by="laya")

        self.assertEqual(training_weight(self_confirmed), LAYA_SELF_CONFIRMED_WEIGHT)

    def test_laya_pick_corrected_by_the_owner_counts_fully(self):
        corrected = example("a", correct="2", planner_pick="1", picked_by="laya")

        self.assertEqual(training_weight(corrected), 1.0)

    def test_language_model_and_older_examples_count_fully(self):
        self.assertEqual(training_weight(example("a", picked_by="languageModel")), 1.0)
        self.assertEqual(training_weight(example("b")), 1.0)


if __name__ == "__main__":
    unittest.main()
