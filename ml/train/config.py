"""Training configuration.

A dataclass plus YAML files rather than a pile of CLI flags, because a
fine-tune that cannot be reproduced from a file in the repository is a
fine-tune nobody can check. Every run writes its resolved config next to
its checkpoints.

The defaults are set for **one RTX 2060 with 6 GB**, which is the
machine this sprint has. That constraint drives almost every choice
here, and the ones worth knowing about are:

* `max_clip_secs = 25`. Whisper's encoder always processes a padded
  30-second window, so clip length does not change encoder memory — but
  it does change how much of each example is padding, and the alignment
  pipeline caps utterances at 25 s for the same reason.
* `per_device_batch_size` of 1–4 with `gradient_accumulation_steps` to
  reach a useful effective batch. On 6 GB, turbo only fits at 1.
* `gradient_checkpointing` trades about 30% speed for a large memory
  saving, and on 6 GB it is not optional for anything above `small`.
* 4-bit base weights (`load_in_4bit`) for turbo; `small` and `base` fit
  in fp16 without quantisation, and quantising them would cost accuracy
  for memory that is not needed.
* LoRA on attention projections only (`q_proj`, `v_proj` by default).
  For turbo on 6 GB the encoder is frozen except its top layers — see
  `encoder_top_layers` — because the decoder is where Indonesian
  vocabulary and style live, and the encoder's acoustic features
  transfer.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass, field, fields
from pathlib import Path
from typing import Any

import yaml


@dataclass
class TrainConfig:
    """One fine-tuning run."""

    # -- what to train ------------------------------------------------
    name: str = "whisper-small-id"
    base_model: str = "openai/whisper-small"
    language: str = "indonesian"
    task: str = "transcribe"

    # -- data ---------------------------------------------------------
    #: audiofolder directories written by `align/shards.py`, and/or HF
    #: dataset ids. Mixed freely.
    train_sets: list[str] = field(default_factory=list)
    eval_sets: list[str] = field(default_factory=list)
    text_column: str = "sentence"
    max_clip_secs: float = 25.0
    min_clip_secs: float = 1.0
    #: Drop aligned utterances whose anchor rate is below this. The
    #: alignment pipeline already gates on it; this is a second, stricter
    #: gate for training specifically.
    min_anchor_rate: float = 0.7
    #: Cap on training examples, for a dry run.
    max_train_samples: int | None = None
    max_eval_samples: int | None = None

    # -- memory -------------------------------------------------------
    load_in_4bit: bool = False
    load_in_8bit: bool = False
    fp16: bool = True
    bf16: bool = False
    gradient_checkpointing: bool = True
    per_device_batch_size: int = 1
    gradient_accumulation_steps: int = 16
    eval_batch_size: int = 1

    # -- LoRA ---------------------------------------------------------
    lora_r: int = 32
    lora_alpha: int = 64
    lora_dropout: float = 0.05
    target_modules: list[str] = field(default_factory=lambda: ["q_proj", "v_proj"])
    #: Freeze the encoder except its top N layers. 0 = train every
    #: targeted encoder layer; None = freeze the encoder entirely.
    encoder_top_layers: int | None = None

    # -- SpecAugment --------------------------------------------------
    #: Applied to the log-mel features, not the waveform. Meeting audio
    #: is noisy and reverberant in ways read speech is not, and masking
    #: is the cheapest regulariser that moves in that direction.
    spec_augment: bool = True
    mask_time_prob: float = 0.05
    mask_time_length: int = 10
    mask_feature_prob: float = 0.05
    mask_feature_length: int = 10

    # -- optimisation -------------------------------------------------
    learning_rate: float = 1e-3
    warmup_steps: int = 50
    max_steps: int = 2000
    #: 8-bit Adam halves optimiser state. GPU only.
    optim: str = "adamw_torch"
    lr_scheduler_type: str = "linear"
    weight_decay: float = 0.0
    max_grad_norm: float = 1.0
    seed: int = 20261005

    # -- bookkeeping --------------------------------------------------
    output_dir: str = "out/train/whisper-small-id"
    save_steps: int = 200
    eval_steps: int = 200
    logging_steps: int = 20
    save_total_limit: int = 3
    #: Resume from the last checkpoint in `output_dir` if one is there.
    resume: bool = True
    #: CPU dry run: tiny model, a handful of steps, no quantisation.
    dry_run: bool = False

    def __post_init__(self) -> None:
        if self.load_in_4bit and self.load_in_8bit:
            raise ValueError("pilih salah satu: load_in_4bit atau load_in_8bit")
        if self.fp16 and self.bf16:
            raise ValueError("pilih salah satu: fp16 atau bf16")
        if self.per_device_batch_size < 1:
            raise ValueError("per_device_batch_size minimal 1")
        if self.max_clip_secs > 30.0:
            # Whisper's window is 30 s; anything longer is truncated
            # silently, which would mean training on labels whose audio
            # is not all there.
            raise ValueError("max_clip_secs tidak boleh di atas 30 (jendela Whisper)")

    @property
    def effective_batch_size(self) -> int:
        return self.per_device_batch_size * self.gradient_accumulation_steps

    def as_dict(self) -> dict[str, Any]:
        return asdict(self)


def load_config(path: str | Path, **overrides: Any) -> TrainConfig:
    """Read a YAML config, applying `overrides` on top.

    An unknown key is an error rather than being ignored: a typo in a
    config that silently trains with the default is the worst possible
    outcome for a run that takes hours.
    """
    payload = yaml.safe_load(Path(path).read_text(encoding="utf-8")) or {}
    if not isinstance(payload, dict):
        raise ValueError(f"{path}: isi YAML harus berupa map")
    payload.update({key: value for key, value in overrides.items() if value is not None})

    known = {item.name for item in fields(TrainConfig)}
    unknown = sorted(set(payload) - known)
    if unknown:
        raise ValueError(f"{path}: kunci tidak dikenal: {unknown}; yang sah: {sorted(known)}")
    return TrainConfig(**payload)


def save_config(config: TrainConfig, path: str | Path) -> Path:
    """Write the resolved config next to the checkpoints."""
    from common.atomic import write_text

    return write_text(path, yaml.safe_dump(config.as_dict(), sort_keys=True, allow_unicode=True))
