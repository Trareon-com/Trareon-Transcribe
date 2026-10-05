"""Does this config fit in VRAM? Answer before spending the afternoon.

    # On the RTX 2060 box
    uv run python -m train.dry_run_memory --config train/configs/whisper-turbo-id-6gb.yaml

Runs a handful of real training steps on synthetic batches and reports
**peak** allocated and reserved VRAM. Synthetic batches because the
question is a memory question: Whisper always encodes a padded 30-second
window, so a batch of random features of the right shape costs exactly
what a real one does, and no dataset has to exist yet.

Peak rather than final, because the peak is what triggers an
out-of-memory error — and it happens inside the backward pass, not after
it. A script that reports memory after `optimizer.step()` reports a
number that was never the problem.

The verdict compares peak reserved against the device's total with a
headroom margin, because a training run that fits with 50 MB to spare
fails the moment the display manager redraws. On Windows the desktop
compositor is using the same card.
"""

from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from pathlib import Path

from common.atomic import write_json
from train.config import TrainConfig, load_config
from train.lora import build_model

#: Fraction of total VRAM a run may peak at and still be called safe.
#: The rest is for the desktop, the driver and fragmentation.
SAFE_FRACTION = 0.85


@dataclass
class MemoryReport:
    config_name: str
    base_model: str
    device: str
    total_gib: float
    peak_allocated_gib: float
    peak_reserved_gib: float
    steps: int
    batch_size: int
    gradient_accumulation: int
    trainable_params: int
    total_params: int
    quantisation: str
    gradient_checkpointing: bool
    error: str | None = None

    @property
    def fits(self) -> bool:
        if self.error:
            return False
        if self.total_gib <= 0:
            return True  # CPU run: nothing to exceed
        return self.peak_reserved_gib <= self.total_gib * SAFE_FRACTION

    @property
    def headroom_gib(self) -> float:
        return max(0.0, self.total_gib - self.peak_reserved_gib)

    def as_dict(self) -> dict:
        return {
            "config": self.config_name,
            "base_model": self.base_model,
            "device": self.device,
            "total_gib": round(self.total_gib, 3),
            "peak_allocated_gib": round(self.peak_allocated_gib, 3),
            "peak_reserved_gib": round(self.peak_reserved_gib, 3),
            "headroom_gib": round(self.headroom_gib, 3),
            "safe_fraction": SAFE_FRACTION,
            "fits": self.fits,
            "steps": self.steps,
            "batch_size": self.batch_size,
            "gradient_accumulation": self.gradient_accumulation,
            "trainable_params": self.trainable_params,
            "total_params": self.total_params,
            "trainable_percent": (
                round(100.0 * self.trainable_params / self.total_params, 4)
                if self.total_params
                else 0.0
            ),
            "quantisation": self.quantisation,
            "gradient_checkpointing": self.gradient_checkpointing,
            "error": self.error,
        }

    def verdict(self) -> str:
        if self.error:
            return f"GAGAL: {self.error}"
        if self.total_gib <= 0:
            return (
                f"Dijalankan di CPU — tidak ada batas VRAM yang diuji. "
                f"Puncak alokasi dilaporkan {self.peak_allocated_gib:.2f} GiB (host)."
            )
        if self.fits:
            return (
                f"MUAT: puncak {self.peak_reserved_gib:.2f} GiB dari "
                f"{self.total_gib:.2f} GiB (sisa {self.headroom_gib:.2f} GiB)."
            )
        return (
            f"TIDAK MUAT dengan aman: puncak {self.peak_reserved_gib:.2f} GiB dari "
            f"{self.total_gib:.2f} GiB (ambang aman "
            f"{self.total_gib * SAFE_FRACTION:.2f} GiB).\n"
            "Coba, berurutan:\n"
            "  1. load_in_4bit: true (jika masih 8-bit atau fp16)\n"
            "  2. gradient_checkpointing: true\n"
            "  3. per_device_batch_size: 1, naikkan gradient_accumulation_steps\n"
            "  4. turunkan lora_r (32 -> 16 -> 8)\n"
            "  5. encoder_top_layers: 4 -> 2 -> null (adapter khusus decoder)\n"
            "  6. beralih ke train/configs/whisper-turbo-id-kaggle-2xt4.yaml"
        )


def _synthetic_batch(model, config: TrainConfig, device: str):
    """A batch of the exact shape real training uses.

    Whisper's encoder input is always (batch, n_mels, 3000) — 30 seconds
    of frames — regardless of clip length, so this costs what a real
    batch costs.
    """
    import torch

    mels = int(getattr(model.config, "num_mel_bins", 80))
    frames = 3000
    features = torch.randn(
        config.per_device_batch_size,
        mels,
        frames,
        dtype=torch.float16 if config.fp16 else torch.float32,
        device=device,
    )
    # A label sequence at the long end of what the tokenizer produces for
    # a 25-second utterance.
    labels = torch.randint(
        0,
        int(getattr(model.config, "vocab_size", 51865)) - 1,
        (config.per_device_batch_size, 96),
        dtype=torch.long,
        device=device,
    )
    return {"input_features": features, "labels": labels}


def measure(config: TrainConfig, *, steps: int = 3) -> MemoryReport:
    try:
        import torch
    except ImportError:  # pragma: no cover - dependency guard
        raise SystemExit("`torch` belum terpasang; uv sync --extra train") from None

    device = "cuda" if torch.cuda.is_available() else "cpu"
    total_gib = 0.0
    if device == "cuda":
        total_gib = torch.cuda.get_device_properties(0).total_memory / 1024**3
        torch.cuda.empty_cache()
        torch.cuda.reset_peak_memory_stats()

    quantisation = (
        "4-bit NF4" if config.load_in_4bit else "8-bit" if config.load_in_8bit else "fp16/fp32"
    )

    report = MemoryReport(
        config_name=config.name,
        base_model=config.base_model,
        device=(torch.cuda.get_device_name(0) if device == "cuda" else "cpu"),
        total_gib=total_gib,
        peak_allocated_gib=0.0,
        peak_reserved_gib=0.0,
        steps=steps,
        batch_size=config.per_device_batch_size,
        gradient_accumulation=config.gradient_accumulation_steps,
        trainable_params=0,
        total_params=0,
        quantisation=quantisation,
        gradient_checkpointing=config.gradient_checkpointing,
    )

    try:
        model, _processor = build_model(config)
        model.to(device)
        if config.gradient_checkpointing:
            model.gradient_checkpointing_enable()
        model.train()

        report.trainable_params = sum(
            parameter.numel() for parameter in model.parameters() if parameter.requires_grad
        )
        report.total_params = sum(parameter.numel() for parameter in model.parameters())

        parameters = [p for p in model.parameters() if p.requires_grad]
        optimizer = torch.optim.AdamW(parameters, lr=config.learning_rate)
        scaler = torch.amp.GradScaler("cuda") if (config.fp16 and device == "cuda") else None

        for _ in range(steps):
            batch = _synthetic_batch(model, config, device)
            with torch.autocast(device_type=device, dtype=torch.float16, enabled=config.fp16):
                loss = model(**batch).loss
            if scaler is not None:
                scaler.scale(loss).backward()
                scaler.step(optimizer)
                scaler.update()
            else:
                loss.backward()
                optimizer.step()
            optimizer.zero_grad(set_to_none=True)

        if device == "cuda":
            report.peak_allocated_gib = torch.cuda.max_memory_allocated() / 1024**3
            report.peak_reserved_gib = torch.cuda.max_memory_reserved() / 1024**3
    except torch.cuda.OutOfMemoryError as error:  # pragma: no cover - GPU only
        report.error = f"CUDA out of memory: {str(error)[:200]}"
        if device == "cuda":
            report.peak_reserved_gib = torch.cuda.max_memory_reserved() / 1024**3
            report.peak_allocated_gib = torch.cuda.max_memory_allocated() / 1024**3
    except Exception as error:
        report.error = f"{type(error).__name__}: {str(error)[:300]}"
    return report


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="train.dry_run_memory")
    parser.add_argument("--config", required=True)
    parser.add_argument("--steps", type=int, default=3)
    parser.add_argument("--json", default=None, help="tulis laporan ke berkas")
    args = parser.parse_args(argv)

    config = load_config(args.config)
    report = measure(config, steps=args.steps)

    print(json.dumps(report.as_dict(), ensure_ascii=False, indent=2))
    print()
    print(report.verdict())
    if args.json:
        write_json(Path(args.json), report.as_dict())
    return 0 if report.fits else 1


if __name__ == "__main__":
    raise SystemExit(main())
