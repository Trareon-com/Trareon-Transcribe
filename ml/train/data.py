"""Assembling the training set from aligned shards.

Inputs are the audiofolder shards `align/shards.py` writes, HF dataset
ids, or both. Everything is resampled to 16 kHz and turned into Whisper
features by the processor.

Two filters earn their place:

* **Clip length.** Over `max_clip_secs` the audio is longer than what
  gets encoded, so part of the label has no audio behind it — training
  on that teaches the model to invent the tail. Under `min_clip_secs`
  there is not enough signal to learn from.
* **Anchor rate.** Aligned shards carry the proportion of tokens the
  model and the risalah actually agreed on. The alignment step already
  dropped the worst, but training deserves a stricter threshold than
  dataset-building: a 0.6-anchor utterance is worth keeping in a corpus
  and not worth learning from.

`GigaSpeech 2` is not loaded here by accident: it is non-commercial, and
including it changes what licence the resulting model may carry. It has
to be named explicitly in `train_sets`, and `check_licences` reports
when it is present so the run's model card says so.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any

from train.config import TrainConfig

#: Dataset ids whose licence restricts the trained model.
NON_COMMERCIAL_MARKERS = ("gigaspeech2", "gigaspeech_2", "indo_csc", "-nc-")


@dataclass
class LicenceVerdict:
    """What licence the model trained on these sets may carry."""

    non_commercial_sources: list[str]

    @property
    def commercial_use_allowed(self) -> bool:
        return not self.non_commercial_sources

    @property
    def recommended_licence(self) -> str:
        return "apache-2.0" if self.commercial_use_allowed else "cc-by-nc-4.0"

    def summary(self) -> str:
        if self.commercial_use_allowed:
            return (
                "Semua sumber latih mengizinkan penggunaan komersial; "
                f"lisensi model yang disarankan: {self.recommended_licence}."
            )
        return (
            "Sumber NON-KOMERSIAL dipakai: "
            + ", ".join(self.non_commercial_sources)
            + f". Model HARUS dirilis sebagai {self.recommended_licence} "
            "dengan pengungkapan jelas. Lihat ml/DATA_CARD.md."
        )


def check_licences(train_sets: list[str]) -> LicenceVerdict:
    """Decide the model's licence from its training sources."""
    found = [
        name
        for name in train_sets
        if any(marker in name.casefold() for marker in NON_COMMERCIAL_MARKERS)
    ]
    return LicenceVerdict(non_commercial_sources=found)


def load_sets(names: list[str], *, split: str = "train") -> Any:
    """Load and concatenate audiofolder shards and/or HF datasets."""
    from datasets import Audio, concatenate_datasets, load_dataset

    parts = []
    for name in names:
        path = Path(name)
        if path.exists() and (path / "metadata.jsonl").exists():
            part = load_dataset("audiofolder", data_dir=str(path), split="train")
        elif path.exists():
            raise FileNotFoundError(f"{path} bukan shard audiofolder (tidak ada metadata.jsonl)")
        else:
            part = load_dataset(name, split=split)
        parts.append(part.cast_column("audio", Audio(sampling_rate=16000)))

    if not parts:
        raise ValueError("tidak ada set data yang dimuat")
    if len(parts) == 1:
        return parts[0]
    # Concatenation needs a common schema; keep only what training uses.
    keep = {"audio", "sentence"}
    trimmed = []
    for part in parts:
        extra = [column for column in part.column_names if column not in keep]
        trimmed.append(part.remove_columns(extra) if extra else part)
    return concatenate_datasets(trimmed)


def filter_examples(dataset: Any, config: TrainConfig) -> Any:
    """Apply the length and anchor-rate gates."""
    columns = set(dataset.column_names)

    if "anchor_rate" in columns and config.min_anchor_rate > 0:
        dataset = dataset.filter(
            lambda rate: rate is None or rate >= config.min_anchor_rate,
            input_columns=["anchor_rate"],
        )

    if "duration" in columns:
        # Cheap path: the shard already recorded it.
        dataset = dataset.filter(
            lambda value: value is None or config.min_clip_secs <= value <= config.max_clip_secs,
            input_columns=["duration"],
        )
    return dataset


def build_prepare_fn(processor: Any, config: TrainConfig):
    """Return the map function turning a row into model inputs."""
    text_column = config.text_column

    def prepare(batch: dict) -> dict:
        audio = batch["audio"]
        features = processor.feature_extractor(audio["array"], sampling_rate=audio["sampling_rate"])
        batch["input_features"] = features.input_features[0]
        # Duration after decode, so a set without a `duration` column is
        # still length-filtered below.
        batch["clip_secs"] = len(audio["array"]) / float(audio["sampling_rate"])
        batch["labels"] = processor.tokenizer(batch[text_column]).input_ids
        return batch

    return prepare


def prepare_dataset(dataset: Any, processor: Any, config: TrainConfig) -> Any:
    """Turn raw rows into model inputs, filtering by true clip length."""
    remove = [name for name in dataset.column_names if name != "audio"]
    prepared = dataset.map(
        build_prepare_fn(processor, config),
        remove_columns=remove,
        desc="menyiapkan fitur",
    )
    prepared = prepared.filter(
        lambda secs: config.min_clip_secs <= secs <= config.max_clip_secs,
        input_columns=["clip_secs"],
    )
    return prepared.remove_columns(["clip_secs", "audio"])


@dataclass
class WhisperCollator:
    """Pad features and labels for a Whisper batch.

    Labels are padded with -100 so the loss ignores the padding, and the
    decoder-start token is stripped when the tokenizer has already
    prepended it — leaving it in shifts every label by one position,
    which trains the model to emit a token late.
    """

    processor: Any
    decoder_start_token_id: int

    def __call__(self, features: list[dict]) -> dict:
        import torch

        inputs = [{"input_features": item["input_features"]} for item in features]
        batch = self.processor.feature_extractor.pad(inputs, return_tensors="pt")

        label_features = [{"input_ids": item["labels"]} for item in features]
        labels_batch = self.processor.tokenizer.pad(label_features, return_tensors="pt")
        labels = labels_batch["input_ids"].masked_fill(labels_batch.attention_mask.ne(1), -100)
        if (labels[:, 0] == self.decoder_start_token_id).all().cpu().item():
            labels = labels[:, 1:]
        batch["labels"] = labels
        _ = torch  # imported for its side effect of being required
        return batch
