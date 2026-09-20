"""Retrains the "is this a breast ultrasound?" gate so it also refuses ultrasounds of other organs.

The classifier network is NOT retrained: the gate is a logistic regression on the network's 2,048-number embedding, so only
the embeddings of new images are needed. Run locally (CPU) with the datasets downloaded to D:/dl/gate and D:/dl/old.

  D:/dl/gateenv/Scripts/python ml/train_gate_v2.py

Writes ml/output/gate_v2/breast_gate.npz and gate_v2_metrics.json. Compares the new gate with the deployed one on the same images.
"""
import csv, glob, json, os, random, sys, time
import numpy as np
import onnxruntime as ort
from PIL import Image, ImageOps
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
G = "D:/dl/gate"
OUT = os.path.join(ROOT, "ml", "output", "gate_v2")
os.makedirs(OUT, exist_ok=True)
SEED = 42
FINAL = os.environ.get("GATE_FINAL") == "1"   # final model: also trains on kidney and the second thyroid set
SUFFIX = "_final" if FINAL else ""
rng = random.Random(SEED)

meta = json.load(open(os.path.join(ROOT, "backend/models/breast_meta.json"), encoding="utf-8"))
sess = ort.InferenceSession(os.path.join(ROOT, "backend/models", meta["onnx_file"]), providers=["CPUExecutionProvider"])
MEAN = np.array(meta["input"]["mean"], np.float32)[:, None, None]
STD = np.array(meta["input"]["std"], np.float32)[:, None, None]
COLOUR_LIMIT = meta["colour_limit"]


def to_gray(img):
    if img.mode in ("I", "I;16", "I;16B", "F"):
        a = np.asarray(img, np.float32); a = (a - a.min()) / max(float(a.max() - a.min()), 1e-6) * 255
        return Image.fromarray(a.astype(np.uint8))
    return img.convert("L")


def tensor(gray):
    w, h = gray.size; s = max(w, h)
    c = Image.new("L", (s, s), 0); c.paste(gray, ((s - w) // 2, (s - h) // 2))
    x = np.asarray(c.resize((224, 224), Image.BILINEAR), np.float32) / 255.0
    return ((np.repeat(x[None], 3, 0) - MEAN) / STD)[None].astype(np.float32)


def colour_fraction(img):
    a = np.asarray(img.convert("RGB").resize((128, 128)), np.int16)
    diff = np.maximum.reduce([abs(a[..., 0] - a[..., 1]), abs(a[..., 1] - a[..., 2]), abs(a[..., 0] - a[..., 2])])
    return float((diff > 30).mean())


def embed(paths, name):
    cache = os.path.join(OUT, f"emb_{name}.npz")
    if os.path.exists(cache):
        z = np.load(cache, allow_pickle=True)
        if list(z["paths"]) == list(paths):
            return z["emb"], z["colour"]
    embs, cols, t0 = [], [], time.time()
    for i, p in enumerate(paths):
        try:
            im = ImageOps.exif_transpose(Image.open(p)); im.load()
            cols.append(colour_fraction(im) if im.mode not in ("L", "I", "I;16", "I;16B", "F") else 0.0)
            embs.append(sess.run(None, {"image": tensor(to_gray(im))})[1][0])
        except Exception as e:
            print("skip", p, e)
        if i % 200 == 0:
            print(f"  {name}: {i}/{len(paths)} ({time.time() - t0:.0f}s)", flush=True)
    emb, col = np.stack(embs), np.array(cols)
    np.savez(cache, paths=np.array(paths), emb=emb, colour=col)
    return emb, col


def imgs(pattern, n, exclude=()):
    files = sorted(p for p in glob.glob(pattern, recursive=True)
                   if p.lower().endswith((".jpg", ".jpeg", ".png", ".bmp")) and not any(x in os.path.basename(p) for x in exclude))
    rng2 = random.Random(SEED); rng2.shuffle(files)
    return files[:n]


# ---------------------------------------------------------------- positives (breast ultrasounds) from the pinned split
breast_dir = os.path.dirname(glob.glob("D:/dl/old/breast_usg/**/case001.png", recursive=True)[0]).replace("\\", "/")
def bpath(r):
    return {"BUSI": f"D:/dl/old/Dataset_BUSI_with_GT/{r['label']}/{r['file']}", "BrEaST": f"{breast_dir}/{r['file']}",
            "BUS-BRA": os.path.join(ROOT, "ml/data/busbra/BUSBRA/BUSBRA/Images", r["file"])}[r["source"]]
rows = list(csv.DictReader(open(os.path.join(ROOT, "ml/output/breast_busbra/model/breast_split.csv"), encoding="utf-8")))
pos = {s: [bpath(r) for r in rows if r["split"] == s] for s in ("train", "val", "test")}

# ---------------------------------------------------------------- negatives
nat_train_cls = ["airplane", "car", "cat", "dog"]
nat_cls = lambda p: os.path.basename(os.path.dirname(p))
nat_all = sorted({(nat_cls(p), os.path.basename(p)): p for p in glob.glob(f"{G}/natural/**/*.jpg", recursive=True)}.values())   # the archive holds two copies of the tree
train_neg = {
    "photos": sorted(p for p in nat_all if nat_cls(p) in nat_train_cls),
    "xray": imgs(f"{G}/xray_small/**/train/**/*", 400),
    "thyroid_ddti": imgs(f"{G}/thyroid_ddti/*", 250),
    "fetal_head": imgs(f"{G}/fetal_head/training_set/**/*", 250, exclude=("Annotation",)),
}
rr = random.Random(SEED); rr.shuffle(train_neg["photos"]); train_neg["photos"] = train_neg["photos"][:600]
held = {
    "Colour and grayscale photos, unseen categories": [p for p in nat_all if nat_cls(p) not in nat_train_cls],
    "Chest X-rays, held out": imgs(f"{G}/xray_small/**/test/**/*", 300),
    "Brain MRI, never seen": imgs(f"{G}/brain_mri/**/*", 250),
    "Thyroid ultrasound, different dataset (AUITD)": imgs(f"{G}/thyroid_auitd/**/*", 300),
    "Kidney ultrasound, organ never seen": imgs(f"{G}/kidney/**/*", 300),
    "Fetal head ultrasound, held-out images": imgs(f"{G}/fetal_head/test_set/**/*", 200, exclude=("Annotation",)),
}
rs = random.Random(SEED); held["Colour and grayscale photos, unseen categories"] = rs.sample(held["Colour and grayscale photos, unseen categories"], 300)
if FINAL:   # final model also trains on these two sets; the held-out rows then use other images of the same sources (in-distribution)
    train_neg["thyroid_auitd"] = imgs(f"{G}/thyroid_auitd/**/*", 250)
    train_neg["kidney"] = imgs(f"{G}/kidney/**/*", 250)
    held["Thyroid ultrasound, different dataset (AUITD)"] = imgs(f"{G}/thyroid_auitd/**/*", 550)[250:550]
    held["Kidney ultrasound, organ never seen"] = imgs(f"{G}/kidney/**/*", 550)[250:550]
print({k: len(v) for k, v in train_neg.items()}, {k: len(v) for k, v in held.items()}, {k: len(v) for k, v in pos.items()}, flush=True)

E = {}
for s, ps in pos.items(): E["pos_" + s] = embed(ps, "pos_" + s)
for k, ps in train_neg.items(): E["neg_" + k] = embed(ps, "neg_" + k)
for k, ps in held.items(): E["held_" + k] = embed(ps, "held_" + k[:20].replace(" ", "_").replace(",", ""))

# ---------------------------------------------------------------- fit the new gate
X = np.concatenate([E["pos_train"][0]] + [E["neg_" + k][0] for k in train_neg])
y = np.r_[np.ones(len(E["pos_train"][0])), np.zeros(sum(len(E["neg_" + k][0]) for k in train_neg))]
gate = make_pipeline(StandardScaler(), LogisticRegression(C=0.1, max_iter=5000, class_weight="balanced")).fit(X, y)
score = lambda emb: gate.predict_proba(emb)[:, 1]
thr = float(min(np.percentile(score(E["pos_val"][0]), 1), 0.5))

old = dict(np.load(os.path.join(ROOT, "backend/models/breast_gate.npz")))
def old_score(emb):
    z = (emb - old["mean"]) / old["scale"]
    return 1 / (1 + np.exp(-(z @ old["coef"] + old["intercept"])))
old_thr = meta["gate_threshold"]

def rejected(emb, col, sc, th):   # colour check or gate
    return (col > COLOUR_LIMIT) | (sc(emb) < th)

result = {"new_threshold": thr, "old_threshold": old_thr, "train_counts": {k: len(v) for k, v in train_neg.items()}, "rows": []}
sets = [("Breast test ultrasounds (must pass; rejected = wrong)", "pos_test")] + [(k, "held_" + k) for k in held]
for name, key in sets:
    emb, col = E[key]
    r_old, r_new = rejected(emb, col, old_score, old_thr).mean(), rejected(emb, col, score, thr).mean()
    result["rows"].append({"images": name, "n": int(len(emb)), "rejected_old_gate": round(float(r_old), 4), "rejected_new_gate": round(float(r_new), 4)})
    print(f"{name:58s} n={len(emb):4d}  old gate rejects {r_old:6.1%}   new gate rejects {r_new:6.1%}", flush=True)

sc = gate.named_steps["standardscaler"]; lr = gate.named_steps["logisticregression"]
np.savez(os.path.join(OUT, f"breast_gate{SUFFIX}.npz"), mean=sc.mean_.astype(np.float32), scale=sc.scale_.astype(np.float32),
         coef=lr.coef_[0].astype(np.float32), intercept=np.float32(lr.intercept_[0]))
json.dump(result, open(os.path.join(OUT, f"gate_v2{SUFFIX}_metrics.json"), "w"), indent=2)
print("saved", OUT)
