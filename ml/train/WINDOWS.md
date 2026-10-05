# Fine-tuning on the Windows RTX 2060 box

The GPU machine for this project is a Windows 11 laptop with an **RTX
2060, 6 GB**, 16 GB RAM, reachable as `ssh win2060`. 6 GB is the
constraint that shapes every config in `train/configs/`.

## One-time setup

```powershell
# Flutter's bundled tooling is not needed for training, but the repo's
# other scripts expect it on PATH.
$env:Path = "C:\Users\Kepatuhan\flutter\bin;$env:Path"

# Work area (do not clone into a OneDrive-synced folder: the checkpoints
# are large and sync will fight the trainer for the files).
New-Item -ItemType Directory -Force C:\trareon-work | Out-Null
cd C:\trareon-work
git clone <repo> transcribe
cd transcribe\ml

uv sync --extra train --extra gpu --extra data
```

### Verify CUDA before anything else

```powershell
uv run python -c "import torch; print(torch.__version__, torch.cuda.is_available(), torch.cuda.get_device_name(0))"
```

Expect something like `2.6.0+cu124 True NVIDIA GeForce RTX 2060`. If
`cuda.is_available()` is `False`, the CPU wheel got installed; reinstall
torch from the CUDA index before continuing.

### Verify bitsandbytes

```powershell
uv run python -c "import bitsandbytes; print(bitsandbytes.__version__)"
```

`bitsandbytes` is what makes 4-bit and 8-bit base weights work, and it
is the component most likely to be missing or mismatched on Windows. If
the import fails:

- every config with `load_in_4bit` or `load_in_8bit` will fail, which on
  6 GB means **turbo will not fit at all**;
- `whisper-base-id` and `whisper-small-id` still work (they are fp16 and
  need no quantisation) except for `optim: adamw_bnb_8bit` — change that
  to `adamw_torch` and expect slightly higher memory use;
- install the wheel matching the installed CUDA toolkit, then re-verify.

## Always run the memory dry run first

```powershell
uv run python -m train.dry_run_memory --config train\configs\whisper-turbo-id-6gb.yaml
```

This runs a few real training steps on synthetic batches and prints
**peak reserved VRAM** against the card's total. It exits 0 if the run
fits with headroom and 1 if it does not, with a specific ordered list of
things to change.

Two Windows-specific reasons to trust the headroom margin rather than
the raw number:

- **The desktop compositor is on the same card.** Windows reserves a few
  hundred megabytes for the display, and that reservation grows when
  something redraws. The dry run's `SAFE_FRACTION` of 0.85 exists for
  this.
- **Close Chrome/Brave and any Electron apps before a long run.**
  Hardware-accelerated browsers hold VRAM, and a run that fit at launch
  will die three hours in when a tab wakes up.

## Train

```powershell
# Live-preview model first: it is the one that changes what users see
# during a meeting, and it trains in a fraction of the time.
.\train\train.ps1 -Config whisper-base-id

# The accuracy model.
.\train\train.ps1 -Config whisper-turbo-id-6gb

# Short smoke run before committing hours.
.\train\train.ps1 -Config whisper-turbo-id-6gb -Steps 20
```

`train.ps1` runs: memory dry run → train → merge adapter → GGML export →
tell you how to measure the result.

### It is resumable, and it will need to be

A 3000-step turbo run on a 2060 takes many hours. `resume: true` is the
default: re-running the same command picks up the newest
`checkpoint-N` in the output directory. The laptop sleeping, Windows
Update rebooting, or the SSH session dropping all cost one checkpoint
interval (`save_steps: 200`), not the run.

To start over deliberately: `uv run python -m train.lora --config ... --no-resume`.

## Do not, on this machine

These are the owner's standing rules for the office laptop:

- **No audio playback and no microphone capture.** File-import
  transcription, builds, unit tests, screenshots and GPU work are fine.
  A WASAPI live-capture test needs explicit permission and goes in the
  sprint report under *PERLU IZIN OWNER*.
- Do not log the user out, and do not touch the Hermes Desktop /
  Hermes_Gateway scheduled tasks or Telegram.
- Do not change system settings beyond what a task needs.
- Never disable Kaspersky. It may scan newly written `.safetensors` and
  `.bin` files, which slows checkpoint saves — that is expected, not a
  reason to turn it off.

## When 6 GB is not enough

`train/configs/whisper-turbo-id-kaggle-2xt4.yaml` is the fallback for
free Kaggle 2×T4 (16 GB each): 8-bit instead of 4-bit, a larger adapter,
a real batch size, and the full encoder. See
`train/kaggle_whisper_lora.ipynb`.

The ordered list of things to try on the 2060 before giving up is
printed by the memory dry run itself, and is:

1. `load_in_4bit: true`
2. `gradient_checkpointing: true`
3. `per_device_batch_size: 1`, raise `gradient_accumulation_steps`
4. lower `lora_r` (32 → 16 → 8)
5. `encoder_top_layers: 4 → 2 → null` (decoder-only adapter)
6. switch to the Kaggle config

## Running the app's own tests on Windows

Separate from training, and worth doing in the same session:

```powershell
cd C:\trareon-work\transcribe
$env:Path = "C:\Users\Kepatuhan\flutter\bin;$env:Path"
flutter test
flutter build windows --release
cd rust_core; cargo test --lib
```
