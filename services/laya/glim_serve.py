"""Starts the Laya service on the active checkpoint (services/laya/checkpoints/active.json),
or on the published model when none is active. The cloned localdecide source is not changed."""

import os

from localdecide.backends.base import LayaMLXBackend
from localdecide.serve import serve

from training.checkpoints import active_checkpoint

checkpoint = active_checkpoint()
if checkpoint is not None:
    LayaMLXBackend.BROWSER_MODEL = str(checkpoint)
    LayaMLXBackend.BROWSER_SUBFOLDER = None
print(f"Laya model: {checkpoint or 'published cklxx/laya-browser v10s'}", flush=True)
serve(host=os.environ.get("LOCALDECIDE_HOST", "127.0.0.1"),
      port=int(os.environ.get("LOCALDECIDE_PORT", "8791")))
