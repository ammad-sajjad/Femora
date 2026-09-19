"""Builds the Kaggle notebooks in ml/notebooks/ from plain Python cells.

Run: ml/.venv/Scripts/python ml/build_notebooks.py
Then push, e.g.: ml/.venv/Scripts/kaggle kernels push -p ml/notebooks/breast_ultrasound
"""
import json
from pathlib import Path

ROOT = Path(__file__).parent / "notebooks"


def notebook(cells):
    return {
        "cells": [
            {
                "cell_type": kind,
                "metadata": {},
                "source": src.strip("\n"),
                **({"outputs": [], "execution_count": None} if kind == "code" else {}),
            }
            for kind, src in cells
        ],
        "metadata": {
            "kernelspec": {"display_name": "Python 3", "language": "python", "name": "python3"},
            "language_info": {"name": "python"},
        },
        "nbformat": 4,
        "nbformat_minor": 5,
    }


def write(folder, slug, title, datasets, cells, gpu=False):
    out = ROOT / folder
    out.mkdir(parents=True, exist_ok=True)
    (out / "notebook.ipynb").write_text(json.dumps(notebook(cells), indent=1), encoding="utf-8")
    (out / "kernel-metadata.json").write_text(json.dumps({
        "id": f"ammad0/{slug}",
        "title": title,
        "code_file": "notebook.ipynb",
        "language": "python",
        "kernel_type": "notebook",
        "is_private": True,
        "enable_gpu": gpu,
        "enable_internet": True,
        # Recent PyTorch builds no longer support the P100 that Kaggle hands out by default
        **({"machine_shape": "NvidiaTeslaT4"} if gpu else {}),
        "dataset_sources": datasets,
        "competition_sources": [],
        "kernel_sources": [],
    }, indent=2), encoding="utf-8")


PCOS = [
    ("markdown", """
# Femora — PCOS Risk Model (XGBoost)

Dataset: *Polycystic ovary syndrome (PCOS)* — 541 women, 10 hospitals in Kerala, India (Kottarathil, Kaggle).

**Design decisions**
- The app can only ask questions a woman can answer herself, so the deployed model uses **self-reportable
  features only** (no blood tests or ultrasound follicle counts). A full clinical model is trained alongside
  as a reference upper bound.
- **Monotonic constraints**: symptoms can only increase risk and regular exercise can only decrease it,
  so predictions stay medically sensible and explainable.
- **Age is excluded**: the dataset only covers women aged 20–48 and the unconstrained model learned a
  spurious "younger = higher risk" rule.

Output: probability of PCOS → **Low (<30%) / Medium (30–60%) / High (≥60%)**, awareness only — not a diagnosis.
"""),
    ("code", """
import glob, json, os, warnings
import numpy as np, pandas as pd
import matplotlib.pyplot as plt, seaborn as sns
from sklearn.model_selection import train_test_split, StratifiedKFold, cross_validate
from sklearn.linear_model import LogisticRegression
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import StandardScaler
from sklearn.pipeline import make_pipeline
from sklearn.metrics import (accuracy_score, f1_score, roc_auc_score, recall_score, precision_score,
                             confusion_matrix, classification_report, RocCurveDisplay)
from imblearn.over_sampling import SMOTE
from imblearn.pipeline import Pipeline as ImbPipeline
from xgboost import XGBClassifier
warnings.filterwarnings("ignore")
SEED = 42
os.makedirs("/kaggle/working/model", exist_ok=True)
"""),
    ("markdown", "## 1. Load & clean"),
    ("code", """
path = glob.glob("/kaggle/input/**/PCOS_data_without_infertility.xlsx", recursive=True)[0]
df = pd.read_excel(path, sheet_name="Full_new")
df.columns = df.columns.str.strip()
df = df.drop(columns=["Sl. No", "Patient File No.", "Unnamed: 44"], errors="ignore")

# A few lab columns contain typos like '1.99.' or 'a' — coerce to numeric
for c in df.columns:
    df[c] = pd.to_numeric(df[c], errors="coerce")
df = df.fillna(df.median(numeric_only=True))

# Cycle(R/I): 2 = regular, 4/5 = irregular.  'Cycle length(days)' is actually period duration (0-12).
df["irregular_cycle"] = (df["Cycle(R/I)"] != 2).astype(int)
df["waist_hip_ratio"] = df["Waist(inch)"] / df["Hip(inch)"]

print(df.shape)
print(df["PCOS (Y/N)"].value_counts(normalize=True).round(3))
"""),
    ("markdown", "## 2. Feature sets"),
    ("code", """
# Age is deliberately excluded: every woman in the dataset is 20-48 and PCOS patients are only ~2 years younger,
# so an unconstrained model learned a spurious "young = high risk" rule that doesn't generalise to app users.
SELF_REPORT = {                      # app field name  <- dataset column
    "bmi":               "BMI",
    "irregular_cycle":   "irregular_cycle",
    "period_days":       "Cycle length(days)",
    "waist_hip_ratio":   "waist_hip_ratio",
    "weight_gain":       "Weight gain(Y/N)",
    "hair_growth":       "hair growth(Y/N)",
    "skin_darkening":    "Skin darkening (Y/N)",
    "hair_loss":         "Hair loss(Y/N)",
    "pimples":           "Pimples(Y/N)",
    "fast_food":         "Fast food (Y/N)",
    "regular_exercise":  "Reg.Exercise(Y/N)",
}
X_self = df[list(SELF_REPORT.values())].copy()
X_self.columns = list(SELF_REPORT.keys())

# Monotonic constraints keep the model medically sensible: +1 = can only raise risk, -1 = can only lower it,
# 0 = learned freely (period length and waist:hip have no clear one-directional relationship).
MONOTONE = {"bmi": 1, "irregular_cycle": 1, "period_days": 0, "waist_hip_ratio": 0, "weight_gain": 1,
            "hair_growth": 1, "skin_darkening": 1, "hair_loss": 1, "pimples": 1, "fast_food": 1,
            "regular_exercise": -1}
MONOTONE_TUPLE = tuple(MONOTONE[c] for c in X_self.columns)
X_full = df.drop(columns=["PCOS (Y/N)", "Cycle(R/I)"])
y = df["PCOS (Y/N)"].astype(int)

fig, ax = plt.subplots(figsize=(8, 5))
X_self.assign(PCOS=y).corr()["PCOS"].drop("PCOS").sort_values().plot.barh(ax=ax, color="#C2185B")
ax.set_title("Correlation of self-reported features with PCOS"); plt.tight_layout(); plt.show()
"""),
    ("markdown", """
## 3. Compare models (5-fold stratified CV, SMOTE applied inside each training fold only)

Applying SMOTE *inside* the CV pipeline avoids leaking synthetic copies of test rows into training.
"""),
    ("code", """
cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=SEED)
scoring = ["accuracy", "f1", "recall", "roc_auc"]

def candidates(monotone=None):
    xgb_extra = {"monotone_constraints": monotone} if monotone else {}
    return {
        "Logistic Regression": make_pipeline(StandardScaler(), LogisticRegression(max_iter=2000)),
        "Random Forest": RandomForestClassifier(n_estimators=300, random_state=SEED),
        "XGBoost": XGBClassifier(n_estimators=300, max_depth=3, learning_rate=0.05, subsample=0.9,
                                 colsample_bytree=0.9, eval_metric="logloss", random_state=SEED, **xgb_extra),
    }

rows = []
for feat_name, X, mono in [("Self-report (app)", X_self, MONOTONE_TUPLE), ("Full clinical (reference)", X_full, None)]:
    for name, model in candidates(mono).items():
        pipe = ImbPipeline([("smote", SMOTE(random_state=SEED)), ("model", model)])
        s = cross_validate(pipe, X, y, cv=cv, scoring=scoring)
        rows.append({"features": feat_name, "model": name,
                     **{m: f"{s['test_'+m].mean():.3f} ± {s['test_'+m].std():.3f}" for m in scoring}})
cv_table = pd.DataFrame(rows)
cv_table
"""),
    ("markdown", "## 4. Final XGBoost on self-report features — held-out 20% test set"),
    ("code", """
X_tr, X_te, y_tr, y_te = train_test_split(X_self, y, test_size=0.2, stratify=y, random_state=SEED)
X_tr_sm, y_tr_sm = SMOTE(random_state=SEED).fit_resample(X_tr, y_tr)

model = XGBClassifier(n_estimators=300, max_depth=3, learning_rate=0.05, subsample=0.9,
                      colsample_bytree=0.9, eval_metric="logloss", random_state=SEED,
                      monotone_constraints=MONOTONE_TUPLE)
model.fit(X_tr_sm, y_tr_sm)

proba = model.predict_proba(X_te)[:, 1]
pred = (proba >= 0.5).astype(int)
metrics = {
    "test_size": int(len(y_te)),
    "accuracy": round(accuracy_score(y_te, pred), 4),
    "precision": round(precision_score(y_te, pred), 4),
    "recall": round(recall_score(y_te, pred), 4),
    "f1": round(f1_score(y_te, pred), 4),
    "roc_auc": round(roc_auc_score(y_te, proba), 4),
}
print(json.dumps(metrics, indent=2))
print(classification_report(y_te, pred, target_names=["No PCOS", "PCOS"]))

fig, axes = plt.subplots(1, 2, figsize=(11, 4.5))
sns.heatmap(confusion_matrix(y_te, pred), annot=True, fmt="d", cmap="RdPu", ax=axes[0],
            xticklabels=["No PCOS", "PCOS"], yticklabels=["No PCOS", "PCOS"])
axes[0].set(title="Confusion matrix (test set)", xlabel="Predicted", ylabel="Actual")
RocCurveDisplay.from_predictions(y_te, proba, ax=axes[1], color="#C2185B")
axes[1].set_title(f"ROC curve (AUC = {metrics['roc_auc']:.3f})")
plt.tight_layout(); plt.savefig("/kaggle/working/model/pcos_evaluation.png", dpi=150); plt.show()
"""),
    ("markdown", "## 5. Risk bands & feature importance"),
    ("code", """
def risk_band(p):
    return "Low" if p < 0.30 else "Medium" if p < 0.60 else "High"

bands = pd.DataFrame({"band": [risk_band(p) for p in proba], "actual_pcos": y_te.values})
band_table = bands.groupby("band")["actual_pcos"].agg(women="count", pcos_rate="mean").reindex(["Low", "Medium", "High"])
print(band_table)

# Sanity check: a woman with regular cycles and no symptoms should score Low regardless of other answers
healthy = pd.DataFrame([{"bmi": 21, "irregular_cycle": 0, "period_days": 5, "waist_hip_ratio": 0.89, "weight_gain": 0,
                         "hair_growth": 0, "skin_darkening": 0, "hair_loss": 0, "pimples": 0, "fast_food": 0,
                         "regular_exercise": 1}])[X_self.columns]
print("Healthy profile risk:", round(float(model.predict_proba(healthy)[0, 1]), 3))

imp = pd.Series(model.feature_importances_, index=X_self.columns).sort_values()
fig, ax = plt.subplots(figsize=(8, 5))
imp.plot.barh(ax=ax, color="#C2185B"); ax.set_title("XGBoost feature importance")
plt.tight_layout(); plt.savefig("/kaggle/working/model/pcos_feature_importance.png", dpi=150); plt.show()
"""),
    ("markdown", "## 6. Export for the Femora backend"),
    ("code", """
model.save_model("/kaggle/working/model/pcos_xgb.json")
with open("/kaggle/working/model/pcos_meta.json", "w") as f:
    json.dump({
        "features": list(SELF_REPORT.keys()),
        "risk_bands": {"low": [0, 0.30], "medium": [0.30, 0.60], "high": [0.60, 1.0]},
        "monotone_constraints": MONOTONE,
        "test_metrics": metrics,
        "risk_band_validation": band_table.reset_index().to_dict(orient="records"),
        "cv_results": cv_table.to_dict(orient="records"),
        "feature_importance": imp.sort_values(ascending=False).round(4).to_dict(),
        "dataset": "prasoonkottarathil/polycystic-ovary-syndrome-pcos (n=541)",
    }, f, indent=2)
print(os.listdir("/kaggle/working/model"))
"""),
]

BREAST_ULTRASOUND = [
    ("markdown", r"""
# Femora — Breast Ultrasound Classifier (ResNet50)

**Datasets (combined)**
- **BUSI**: 780 images from 600 women, Baheya Hospital, Cairo (Al-Dhabyani et al., 2020). Labels: normal / benign / malignant.
- **BrEaST-Lesions-USG**: 256 scans from 256 patients, every label confirmed by biopsy or follow-up (Pawłowska et al., 2024,
  The Cancer Imaging Archive, CC BY 4.0). A different hospital and different scanners, so it tests whether the model
  generalises beyond one clinic.

**Design decisions**
- **ResNet50 pretrained on ImageNet**, fine-tuned in two phases (classifier head first, then the whole network) with a
  class-weighted loss, because malignant and normal scans are the minority.
- **Grayscale, padded to a square**: scanners tint images differently and colour carries no information in B-mode
  ultrasound. Padding (instead of stretching) keeps lesion shape, which matters because irregular shape is a malignancy sign.
- **Near-duplicate images are grouped** by perceptual hash (BUSI contains several), so a copy of a test image can never be
  in the training set.
- **Two training recipes are compared by 5-fold cross-validation**: the baseline, and a recipe that weights both hospitals
  equally and adds scanner-style augmentation. The winner is chosen by a rule fixed in advance: the average malignant
  ROC-AUC across the two hospitals, on out-of-fold predictions. The test set is not used for any decision.
- **Screening threshold**: a screening tool should rarely miss cancer, so the "suspicious" threshold is tuned for ≥ 90%
  malignant sensitivity on ~870 out-of-fold predictions (a small validation split gives a noisy threshold).
- **Explainability**: Class Activation Maps (exact for a global-average-pool + linear head), checked against the
  radiologists' lesion masks.
- **Safety**: uploads that are not breast ultrasounds are rejected by a colour check and an "is this an ultrasound?"
  gate, evaluated on image types it never saw during training.
- **Every reported test number is computed with the exported ONNX model**, which is exactly what the Femora backend runs.

Output: normal / benign / malignant probabilities plus a heatmap. This is awareness only, not a diagnosis.
"""),
    ("code", r"""
%pip install -q onnx onnxruntime onnxscript
"""),
    ("code", r"""
import copy, glob, json, os, random, shutil, urllib.request, zipfile, warnings
from pathlib import Path
import numpy as np, pandas as pd
import matplotlib.pyplot as plt, seaborn as sns
from PIL import Image, ImageOps
import torch, torch.nn as nn, torch.nn.functional as F
from torch.utils.data import Dataset, DataLoader
from torchvision import models, transforms
from sklearn.model_selection import StratifiedGroupKFold
from sklearn.linear_model import LogisticRegression
from sklearn.preprocessing import StandardScaler
from sklearn.pipeline import make_pipeline
from sklearn.metrics import (accuracy_score, f1_score, roc_auc_score, recall_score, confusion_matrix,
                             classification_report, roc_curve)
warnings.filterwarnings("ignore")

# Paths can be overridden so the notebook can be smoke-tested locally before a Kaggle run
INPUT = os.environ.get("FEMORA_INPUT", "/kaggle/input")
WORK = os.environ.get("FEMORA_WORK", "/kaggle/working")
TMP = os.environ.get("FEMORA_TMP", "/tmp/femora")      # downloads go here so they don't bloat the notebook output
SMOKE = os.environ.get("FEMORA_SMOKE") == "1"          # tiny run: a few images, one epoch
OUT = f"{WORK}/model"
for d in (OUT, TMP):
    os.makedirs(d, exist_ok=True)

SEED = 42
CLASSES = ["normal", "benign", "malignant"]
SOURCES = ["BUSI", "BrEaST"]
MAL = CLASSES.index("malignant")
IMG = 224
MEAN = np.array([0.485, 0.456, 0.406], np.float32)[:, None, None]   # ImageNet statistics (pretrained backbone)
STD = np.array([0.229, 0.224, 0.225], np.float32)[:, None, None]
COLOUR_LIMIT = 0.10       # max share of clearly coloured pixels in an upload
BATCH = 8 if SMOKE else 32
EPOCHS_HEAD, EPOCHS_FT, CV_FOLDS = (1, 1, 2) if SMOKE else (4, 26, 5)
NUM_WORKERS = 0 if os.name == "nt" else 4

def seed_everything(s=SEED):
    random.seed(s); np.random.seed(s); torch.manual_seed(s); torch.cuda.manual_seed_all(s)

def pick_device():
    if torch.cuda.is_available():
        try:  # fail over to CPU if this GPU architecture isn't in the installed torch build
            (torch.ones(2, 2, device="cuda") @ torch.ones(2, 2, device="cuda")).sum().item()
            return torch.device("cuda")
        except RuntimeError as e:
            print("GPU not usable:", e)
    return torch.device("cpu")

seed_everything()
DEVICE = pick_device()
print(DEVICE, torch.cuda.get_device_name(0) if DEVICE.type == "cuda" else "", "torch", torch.__version__)

# ---- Preprocessing shared with backend/app.py (keep the two in sync)
def pad_square(img, fill=0):
    w, h = img.size
    s = max(w, h)
    canvas = Image.new(img.mode, (s, s), fill)
    canvas.paste(img, ((s - w) // 2, (s - h) // 2))
    return canvas

def to_gray224(img):
    # any upload -> 224x224 uint8 grayscale, padded (not stretched) to a square
    return np.asarray(pad_square(ImageOps.exif_transpose(img).convert("L")).resize((IMG, IMG), Image.BILINEAR))

def normalize(gray224):
    x = gray224.astype(np.float32) / 255.0
    return ((np.repeat(x[None], 3, 0) - MEAN) / STD).astype(np.float32)

def colour_fraction(img):
    # share of clearly coloured pixels: B-mode ultrasound is grey (sometimes tinted), photos and Doppler are not
    a = np.asarray(img.convert("RGB").resize((128, 128)), np.int16)
    diff = np.maximum.reduce([abs(a[..., 0] - a[..., 1]), abs(a[..., 1] - a[..., 2]), abs(a[..., 0] - a[..., 2])])
    return float((diff > 30).mean())

def softmax(z):
    e = np.exp(z - z.max(1, keepdims=True))
    return e / e.sum(1, keepdims=True)

def download(url, dest):
    if not os.path.exists(dest):
        request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(request) as r, open(dest, "wb") as f:
            shutil.copyfileobj(r, f)
    return dest
"""),
    ("markdown", "## 1. Load both datasets"),
    ("code", r"""
# BUSI (Kaggle): <class>/<name>.png, lesion masks are <name>_mask.png, <name>_mask_1.png, ...
busi_root = glob.glob(f"{INPUT}/**/Dataset_BUSI_with_GT", recursive=True)[0]
rows = []
for label in CLASSES:
    for path in sorted(glob.glob(f"{busi_root}/{label}/*.png")):
        if "_mask" not in os.path.basename(path):
            masks = sorted(glob.glob(glob.escape(path[:-4]) + "_mask*.png"))
            rows.append({"path": path, "source": "BUSI", "label": label, "masks": masks})

# BrEaST-Lesions-USG (TCIA, CC BY 4.0): one scan per patient, labels confirmed by biopsy or follow-up
TCIA = "https://www.cancerimagingarchive.net/wp-content/uploads/"
zip_path = download(TCIA + "BrEaST-Lesions_USG-images_and_masks-Dec-15-2023.zip", f"{TMP}/breast_usg.zip")
xlsx_path = download(TCIA + "BrEaST-Lesions-USG-clinical-data-Dec-15-2023.xlsx", f"{TMP}/breast_usg.xlsx")
if not glob.glob(f"{TMP}/breast_usg/**/case001.png", recursive=True):
    zipfile.ZipFile(zip_path).extractall(f"{TMP}/breast_usg")
img_dir = os.path.dirname(glob.glob(f"{TMP}/breast_usg/**/case001.png", recursive=True)[0])
clinical = pd.read_excel(xlsx_path)
for r in clinical.itertuples():
    masks = [f"{img_dir}/{m}" for m in r.Mask_tumor_filename.split("&")] if isinstance(r.Mask_tumor_filename, str) else []
    rows.append({"path": f"{img_dir}/{r.Image_filename}", "source": "BrEaST", "label": r.Classification, "masks": masks})

df = pd.DataFrame(rows)
assert set(df["label"]) <= set(CLASSES), set(df["label"])
if SMOKE:
    df = df.groupby(["source", "label"], group_keys=False).head(12).reset_index(drop=True)
print(pd.crosstab(df["source"], df["label"], margins=True))

fig, axes = plt.subplots(2, 6, figsize=(16, 5.5))
for ax in axes.flat:
    ax.axis("off")
for ax, r in zip(axes.T.flat, df.groupby(["source", "label"]).head(2).itertuples()):
    ax.imshow(Image.open(r.path).convert("L"), cmap="gray")
    ax.set_title(f"{r.source} · {r.label}", fontsize=10)
plt.tight_layout(); plt.show()
"""),
    ("markdown", r"""
## 2. Remove near-duplicates, then split by duplicate group

Each image gets a 256-bit difference hash. Images whose hashes differ in ≤ 12 bits (≈ 5%) are treated as copies of the same
scan and kept in the same split. Copies with *conflicting* labels are dropped, because we can't tell which label is correct.
The split is stratified by source × class: 5/7 train, 1/7 validation, 1/7 test.
"""),
    ("code", r"""
def dhash(path, size=16):
    g = np.asarray(Image.open(path).convert("L").resize((size + 1, size), Image.BILINEAR), dtype=np.int16)
    return (g[:, 1:] > g[:, :-1]).flatten()

h = np.stack([dhash(p) for p in df["path"]]).astype(np.float32) * 2 - 1
hamming = (h.shape[1] - h @ h.T) / 2
parent = list(range(len(df)))
def find(i):
    while parent[i] != i:
        parent[i] = parent[parent[i]]
        i = parent[i]
    return i
for i, j in zip(*np.where(np.triu(hamming <= 12, k=1))):
    parent[find(i)] = find(j)
df["group"] = [find(i) for i in range(len(df))]

dups = df[df.duplicated("group", keep=False)]
n_labels = dups.groupby("group")["label"].nunique()
conflicting = n_labels[n_labels > 1].index
print(f"{len(dups)} images fall into {dups['group'].nunique()} near-duplicate groups; "
      f"{len(conflicting)} groups have conflicting labels and are dropped "
      f"({df['group'].isin(conflicting).sum()} images)")

examples = dups.groupby("group").head(2).head(8)
if len(examples):
    fig, axes = plt.subplots(1, len(examples), figsize=(2.4 * len(examples), 2.8))
    for ax, r in zip(np.atleast_1d(axes), examples.itertuples()):
        ax.imshow(Image.open(r.path).convert("L"), cmap="gray"); ax.axis("off")
        ax.set_title(f"group {r.group}\n{r.label}", fontsize=8)
    plt.suptitle("Examples of detected near-duplicates (pairs)"); plt.tight_layout(); plt.show()

dedup_stats = {"images_in_duplicate_groups": int(len(dups)), "duplicate_groups": int(dups["group"].nunique()),
               "dropped_conflicting_images": int(df["group"].isin(conflicting).sum())}
df = df[~df["group"].isin(conflicting)].reset_index(drop=True)
df["strata"] = df["source"] + "_" + df["label"]

folds = np.zeros(len(df), int)
for k, (_, test_part) in enumerate(StratifiedGroupKFold(n_splits=7, shuffle=True, random_state=SEED)
                                   .split(df, df["strata"], df["group"])):
    folds[test_part] = k
df["split"] = np.select([folds == 0, folds == 1], ["test", "val"], "train")
idx = {s: np.where(df["split"] == s)[0] for s in ["train", "val", "test"]}
print(pd.crosstab([df["source"], df["label"]], df["split"], margins=True))
"""),
    ("markdown", r"""
## 3. Preprocessing, augmentation and the two training recipes

- **baseline**: mild augmentation; classes weighted by inverse frequency.
- **source-balanced + scanner augmentation**: BUSI makes up ~75% of the images, so a model can score well by learning
  what BUSI's scanners look like. This recipe gives each hospital equal total weight and adds augmentation that mimics
  differences between machines (zoom, blur, sharpness, gain and contrast).
"""),
    ("code", r"""
labels = df["label"].map(CLASSES.index).values
sources = df["source"].values
gray224 = np.stack([to_gray224(Image.open(p)) for p in df["path"]])   # exactly what the backend feeds the model
train_imgs = [Image.fromarray(np.asarray(pad_square(ImageOps.exif_transpose(Image.open(p)).convert("L"))
                                         .resize((288, 288), Image.BILINEAR))) for p in df["path"]]

AUGMENT = {
    "standard": transforms.Compose([
        transforms.RandomResizedCrop(IMG, scale=(0.7, 1.0), ratio=(0.85, 1.18)),
        transforms.RandomHorizontalFlip(),   # no vertical flip: the transducer is always at the top of the image
        transforms.RandomApply([transforms.RandomRotation(10)], p=0.5),
        transforms.ColorJitter(brightness=0.25, contrast=0.25),
        transforms.PILToTensor(),
    ]),
    "scanner": transforms.Compose([
        transforms.RandomResizedCrop(IMG, scale=(0.55, 1.0), ratio=(0.8, 1.25)),
        transforms.RandomHorizontalFlip(),
        transforms.RandomApply([transforms.RandomRotation(12)], p=0.5),
        transforms.ColorJitter(brightness=0.4, contrast=0.4),
        transforms.RandomApply([transforms.GaussianBlur(5, sigma=(0.1, 1.5))], p=0.3),
        transforms.RandomAdjustSharpness(2.0, p=0.3),
        transforms.PILToTensor(),
    ]),
}
RECIPES = {
    "baseline": {"augment": "standard", "balance_sources": False},
    "source-balanced + scanner augmentation": {"augment": "scanner", "balance_sources": True},
}

def sample_weights(ids, balance_sources):
    # inverse class frequency, optionally times inverse source frequency so both hospitals count equally
    y, src = labels[ids], sources[ids]
    w = (len(ids) / (len(CLASSES) * np.maximum(np.bincount(y, minlength=len(CLASSES)), 1)))[y]
    if balance_sources:
        names, counts = np.unique(src, return_counts=True)
        per_source = dict(zip(names, len(ids) / (len(names) * counts)))
        w = w * np.array([per_source[s] for s in src])
    out = np.zeros(len(df), np.float32)
    out[ids] = w / w.mean()
    return out

class UltrasoundDS(Dataset):
    def __init__(self, ids, augment=None):
        self.ids, self.augment = np.asarray(ids), augment
    def __len__(self):
        return len(self.ids)
    def __getitem__(self, i):
        j = self.ids[i]
        g = AUGMENT[self.augment](train_imgs[j])[0].numpy() if self.augment else gray224[j]
        return torch.from_numpy(normalize(g)), int(labels[j]), int(j)

def loader(ids, augment=None):
    return DataLoader(UltrasoundDS(ids, augment), batch_size=BATCH, shuffle=augment is not None,
                      drop_last=augment is not None, num_workers=NUM_WORKERS, pin_memory=DEVICE.type == "cuda")

class Net(nn.Module):
    def __init__(self):
        super().__init__()
        resnet = models.resnet50(weights=models.ResNet50_Weights.IMAGENET1K_V2)
        self.backbone = nn.Sequential(*list(resnet.children())[:-2])   # -> B x 2048 x 7 x 7 feature maps
        self.drop = nn.Dropout(0.3)
        self.fc = nn.Linear(2048, len(CLASSES))
    def forward(self, x):
        emb = self.backbone(x).mean((2, 3))   # global average pooling
        return self.fc(self.drop(emb)), emb

def predict_logits(net, ids, amp=True):
    net.eval()
    out = []
    with torch.no_grad():
        for x, *_ in loader(ids):
            with torch.autocast(DEVICE.type, enabled=amp and DEVICE.type == "cuda"):
                out.append(net(x.to(DEVICE))[0].float().cpu())
    return torch.cat(out).numpy()

def summarize(y, p, pred=None):
    pred = p.argmax(1) if pred is None else pred
    return {"accuracy": round(float(accuracy_score(y, pred)), 4),
            "macro_f1": round(float(f1_score(y, pred, average="macro")), 4),
            "malignant_sensitivity": round(float(recall_score(y == MAL, pred == MAL)), 4),
            "malignant_specificity": round(float(recall_score(y != MAL, pred != MAL)), 4),
            "malignant_auc": round(float(roc_auc_score(y == MAL, p[:, MAL])), 4)}

def summarize_by_source(ids, p, pred=None):
    out = {}
    for src in SOURCES:
        m = sources[ids] == src
        try:
            out[src] = {"images": int(m.sum()), **summarize(labels[ids][m], p[m], None if pred is None else pred[m])}
        except ValueError as e:   # e.g. a class missing from a tiny smoke-test split
            print(src, e)
    return out

fig, axes = plt.subplots(2, 6, figsize=(15, 5.6))
for row, name in zip(axes, AUGMENT):
    for ax in row:
        ax.imshow(AUGMENT[name](train_imgs[idx["train"][0]])[0], cmap="gray"); ax.axis("off")
    row[0].set_title(f"{name} augmentation", loc="left", fontsize=10)
plt.tight_layout(); plt.show()
"""),
    ("markdown", r"""
## 4. Baseline: frozen ImageNet ResNet50 + logistic regression

A *linear probe* uses ResNet50 exactly as trained on everyday photos, with no fine-tuning. It shows how much the
fine-tuning in the next sections actually adds.
"""),
    ("code", r"""
@torch.no_grad()
def embed(net, ids):
    net.eval()
    return torch.cat([net(x.to(DEVICE))[1].float().cpu() for x, *_ in loader(ids)]).numpy()

imagenet_net = Net().to(DEVICE)
probe = make_pipeline(StandardScaler(), LogisticRegression(max_iter=5000, C=0.05, class_weight="balanced"))
probe.fit(embed(imagenet_net, idx["train"]), labels[idx["train"]])
p_probe_test = probe.predict_proba(embed(imagenet_net, idx["test"]))
baseline = summarize(labels[idx["test"]], p_probe_test)
del imagenet_net
print(json.dumps(baseline, indent=2))
"""),
    ("markdown", r"""
## 5. Choose the training recipe by 5-fold cross-validation (development set only)

Phase 1 trains only the new classifier head (backbone frozen). Phase 2 unfreezes the whole network, with a 5× lower
learning rate for the pretrained layers and cosine decay. Folds use the last epoch (no checkpoint picking), so the
estimate is not optimistically biased. The test set is not touched.

**Selection rule (fixed before running):** the recipe with the higher average of the out-of-fold malignant ROC-AUC on
BUSI and on BrEaST, so doing well on one hospital cannot hide doing badly on the other.
"""),
    ("code", r"""
def train_model(train_ids, val_ids, recipe, select_best=True, verbose=False):
    seed_everything()
    net = Net().to(DEVICE)
    weights = torch.tensor(sample_weights(train_ids, recipe["balance_sources"]), device=DEVICE)
    criterion = nn.CrossEntropyLoss(reduction="none", label_smoothing=0.05)
    train_dl = loader(train_ids, recipe["augment"])
    scaler = torch.amp.GradScaler(enabled=DEVICE.type == "cuda")

    for p in net.backbone.parameters():
        p.requires_grad = False
    opt, sched = torch.optim.AdamW(net.fc.parameters(), lr=1e-3, weight_decay=1e-4), None
    best, history = (-1.0, None, 0), []
    for epoch in range(EPOCHS_HEAD + EPOCHS_FT):
        if epoch == EPOCHS_HEAD:   # phase 2: fine-tune everything
            for p in net.backbone.parameters():
                p.requires_grad = True
            opt = torch.optim.AdamW([{"params": net.backbone.parameters(), "lr": 1e-4},
                                     {"params": net.fc.parameters(), "lr": 5e-4}], weight_decay=1e-4)
            sched = torch.optim.lr_scheduler.CosineAnnealingLR(opt, T_max=EPOCHS_FT * len(train_dl))
        net.train()
        loss_sum, seen = 0.0, 0
        for x, y, j in train_dl:
            x, y = x.to(DEVICE, non_blocking=True), y.to(DEVICE, non_blocking=True)
            with torch.autocast(DEVICE.type, enabled=DEVICE.type == "cuda"):
                loss = (criterion(net(x)[0], y) * weights[j.to(DEVICE)]).mean()
            opt.zero_grad(set_to_none=True)
            scaler.scale(loss).backward()
            scaler.step(opt)
            scaler.update()
            if sched:
                sched.step()
            loss_sum, seen = loss_sum + loss.item() * len(y), seen + len(y)
        val_f1 = f1_score(labels[val_ids], predict_logits(net, val_ids).argmax(1), average="macro")
        history.append({"epoch": epoch + 1, "train_loss": loss_sum / max(seen, 1), "val_macro_f1": val_f1})
        if val_f1 > best[0]:
            best = (val_f1, copy.deepcopy(net.state_dict()), epoch + 1)
        if verbose:
            print(f"epoch {epoch + 1:2d}  loss {history[-1]['train_loss']:.3f}  val macro-F1 {val_f1:.3f}")
    if select_best:
        net.load_state_dict(best[1])
    return net, pd.DataFrame(history), best[2]

dev = np.concatenate([idx["train"], idx["val"]])
cv_splits = list(StratifiedGroupKFold(n_splits=CV_FOLDS, shuffle=True, random_state=SEED)
                 .split(dev, df["strata"].values[dev], df["group"].values[dev]))
oof_logits, cv_rows = {}, []
for name, recipe in RECIPES.items():
    oof_logits[name] = np.zeros((len(df), len(CLASSES)), np.float32)
    for k, (tr, va) in enumerate(cv_splits):
        fold_net, _, _ = train_model(dev[tr], dev[va], recipe, select_best=False)
        logits = predict_logits(fold_net, dev[va], amp=False)
        oof_logits[name][dev[va]] = logits
        cv_rows.append({"recipe": name, "fold": k + 1, **summarize(labels[dev[va]], softmax(logits))})
        print(cv_rows[-1])
        del fold_net
        torch.cuda.empty_cache()
cv_table = pd.DataFrame(cv_rows)

recipe_rows = []
for name in RECIPES:
    p_oof = softmax(oof_logits[name][dev])
    by_source = summarize_by_source(dev, p_oof)
    folds_of = cv_table[cv_table.recipe == name]
    recipe_rows.append({
        "recipe": name,
        "selection_score": round(float(np.mean([by_source[s]["malignant_auc"] for s in by_source])), 4),
        **{f"cv_{m}": f"{folds_of[m].mean():.3f} ± {folds_of[m].std():.3f}"
           for m in ["accuracy", "macro_f1", "malignant_sensitivity", "malignant_auc"]},
        **{f"{s}_{m}": by_source[s][m] for s in by_source for m in ["accuracy", "malignant_auc"]},
    })
recipe_table = pd.DataFrame(recipe_rows)
BEST_RECIPE = recipe_table.loc[recipe_table["selection_score"].idxmax(), "recipe"]
display(recipe_table)
print("Selected recipe:", BEST_RECIPE)
cv_summary = recipe_table.set_index("recipe").loc[BEST_RECIPE].to_dict()
"""),
    ("markdown", "## 6. Final model (selected recipe, train split, best epoch picked on the validation split)"),
    ("code", r"""
net, history, best_epoch = train_model(idx["train"], idx["val"], RECIPES[BEST_RECIPE], verbose=True)
p_torch_test = softmax(predict_logits(net, idx["test"], amp=False))   # full-precision reference for the parity check

fig, ax1 = plt.subplots(figsize=(8, 4))
ax1.plot(history["epoch"], history["train_loss"], color="#C2185B", label="train loss")
ax2 = ax1.twinx()
ax2.plot(history["epoch"], history["val_macro_f1"], color="#6C2D7E", label="val macro-F1")
ax1.axvline(best_epoch, ls="--", color="grey"); ax1.axvline(EPOCHS_HEAD + 0.5, ls=":", color="lightgrey")
ax1.set(xlabel="epoch", ylabel="train loss"); ax2.set_ylabel("val macro-F1")
fig.legend(loc="upper center", ncol=2); plt.title(f"Training (best epoch {best_epoch})", pad=24)
plt.tight_layout(); plt.savefig(f"{OUT}/breast_training_curve.png", dpi=150); plt.show()
"""),
    ("markdown", r"""
## 7. Export to ONNX and verify parity

The exported graph returns three outputs: **logits** (the prediction), the **embedding** (used by the ultrasound gate)
and **class activation maps** (the heatmap). With a global-average-pool + linear head, CAM is exact: it is the
classifier's weights applied to every spatial location of the last feature map.

The fp32 ResNet50 is 94 MB, close to GitHub's 100 MB file limit. Conv/linear weights are therefore **stored** in fp16 and
cast back to fp32 when the model loads. All computation stays in fp32.
"""),
    ("code", r"""
import onnx, onnxruntime as ort
from onnx import helper, numpy_helper, TensorProto

class ExportNet(nn.Module):
    def __init__(self, net):
        super().__init__()
        self.net = net
    def forward(self, x):
        fmap = self.net.backbone(x)
        emb = fmap.mean((2, 3))
        cam = F.conv2d(fmap, self.net.fc.weight[:, :, None, None])   # class activation maps, B x 3 x 7 x 7
        return self.net.fc(emb), emb, cam

net = net.float().cpu().eval()
fp32_path = f"{TMP}/breast_resnet50_fp32.onnx"
export_args = dict(input_names=["image"], output_names=["logits", "embedding", "cam"], opset_version=17,
                   dynamic_axes={n: {0: "batch"} for n in ["image", "logits", "embedding", "cam"]})
dummy = torch.from_numpy(normalize(gray224[0]))[None]
try:
    torch.onnx.export(ExportNet(net).eval(), dummy, fp32_path, dynamo=False, **export_args)
except TypeError:   # torch < 2.5 has no `dynamo` argument
    torch.onnx.export(ExportNet(net).eval(), dummy, fp32_path, **export_args)

model = onnx.load(fp32_path)
graph = model.graph
initializers, casts = [], []
for init in graph.initializer:
    w = numpy_helper.to_array(init)
    if w.dtype == np.float32 and w.ndim >= 2:   # conv / linear weights; BatchNorm statistics stay fp32
        initializers.append(numpy_helper.from_array(w.astype(np.float16), init.name + "_fp16"))
        casts.append(helper.make_node("Cast", [init.name + "_fp16"], [init.name], to=TensorProto.FLOAT))
    else:
        initializers.append(numpy_helper.from_array(w, init.name))
nodes = casts + [copy.deepcopy(n) for n in graph.node]
graph.ClearField("initializer"); graph.initializer.extend(initializers)
graph.ClearField("node"); graph.node.extend(nodes)
onnx.checker.check_model(model)
ONNX_PATH = f"{OUT}/breast_resnet50.onnx"
onnx.save(model, ONNX_PATH)
print(f"fp32 {os.path.getsize(fp32_path) / 1e6:.1f} MB -> deployed {os.path.getsize(ONNX_PATH) / 1e6:.1f} MB")

def run_session(sess, grays, batch=32):
    outs = [sess.run(None, {"image": np.stack([normalize(g) for g in grays[i:i + batch]])})
            for i in range(0, len(grays), batch)]
    return [np.concatenate(o) for o in zip(*outs)]

session = ort.InferenceSession(ONNX_PATH, providers=["CPUExecutionProvider"])
def run_onnx(grays):
    return run_session(session, grays)

onnx_out = {s: run_onnx(gray224[idx[s]]) for s in ["train", "val", "test"]}   # (logits, embedding, cam) per split
# Two separate checks: the export itself must be exact; fp16 weight storage only adds rounding noise.
# (All metrics below are computed with the deployed model, so that noise is already reflected in them.)
fp32_session = ort.InferenceSession(fp32_path, providers=["CPUExecutionProvider"])
p_onnx_test = softmax(onnx_out["test"][0])
parity_fp32 = float(np.abs(softmax(run_session(fp32_session, gray224[idx["test"]])[0]) - p_torch_test).max())
parity = float(np.abs(p_onnx_test - p_torch_test).max())
flipped = int((p_onnx_test.argmax(1) != p_torch_test.argmax(1)).sum())
print(f"max |P_onnx - P_torch| on the test set: fp32 export {parity_fp32:.5f}, deployed (fp16 weights) {parity:.5f}; "
      f"{flipped} of {len(p_torch_test)} test predictions change class")
assert parity_fp32 < 1e-3, "ONNX export disagrees with the trained network"
assert parity < 0.05, "fp16 weight storage changes predictions too much"
"""),
    ("markdown", r"""
## 8. Calibration and the screening threshold (out-of-fold predictions)

- **Temperature scaling** makes the displayed confidence honest: when the app says "85% confident", it should be right
  about 85% of the time.
- **Screening rule**: a scan is flagged *suspicious* when P(malignant) ≥ threshold, even if another class is more likely.
  The threshold is the highest value that still catches ≥ 90% of malignant scans.

Both are fitted on the selected recipe's out-of-fold predictions for the whole development set (~870 scans, ~260
malignant). A threshold fitted on the small validation split alone (~30 malignant scans) is too noisy.
"""),
    ("code", r"""
def fit_temperature(logits, y):
    log_t = torch.zeros(1, requires_grad=True)
    z, target = torch.tensor(logits), torch.tensor(y)
    opt = torch.optim.LBFGS([log_t], lr=0.1, max_iter=200)
    def closure():
        opt.zero_grad()
        loss = F.cross_entropy(z / log_t.exp(), target)
        loss.backward()
        return loss
    opt.step(closure)
    return float(log_t.exp())

def ece(p, y, bins=10):
    # expected calibration error: average gap between confidence and accuracy, weighted by bin size
    conf, correct = p.max(1), p.argmax(1) == y
    edges = np.linspace(0, 1, bins + 1)
    total = 0.0
    for lo, hi in zip(edges[:-1], edges[1:]):
        m = (conf > lo) & (conf <= hi)
        if m.any():
            total += m.mean() * abs(correct[m].mean() - conf[m].mean())
    return float(total)

def decide(p, t_mal):
    pred = p.argmax(1)
    pred[p[:, MAL] >= t_mal] = MAL
    return pred

z_oof, y_dev = oof_logits[BEST_RECIPE][dev], labels[dev]
TEMPERATURE = fit_temperature(z_oof, y_dev)
p_oof = softmax(z_oof / TEMPERATURE)
ok = [t for t in np.round(np.arange(0.50, 0.04, -0.01), 2)
      if recall_score(y_dev == MAL, decide(p_oof, t) == MAL) >= 0.90]
MAL_THRESHOLD = float(ok[0]) if ok else 0.10
y_val, y_test = labels[idx["val"]], labels[idx["test"]]
calibration = {"temperature": round(TEMPERATURE, 4), "fitted_on": f"{len(dev)} out-of-fold predictions",
               "oof_ece_before": round(ece(softmax(z_oof), y_dev), 4), "oof_ece_after": round(ece(p_oof, y_dev), 4),
               "val_ece_final_model": round(ece(softmax(onnx_out["val"][0] / TEMPERATURE), y_val), 4)}
print(calibration, "| malignant threshold:", MAL_THRESHOLD)
"""),
    ("markdown", "## 9. Held-out test set (computed with the exported ONNX model)"),
    ("code", r"""
p_test = softmax(onnx_out["test"][0] / TEMPERATURE)
pred_test = decide(p_test, MAL_THRESHOLD)
test_metrics = {"test_size": int(len(y_test)), **summarize(y_test, p_test, pred_test),
                "macro_auc_ovr": round(float(roc_auc_score(y_test, p_test, multi_class="ovr")), 4),
                "ece": round(ece(p_test, y_test), 4)}
calibration["test_ece_before"] = round(ece(softmax(onnx_out["test"][0]), y_test), 4)
calibration["test_ece_after"] = test_metrics["ece"]
argmax_metrics = summarize(y_test, p_test)
print(json.dumps(test_metrics, indent=2))
print(classification_report(y_test, pred_test, target_names=CLASSES))

per_source = summarize_by_source(idx["test"], p_test, pred_test)
print(pd.DataFrame(per_source).T)

comparison = pd.DataFrame([
    {"model": "Linear probe (frozen ImageNet ResNet50)", **baseline},
    {"model": "Fine-tuned ResNet50, argmax", **argmax_metrics},
    {"model": f"Fine-tuned ResNet50, screening rule (P(mal) >= {MAL_THRESHOLD})", **summarize(y_test, p_test, pred_test)},
])
display(comparison)

fig, axes = plt.subplots(1, 2, figsize=(12, 4.8))
sns.heatmap(confusion_matrix(y_test, pred_test, labels=range(len(CLASSES))), annot=True, fmt="d", cmap="RdPu",
            ax=axes[0], xticklabels=CLASSES, yticklabels=CLASSES)
axes[0].set(title="Confusion matrix (test set, screening rule)", xlabel="Predicted", ylabel="Actual")
for src, colour in [("BUSI", "#C2185B"), ("BrEaST", "#6C2D7E")]:
    m = sources[idx["test"]] == src
    fpr, tpr, _ = roc_curve(y_test[m] == MAL, p_test[m, MAL])
    axes[1].plot(fpr, tpr, color=colour, label=f"{src} (AUC {per_source[src]['malignant_auc']:.2f})")
axes[1].plot([0, 1], [0, 1], "--", color="grey")
axes[1].set(xlabel="False positive rate", ylabel="True positive rate", title="Malignant vs rest, by hospital")
axes[1].legend(loc="lower right")
plt.tight_layout(); plt.savefig(f"{OUT}/breast_evaluation.png", dpi=150); plt.show()
"""),
    ("markdown", r"""
## 10. Explainability: do the heatmaps land on the lesion?

For every test scan with a lesion, the activation map of its true class is upsampled to the image. Two scores:
- **Pointing game**: is the hottest pixel inside the radiologist's lesion mask?
- **IoU**: overlap between the hot region (≥ 50% of the maximum) and the mask.
"""),
    ("code", r"""
def upsample_cam(cam7):
    c = np.maximum(cam7, 0)
    c = c / c.max() if c.max() > 0 else c
    return np.asarray(Image.fromarray((c * 255).astype(np.uint8)).resize((IMG, IMG), Image.BILINEAR)) / 255.0

def mask224(paths):
    m = np.zeros((IMG, IMG), bool)
    for p in paths:
        m |= np.asarray(pad_square(Image.open(p).convert("L")).resize((IMG, IMG), Image.NEAREST)) > 127
    return m

cam_test = onnx_out["test"][2]
hits, ious, chance, shown = [], [], [], []
for k, j in enumerate(idx["test"]):
    if labels[j] == CLASSES.index("normal") or not df.at[j, "masks"]:
        continue
    mask = mask224(df.at[j, "masks"])
    if not mask.any():
        continue
    heat = upsample_cam(cam_test[k, labels[j]])
    hits.append(bool(mask[np.unravel_index(heat.argmax(), heat.shape)]))
    hot = heat >= 0.5
    ious.append((hot & mask).sum() / (hot | mask).sum())
    chance.append(mask.sum() / (gray224[j] > 10).sum())   # hit rate of a random point on the scan
    if len(shown) < 8 and (len(shown) < 4 or labels[j] == MAL):
        shown.append((j, heat, mask))
cam_eval = {"lesion_images": len(hits), "pointing_game": round(float(np.mean(hits)), 4),
            "mean_iou": round(float(np.mean(ious)), 4), "pointing_game_chance": round(float(np.mean(chance)), 4)}
print(cam_eval)

fig, axes = plt.subplots(2, 4, figsize=(14, 7.5))
for ax in axes.flat:
    ax.axis("off")
for ax, (j, heat, mask) in zip(axes.flat, shown):
    ax.imshow(gray224[j], cmap="gray"); ax.imshow(heat, cmap="jet", alpha=0.35)
    ax.contour(mask, levels=[0.5], colors="white", linewidths=1.2)
    ax.set_title(f"{df.at[j, 'label']} ({df.at[j, 'source']})", fontsize=10)
plt.suptitle("Class activation maps (colour) vs radiologist lesion masks (white outline)")
plt.tight_layout(); plt.savefig(f"{OUT}/breast_cam_examples.png", dpi=130); plt.show()
"""),
    ("markdown", r"""
## 11. Rejecting uploads that aren't breast ultrasounds

People will upload the wrong image: a selfie, a photo of a report, an X-ray. The classifier would still output
normal/benign/malignant for any of these, so the backend runs two checks first:
1. **Colour check**: B-mode ultrasound is grey. Images where more than 10% of pixels are clearly coloured are rejected.
2. **Ultrasound gate**: a logistic regression on the network's embedding, trained to separate the training ultrasounds
   from *grayscale* photos (4 categories) and chest X-rays. Its threshold lets 99% of validation scans through.

To check that the gate generalises, it is tested on held-out ultrasounds and on images it never saw: other photo
categories (in colour and in grayscale), held-out chest X-rays, and brain MRIs, an image type absent from its training.
(An unsupervised feature-distance check was tried first and rejected almost nothing: photos and X-rays landed at the
same distances as real scans.)
"""),
    ("code", r"""
def find_images(pattern):
    paths = glob.glob(f"{INPUT}/**/{pattern}", recursive=True)
    return sorted(p for p in paths if "__MACOSX" not in p and not os.path.basename(p).startswith("._")
                  and p.lower().endswith((".jpg", ".jpeg", ".png")))

def load_images(paths):
    images = []
    for p in paths:
        try:
            im = Image.open(p)
            im.load()
            images.append(im)
        except Exception:
            pass
    return images

rng = np.random.default_rng(SEED)
def sample(paths, n):
    return list(rng.choice(paths, min(n, len(paths)), replace=False)) if paths else []

GATE_PHOTO_CLASSES = ["airplane", "car", "cat", "dog"]   # the other natural-image classes are held out
natural = find_images("natural_images/*/*.jpg")
photos_train = load_images(sample([p for p in natural if Path(p).parent.name in GATE_PHOTO_CLASSES], 600))
photos_heldout = load_images(sample([p for p in natural if Path(p).parent.name not in GATE_PHOTO_CLASSES], 300))
xray_train = load_images(sample(find_images("chest_xray/train/*/*.jpeg"), 400))
xray_heldout = load_images(sample(find_images("chest_xray/test/*/*.jpeg"), 300))
mri = load_images(sample(find_images("brain_tumor_dataset/*/*"), 250))
print({"photos (train)": len(photos_train), "photos (held out)": len(photos_heldout), "x-rays (train)": len(xray_train),
       "x-rays (held out)": len(xray_heldout), "brain MRI (never seen)": len(mri)})

def embeddings(images):
    return run_onnx(np.stack([to_gray224(im) for im in images]))[1] if images else np.zeros((0, 2048), np.float32)

negatives = np.concatenate([embeddings(photos_train), embeddings(xray_train)])
X_gate = np.concatenate([onnx_out["train"][1], negatives])
y_gate = np.r_[np.ones(len(idx["train"])), np.zeros(len(negatives))]
gate = make_pipeline(StandardScaler(), LogisticRegression(C=0.1, max_iter=5000, class_weight="balanced")).fit(X_gate, y_gate)
gate_score = lambda emb: gate.predict_proba(emb)[:, 1] if len(emb) else np.zeros(0)
GATE_THRESHOLD = float(min(np.percentile(gate_score(onnx_out["val"][1]), 1), 0.5))

test_colour = np.array([colour_fraction(Image.open(p)) for p in df["path"].values[idx["test"]]])
photo_scores = gate_score(embeddings(photos_heldout))   # the model only ever sees the grayscale version
eval_sets = [
    # name, colour fractions (None = already grayscale, so the colour check can't help), gate scores
    ("Test ultrasounds (should pass)", test_colour, gate_score(onnx_out["test"][1])),
    ("Colour photos, unseen categories", np.array([colour_fraction(im) for im in photos_heldout]), photo_scores),
    ("Grayscale photos, unseen categories", None, photo_scores),
    ("Chest X-rays, held out", np.array([colour_fraction(im) for im in xray_heldout]), gate_score(embeddings(xray_heldout))),
    ("Brain MRI, never seen", np.array([colour_fraction(im) for im in mri]), gate_score(embeddings(mri))),
]
ood_rows, gate_scores = [], {}
for name, colour, score in eval_sets:
    if len(score) == 0:
        print(f"{name}: dataset not attached, skipped")
        continue
    by_colour = colour > COLOUR_LIMIT if colour is not None else np.zeros(len(score), bool)
    by_gate = score < GATE_THRESHOLD
    gate_scores[name] = score
    ood_rows.append({"images": name, "n": len(score), "rejected_colour": round(float(by_colour.mean()), 4),
                     "rejected_gate": round(float(by_gate.mean()), 4),
                     "rejected_total": round(float((by_colour | by_gate).mean()), 4)})
ood_table = pd.DataFrame(ood_rows)
print(f"gate threshold {GATE_THRESHOLD:.3f}")
display(ood_table)

fig, ax = plt.subplots(figsize=(9, 4))
for name, score in gate_scores.items():
    ax.hist(score, bins=40, range=(0, 1), alpha=0.5, label=name, density=True)
ax.axvline(GATE_THRESHOLD, color="k", ls="--", label="threshold")
ax.set(xlabel="gate probability of 'breast ultrasound'", title="Ultrasound gate", yscale="log"); ax.legend(fontsize=8)
plt.tight_layout(); plt.savefig(f"{OUT}/breast_gate.png", dpi=130); plt.show()
"""),
    ("markdown", "## 12. Export for the Femora backend"),
    ("code", r"""
scaler, logreg = gate.named_steps["standardscaler"], gate.named_steps["logisticregression"]
np.savez(f"{OUT}/breast_gate.npz", mean=scaler.mean_.astype(np.float32), scale=scaler.scale_.astype(np.float32),
         coef=logreg.coef_[0].astype(np.float32), intercept=np.float32(logreg.intercept_[0]))

# Demo scans for the app: held-out BrEaST test images (CC BY 4.0) the model classifies correctly, median confidence
os.makedirs(f"{OUT}/samples", exist_ok=True)
test_df = df.iloc[idx["test"]].assign(pred=pred_test, conf=p_test.max(1))
samples = {}
for label in ["benign", "malignant"]:
    ok_rows = test_df[(test_df.source == "BrEaST") & (test_df.label == label) & (test_df.pred == CLASSES.index(label))]
    if len(ok_rows):
        r = ok_rows.sort_values("conf").iloc[len(ok_rows) // 2]
        shutil.copy(r["path"], f"{OUT}/samples/breast_sample_{label}.png")
        samples[label] = os.path.basename(r["path"])

df.assign(file=df["path"].map(os.path.basename))[["file", "source", "label", "group", "split"]] \
  .to_csv(f"{OUT}/breast_split.csv", index=False)

def to_builtin(o):
    return o.item() if hasattr(o, "item") else str(o)

with open(f"{OUT}/breast_meta.json", "w") as f:
    json.dump({
        "classes": CLASSES,
        "onnx_file": "breast_resnet50.onnx",
        "outputs": ["logits", "embedding", "cam"],
        "input": {"size": IMG, "mean": MEAN.ravel().tolist(), "std": STD.ravel().tolist(),
                  "preprocessing": "EXIF-rotate, grayscale, pad to square with black, bilinear resize to 224, "
                                   "repeat to 3 channels, ImageNet normalisation"},
        "temperature": TEMPERATURE,
        "malignant_threshold": MAL_THRESHOLD,
        "colour_limit": COLOUR_LIMIT,
        "gate_file": "breast_gate.npz",
        "gate_threshold": GATE_THRESHOLD,
        "recipe": {"name": BEST_RECIPE, **RECIPES[BEST_RECIPE]},
        "recipe_comparison": recipe_table.to_dict(orient="records"),
        "test_metrics": test_metrics,
        "test_metrics_argmax": argmax_metrics,
        "per_source_test": per_source,
        "comparison": comparison.to_dict(orient="records"),
        "cv_results": cv_table.to_dict(orient="records"),
        "cv_summary": cv_summary,
        "calibration": calibration,
        "cam_evaluation": cam_eval,
        "ood_evaluation": ood_table.to_dict(orient="records"),
        "onnx_parity": {"fp32_export_max_abs_diff": parity_fp32, "deployed_max_abs_diff": parity,
                        "test_predictions_changed_by_fp16": flipped},
        "best_epoch": best_epoch,
        "samples": samples,
        "dataset": {
            "sources": ["BUSI (Al-Dhabyani et al., 2020)", "BrEaST-Lesions-USG (Pawłowska et al., 2024, TCIA, CC BY 4.0)"],
            "images": int(len(df)), "near_duplicates": dedup_stats,
            "counts": pd.crosstab(df["source"], df["label"]).to_dict(),
            "splits": df["split"].value_counts().to_dict(),
        },
    }, f, indent=2, default=to_builtin)
print(sorted(os.listdir(OUT)))
"""),
]


BREAST_RISK = [
    ("markdown", r"""
# Femora — Breast Cancer Risk Questionnaire (XGBoost)

**Deployed model: BCSC Risk Estimation dataset** (Breast Cancer Surveillance Consortium; Barlow et al., JNCI 2006).
Screening mammograms of women with **no previous breast cancer**. Outcome: breast cancer (invasive or DCIS) diagnosed
**within one year** of the mammogram. The data is aggregated: each row is one combination of risk factors plus a count.

**Reference model: Wisconsin Diagnostic dataset** (Wolberg et al., 1993; the dataset named in the scope document).
569 biopsies described by 30 cell-nucleus measurements from fine-needle aspirate images. It is trained here for comparison,
but it **cannot power a questionnaire**: a user cannot self-report any of its inputs.

**Design decisions**
- **Only self-reportable questions**: age, menopause, BMI, age at first birth, close relatives with breast cancer, previous
  breast biopsy, hormone therapy. Breast density and the last mammogram result are optional. "Don't know" is treated as
  missing, exactly as BCSC codes it.
- **Race/ethnicity excluded**: US census categories don't transfer to Femora's Pakistani users.
- **Monotonic constraints** on established risk factors (age, family history, biopsy, breast density, hormone therapy)
  keep the model medically sensible.
- **No SMOTE / class re-weighting**: the goal is a calibrated absolute risk, not a classifier.
- The output is a 1-year risk **relative to the average woman of the same age**. Bands follow the NICE familial-risk
  categories (moderate ≈ 17%, high ≈ 30% lifetime risk vs 12.5% for the population, so ≈ 1.35× and 2.4×).
- **Symptoms** (lump, nipple discharge, skin changes) are not in any public outcome dataset. The app handles them with
  NICE NG12 referral rules instead of this model.
"""),
    ("code", r"""
import glob, json, os, warnings
import numpy as np, pandas as pd
import matplotlib.pyplot as plt, seaborn as sns
from sklearn.datasets import load_breast_cancer
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import StratifiedKFold, cross_validate, train_test_split
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import OneHotEncoder
from sklearn.metrics import (accuracy_score, brier_score_loss, f1_score, precision_score, recall_score,
                             roc_auc_score, roc_curve)
from xgboost import XGBClassifier
warnings.filterwarnings("ignore")

INPUT = os.environ.get("FEMORA_INPUT", "/kaggle/input")
WORK = os.environ.get("FEMORA_WORK", "/kaggle/working")
OUT = f"{WORK}/model"
os.makedirs(OUT, exist_ok=True)
SEED = 42
"""),
    ("markdown", "## 1. Load the BCSC Risk Estimation dataset"),
    ("code", r"""
COLUMNS = ["menopaus", "agegrp", "density", "race", "Hispanic", "bmi", "agefirst", "nrelbc", "brstproc",
           "lastmamm", "surgmeno", "hrt", "invasive", "cancer", "training", "count"]
path = next(p for p in sorted(glob.glob(f"{INPUT}/**/*", recursive=True))
            if os.path.isfile(p) and "risk" in os.path.basename(p).lower() and p.lower().endswith((".txt", ".csv", ".dat")))
with open(path) as f:
    has_header = any(ch.isalpha() for ch in f.readline())
bcsc = pd.read_csv(path, sep=r"[,\s]+", engine="python", header=0 if has_header else None,
                   names=None if has_header else COLUMNS)
bcsc.columns = bcsc.columns.str.strip()

women = bcsc["count"].sum()
cancers = bcsc.loc[bcsc["cancer"] == 1, "count"].sum()
print(f"{path}\n{len(bcsc):,} risk-factor combinations covering {women:,} mammograms; "
      f"{cancers:,} cancers within 1 year ({cancers / women:.3%})")
print(bcsc.groupby("training")["count"].sum().rename({0: "validation", 1: "training"}))
"""),
    ("markdown", r"""
## 2. Features

BCSC codes "unknown" as 9. For hormone therapy and surgical menopause, 9 also means "not menopausal". These become missing
values, which XGBoost handles natively by learning which branch they should follow. Age group 9 is a real value (75–79).
"""),
    ("code", r"""
AGE_GROUPS = {1: "35-39", 2: "40-44", 3: "45-49", 4: "50-54", 5: "55-59", 6: "60-64", 7: "65-69",
              8: "70-74", 9: "75-79", 10: "80-84"}
FEATURES = ["agegrp", "menopaus", "bmi", "agefirst", "nrelbc", "brstproc", "hrt", "surgmeno", "density", "lastmamm"]
MONOTONE = {"agegrp": 1, "menopaus": 0, "bmi": 0, "agefirst": 0, "nrelbc": 1, "brstproc": 1, "hrt": 1,
            "surgmeno": 0, "density": 1, "lastmamm": 0}

X = bcsc[FEATURES].astype(float)
coded = [f for f in FEATURES if f != "agegrp"]
X[coded] = X[coded].mask(X[coded] == 9)
y = bcsc["cancer"].astype(int).values
w = bcsc["count"].astype(float).values
is_train = (bcsc["training"] == 1).values
X_tr, X_va, y_tr, y_va, w_tr, w_va = X[is_train], X[~is_train], y[is_train], y[~is_train], w[is_train], w[~is_train]

def weighted_rate(frame, col):
    g = pd.DataFrame({"level": frame[col].fillna(-1), "w": w, "cases": y * w}).groupby("level").sum()
    return (g["cases"] / g["w"]).rename(index={-1: "unknown"})

fig, axes = plt.subplots(2, 3, figsize=(15, 7))
for ax, col in zip(axes.flat, ["agegrp", "nrelbc", "brstproc", "density", "bmi", "agefirst"]):
    (weighted_rate(X, col) * 1000).plot.bar(ax=ax, color="#C2185B")
    ax.set(title=col, ylabel="cancers per 1,000 women (1 year)", xlabel="")
plt.tight_layout(); plt.show()
"""),
    ("markdown", r"""
## 3. Compare models on the BCSC validation split

The dataset ships with its own training/validation split (`training` column), which is used as-is. Published risk-factor
models (Gail, BCSC) typically reach a ROC-AUC of about 0.60–0.67, so **calibration** (expected ÷ observed cancers ≈ 1)
matters as much as AUC.
"""),
    ("code", r"""
def weighted_metrics(p, y_, w_):
    return {"roc_auc": round(roc_auc_score(y_, p, sample_weight=w_), 4),
            "brier": round(brier_score_loss(y_, p, sample_weight=w_), 6),
            "expected_over_observed": round((p * w_).sum() / (y_ * w_).sum(), 3)}

def one_hot_logit(cols):
    pipe = make_pipeline(OneHotEncoder(handle_unknown="ignore"), LogisticRegression(max_iter=3000))
    pipe.fit(X_tr[cols].fillna(9).astype(int).astype(str), y_tr, logisticregression__sample_weight=w_tr)
    return pipe.predict_proba(X_va[cols].fillna(9).astype(int).astype(str))[:, 1]

fit_rows, stop_rows = train_test_split(np.arange(len(X_tr)), test_size=0.15, stratify=y_tr, random_state=SEED)
model = XGBClassifier(n_estimators=1000, max_depth=4, learning_rate=0.03, subsample=0.8, colsample_bytree=0.9,
                      min_child_weight=20, monotone_constraints=tuple(MONOTONE[f] for f in FEATURES),
                      tree_method="hist", eval_metric="logloss", early_stopping_rounds=50, random_state=SEED)
# early stopping uses a slice of the *training* rows; the BCSC validation split stays untouched
model.fit(X_tr.iloc[fit_rows], y_tr[fit_rows], sample_weight=w_tr[fit_rows],
          eval_set=[(X_tr.iloc[stop_rows], y_tr[stop_rows])], sample_weight_eval_set=[w_tr[stop_rows]], verbose=False)
p_va = model.predict_proba(X_va)[:, 1]
print("trees:", model.best_iteration + 1)

comparison = pd.DataFrame([
    {"model": "Age only (logistic regression)", **weighted_metrics(one_hot_logit(["agegrp"]), y_va, w_va)},
    {"model": "All questions (logistic regression, one-hot)", **weighted_metrics(one_hot_logit(FEATURES), y_va, w_va)},
    {"model": "All questions (XGBoost, monotone) — deployed", **weighted_metrics(p_va, y_va, w_va)},
])
display(comparison)
val_metrics = comparison.iloc[-1].drop("model").to_dict()

cal = pd.DataFrame({"p": p_va, "w": w_va, "cases": y_va * w_va, "pw": p_va * w_va}).sort_values("p")
cal["decile"] = np.minimum((cal["w"].cumsum() / cal["w"].sum() * 10).astype(int), 9)
cal = cal.groupby("decile").sum()
fig, axes = plt.subplots(1, 2, figsize=(12, 4.6))
axes[0].plot(cal["pw"] / cal["w"] * 1000, cal["cases"] / cal["w"] * 1000, "o-", color="#C2185B")
lim = max((cal["pw"] / cal["w"]).max(), (cal["cases"] / cal["w"]).max()) * 1000 * 1.05
axes[0].plot([0, lim], [0, lim], "--", color="grey")
axes[0].set(title="Calibration by risk decile (validation)", xlabel="predicted per 1,000", ylabel="observed per 1,000")
fpr, tpr, _ = roc_curve(y_va, p_va, sample_weight=w_va)
axes[1].plot(fpr, tpr, color="#C2185B"); axes[1].plot([0, 1], [0, 1], "--", color="grey")
axes[1].set(xlabel="False positive rate", ylabel="True positive rate")
axes[1].set_title(f"ROC (AUC = {val_metrics['roc_auc']:.3f})")
plt.tight_layout(); plt.savefig(f"{OUT}/breast_risk_evaluation.png", dpi=150); plt.show()
"""),
    ("markdown", r"""
## 4. Relative risk and risk bands

The app compares a woman's 1-year risk with the **average woman in her age group**, so age alone never makes someone
"high risk". The bands are checked on the validation split: the observed cancer rate should rise from Low to High.
"""),
    ("code", r"""
BANDS = {"low": [0, 1.35], "medium": [1.35, 2.4], "high": [2.4, None]}
p_tr = model.predict_proba(X_tr)[:, 1]
age_avg = (pd.Series(p_tr * w_tr).groupby(X_tr["agegrp"].values).sum()
           / pd.Series(w_tr).groupby(X_tr["agegrp"].values).sum())

expected_va = X_va["agegrp"].map(age_avg).values
rr_va = p_va / expected_va
band_va = np.select([rr_va < 1.35, rr_va < 2.4], ["low", "medium"], "high")
band_table = (pd.DataFrame({"band": band_va, "women": w_va, "cases": y_va * w_va, "expected_at_age_average": expected_va * w_va})
              .groupby("band").sum().reindex(["low", "medium", "high"]).fillna(0))
band_table["share_of_women"] = band_table["women"] / band_table["women"].sum()
band_table["observed_per_1000"] = band_table["cases"] / band_table["women"] * 1000
band_table["observed_rr_vs_age_average"] = band_table["cases"] / band_table["expected_at_age_average"]
display(band_table.round(3))
print((age_avg * 1000).round(2).rename(AGE_GROUPS).rename("average 1-year risk per 1,000"))
"""),
    ("markdown", "## 5. Sanity checks & feature importance"),
    ("code", r"""
profiles = pd.DataFrame([
    {"name": "42, no risk factors",            "agegrp": 2, "menopaus": 0, "bmi": 1, "agefirst": 0, "nrelbc": 0, "brstproc": 0},
    {"name": "42, mother had breast cancer",   "agegrp": 2, "menopaus": 0, "bmi": 1, "agefirst": 0, "nrelbc": 1, "brstproc": 0},
    {"name": "42, 2 relatives + prior biopsy", "agegrp": 2, "menopaus": 0, "bmi": 1, "agefirst": 2, "nrelbc": 2, "brstproc": 1},
    {"name": "58, post-menopausal, BMI 32, HRT", "agegrp": 5, "menopaus": 1, "bmi": 3, "agefirst": 1, "nrelbc": 0,
     "brstproc": 0, "hrt": 1, "surgmeno": 0},
]).set_index("name").reindex(columns=FEATURES).astype(float)
p_prof = model.predict_proba(profiles)[:, 1]
print(pd.DataFrame({"1-year risk per 1,000": p_prof * 1000,
                    "x age average": p_prof / profiles["agegrp"].map(age_avg).values}, index=profiles.index).round(2))

imp = pd.Series(model.get_booster().get_score(importance_type="total_gain")).reindex(FEATURES).fillna(0)
imp = imp / imp.sum()
fig, ax = plt.subplots(figsize=(8, 4.5))
imp.sort_values().plot.barh(ax=ax, color="#C2185B"); ax.set_title("XGBoost feature importance (share of total gain)")
plt.tight_layout(); plt.savefig(f"{OUT}/breast_risk_feature_importance.png", dpi=150); plt.show()
"""),
    ("markdown", r"""
## 6. Reference: XGBoost on the Wisconsin Diagnostic dataset

This is the dataset named in the scope document. It scores very well, but every input is a microscope measurement of cells
taken by a needle biopsy (radius, texture, concavity...). It answers "is this biopsied lump malignant?", not "what is
my risk?". That's why it is kept as a reference and the app uses the BCSC model.
"""),
    ("code", r"""
wisconsin_files = glob.glob(f"{INPUT}/**/data.csv", recursive=True)
if wisconsin_files:
    wis = pd.read_csv(wisconsin_files[0]).drop(columns=["id", "Unnamed: 32"], errors="ignore")
    Xw, yw = wis.drop(columns="diagnosis"), (wis["diagnosis"] == "M").astype(int)
else:   # the same data ships with scikit-learn (there 0 = malignant)
    data = load_breast_cancer(as_frame=True)
    Xw, yw = data.data, 1 - data.target

wis_model = XGBClassifier(n_estimators=300, max_depth=3, learning_rate=0.05, subsample=0.9, colsample_bytree=0.9,
                          eval_metric="logloss", random_state=SEED)
scores = cross_validate(wis_model, Xw, yw, cv=StratifiedKFold(5, shuffle=True, random_state=SEED),
                        scoring=["accuracy", "f1", "recall", "roc_auc"])
wisconsin_cv = {m: f"{scores['test_' + m].mean():.3f} ± {scores['test_' + m].std():.3f}"
                for m in ["accuracy", "f1", "recall", "roc_auc"]}
Xw_tr, Xw_te, yw_tr, yw_te = train_test_split(Xw, yw, test_size=0.2, stratify=yw, random_state=SEED)
wis_model.fit(Xw_tr, yw_tr)
pw = wis_model.predict_proba(Xw_te)[:, 1]
wisconsin_test = {"test_size": int(len(yw_te)), "accuracy": round(accuracy_score(yw_te, pw >= 0.5), 4),
                  "precision": round(precision_score(yw_te, pw >= 0.5), 4), "recall": round(recall_score(yw_te, pw >= 0.5), 4),
                  "f1": round(f1_score(yw_te, pw >= 0.5), 4), "roc_auc": round(roc_auc_score(yw_te, pw), 4)}
print("5-fold CV:", wisconsin_cv)
print("held-out 20%:", wisconsin_test)
print("top inputs:", list(pd.Series(wis_model.feature_importances_, index=Xw.columns).nlargest(5).index))
"""),
    ("markdown", "## 7. Export for the Femora backend"),
    ("code", r"""
model.save_model(f"{OUT}/breast_risk_xgb.json")

def to_builtin(o):
    return o.item() if hasattr(o, "item") else str(o)

with open(f"{OUT}/breast_risk_meta.json", "w") as f:
    json.dump({
        "features": FEATURES,
        "monotone_constraints": MONOTONE,
        "age_groups": {str(k): v for k, v in AGE_GROUPS.items()},
        "age_average_risk": {str(int(k)): float(v) for k, v in age_avg.items()},
        "relative_risk_bands": BANDS,
        "validation_metrics": val_metrics,
        "comparison": comparison.to_dict(orient="records"),
        "band_validation": band_table.reset_index().to_dict(orient="records"),
        "feature_importance": imp.sort_values(ascending=False).round(4).to_dict(),
        "dataset": {"name": "BCSC Risk Estimation Dataset (Barlow et al., JNCI 2006)", "file": os.path.basename(path),
                    "combinations": int(len(bcsc)), "mammograms": int(women), "cancers_1yr": int(cancers)},
        "wisconsin_reference": {
            "dataset": "Breast Cancer Wisconsin (Diagnostic), Wolberg et al. 1993 (n=569)",
            "cv": wisconsin_cv, "test": wisconsin_test,
            "note": "Inputs are cytology measurements from a biopsy, so it is not usable as a self-report questionnaire.",
        },
    }, f, indent=2, default=to_builtin)
print(sorted(os.listdir(OUT)))
"""),
]


# ---------------------------------------------------------------- Breast ultrasound + BUS-BRA (a copy of the v7 notebook, edited)
# A separate Kaggle notebook, so v7 stays untouched. Each edit must match exactly once, so a change to the v7 cells above
# can never silently skip an edit here.
def _edit(cells, old, new):
    hits = [i for i, (_, src) in enumerate(cells) if old in src]
    assert len(hits) == 1 and cells[hits[0]][1].count(old) == 1, f"edit must match exactly once: {old[:60]!r} ({len(hits)} cells)"
    i = hits[0]
    cells[i] = (cells[i][0], cells[i][1].replace(old, new))


BUSBRA_SPLIT_LOGIC = r"""
# ---- BUSI + BrEaST keep the exact train/val/test assignment of notebook v7, so v7's test set is unchanged.
# BUS-BRA is split by patient. All BUS-BRA test patients are unseen by the model, and come from a third hospital.
V7 = pd.read_csv(io.StringIO(V7_SPLIT_CSV))
v7_split = dict(zip(V7["source"] + "/" + V7["file"], V7["split"]))
old = df["source"].isin(["BUSI", "BrEaST"]).values
df["split"] = (df["source"] + "/" + df["path"].map(os.path.basename)).map(v7_split)
df = df[~(old & df["split"].isna().values)].reset_index(drop=True)   # v7 dropped these (conflicting near-duplicates)

bra = (df["source"] == "BUS-BRA").values
shared = df.groupby("group")["source"].transform(lambda s: bool((s == "BUS-BRA").any() and (s != "BUS-BRA").any()))
print(f"{int((shared.values & bra).sum())} BUS-BRA images are near-duplicates of BUSI/BrEaST images and are dropped")
df = df[~(shared.values & bra)].reset_index(drop=True)
bra = (df["source"] == "BUS-BRA").values

# One patient (both breasts) and any near-duplicate scans always stay together, in the split and in cross-validation
uf = {}
def ufind(a):
    uf.setdefault(a, a)
    while uf[a] != a:
        uf[a] = uf[uf[a]]
        a = uf[a]
    return a
for case, grp in zip(df.loc[bra, "case"], df.loc[bra, "group"]):
    uf[ufind(case)] = ufind(f"g{grp}")
df.loc[bra, "group"] = pd.factorize(pd.Series([ufind(c) for c in df.loc[bra, "case"]]))[0] + 10**6

bra_idx = np.where(bra)[0]
if SMOKE:
    df.loc[bra, "split"] = np.array(["test", "val", "train"])[np.arange(len(bra_idx)) % 3]
else:
    fold = np.zeros(len(bra_idx), int)
    for k, (_, part) in enumerate(StratifiedGroupKFold(n_splits=10, shuffle=True, random_state=SEED)
                                  .split(bra_idx, df["strata"].values[bra_idx], df["group"].values[bra_idx])):
        fold[part] = k
    df.loc[bra, "split"] = np.select([fold < 3, fold == 3], ["test", "val"], "train")   # 30% / 10% / 60% of patients
"""

BUSBRA_LOAD = r"""
# BUS-BRA (Kaggle mirror of Gómez-Flores et al., Medical Physics 2024): National Cancer Institute, Rio de Janeiro,
# 4 scanners, 1,875 biopsy-proven scans from 1,064 patients (benign / malignant only, no normal class).
bra_dir = os.path.dirname(glob.glob(f"{INPUT}/**/bus_data.csv", recursive=True)[0])
for r in pd.read_csv(f"{bra_dir}/bus_data.csv").itertuples():
    mask = f"{bra_dir}/Masks/mask_{r.ID[4:]}.png"
    rows.append({"path": f"{bra_dir}/Images/{r.ID}.png", "source": "BUS-BRA", "label": r.Pathology,
                 "masks": [mask] if os.path.exists(mask) else [], "case": f"bra{r.Case}", "device": r.Device})

df = pd.DataFrame(rows)"""

BUSBRA_EXTRA_METRICS = r"""
print(pd.DataFrame(per_source).T)

# Same images as v7's test set (BUSI + BrEaST), so this row is directly comparable with v7's published numbers
old_t = np.isin(sources[idx["test"]], ["BUSI", "BrEaST"])
test_v7_subset = {"test_size": int(old_t.sum()), **summarize(y_test[old_t], p_test[old_t], pred_test[old_t])}
test_busbra = {"test_size": int((~old_t).sum()), **summarize(y_test[~old_t], p_test[~old_t], pred_test[~old_t])}
per_device = {}
for d in sorted(set(devices[idx["test"]][~old_t])):
    m = devices[idx["test"]] == d
    try:
        per_device[d] = {"images": int(m.sum()), **summarize(y_test[m], p_test[m], pred_test[m])}
    except ValueError as e:
        print(d, e)
print("v7-comparable test subset:", test_v7_subset)
print("BUS-BRA held-out patients:", test_busbra)
display(pd.DataFrame(per_device).T)"""

BREAST_ULTRASOUND_BUSBRA = list(BREAST_ULTRASOUND)
_edit(BREAST_ULTRASOUND_BUSBRA, "# Femora — Breast Ultrasound Classifier (ResNet50)", """# Femora — Breast Ultrasound Classifier (ResNet50) + BUS-BRA

> **A separate notebook from v7.** It is v7's pipeline with a third hospital added (BUS-BRA: 1,875 scans, 4 scanners, Brazil).
> BUSI and BrEaST keep **exactly v7's train / validation / test split**, so the v7 test images are unchanged and the
> numbers are comparable. BUS-BRA is split **by patient**: ~60% train, ~10% validation, ~30% held out as a test set the
> model never trains on. v7 scored 77% sensitivity / 58% specificity / AUC 0.73 on all of BUS-BRA before seeing it.""")
_edit(BREAST_ULTRASOUND_BUSBRA, "**Datasets (combined)**", """**Datasets (combined)**
- **BUS-BRA**: 1,875 scans from 1,064 patients, 4 scanners, National Cancer Institute, Rio de Janeiro (Gómez-Flores et al.,
  Medical Physics 2024). Biopsy-proven benign / malignant only (no normal class). Cite the paper when using it.""")
_edit(BREAST_ULTRASOUND_BUSBRA, "import copy, glob, json, os, random, shutil, urllib.request, zipfile, warnings",
      "import copy, glob, io, json, os, random, shutil, urllib.request, zipfile, warnings")
_edit(BREAST_ULTRASOUND_BUSBRA, 'SOURCES = ["BUSI", "BrEaST"]', 'SOURCES = ["BUSI", "BrEaST", "BUS-BRA"]')
_edit(BREAST_ULTRASOUND_BUSBRA, "## 1. Load both datasets", "## 1. Load the three datasets")
_edit(BREAST_ULTRASOUND_BUSBRA, "\ndf = pd.DataFrame(rows)", BUSBRA_LOAD)
_edit(BREAST_ULTRASOUND_BUSBRA, "The split is stratified by source × class: 5/7 train, 1/7 validation, 1/7 test.",
      "BUSI and BrEaST keep v7's exact split. BUS-BRA is split by patient (both breasts of a patient stay together).")
_edit(BREAST_ULTRASOUND_BUSBRA, '''folds = np.zeros(len(df), int)
for k, (_, test_part) in enumerate(StratifiedGroupKFold(n_splits=7, shuffle=True, random_state=SEED)
                                   .split(df, df["strata"], df["group"])):
    folds[test_part] = k
df["split"] = np.select([folds == 0, folds == 1], ["test", "val"], "train")''', BUSBRA_SPLIT_LOGIC.strip("\n"))
_edit(BREAST_ULTRASOUND_BUSBRA, 'sources = df["source"].values', 'sources = df["source"].values\ndevices = df["device"].fillna("").values')
_edit(BREAST_ULTRASOUND_BUSBRA, "\nprint(pd.DataFrame(per_source).T)", BUSBRA_EXTRA_METRICS)
_edit(BREAST_ULTRASOUND_BUSBRA, 'for src, colour in [("BUSI", "#C2185B"), ("BrEaST", "#6C2D7E")]:',
      'for src, colour in [("BUSI", "#C2185B"), ("BrEaST", "#6C2D7E"), ("BUS-BRA", "#00897B")]:')
_edit(BREAST_ULTRASOUND_BUSBRA, '[["file", "source", "label", "group", "split"]]', '[["file", "source", "label", "group", "split", "case", "device"]]')
_edit(BREAST_ULTRASOUND_BUSBRA, '        "per_source_test": per_source,',
      '        "per_source_test": per_source,\n        "test_metrics_v7_subset": test_v7_subset,\n        "test_metrics_busbra": test_busbra,\n        "per_device_test": per_device,')
_edit(BREAST_ULTRASOUND_BUSBRA, '"BrEaST-Lesions-USG (Pawłowska et al., 2024, TCIA, CC BY 4.0)"],',
      '"BrEaST-Lesions-USG (Pawłowska et al., 2024, TCIA, CC BY 4.0)",\n                    "BUS-BRA (Gómez-Flores et al., Medical Physics 2024)"],')
_edit(BREAST_ULTRASOUND_BUSBRA, '        "classes": CLASSES,', '        "version": "busbra (v7 pipeline + BUS-BRA)",\n        "classes": CLASSES,')
# the v7 split ships inside the notebook, since a Kaggle notebook is a single file
BREAST_ULTRASOUND_BUSBRA.insert(3, ("code", "V7_SPLIT_CSV = '''" + (Path(__file__).parent / "v7_split.csv").read_text(encoding="utf-8") + "'''"))


if __name__ == "__main__":
    write("breast_ultrasound_busbra", "femora-breast-ultrasound-resnet50-busbra", "Femora Breast Ultrasound ResNet50 BUSBRA",
          ["aryashah2k/breast-ultrasound-images-dataset", "orvile/bus-bra-a-breast-ultrasound-dataset", "prasunroy/natural-images",
           "paultimothymooney/chest-xray-pneumonia", "navoneel/brain-mri-images-for-brain-tumor-detection"],
          BREAST_ULTRASOUND_BUSBRA, gpu=True)
    write("pcos", "femora-pcos-risk-xgboost", "Femora PCOS Risk XGBoost",
          ["prasoonkottarathil/polycystic-ovary-syndrome-pcos"], PCOS)
    write("breast_ultrasound", "femora-breast-ultrasound-resnet50", "Femora Breast Ultrasound ResNet50",
          ["aryashah2k/breast-ultrasound-images-dataset", "prasunroy/natural-images",
           "paultimothymooney/chest-xray-pneumonia", "navoneel/brain-mri-images-for-brain-tumor-detection"],
          BREAST_ULTRASOUND, gpu=True)
    write("breast_risk", "femora-breast-risk-xgboost", "Femora Breast Risk XGBoost",
          ["ammad0/bcsc-risk-estimation", "uciml/breast-cancer-wisconsin-data"], BREAST_RISK)
    print("built", ROOT)
