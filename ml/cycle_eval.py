"""Cycle prediction study on the Fehring data (Marquette University, 159 women, 1,665 cycles).

Question: how well can the next cycle length, period length and ovulation day be predicted, from day one (no history)
and as a woman logs more cycles? Every prediction for a woman uses only her own earlier cycles and models fitted on OTHER
women (5-fold cross-validation grouped by woman), so nothing about the test woman leaks into training.

Run:  ml/.venv/Scripts/python.exe ml/cycle_eval.py D:/dl/cycle/fed_cycle.csv
"""
import json
import sys
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import GroupKFold

SRC = sys.argv[1] if len(sys.argv) > 1 else "D:/dl/cycle/fed_cycle.csv"
OUT = Path(__file__).parent / "output" / "cycle"
OUT.mkdir(parents=True, exist_ok=True)
SEED = 42

d = pd.read_csv(SRC)
for c in ["LengthofCycle", "EstimatedDayofOvulation", "LengthofLutealPhase", "LengthofMenses", "Age", "BMI", "CycleNumber"]:
    d[c] = pd.to_numeric(d[c].astype(str).str.strip().replace({"": np.nan}), errors="coerce")
d = d.sort_values(["ClientID", "CycleNumber"]).reset_index(drop=True)
# Age and BMI are recorded once per woman: spread them over all her cycles
for c in ("Age", "BMI"):
    d[c] = d.groupby("ClientID")[c].transform(lambda s: s.dropna().iloc[0] if s.notna().any() else np.nan)

WOMEN = d["ClientID"].unique()
POP_LUTEAL = float(d["LengthofLutealPhase"].median())


def build_rows(df: pd.DataFrame) -> pd.DataFrame:
    """One row per (woman, cycle t): features from cycles before t, targets from cycle t."""
    rows = []
    for cid, g in df.groupby("ClientID", sort=False):
        L = g["LengthofCycle"].to_numpy(float)
        M = g["LengthofMenses"].to_numpy(float)
        U = g["LengthofLutealPhase"].to_numpy(float)
        O = g["EstimatedDayofOvulation"].to_numpy(float)
        for t in range(len(g)):
            prev = L[:t]
            pm = M[:t][~np.isnan(M[:t])]
            pu = U[:t][~np.isnan(U[:t])]
            rows.append(dict(
                cid=cid, t=t, n_prev=t, y_len=L[t], y_menses=M[t], y_ov=O[t], y_lut=U[t],
                last1=prev[-1] if t >= 1 else np.nan, last2=prev[-2] if t >= 2 else np.nan, last3=prev[-3] if t >= 3 else np.nan,
                mean_prev=prev.mean() if t >= 1 else np.nan, sd_prev=prev.std(ddof=1) if t >= 2 else np.nan,
                min_prev=prev.min() if t >= 1 else np.nan, max_prev=prev.max() if t >= 1 else np.nan,
                menses_prev=pm.mean() if len(pm) else np.nan, luteal_prev=pu.mean() if len(pu) else np.nan,
                age=g["Age"].iloc[0], bmi=g["BMI"].iloc[0],
                prev_seq=list(prev[-6:]),
            ))
    return pd.DataFrame(rows)


R = build_rows(d)
R = R[R["y_len"].notna()].reset_index(drop=True)


def ewma(seq, alpha=0.4):
    if not len(seq):
        return np.nan
    v = seq[0]
    for x in seq[1:]:
        v = alpha * x + (1 - alpha) * v
    return v


def shrink(mean_user, n, mu_pop, tau):
    return np.where(n > 0, (n * np.nan_to_num(mean_user) + tau * mu_pop) / (n + tau), mu_pop)


def fit_tau(train_women):
    """Empirical-Bayes weight: how many cycles of her own history equal one 'population' observation."""
    g = d[d["ClientID"].isin(train_women)].groupby("ClientID")["LengthofCycle"]
    var_w = g.var(ddof=1).mean()
    n_bar = g.size().mean()
    var_b = max(g.mean().var(ddof=1) - var_w / n_bar, 1e-6)
    return float(var_w / var_b), float(var_w), float(var_b)


FEATS = ["n_prev", "last1", "last2", "last3", "mean_prev", "sd_prev", "min_prev", "max_prev", "menses_prev", "luteal_prev", "age", "bmi"]


def rf_matrix(X, med):
    Z = X[FEATS].copy()
    Z["age_missing"] = Z["age"].isna().astype(float)
    Z["bmi_missing"] = Z["bmi"].isna().astype(float)
    for c in FEATS:
        Z[c] = Z[c].fillna(med[c])
    return Z


preds = {k: np.full(len(R), np.nan) for k in
         ["pop_mean", "pop_median", "last", "user_mean", "user_ewma", "shrink", "rf_all", "rf_day1", "menses_pop", "menses_user", "menses_shrink", "menses_rf",
          "ov_day14", "ov_len_minus_pop", "ov_len_minus_user", "ov_rf"]}
folds = GroupKFold(n_splits=5)
taus = []
for tr_idx, te_idx in folds.split(R, groups=R["cid"]):
    tr, te = R.iloc[tr_idx], R.iloc[te_idx]
    train_women = tr["cid"].unique()
    mu = tr["y_len"].mean()
    med_len = tr["y_len"].median()
    tau, var_w, var_b = fit_tau(train_women)
    taus.append(tau)
    n = te["n_prev"].to_numpy(float)

    preds["pop_mean"][te_idx] = mu
    preds["pop_median"][te_idx] = med_len
    preds["last"][te_idx] = np.where(n > 0, te["last1"].fillna(mu), mu)
    preds["user_mean"][te_idx] = np.where(n > 0, te["mean_prev"].fillna(mu), mu)
    preds["user_ewma"][te_idx] = [ewma(s) if len(s) else mu for s in te["prev_seq"]]
    preds["shrink"][te_idx] = shrink(te["mean_prev"].to_numpy(float), n, mu, tau)

    med = tr[FEATS].median()
    rf = RandomForestRegressor(n_estimators=300, min_samples_leaf=5, max_features=0.6, random_state=SEED, n_jobs=1)
    rf.fit(rf_matrix(tr, med), tr["y_len"])
    preds["rf_all"][te_idx] = rf.predict(rf_matrix(te, med))
    # "Day one" model: only what a new user can tell us (age, BMI), no history
    d1 = ["age", "bmi"]
    tr1, te1 = tr[d1].copy(), te[d1].copy()
    for X in (tr1, te1):
        X["age_missing"] = X["age"].isna().astype(float); X["bmi_missing"] = X["bmi"].isna().astype(float)
        X["age"] = X["age"].fillna(tr["age"].median()); X["bmi"] = X["bmi"].fillna(tr["bmi"].median())
    rf1 = RandomForestRegressor(n_estimators=300, min_samples_leaf=15, random_state=SEED, n_jobs=1).fit(tr1, tr["y_len"])
    preds["rf_day1"][te_idx] = rf1.predict(te1)

    # Period length
    trm = tr[tr["y_menses"].notna()]
    mm = trm["y_menses"].mean()
    preds["menses_pop"][te_idx] = mm
    preds["menses_user"][te_idx] = np.where(n > 0, te["menses_prev"].fillna(mm), mm)
    # shrink towards the population with a fixed weight of 2 cycles (menses varies little within a woman)
    preds["menses_shrink"][te_idx] = np.where(n > 0, (n * te["menses_prev"].fillna(mm) + 2 * mm) / (n + 2), mm)
    rfm = RandomForestRegressor(n_estimators=300, min_samples_leaf=5, max_features=0.6, random_state=SEED, n_jobs=1)
    rfm.fit(rf_matrix(trm, med), trm["y_menses"])
    preds["menses_rf"][te_idx] = rfm.predict(rf_matrix(te, med))

    # Ovulation day (counted from the first day of the period)
    lut_pop = tr["y_lut"].median()
    preds["ov_day14"][te_idx] = 14.0
    preds["ov_len_minus_pop"][te_idx] = preds["shrink"][te_idx] - lut_pop
    lut_user = np.where(n > 0, te["luteal_prev"].fillna(lut_pop), lut_pop)
    lut_shr = (n * lut_user + 3 * lut_pop) / (n + 3)
    preds["ov_len_minus_user"][te_idx] = preds["shrink"][te_idx] - lut_shr
    tro = tr[tr["y_ov"].notna()]
    rfo = RandomForestRegressor(n_estimators=300, min_samples_leaf=5, max_features=0.6, random_state=SEED, n_jobs=1)
    rfo.fit(rf_matrix(tro, med), tro["y_ov"])
    preds["ov_rf"][te_idx] = rfo.predict(rf_matrix(te, med))


def metrics(y, p, mask=None):
    ok = ~np.isnan(y) & ~np.isnan(p)
    if mask is not None:
        ok &= mask
    e = np.abs(y[ok] - p[ok])
    er = np.abs(y[ok] - np.round(p[ok]))  # the app shows whole days, so "within k days" is scored on the rounded prediction
    return dict(n=int(ok.sum()), mae=round(float(e.mean()), 2), within2=round(float((er <= 2).mean()), 3), within3=round(float((er <= 3).mean()), 3),
                within5=round(float((er <= 5).mean()), 3))


def boot_ci(y, p, women, stat, n=1000):
    rng = np.random.default_rng(SEED)
    uw = np.unique(women)
    idx = {w: np.where(women == w)[0] for w in uw}
    vals = []
    for _ in range(n):
        pick = np.concatenate([idx[w] for w in rng.choice(uw, len(uw))])
        vals.append(stat(y[pick], p[pick]))
    return [round(float(np.percentile(vals, 2.5)), 3), round(float(np.percentile(vals, 97.5)), 3)]


def w3(y, p):
    ok = ~np.isnan(y) & ~np.isnan(p)
    return float((np.abs(y[ok] - np.round(p[ok])) <= 3).mean())


y = R["y_len"].to_numpy(float)
n_prev = R["n_prev"].to_numpy()
women = R["cid"].to_numpy()
buckets = {"day one (0 cycles)": n_prev == 0, "1 cycle": n_prev == 1, "2 cycles": n_prev == 2, "3 to 5 cycles": (n_prev >= 3) & (n_prev <= 5),
           "6 or more": n_prev >= 6, "all": n_prev >= 0, "3 or more": n_prev >= 3}
res = {"data": dict(women=int(len(WOMEN)), cycles=int(len(d)), predictions=int(len(R)), cycle_length_mean=round(float(d.LengthofCycle.mean()), 2),
                    cycle_length_sd=round(float(d.LengthofCycle.std()), 2)), "tau_mean": round(float(np.mean(taus)), 2), "length": {}, "menses": {}, "ovulation": {}}
for b, m in buckets.items():
    res["length"][b] = {k: metrics(y, preds[k], m) for k in ["pop_mean", "pop_median", "last", "user_mean", "user_ewma", "shrink", "rf_all", "rf_day1"]}
    res["menses"][b] = {k: metrics(R["y_menses"].to_numpy(float), preds[k], m) for k in ["menses_pop", "menses_user", "menses_shrink", "menses_rf"]}
    res["ovulation"][b] = {k: metrics(R["y_ov"].to_numpy(float), preds[k], m) for k in ["ov_day14", "ov_len_minus_pop", "ov_len_minus_user", "ov_rf"]}
for name in ["pop_mean", "shrink", "rf_all", "user_mean"]:
    m = buckets["3 or more"]
    res.setdefault("ci_within3_3plus", {})[name] = boot_ci(y[m], preds[name][m], women[m], w3)
m0 = buckets["day one (0 cycles)"]
res["ci_within3_day1"] = {name: boot_ci(y[m0], preds[name][m0], women[m0], w3) for name in ["pop_mean", "rf_day1"]}

# What share of cycles is 'unpredictable' (irregular) - context for the ceiling
res["irregular_share"] = dict(outside_21_35=round(float(((d.LengthofCycle < 21) | (d.LengthofCycle > 35)).mean()), 3),
                              jump_over_7_days=round(float((d.groupby("ClientID")["LengthofCycle"].diff().abs() > 7).mean()), 3))
res["population"] = dict(length_mean=round(float(R.y_len.mean()), 2), menses_mean=round(float(d.LengthofMenses.mean()), 2),
                         luteal_median=POP_LUTEAL, luteal_mean=round(float(d.LengthofLutealPhase.mean()), 2),
                         ovulation_day_mean=round(float(d.EstimatedDayofOvulation.mean()), 2))
(OUT / "cycle_eval.json").write_text(json.dumps(res, indent=1))

print("cycles:", len(d), "women:", len(WOMEN), "| predictions:", len(R), "| tau (own cycles worth one population obs): %.2f" % np.mean(taus))
print("\nNEXT CYCLE LENGTH  (MAE days | within 2 | within 3 days)")
for b in ["day one (0 cycles)", "1 cycle", "2 cycles", "3 to 5 cycles", "6 or more", "3 or more", "all"]:
    print(f"-- {b} (n={res['length'][b]['pop_mean']['n']})")
    for k, v in res["length"][b].items():
        print(f"   {k:11s} {v['mae']:5.2f} | {v['within2']:.1%} | {v['within3']:.1%}")
print("\nbootstrap 95% CI, within 3 days, 3+ cycles:", res["ci_within3_3plus"])
print("bootstrap 95% CI, within 3 days, day one:", res["ci_within3_day1"])
print("\nPERIOD LENGTH (MAE | within 2)")
for b in ["day one (0 cycles)", "3 or more", "all"]:
    print("--", b, {k: (v["mae"], v["within2"]) for k, v in res["menses"][b].items()})
print("\nOVULATION DAY (MAE | within 2 | within 3)")
for b in ["day one (0 cycles)", "3 or more", "all"]:
    print("--", b, {k: (v["mae"], v["within2"], v["within3"]) for k, v in res["ovulation"][b].items()})
print("\nirregular share:", res["irregular_share"])


# ---------------------------------------------------------------- prediction window and exported constants
var_w_all = float(d.groupby("ClientID")["LengthofCycle"].var(ddof=1).mean())
K0 = 3  # her own spread counts like this many cycles of population spread


def window_half(n_prev_arr, sd_prev_arr, z):
    sd_own = np.nan_to_num(sd_prev_arr, nan=np.sqrt(var_w_all))
    sd_est = np.sqrt((np.maximum(n_prev_arr - 1, 0) * sd_own ** 2 + K0 * var_w_all) / (np.maximum(n_prev_arr - 1, 0) + K0))
    return np.maximum(np.ceil(z * sd_est), 2), sd_est


print("\nPREDICTION WINDOW (share of cycles whose real start falls inside predicted +- h days)")
win = {}
for z in (1.0, 1.28, 1.64):
    h, _ = window_half(R["n_prev"].to_numpy(float), R["sd_prev"].to_numpy(float), z)
    inside = np.abs(y - np.round(preds["shrink"])) <= h
    win[str(z)] = {b: dict(coverage=round(float(inside[m].mean()), 3), mean_half_width=round(float(h[m].mean()), 2)) for b, m in
                   {"day one": n_prev == 0, "1 to 2 cycles": (n_prev >= 1) & (n_prev <= 2), "3 or more": n_prev >= 3, "all": n_prev >= 0}.items()}
    print(f"z={z}:", {b: (v["coverage"], v["mean_half_width"]) for b, v in win[str(z)].items()})
res["window"] = win

# Constants the phone uses (fitted on all women)
mu_all = float(R["y_len"].mean())
g_all = d.groupby("ClientID")["LengthofCycle"]
tau_all = float(var_w_all / max(g_all.mean().var(ddof=1) - var_w_all / g_all.size().mean(), 1e-6))
params = dict(
    source="Fehring et al. 2013, Marquette University, 159 women, 1665 cycles",
    length_mean=round(mu_all, 2), tau=round(tau_all, 2), within_sd=round(float(np.sqrt(var_w_all)), 2), sd_weight=K0,
    menses_mean=round(float(d.LengthofMenses.mean()), 2), menses_weight=2,
    luteal_median=POP_LUTEAL, luteal_mean=round(float(d.LengthofLutealPhase.mean()), 2),
    window_z=1.28,
)
res["params"] = params
(OUT / "cycle_eval.json").write_text(json.dumps(res, indent=1))
(OUT / "cycle_params.json").write_text(json.dumps(params, indent=1))
(Path(__file__).parent / "cycle_results.json").write_text(json.dumps(res, indent=1))  # small, committed: the report reads it
print("\nphone constants:", params)

# Dart file with the same constants, so the app and this study cannot drift apart
DART = Path(__file__).parent.parent / "lib" / "models" / "cycle_params.dart"
DART.write_text(f"""// GENERATED by ml/cycle_eval.py. Do not edit by hand: rerun the script.
// Source: {params['source']}.

class CycleParams {{
  final double lengthMean; // average cycle length of all women, days
  final double tau; // her own cycles are worth this many population cycles when averaging
  final double withinSd; // typical spread of one woman's cycle length, days
  final int sdWeight; // her own spread counts like this many cycles of population spread
  final double mensesMean; // average period length, days
  final int mensesWeight; // her own period lengths count like this many population periods
  final int lutealDays; // days from ovulation to the next period (median)
  final double windowZ; // width of the 'expected between' window, in standard deviations

  const CycleParams({{
    required this.lengthMean,
    required this.tau,
    required this.withinSd,
    required this.sdWeight,
    required this.mensesMean,
    required this.mensesWeight,
    required this.lutealDays,
    required this.windowZ,
  }});
}}

const kCycleParams = CycleParams(
  lengthMean: {params['length_mean']},
  tau: {params['tau']},
  withinSd: {params['within_sd']},
  sdWeight: {params['sd_weight']},
  mensesMean: {params['menses_mean']},
  mensesWeight: {params['menses_weight']},
  lutealDays: {int(params['luteal_median'])},
  windowZ: {params['window_z']},
);
""", encoding="utf-8")
print("wrote", DART)
