"""Whisper LoRA fine-tuning, sized for one 6 GB GPU.

    # On the RTX 2060 box
    uv run python -m train.lora --config train/configs/whisper-small-id.yaml

    # Prove the pipeline on a CPU first — minutes, not hours
    uv run python -m train.lora --config train/configs/dry-run-cpu.yaml

Resumable: with `resume: true` a run picks up the newest checkpoint in
`output_dir`, which matters because a 2000-step run on a 2060 is
measured in hours and the machine is somebody's laptop.

The 6 GB budget, and where it goes:

* The base model's weights. `small` in fp16 is ~0.5 GB and fits; turbo
  in fp16 is ~1.6 GB and, with activations and optimiser state, does
  not — hence 4-bit base weights for turbo via bitsandbytes.
* Activations. Whisper always encodes a padded 30-second window, so
  these do not shrink with shorter clips; `gradient_checkpointing` is
  what shrinks them, at about 30% speed.
* Optimiser state. LoRA is the main saving: only the adapter is
  trained, so Adam's two moments cover a few million parameters instead
  of hundreds of millions. `adamw_bnb_8bit` halves what remains.

`dry_run` exists so the whole chain — train, merge, export to GGML,
re-evaluate — can be proven on a CPU with `whisper-tiny` before a GPU
is involved. A training script that has only ever run on the machine it
was written for is a script that fails on the one that matters.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

from common.atomic import write_json
from train.config import TrainConfig, load_config, save_config
from train.data import (
    WhisperCollator,
    check_licences,
    filter_examples,
    load_sets,
    prepare_dataset,
)


def _require(module: str) -> None:
    raise SystemExit(
        f"`{module}` belum terpasang.\n"
        "  GPU : uv sync --extra train --extra gpu\n"
        "  CPU : uv sync --extra train"
    )


def latest_checkpoint(output_dir: str | Path) -> Path | None:
    """Newest `checkpoint-N` in `output_dir`, by step number."""
    root = Path(output_dir)
    if not root.exists():
        return None
    checkpoints = [
        path
        for path in root.glob("checkpoint-*")
        if path.is_dir() and path.name.removeprefix("checkpoint-").isdigit()
    ]
    if not checkpoints:
        return None
    return max(checkpoints, key=lambda path: int(path.name.removeprefix("checkpoint-")))


def build_model(config: TrainConfig) -> tuple[Any, Any]:
    """Load the base model with the adapter attached."""
    try:
        import torch
        from peft import LoraConfig, get_peft_model, prepare_model_for_kbit_training
        from transformers import WhisperForConditionalGeneration, WhisperProcessor
    except ImportError as error:  # pragma: no cover - dependency guard
        _require(str(error).split("'")[1] if "'" in str(error) else "transformers")
        raise

    processor = WhisperProcessor.from_pretrained(
        config.base_model, language=config.language, task=config.task
    )

    load_kwargs: dict[str, Any] = {}
    if config.load_in_4bit or config.load_in_8bit:
        try:
            from transformers import BitsAndBytesConfig
        except ImportError:  # pragma: no cover
            _require("bitsandbytes")
            raise
        load_kwargs["quantization_config"] = BitsAndBytesConfig(
            load_in_4bit=config.load_in_4bit,
            load_in_8bit=config.load_in_8bit,
            # NF4 with double quantisation: the combination that fits
            # turbo on 6 GB. compute dtype stays fp16 so the 2060's
            # tensor cores are used.
            bnb_4bit_quant_type="nf4",
            bnb_4bit_use_double_quant=True,
            bnb_4bit_compute_dtype=torch.float16,
        )
    else:
        load_kwargs["dtype"] = torch.float16 if config.fp16 else torch.float32

    model = WhisperForConditionalGeneration.from_pretrained(config.base_model, **load_kwargs)

    # SpecAugment is a property of the model config in transformers.
    if config.spec_augment:
        model.config.apply_spec_augment = True
        model.config.mask_time_prob = config.mask_time_prob
        model.config.mask_time_length = config.mask_time_length
        model.config.mask_feature_prob = config.mask_feature_prob
        model.config.mask_feature_length = config.mask_feature_length

    # Whisper caches during generation; it must be off while training
    # with gradient checkpointing or the two disagree about the graph.
    model.config.use_cache = False
    model.generation_config.language = config.language
    model.generation_config.task = config.task
    model.generation_config.forced_decoder_ids = None

    if config.load_in_4bit or config.load_in_8bit:
        model = prepare_model_for_kbit_training(
            model, use_gradient_checkpointing=config.gradient_checkpointing
        )

    target_modules = _resolve_targets(model, config)
    adapter = LoraConfig(
        r=config.lora_r,
        lora_alpha=config.lora_alpha,
        lora_dropout=config.lora_dropout,
        target_modules=target_modules,
        bias="none",
    )
    model = get_peft_model(model, adapter)
    model.print_trainable_parameters()
    return model, processor


def _resolve_targets(model: Any, config: TrainConfig) -> list[str]:
    """Expand the target module list, honouring `encoder_top_layers`.

    With `encoder_top_layers = N`, encoder layers below the top N are
    left out of the adapter entirely. On 6 GB with turbo this is the
    difference between fitting and not, and it costs little: the encoder
    computes acoustic features that transfer across languages, while the
    decoder holds the vocabulary and style a fine-tune is actually for.
    """
    if config.encoder_top_layers is None and "encoder" not in str(config.target_modules):
        return list(config.target_modules)

    names = [
        name
        for name, _ in model.named_modules()
        if any(name.endswith(suffix) for suffix in config.target_modules)
    ]
    if config.encoder_top_layers is None:
        # Freeze the encoder entirely: decoder-only adapter.
        return [name for name in names if ".encoder." not in name] or list(config.target_modules)

    # `encoder_layers` is a count, not a list.
    encoder_depth = int(getattr(model.config, "encoder_layers", 0) or 0)
    keep_from = max(0, encoder_depth - config.encoder_top_layers)
    selected: list[str] = []
    for name in names:
        if ".encoder.layers." in name:
            try:
                index = int(name.split(".encoder.layers.")[1].split(".")[0])
            except (IndexError, ValueError):
                continue
            if index >= keep_from:
                selected.append(name)
        else:
            selected.append(name)
    return selected or list(config.target_modules)


def train(config: TrainConfig) -> dict:
    """Run the fine-tune. Returns the metrics it recorded."""
    try:
        from transformers import Seq2SeqTrainer, Seq2SeqTrainingArguments, set_seed
    except ImportError:  # pragma: no cover
        _require("transformers")
        raise

    set_seed(config.seed)
    licence = check_licences(config.train_sets)
    print(licence.summary(), flush=True)

    model, processor = build_model(config)

    train_set = filter_examples(load_sets(config.train_sets), config)
    if config.max_train_samples:
        train_set = train_set.select(range(min(config.max_train_samples, len(train_set))))
    train_set = prepare_dataset(train_set, processor, config)

    eval_set = None
    if config.eval_sets:
        eval_set = filter_examples(load_sets(config.eval_sets, split="test"), config)
        if config.max_eval_samples:
            eval_set = eval_set.select(range(min(config.max_eval_samples, len(eval_set))))
        eval_set = prepare_dataset(eval_set, processor, config)

    print(f"contoh latih: {len(train_set)}", flush=True)
    if not len(train_set):
        raise SystemExit("set latih kosong setelah penyaringan - periksa gerbang panjang/anchor")

    output_dir = Path(config.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    save_config(config, output_dir / "config.resolved.yaml")

    arguments = Seq2SeqTrainingArguments(
        output_dir=str(output_dir),
        per_device_train_batch_size=config.per_device_batch_size,
        per_device_eval_batch_size=config.eval_batch_size,
        gradient_accumulation_steps=config.gradient_accumulation_steps,
        gradient_checkpointing=config.gradient_checkpointing,
        learning_rate=config.learning_rate,
        warmup_steps=config.warmup_steps,
        max_steps=config.max_steps,
        fp16=config.fp16,
        bf16=config.bf16,
        optim=config.optim,
        lr_scheduler_type=config.lr_scheduler_type,
        weight_decay=config.weight_decay,
        max_grad_norm=config.max_grad_norm,
        logging_steps=config.logging_steps,
        save_steps=config.save_steps,
        save_total_limit=config.save_total_limit,
        eval_strategy="steps" if eval_set is not None else "no",
        eval_steps=config.eval_steps if eval_set is not None else None,
        label_names=["labels"],
        remove_unused_columns=False,
        report_to=[],
        seed=config.seed,
    )

    trainer = Seq2SeqTrainer(
        model=model,
        args=arguments,
        train_dataset=train_set,
        eval_dataset=eval_set,
        data_collator=WhisperCollator(
            processor=processor,
            decoder_start_token_id=model.config.decoder_start_token_id,
        ),
        processing_class=processor.feature_extractor,
    )

    resume_from = str(latest_checkpoint(output_dir)) if config.resume else None
    if resume_from:
        print(f"melanjutkan dari {resume_from}", flush=True)

    result = trainer.train(resume_from_checkpoint=resume_from)

    adapter_dir = output_dir / "adapter"
    model.save_pretrained(str(adapter_dir))
    processor.save_pretrained(str(adapter_dir))

    metrics = {
        "name": config.name,
        "base_model": config.base_model,
        "train_examples": len(train_set),
        "eval_examples": len(eval_set) if eval_set is not None else 0,
        "steps": result.global_step,
        "train_loss": float(result.training_loss),
        "effective_batch_size": config.effective_batch_size,
        "adapter": str(adapter_dir),
        "licence": {
            "commercial_use_allowed": licence.commercial_use_allowed,
            "recommended_licence": licence.recommended_licence,
            "non_commercial_sources": licence.non_commercial_sources,
            "summary": licence.summary(),
        },
    }
    write_json(output_dir / "train_metrics.json", metrics)
    print(json.dumps(metrics, ensure_ascii=False, indent=2))
    return metrics


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="train.lora")
    parser.add_argument("--config", required=True)
    parser.add_argument("--output-dir", default=None)
    parser.add_argument("--max-steps", type=int, default=None)
    parser.add_argument("--base-model", default=None)
    parser.add_argument("--train-set", action="append", default=None)
    parser.add_argument("--no-resume", action="store_true")
    args = parser.parse_args(argv)

    overrides: dict[str, Any] = {
        "output_dir": args.output_dir,
        "max_steps": args.max_steps,
        "base_model": args.base_model,
        "train_sets": args.train_set,
    }
    if args.no_resume:
        overrides["resume"] = False
    config = load_config(args.config, **overrides)

    try:
        train(config)
    except SystemExit as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
