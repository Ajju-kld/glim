# Laya service (v1 checker)

Glim's local second-opinion checker talks to `localdecide` from
[ChenneyZhuang/laya-browser-agent](https://github.com/ChenneyZhuang/laya-browser-agent)
(Apache-2.0), running the browser-tuned `cklxx/laya-browser` v10s model (Apache-2.0, ~650 MB)
on the MLX backend.

Start it with:

```sh
scripts/start-laya.sh
```

The first run clones the source, creates a Python virtual environment and downloads the model.
**Everything stays inside `services/laya/`** — `src/`, `.venv/` and `model-cache/` (all
git-ignored). Stop it with Ctrl-C. Glim never starts it for you.

## Pinned version

| Item | Value |
|---|---|
| Repository | `https://github.com/ChenneyZhuang/laya-browser-agent.git` |
| Pinned commit | `bafba5975cc1bdb0138f3baa5330108afa0f9055` (HEAD on 2026-09-23) |
| Python | Homebrew 3.13 (`laya-mlx` needs ≥ 3.11) |
| Extra | `.[mlx]` → `laya-mlx` |

`scripts/start-laya.sh` refuses to run if the checked-out commit differs from the pin.

## Review notes (2026-09-23)

Reviewed `localdecide/serve.py` (190 lines) and scanned the package from a snapshot of the
repository's main branch taken during research on 2026-09-22/23.

- **Binds `127.0.0.1` by default** (`serve(host="127.0.0.1", port=8791)`); the start script
  also sets `LOCALDECIDE_HOST=127.0.0.1` and passes `--host 127.0.0.1` explicitly.
- **No authentication.** Any local process can ask it for decisions. Accepted: Glim uses Laya
  only as a checker, so a spoofed answer can add or remove a confirmation but can never loosen
  the safety gate.
- **Request bodies capped** at 4 MB (`MAX_BODY_BYTES`); malformed JSON returns 400.
- **No shell execution in the server path.** `subprocess` appears only in `cli.py` for
  `sysctl` hardware readouts in `localdecide doctor`.
- **Outbound network:** `backends/base.py` has an HTTP client for *remote* backends (Jev or
  another server). Glim's setup uses the local MLX backend, so it isn't used. The model download
  on first run goes to Hugging Face, into `model-cache/`.
- **No CORS headers**, so web pages can't read its answers.

**Before the first run, re-check the pinned commit** — the review above was of a snapshot, not
byte-for-byte of the pin:

```sh
git -C services/laya/src show --stat bafba5975cc1bdb0138f3baa5330108afa0f9055
git -C services/laya/src diff bafba5975cc1bdb0138f3baa5330108afa0f9055 -- localdecide/serve.py
```

## v2 plan

Replace the service with in-process CoreML behind the same `TargetChecker` interface: adapt
FluidUse's Apache-2.0 Swift tokenizer and scoring, and convert v10s once with Python on the
development side.
