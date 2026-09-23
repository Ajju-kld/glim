import unittest

import mlx.core as mx
import numpy as np
from laya_mlx.model import DecisionModel, EncoderConfig, sanitize_weights

from training.trainer import checkpoint_weights, choice_loss, freeze_encoder, train_steps


def tiny_model():
    encoder_config = EncoderConfig.from_dict({
        "vocab_size": 64, "hidden_size": 64, "intermediate_size": 128, "num_hidden_layers": 1,
        "num_attention_heads": 1, "max_position_embeddings": 64})
    return DecisionModel(encoder_config, {"head_layers": 1, "act_costs": {"escalate": 0.5}})


def tiny_batch():
    random = np.random.default_rng(7)
    return {
        "input_ids": mx.array(random.integers(1, 64, size=(4, 16)), dtype=mx.int32),
        "attention_mask": mx.ones((4, 16), dtype=mx.bool_),
        "marker_pos": mx.array([[2, 5, 9]] * 4, dtype=mx.int32),
        "marker_mask": mx.ones((4, 3), dtype=mx.bool_),
        "qtype": mx.zeros((4,), dtype=mx.int32),
    }, mx.array([0, 1, 2, 1], dtype=mx.int32)


class TrainerTests(unittest.TestCase):
    def test_training_lowers_the_choice_loss(self):
        model = tiny_model()
        freeze_encoder(model)
        batch, correct = tiny_batch()
        loss_before = choice_loss(model, batch, correct).item()

        train_steps(model, [(batch, correct, None)] * 30, learning_rate=1e-3)

        self.assertLess(choice_loss(model, batch, correct).item(), loss_before)

    def test_zero_weight_examples_do_not_count_toward_the_loss(self):
        model = tiny_model()
        batch, correct = tiny_batch()
        only_first = mx.array([1.0, 0.0, 0.0, 0.0])
        first_alone = {key: value[:1] for key, value in batch.items()}

        weighted = choice_loss(model, batch, correct, only_first).item()
        alone = choice_loss(model, first_alone, correct[:1]).item()

        self.assertAlmostEqual(weighted, alone, places=4)

    def test_encoder_weights_do_not_change(self):
        model = tiny_model()
        freeze_encoder(model)
        batch, correct = tiny_batch()
        encoder_before = np.array(model.encoder.embeddings.tok_embeddings.weight)

        train_steps(model, [(batch, correct, None)] * 3, learning_rate=1e-3)

        self.assertTrue(np.array_equal(encoder_before, np.array(model.encoder.embeddings.tok_embeddings.weight)))

    def test_saved_weights_load_back_through_layas_own_loader(self):
        trained = tiny_model()
        freeze_encoder(trained)
        batch, correct = tiny_batch()
        train_steps(trained, [(batch, correct, None)] * 2, learning_rate=1e-3)

        weights = sanitize_weights(checkpoint_weights(trained))
        reloaded = tiny_model()
        reloaded.load_weights(list(weights.items()), strict=True)

        trained_logits, _ = trained(**batch)
        reloaded_logits, _ = reloaded(**batch)
        self.assertTrue(np.allclose(np.array(trained_logits), np.array(reloaded_logits), atol=1e-2))


if __name__ == "__main__":
    unittest.main()
