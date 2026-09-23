"""Which checkpoint the Laya service runs. No pointer means the published v10s model."""

import json
from pathlib import Path

CHECKPOINTS_DIRECTORY = Path(__file__).resolve().parent.parent / "checkpoints"
ACTIVE_POINTER_NAME = "active.json"


def active_checkpoint(root: Path = CHECKPOINTS_DIRECTORY) -> Path | None:
    pointer = root / ACTIVE_POINTER_NAME
    if not pointer.exists():
        return None
    path = Path(json.loads(pointer.read_text())["path"])
    return path if path.is_dir() else None


def set_active_checkpoint(root: Path, checkpoint: Path) -> None:
    root.mkdir(parents=True, exist_ok=True)
    (root / ACTIVE_POINTER_NAME).write_text(json.dumps({"path": str(checkpoint)}, indent=2) + "\n")


def clear_active_checkpoint(root: Path = CHECKPOINTS_DIRECTORY) -> None:
    (root / ACTIVE_POINTER_NAME).unlink(missing_ok=True)
