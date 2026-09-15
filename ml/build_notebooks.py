"""Builds the Kaggle notebooks in ml/notebooks/ from plain Python cells.

Run: ml/.venv/bin/python ml/build_notebooks.py
Then push: ml/.venv/bin/kaggle kernels push -p ml/notebooks/pcos
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
    (out / "notebook.ipynb").write_text(json.dumps(notebook(cells), indent=1))
    (out / "kernel-metadata.json").write_text(json.dumps({
        "id": f"ammad0/{slug}",
        "title": title,
        "code_file": "notebook.ipynb",
        "language": "python",
        "kernel_type": "notebook",
        "is_private": True,
        "enable_gpu": gpu,
        "enable_internet": True,
        "dataset_sources": datasets,
        "competition_sources": [],
        "kernel_sources": [],
    }, indent=2))


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

if __name__ == "__main__":
    write("pcos", "femora-pcos-risk-xgboost", "Femora PCOS Risk XGBoost",
          ["prasoonkottarathil/polycystic-ovary-syndrome-pcos"], PCOS)
    print("built", ROOT)
