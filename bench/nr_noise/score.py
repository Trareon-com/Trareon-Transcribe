import glob, re, unicodedata, jiwer

def norm(t):
    t = unicodedata.normalize("NFKC", t).lower()
    t = re.sub(r"[^\w\s]", " ", t)
    return " ".join(t.split())

refs = {k: v for k, v in (l.rstrip("\n").split("\t", 1) for l in open("set/manifest.tsv")) if int(k) < 20}

def hyp(d, k):
    fs = glob.glob(f"{d}/*/{k}.txt")
    if not fs: return None
    txt = open(fs[0]).read()
    txt = re.sub(r"\[\d[\d:.,\s\-–>]*\]", " ", txt)
    txt = re.sub(r"^\s*(Pembicara|Speaker)\s*\d*\s*:", " ", txt, flags=re.M)
    return norm(txt)

print(f"{'kondisi':8} {'NR':3} {'WER%':>6} {'kata_hyp':>8} {'kata_ref':>8} {'del':>5} {'sub':>5} {'ins':>5} {'kosong':>6} {'file':>4}")
for v in ["clean", "fan5", "babble5", "pink5"]:
    for nr in ["off", "on"]:
        d = f"out/{v}-{nr}"
        keys = sorted(refs)
        H = [hyp(d, k) for k in keys]
        nfile = sum(h is not None for h in H)
        H = [h or "" for h in H]
        R = [norm(refs[k]) for k in keys]
        o = jiwer.process_words(R, H)
        nh = sum(len(h.split()) for h in H); nref = sum(len(r.split()) for r in R)
        print(f"{v:8} {nr:3} {o.wer*100:6.1f} {nh:8d} {nref:8d} {o.deletions:5d} {o.substitutions:5d} {o.insertions:5d} {sum(1 for h in H if not h):6d} {nfile:4d}")
