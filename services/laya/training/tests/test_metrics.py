import unittest

from training.metrics import Score, score_examples, should_promote
from training.tests.test_examples import example


def fixed_model(answers):
    """A model that answers each example id with a fixed (choice, probability)."""
    def predict(item):
        choice, probability = answers[item["id"]]
        return {choice: probability}
    return predict


class ScoreTests(unittest.TestCase):
    def test_catch_rate_false_alarm_rate_and_accuracy(self):
        examples = [
            example("wrong-caught", correct="2", planner_pick="1"),
            example("wrong-missed", correct="2", planner_pick="1"),
            example("right-quiet", correct="1", planner_pick="1"),
            example("right-alarm", correct="1", planner_pick="1"),
        ]
        model = fixed_model({
            "wrong-caught": ("2", 0.9),
            "wrong-missed": ("2", 0.5),
            "right-quiet": ("1", 0.95),
            "right-alarm": ("2", 0.8),
        })

        score = score_examples(examples, model, confidence_threshold=0.6)

        self.assertEqual(score.catch_rate, 0.5)
        self.assertEqual(score.false_alarm_rate, 0.5)
        self.assertEqual(score.accuracy, 0.75)

    def test_rates_without_cases_are_none(self):
        score = score_examples([example("right")], fixed_model({"right": ("1", 0.9)}), 0.6)

        self.assertIsNone(score.catch_rate)
        self.assertEqual(score.false_alarm_rate, 0.0)


class PromotionTests(unittest.TestCase):
    def test_better_catch_rate_without_more_false_alarms_is_promoted(self):
        current = Score(catch_rate=0.4, false_alarm_rate=0.1, accuracy=0.6, example_count=50)
        candidate = Score(catch_rate=0.7, false_alarm_rate=0.1, accuracy=0.8, example_count=50)

        self.assertTrue(should_promote(current, candidate))

    def test_more_false_alarms_is_not_promoted(self):
        current = Score(catch_rate=0.4, false_alarm_rate=0.1, accuracy=0.6, example_count=50)
        candidate = Score(catch_rate=0.9, false_alarm_rate=0.2, accuracy=0.9, example_count=50)

        self.assertFalse(should_promote(current, candidate))

    def test_without_wrong_picks_to_catch_accuracy_decides(self):
        current = Score(catch_rate=None, false_alarm_rate=0.1, accuracy=0.6, example_count=50)
        candidate = Score(catch_rate=None, false_alarm_rate=0.1, accuracy=0.7, example_count=50)

        self.assertTrue(should_promote(current, candidate))


if __name__ == "__main__":
    unittest.main()
