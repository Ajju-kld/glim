"""Trains Laya's decision head on reviewed examples with MLX; the encoder stays frozen."""

import json
import shutil
from datetime import datetime
from pathlib import Path

import mlx.core as mx
import mlx.nn as nn
import mlx.optimizers as optim
from mlx.utils import tree_flatten
from laya_mlx.agent import collate_items

from training.examples import choice_question, training_weight

# Tunable: small steps keep the published model's skill while it learns Mac apps.
LEARNING_RATE = 1e-4
# Tunable: passes over the training examples.
EPOCHS = 3
# Tunable: examples per step; small enough for a 16 GB Mac.
BATCH_SIZE = 8


def freeze_encoder(model) -> None:
    """Only the head, type embedding, scorer and act head learn (approach A)."""
    model.freeze()
    for part in (model.head, model.type_emb, model.scorer, model.act_head):
        part.unfreeze()


def choice_loss(
    model, batch: dict, correct_indices: mx.array, example_weights: mx.array | None = None
) -> mx.array:
    """Cross-entropy on the correct option, averaged by each example's weight."""
    logits, _ = model(**batch)
    losses = nn.losses.cross_entropy(logits, correct_indices, reduction="none")
    if example_weights is None:
        return losses.mean()
    return (losses * example_weights).sum() / example_weights.sum()


def train_steps(model, batches, learning_rate: float = LEARNING_RATE) -> list[float]:
    """One optimizer step per (batch, correct indices, example weights or None); returns each
    step's loss."""
    optimizer = optim.Adam(learning_rate=learning_rate)
    loss_and_gradients = nn.value_and_grad(model, choice_loss)
    losses = []
    for batch, correct_indices, example_weights in batches:
        loss, gradients = loss_and_gradients(model, batch, correct_indices, example_weights)
        optimizer.update(model, gradients)
        mx.eval(model.parameters(), optimizer.state)
        losses.append(loss.item())
    return losses


def example_batches(agent, examples: list[dict], batch_size: int = BATCH_SIZE):
    """Batches in Laya's own input format, with the index of each correct option and each
    example's weight."""
    for start in range(0, len(examples), batch_size):
        chunk = examples[start : start + batch_size]
        items, correct_indices, example_weights = [], [], []
        for example in chunk:
            state, questions = choice_question(example)
            prepared, internal = agent.prepare(state, questions)
            items.append(prepared[0])
            option_numbers = list(internal[0]["crit"])
            correct_indices.append(option_numbers.index(example["review"]["correctOption"]))
            example_weights.append(training_weight(example))
        batch = collate_items(
            items, agent.tok.pad_token_id, max_length=agent.cfg.get("max_len", 512))
        yield (
            {key: mx.array(value) for key, value in batch.items()},
            mx.array(correct_indices),
            mx.array(example_weights),
        )


def train(agent, examples: list[dict], epochs: int = EPOCHS) -> list[float]:
    """Trains `agent.model` in place and returns the loss of every step."""
    freeze_encoder(agent.model)
    agent.model.train()
    losses = []
    for _ in range(epochs):
        losses += train_steps(agent.model, list(example_batches(agent, examples)))
    agent.model.eval()
    return losses


def save_checkpoint(agent, source_directory: Path, checkpoints_root: Path, note: dict) -> Path:
    """Writes the trained weights beside a copy of the source's encoder config and tokenizer."""
    destination = checkpoints_root / datetime.now().strftime("%Y-%m-%dT%H%M%S")
    destination.mkdir(parents=True)
    for folder in ("encoder", "tokenizer"):
        shutil.copytree(source_directory / folder, destination / folder)
    config = json.loads((source_directory / "rl_agent_config.json").read_text())
    config["glim_training"] = note
    (destination / "rl_agent_config.json").write_text(json.dumps(config, indent=2) + "\n")
    mx.save_safetensors(str(destination / "model.safetensors"), checkpoint_weights(agent.model))
    return destination


def checkpoint_weights(model) -> dict:
    """Every parameter under the names Laya's loader expects, in half precision like the
    published checkpoint."""
    return {name: value.astype(mx.float16) for name, value in tree_flatten(model.parameters())}
