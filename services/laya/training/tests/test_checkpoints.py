import json
import tempfile
import unittest
from pathlib import Path

from training.checkpoints import active_checkpoint, clear_active_checkpoint, set_active_checkpoint


class ActiveCheckpointTests(unittest.TestCase):
    def test_no_pointer_means_the_published_model(self):
        with tempfile.TemporaryDirectory() as directory:
            self.assertIsNone(active_checkpoint(Path(directory)))

    def test_pointer_round_trips_and_rolls_back(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            checkpoint = root / "2026-09-23T120000"
            checkpoint.mkdir()

            set_active_checkpoint(root, checkpoint)
            self.assertEqual(active_checkpoint(root), checkpoint)
            self.assertEqual(json.loads((root / "active.json").read_text())["path"], str(checkpoint))

            clear_active_checkpoint(root)
            self.assertIsNone(active_checkpoint(root))

    def test_pointer_to_a_missing_folder_is_ignored(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "active.json").write_text(json.dumps({"path": str(root / "gone")}))

            self.assertIsNone(active_checkpoint(root))


if __name__ == "__main__":
    unittest.main()
