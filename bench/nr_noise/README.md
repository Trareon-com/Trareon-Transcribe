# NR (RNNoise) vs ASR word loss — issue #69

Reproduces `docs/QUALITY-PROFILE-BLUEPRINT.md` §5.1.

```bash
# 1. data: FLEURS id_id dev (≈220 MB)
uv venv .venv && uv pip install --python .venv/bin/python jiwer huggingface_hub numpy soundfile
.venv/bin/python -c "from huggingface_hub import hf_hub_download as d; [d('google/fleurs',f,repo_type='dataset',local_dir='.') for f in ['data/id_id/dev.tsv','data/id_id/audio/dev.tar.gz']]"
tar xzf data/id_id/audio/dev.tar.gz -C data/id_id/audio

# 2. noisy set (seed 69): clean / fan5 / babble5 / pink5 / pink0
.venv/bin/python mix.py

# 3. transcribe NR off vs on, then score (first 20 utterances)
(cd ../../rust_core && cargo build --release --bin transcribe_cli)
BIN=../../rust_core/target/release/transcribe_cli MODEL=/path/to/ggml-small.bin bash run.sh
```

Result (Kali, CPU, `ggml-small`, 28 Nov 2026):

```
kondisi  NR    WER% kata_hyp kata_ref   del   sub   ins kosong file
clean    off   13.9      362      361     5    39     6      0   20
clean    on    15.0      359      361     6    44     4      0   20
fan5     off   14.4      363      361     4    42     6      0   20
fan5     on    16.1      361      361     5    48     5      0   20
babble5  off   33.2      359      361    20    82    18      0   20
babble5  on    45.2      313      361    56    99     8      1   20
pink5    off   21.3      360      361     8    62     7      0   20
pink5    on    29.4      359      361     9    90     7      0   20
```

## Probe check on a machine without a physical mic (Kali)

`virtual_mic_probe.sh` creates a silent PipeWire null sink + remapped source,
makes it the default input, plays speech into it and runs the real capture path
(`input_probe`), then restores the default source. Kali, 28 Nov 2026:

```
senyap (virtual)     snr_db=0.0  peak_dbfs=-100.0   (digital silence floor)
bicara bersih        snr_db=18.7 peak_dbfs=-18.9
bicara + babble 5 dB snr_db=11.6 peak_dbfs=-16.2
```

The physical jack input with nothing plugged in reads peak ≈ −68 dBFS,
SNR 2–3 dB (three runs).
