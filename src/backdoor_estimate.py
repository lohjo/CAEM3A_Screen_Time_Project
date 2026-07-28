"""
Backdoor-adjusted total effect of AI-use intensity (X) on schoolwork hours (Y).

Dataset : data/study_habits_ai_proportional_survey_dataset/survey_cleaned_english.csv
DAG     : W->X, W->Y, A->X, A->Y, L->X, X->M1, M1->Y, X->M2, M2->Y
Z       : {W, A}      valid  -- no descendant of X; blocks both backdoor forks
Z'      : {W, A, M1}  INVALID -- M1 is a descendant of X; refit as falsification

Run from the repo root:  python backdoor_estimate.py
"""
import numpy as np
import pandas as pd
import statsmodels.formula.api as smf
from statsmodels.miscmodels.ordinal_model import OrderedModel
from scipy import stats

CSV = "data/study_habits_ai_proportional_survey_dataset/survey_cleaned_english.csv"

FREQ = {"Never": 1, "Rarely": 2, "Occasionally": 3, "Almost always": 4, "Always": 5}
Y_ORD = {"0-1": 0, "1-2": 1, "2-3": 2, "3-4": 3, "4-5": 4, "More than 5": 5}
Y_MID = {"0-1": 0.5, "1-2": 1.5, "2-3": 2.5, "3-4": 3.5, "4-5": 4.5, "More than 5": 5.5}
AGREE = {"Definitely no": 1, "Probably no": 2, "Neutral": 3,
         "Probably yes": 4, "Definitely yes": 5}

raw = pd.read_csv(CSV)
d = pd.DataFrame({
    "X":  raw["ai_use_frequency_for_study"].map(FREQ),           # treatment
    "Yo": raw["independent_study_time"].map(Y_ORD),              # outcome, 6 ordered bands
    "Yh": raw["independent_study_time"].map(Y_MID),              # outcome, band midpoints (h)
    "W":  (raw["current_university_condition"] == "Study and work").astype(float),
    "A1": raw["cumulative_gpa_papa"],                            # prior ability
    "A2": raw["procrastination_frequency"].map(FREQ),            # trait procrastination
    "A3": raw["academic_program"],                               # course difficulty
    "L":  raw["prompt_engineering_knowledge"],                   # mapped, deliberately NOT adjusted
    "M1": raw["ai_helped_understand_topics"].map(AGREE),         # mediator (falsification only)
})
n_raw = len(d)
d = d.dropna(subset=["X", "Yo", "Yh", "W", "A1", "A2", "A3"])
print(f"rows read = {n_raw}   usable n = {len(d)}   (complete cases on X, Y, W, A)")

F_Z = "X + W + A1 + A2 + C(A3)"          # Z  = {W, A}
F_ZP = F_Z + " + M1"                     # Z' = {W, A, M1}


def ordinal_logit(df, rhs, label):
    """Proportional-odds logit on the 6 ordered bands. MLE (observed-information) SEs."""
    des = smf.ols("Yo ~ " + rhs, data=df)
    keep = [i for i, nm in enumerate(des.exog_names) if nm != "Intercept"]
    names = [des.exog_names[i] for i in keep]
    m = OrderedModel(df["Yo"].to_numpy(), des.exog[:, keep], distr="logit").fit(
        method="bfgs", disp=0)
    j = names.index("X")
    b, se = m.params[j], m.bse[j]
    lo, hi = m.conf_int()[j]
    z = b / se
    p = 2 * stats.norm.sf(abs(z))
    print(f"\n[{label}] ordinal logit   n={len(df)}  k={len(names)}+5 cutpoints  "
          f"loglik={m.llf:.6f}")
    print(f"    beta_X = {b:.6f}  SE = {se:.6f}  95% CI = [{lo:.6f}, {hi:.6f}]")
    print(f"    z = {z:.6f}   p = {p:.6f}   odds ratio = {np.exp(b):.6f}")
    return b


def ols_hc3(df, rhs, label, y="Yh"):
    m = smf.ols(f"{y} ~ " + rhs, data=df).fit(cov_type="HC3")
    lo, hi = m.conf_int().loc["X"]
    print(f"\n[{label}] OLS on band midpoints, HC3   n={int(m.nobs)}  R2={m.rsquared:.6f}")
    print(f"    beta_X = {m.params['X']:.6f} h  SE = {m.bse['X']:.6f}  "
          f"95% CI = [{lo:.6f}, {hi:.6f}]")
    print(f"    t = {m.tvalues['X']:.6f}   p = {m.pvalues['X']:.6f}")
    return m


print("\n" + "=" * 74)
print("PRIMARY   Z = {W, A}   (proven valid backdoor adjustment set)")
print("=" * 74)
bZ = ordinal_logit(d, F_Z, "Z")
mZ = ols_hc3(d, F_Z, "Z")

print("\n" + "=" * 74)
print("FALSIFICATION   Z' = {W, A, M1}   (INVALID: M1 is a descendant of X)")
print("=" * 74)
bZP = ordinal_logit(d, F_ZP, "Z'")
mZP = ols_hc3(d, F_ZP, "Z'")

print("\n" + "=" * 74)
print("MEDIATOR-INCLUSION SHIFT  (Z' minus Z)")
print("=" * 74)
print(f"    ordinal logit : {bZP - bZ:+.6f} log-odds "
      f"({100 * (bZP - bZ) / abs(bZ):+.4f}% of |beta_Z|)")
print(f"    OLS (hours)   : {mZP.params['X'] - mZ.params['X']:+.6f} h "
      f"({100 * (mZP.params['X'] - mZ.params['X']) / abs(mZ.params['X']):+.4f}% of |beta_Z|)")

print("\n" + "=" * 74)
print("SENSITIVITY / REFERENCE  (not the estimand)")
print("=" * 74)
# top band is open-ended and holds 51.3% of the sample: vary its midpoint
for top in (5.5, 6.5, 7.5):
    d2 = d.assign(Yt=d["Yh"].where(d["Yo"] != 5, top))
    m = smf.ols("Yt ~ " + F_Z, data=d2).fit(cov_type="HC3")
    print(f"    top band coded {top} h -> beta_X = {m.params['X']:+.6f} h  "
          f"SE = {m.bse['X']:.6f}  p = {m.pvalues['X']:.6f}")
nv = smf.ols("Yh ~ X", data=d).fit(cov_type="HC3")
print(f"    naive unadjusted OLS      -> beta_X = {nv.params['X']:+.6f} h  "
      f"SE = {nv.bse['X']:.6f}  p = {nv.pvalues['X']:.6f}")
print(f"    share in open top band    -> {(d['Yo'] == 5).mean():.6f}")
