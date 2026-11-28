"""Build noisy test set for issue #69: NR on vs off word-loss comparison."""
import csv, os, random
import numpy as np, soundfile as sf

random.seed(69); rng = np.random.default_rng(69)
base = "data/id_id"
rows = list(csv.reader(open(f"{base}/dev.tsv"), delimiter="\t", quoting=csv.QUOTE_NONE))
seen, items = set(), []
for r in rows:
    if r[1] in seen: continue
    seen.add(r[1]); items.append((r[1], r[3]))
random.shuffle(items)
test, babble_src = items[:40], items[40:80]

def load(f):
    a, sr = sf.read(f"{base}/audio/dev/{f}", dtype="float32")
    assert sr == 16000
    return a if a.ndim == 1 else a.mean(1)

def pink(n):
    w = rng.standard_normal(n)
    f = np.fft.rfft(w); k = np.arange(len(f)); k[0] = 1
    return np.fft.irfft(f / np.sqrt(k), n)

def fan(n):  # brown-ish hum + 100 Hz motor tone, like a ceiling fan/AC
    b = np.cumsum(rng.standard_normal(n)); b -= np.convolve(b, np.ones(800) / 800, "same")
    t = np.arange(n) / 16000
    return b / np.std(b) + 0.5 * np.sin(2 * np.pi * 100 * t)

bab_pool = [load(f) for f, _ in babble_src]
def babble(n):
    out = np.zeros(n)
    for a in random.sample(bab_pool, 4):
        a = np.tile(a, n // len(a) + 1)[:n]; out += a / (np.std(a) + 1e-9)
    return out

def mix(s, noise, snr):
    ps = np.mean(s ** 2); pn = np.mean(noise ** 2)
    y = s + noise * np.sqrt(ps / (pn * 10 ** (snr / 10)))
    return (y / max(1.0, np.max(np.abs(y)) / 0.95)).astype("float32")

os.makedirs("set", exist_ok=True)
with open("set/manifest.tsv", "w") as m:
    for i, (f, ref) in enumerate(test):
        s = load(f)
        variants = {"clean": s, "pink5": mix(s, pink(len(s)), 5), "fan5": mix(s, fan(len(s)), 5),
                    "babble5": mix(s, babble(len(s)), 5), "pink0": mix(s, pink(len(s)), 0)}
        for v, y in variants.items():
            out = f"set/{v}/{i:02d}.wav"; os.makedirs(os.path.dirname(out), exist_ok=True)
            sf.write(out, y, 16000, subtype="PCM_16")
        m.write(f"{i:02d}\t{ref}\n")
print("ok", len(test))
