"""Starts the Laya service on the active checkpoint (services/laya/checkpoints/active.json),
or on the published model when none is active. The cloned localdecide source is not changed."""

import os

from huggingface_hub import snapshot_download

from localdecide.backends.base import LayaMLXBackend
from localdecide.serve import serve

from training.checkpoints import active_checkpoint

# Business rule: the published model is pinned, like the Laya source in scripts/start-laya.sh.
# This is the last revision of cklxx/laya-browser that still ships v10s; the latest revision
# ships only v15s, which Glim has not been checked against. Change it only after re-checking.
PUBLISHED_MODEL = "cklxx/laya-browser"
PUBLISHED_REVISION = "4219958196e2c566c141688c773e08da10c1ff3b"
PUBLISHED_SUBFOLDER = "v10s"

checkpoint = active_checkpoint()
if checkpoint is not None:
    model_path = str(checkpoint)
    model_description = model_path
else:
    snapshot_path = snapshot_download(
        PUBLISHED_MODEL, revision=PUBLISHED_REVISION,
        allow_patterns=[f"{PUBLISHED_SUBFOLDER}/*"])
    model_path = os.path.join(snapshot_path, PUBLISHED_SUBFOLDER)
    model_description = (
        f"published {PUBLISHED_MODEL} {PUBLISHED_SUBFOLDER} at {PUBLISHED_REVISION[:7]}")
LayaMLXBackend.BROWSER_MODEL = model_path
LayaMLXBackend.BROWSER_SUBFOLDER = None
print(f"Laya model: {model_description}", flush=True)
serve(host=os.environ.get("LOCALDECIDE_HOST", "127.0.0.1"),
      port=int(os.environ.get("LOCALDECIDE_PORT", "8791")))
