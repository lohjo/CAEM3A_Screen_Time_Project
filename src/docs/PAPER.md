# 1. Claim 1 — proof and disproof



**Graph.** Nodes {X, Y, W, A, L, M1, M2}; edges W→X, W→Y, A→X, A→Y, L→X, X→M1, M1→Y, X→M2, M2→Y.



**Descendant set.** de(X) = {M1, M2, Y}. Computed by forward reachability from X: X→M1→Y, X→M2→Y. W, A, L have no incoming edges at all, so none can be a descendant of anything.



**Exhaustive path enumeration.** The skeleton has adjacency X–{W, A, L, M1, M2} and Y–{W, A, M1, M2}. W, A, M1, M2 each have degree 2 with neighbours exactly {X, Y}; L has degree 1 (neighbour X only). Therefore every simple X–Y path has length 2, and no path can route through L (it is a dead end — any walk entering L must exit via X, which is already used). This yields exactly **four** paths, and the enumeration below is complete by construction, not by sampling:



| # | Path | Arrow into X? (back-door) | Blocked by Z = {W, A}? | Why | Blocked by Z′ = {W, A, M1}? | Why |

|---|---|---|---|---|---|---|

| 1 | X ← W → Y | **YES** | **YES** | fork at W, W ∈ Z | YES | fork at W, W ∈ Z′ |

| 2 | X ← A → Y | **YES** | **YES** | fork at A, A ∈ Z | YES | fork at A, A ∈ Z′ |

| 3 | X → M1 → Y | no (causal) | NO — left open | chain at M1, M1 ∉ Z | **YES** | chain at M1, M1 ∈ Z′ |

| 4 | X → M2 → Y | no (causal) | NO — left open | chain at M2, M2 ∉ Z | NO | chain at M2, M2 ∉ Z′ |



**Verdict for Z = {W, A}: SATISFIES the back-door criterion.**



- Condition (i), applied element-by-element: W ∉ de(X) = {M1, M2, Y} ✓; A ∉ de(X) ✓. Neither is reached by any directed path from X.

- Condition (ii): the back-door paths are exactly {1, 2}. Path 1 is a fork with W ∈ Z → blocked. Path 2 is a fork with A ∈ Z → blocked. No path remains.

- No element of Z is a collider on any X–Y path, so conditioning opens nothing.

- Both causal paths (3, 4) remain open, so the X-coefficient carries the **total** effect — efficiency and procrastination channels summed.



**Verdict for Z′ = {W, A, M1}: DOES NOT SATISFY the back-door criterion — fails condition (i).**



The disproof is immediate and does not depend on path-blocking: the edge X→M1 places M1 ∈ de(X), and condition (i) requires that no node in Z be a descendant of X. Note that Z′ still satisfies condition (ii) — all back-door paths are blocked — which is exactly why the failure must be diagnosed via (i). The damage is visible in row 3: M1 ∈ Z′ blocks the causal chain X→M1→Y, so the X-coefficient under Z′ estimates only the residual effect flowing through M2, not the total effect. It is a mediator, not a confounder.



**§3(a) — is L back-door-relevant?** No. L's only edge is L→X, giving it degree 1 in the skeleton. Every walk from X into L terminates there; L lies on **no path** between X and Y, hence on no back-door path. Z = {W, A} therefore blocks all back-door paths whether or not L is adjoined, and omitting L preserves validity. Adding L is not *invalid* (L ∉ de(X), and L is not a collider on any X–Y path — verified: Z ∪ {L} also returns SATISFIES), but it is inadvisable: L is instrument-like, affecting X with no path to Y except through X, and the attached paper §4.5 warns that including instruments "can amplify bias from unmeasured confounding."



Omitting L **fails** under exactly one hidden-confounding structure: if the true graph contains L→Y (device access or AI literacy affecting schoolwork hours other than via AI use) or a latent U with L ← U → Y, then X ← L → Y (resp. X ← L ← U → Y) becomes an open back-door path and Z = {W, A} is insufficient. Verified computationally: adding the edge L→Y to the graph makes the enumeration return 5 paths, with X ← L → Y back-door and unblocked, verdict DOES NOT SATISFY. So the validity of omitting L rests on an exclusion restriction: **L influences Y only through X.**



**§3(b) — invariance under refinement of A.** Replace A by A₁…A_k = {ability, motivation, trait-procrastination, course difficulty}, each with edges Aᵢ→X and Aᵢ→Y, no edges among themselves, no other edges. Proof, not analogy:



1. *Path structure.* Each Aᵢ has degree 2 with neighbours exactly {X, Y} — the same local structure A had. Every simple X–Y path is therefore still length 2, and the path set is {X ← W → Y} ∪ {X ← Aᵢ → Y}ᵢ₌₁..k ∪ {X → M1 → Y, X → M2 → Y}, i.e. k + 3 paths (7 for k = 4). No new path *shape* is introduced; the single fork through A is replaced by k parallel forks.

2. *Condition (i).* de(X) = {M1, M2, Y} is unchanged, since the refinement touches no edge incident to M1, M2, or Y. Each Aᵢ has no incoming edges, so Aᵢ ∉ de(X). W ∉ de(X). ✓

3. *Condition (ii).* The back-door paths are the k + 1 forks. Each is blocked at its middle node, all of which lie in Z_ref = {W, A₁…A_k}. ✓



Hence Z_ref satisfies the criterion, and the refinement is **invariant**. The invariance is conditional, not free: omitting even one sub-node leaves that fork unblocked and breaks the criterion (verified — dropping A_difficulty yields verdict DOES NOT SATISFY on path X ← A_difficulty → Y). The invariance also fails if the refinement introduces edges among the sub-nodes that create a collider, or if a purported sub-node is in fact post-treatment — which is a live hazard for the trait-procrastination sub-node, since procrastination also appears in this DAG as M2. The proof licenses the refinement graphically; it says nothing about numerical equality of estimates.



---



# 2. Attachment reconciliation



**Paper — available and read.** *The Backdoor Criterion in Causal Inference and Its Applications to Machine Learning: Toward Confounder-Aware Pipelines for Survey-Based AI Usage Data*, John Ray Loh, Ngee Ann Polytechnic, July 2026 (`backdoor_criterion_paper.docx`). The file is a .docx with no fixed pagination, so I cite by section heading rather than fabricating page numbers.



Quoted verbatim, **§3.1 "Formal statement"**:



> "Given a causal DAG G and an ordered pair of variables (X, Y), a set of variables Z satisfies the backdoor criterion relative to (X, Y) if:

> (i) No node in Z is a descendant of X, and

> (ii) Z blocks every path between X and Y that contains an arrow pointing into X (a 'backdoor path')."



**§3.2 "The backdoor adjustment formula"**:



> "If Z satisfies the backdoor criterion relative to (X, Y), the causal effect of X on Y is identifiable from observational data and is given by: P(Y = y | do(X = x)) = Σz P(Y = y | X = x, Z = z) · P(Z = z)"



**No conflict.** Both the two-condition definition and the adjustment formula match §2 (Pearl 2009, Def. 3.3.1) clause for clause, including the ordering of conditions. The paper's §2.1 d-separation statement — "a path is blocked at a chain or fork node in Z, or at a collider node not in Z and with no descendant in Z" — likewise matches §2's d-separation rule. The paper additionally supplies the exact disproof case used in Claim 1, at **§4.2 "Pitfall: conditioning on a mediator"**: "M is a descendant of X and fails condition (i) of the criterion outright — it should never be included in a backdoor adjustment set for the total effect of X on Y." Nothing needed resolution.



**Journal — available and read**, but contributes nothing to §2–§4. The attachment (`drive-download-20260726T084410Z-1-001.zip`) is six photographed pages of handwritten SOAR notes, Days 4 (10/6) and 6 (12/6): a PCB/BMS factory tour, an applied-AI lecture (agentic AI, RAG, MCP, physical AI), an NSTDA / AIForThai site visit, and an entrepreneurship pitch session. These are lecture and site-visit notes, not field observations of student AI use. Applying the §0 filter:



- **AI-literacy/access heterogeneity:** Day 4 (NSTDA) records specific claims — Thai-language under-representation in tokenizers and training corpora, "not enough operators in Thai AI industry," "ICT capacity expansion limited by budget." These are specific but concern Thailand's national AI workforce and government infrastructure, not students in the selected sample. They bear on L only as an external-validity remark (AI access and literacy are institutionally and nationally stratified), and **do not enter the DAG**.

- **Institutional AI policy:** no claim about policy governing *student* AI use appears anywhere in the six pages. The AIForThai notes concern government service provision, not academic-integrity rules.

- **Data-quality caveats:** none. The journal says nothing about any of the four candidate datasets.

- **Excluded under the falsifiability filter:** the Day 6 pitch page contains "inconsistent study productivity during holidays" and students "tend to procrastinate when facing really challenging problems" — this touches A (course difficulty) and M2 (procrastination), but it is a founder's motivating impression with no source, sample, or measurement. Per §0 it is a vague impression and **does not enter the DAG.**



**Net effect on the analysis: none.** The DAG in §3 is used exactly as given.



---



# 3. Dataset selection



**Step 1 — eliminate candidates whose raw file is not present and loadable in `data/`.**



| Candidate | File in `data/` | Loads? | Outcome |

|---|---|---|---|

| Colombian study habits | `study_habits_ai_proportional_survey_dataset/survey_cleaned_english.csv` | yes, 357 × 31 | survives |

| FLoRA | `FLoRA/` — 8 .xlsx, e.g. `5.5_pre-task_biographic_survey.xlsx` (276 × 8) | yes | survives |

| Global ChatGPT survey | `Higher Education Students'…/final dataset.csv` | yes, 22 963 × 180 | survives |

| Middlebury / IZA (n = 634) | none — only `docs/references/dp18055.pdf`, the paper | n/a | **ELIMINATED at step 1** |



**Step 2 — require a single column for each of: ordinal/quantitative X, quantitative total study time Y, ≥1 W, ≥1 A.**



- **FLoRA — ELIMINATED on Y.** Full column scan of all eight workbooks against `hour | study.*time | time.*stud | per week | weekly | schoolwork`: zero matches. The only temporal fields are event timestamps (`log_trace_time`, `user_ask_time`, `writing_log_time`), which measure task time within a two-week assignment. §4(ii) excludes task-level time explicitly. No candidate Y exists.

- **Global ChatGPT survey — ELIMINATED on Y.** X and covariates are present (Q15 extent of ChatGPT use, ordinal 5-level; Q7 student status; Q33 study difficulty). But a full-text scan of `questionnaire.pdf` for `hour | time spent | How many | per week | weekly | study time` returns **zero matches**, and Section 10 ("Study and personal information," Q33–Q40) contains only Likert perception items — Q35a "I am successful in my studies," Q35b "I regularly attend my classes," etc. §4(ii) excludes Likert perception items explicitly. No quantitative study-time variable exists in this instrument; n = 22 963 cannot rescue it.

- **Colombian survey — SURVIVES.** All four roles are fillable from the codebook and bilingual questionnaire.



**Step 3 — largest usable n among survivors.** Only one candidate survives step 2, so the maximisation is over a singleton. Complete cases on X, Y, W, A: 357 of 357 rows (the cleaned file has no missing values on any mapped column).



**Step 4 — selected dataset and column mapping.**



**Selected: `data/study_habits_ai_proportional_survey_dataset/survey_cleaned_english.csv` (Colombian study-habits survey, Mendeley 10.17632/mcwb2ppdsw). Usable n = 357.**



| Role | Column | Item (bilingual questionnaire) | Response format | Coding |

|---|---|---|---|---|

| **X** | `ai_use_frequency_for_study` | Q20 "How often do you use AI tools in your studies?" | Never / Rarely / Occasionally / Almost always / Always | ordinal 1–5, entered linearly |

| **Y** | `independent_study_time` | Q9 "On average, **how many hours per week** do you devote to independent study?" | 0-1; 1-2; 2-3; 3-4; 4-5; More than 5 | ordinal 0–5; midpoints 0.5…4.5, open top band 5.5 h |

| **W** | `current_university_condition` | Q4 "What is your current university situation?" | Full-time student / Study and work | 1 = Study and work |

| **A** (ability) | `cumulative_gpa_papa` | Q8 cumulative GPA/PAPA | numeric 0.0–5.0 | as-is |

| **A** (trait procrastination) | `procrastination_frequency` | Q13 "How often do you postpone important academic activities (procrastination)?" | Never … Always | ordinal 1–5 |

| **A** (course difficulty) | `academic_program` | Q6 degree programme at Manizales campus | 14 programmes | 13 dummies, `C(A3)` |

| **L** | `prompt_engineering_knowledge` | Q27 "Do you think you have knowledge of prompt engineering?" | Not at all … A lot | mapped, **deliberately not adjusted** (§3a) |

| **M1** | `ai_helped_understand_topics` | Q21 "Do you think AI has helped you understand academic topics?" | Definitely no … Definitely yes | ordinal 1–5, **falsification refit only** |



Justifications and their limits, against the codebook rather than the variable names:



- **Y is confirmed quantitative time**, not a perception item — Q9 asks for hours per week. It is interval-censored into six bands, and the top band is open-ended and holds **51.26 %** of the sample. This is the single largest measurement weakness in the analysis and is carried through §4 as a sensitivity.

- **W is a partial proxy.** Q4 captures employment-driven time pressure (study-and-work vs full-time), which is the instrument's only competing-time-demands measure. It does **not** capture academic assignment volume; the questionnaire contains no assignment-load item. Under §2's requirement that Z be measured without error, W is measured with error, and the residual workload confounding is not adjusted away.

- **A is operationalised as the §3(b) refinement**, three sub-nodes rather than one composite — which is precisely why the invariance proof was needed. Note the hazard flagged in §3(b): Q13 asks about procrastination in general and does not separate trait procrastination (an A sub-node) from AI-induced procrastination (M2, post-treatment). To the extent it measures the latter, it is a descendant of X and its inclusion violates condition (i) in the true graph.

- **M1 is the closest available proxy**, a perceived-benefit item rather than measured time saved. Whatever else it measures, it is unambiguously post-treatment — a consequence of AI use — which is all the falsification in §4 requires.



---



# 4. Claim 2 — derivation and computation



**Estimator choice.** Y is ordinal: six ordered, interval-censored bands with an open top category. §2's categorical/ordinal branch therefore governs, and the **primary estimator is proportional-odds (ordinal) logistic regression**, reporting the log-odds coefficient on X with MLE observed-information (delta-method) standard errors. OLS with HC3 on band midpoints is reported alongside as a secondary, hours-scale reading — §2's continuous branch — because the midpoint recode renders Y approximately continuous and gives the only interpretable magnitude in hours. OLS is not primary: with 51 % of mass in an open top band, the midpoint recode imposes an arbitrary ceiling that the ordinal model does not.



**Model formula (both estimators, identical right-hand side).** Adjustment set Z = {W, A}, with A entered as its three sub-nodes:



```

ordinal logit:  Yo ~ X + W + A1 + A2 + C(A3)      # Yo = 6 ordered bands

OLS (HC3):      Yh ~ X + W + A1 + A2 + C(A3)      # Yh = band midpoints, hours/week

falsification:  ... + M1                          # Z' = {W, A, M1}

```



Regression adjustment realises the back-door formula Σ_z P(y | x, z) P(z) under the linear-index restriction; M1 and M2 are excluded so that both causal paths (rows 3 and 4 of the Claim 1 table) stay open and the X-coefficient carries the total effect.



**Code.** Two runnable files, both at the repo root, both re-runnable against the named raw file with no arguments and no network access — `dag_check.py` (Claim 1, dependency-free, reproduces every enumeration table above) and `backdoor_estimate.py` (Claim 2, reproduces every number below; runs in ~5 s). Presented above.



**Results — primary, Z = {W, A}, n = 357.**



Ordinal logit, log-likelihood −449.987175, 17 slopes + 5 cutpoints:



| Quantity | Value |

|---|---|

| β̂_X (log-odds per 1-step increase in AI-use frequency) | **0.215786** |

| SE | **0.131949** |

| 95 % CI | **[−0.042828, 0.474401]** |

| z | **1.635383** |

| p | **0.101969** |

| odds ratio, e^β̂ | 1.240837 |



OLS on band midpoints, HC3, R² = 0.191292:



| Quantity | Value |

|---|---|

| β̂_X (hours/week per 1-step increase) | **0.158947 h** |

| SE (HC3) | **0.094371** |

| 95 % CI | **[−0.026017, 0.343911]** |

| t | **1.684277** |

| p | **0.092128** |



Both fail to reject H₀: β_X = 0 at α = .05. The point estimates are positive: adjusting for W and A, higher AI-use frequency is associated with *more* independent study time, roughly +0.16 h/week per step on the 5-point frequency scale — the opposite sign to the time-saving hypothesis in `idea.md`, though the interval comfortably spans zero.



**Falsification refit — Z′ = {W, A, M1}, the invalid set.** Same data, same n, only M1 added:



| Estimator | β̂_X under Z | β̂_X under Z′ | Shift | SE under Z′ | 95 % CI under Z′ | test stat | p |

|---|---|---|---|---|---|---|---|

| Ordinal logit | 0.215786 | **0.101670** | **−0.114117** (−52.88 % of |β_Z|) | 0.149142 | [−0.190643, 0.393982] | z = 0.681699 | 0.495429 |

| OLS, HC3 (hours) | 0.158947 | **0.096710** | **−0.062237 h** (−39.16 % of |β_Z|) | 0.107682 | [−0.114343, 0.307763] | t = 0.898104 | 0.369130 |



Mediator-inclusion bias is demonstrated empirically, not merely asserted: conditioning on the descendant M1 collapses the estimate toward zero by 53 % on the log-odds scale and 39 % on the hours scale, in the direction the theory predicts — path 3 of the Claim 1 table (X→M1→Y) is blocked, leaving only the M2 channel in the coefficient. The p-value moves from 0.10 to 0.50, so an analyst who "controlled for everything available" would report a substantively different, and non-identified, result.



**Sensitivity to the open top band** (the 51.26 % censoring caveat), OLS/HC3 under Z:



| Top band coded as | β̂_X (h/week) | SE | p |

|---|---|---|---|

| 5.5 h (reported) | +0.158947 | 0.094371 | 0.092128 |

| 6.5 h | +0.190591 | 0.119025 | 0.109319 |

| 7.5 h | +0.222235 | 0.145720 | 0.127237 |



The sign and non-significance are stable; the magnitude scales with the assumed ceiling, which is why the ordinal model — which makes no such assumption — is primary.



**Reference only, not the estimand:** the naive unadjusted OLS gives β̂_X = +0.088319 h (SE 0.096479, p = 0.359973). Adjustment for Z nearly doubles the point estimate, consistent with `idea.md`'s prediction that the raw correlation is confounded — here in the direction of attenuation.



**Numerical verification.** The ordinal-logit fit was re-derived against a hand-written proportional-odds likelihood optimised by Nelder–Mead: log-likelihood −449.98717474 vs −449.98717244 (Δ = 2.3 × 10⁻⁶), β̂_X 0.21578643 vs 0.21575813. The HC3 variance was recomputed by hand from the leverage-adjusted sandwich: SE 0.09437106, matching statsmodels to eight decimals. All value mappings introduce zero NaNs, so usable n = 357 is exact, not the residue of silent coercion.



---



# 5. Final verdict



Under the DAG fixed in §3, Z = {W, A} satisfies Pearl's back-door criterion relative to (X, Y) by exhaustive enumeration of all four X–Y paths — both back-door forks are blocked and neither element is a descendant of X — while Z′ = {W, A, M1} fails condition (i) outright because X→M1 makes M1 a descendant of X; the criterion's validity is invariant to splitting A into its four pre-treatment sub-nodes provided all are retained, and L is back-door-irrelevant because it lies on no X–Y path, though omitting it is licensed only under the exclusion restriction that AI literacy/access affects schoolwork hours solely through AI use. On the one dataset surviving the §4 decision procedure — the Colombian study-habits survey, n = 357 — the back-door-adjusted estimate of the total effect of a one-step increase in AI-use frequency on weekly independent study hours is **0.215786 log-odds (SE 0.131949, 95 % CI [−0.042828, 0.474401], z = 1.635, p = 0.102)** by proportional-odds logit, equivalently **+0.159 h/week (SE 0.094, 95 % CI [−0.026, 0.344], p = 0.092)** on the midpoint scale; the data do not reject the null of no effect at conventional levels. This is **the back-door-adjusted effect estimate, valid under the stated DAG and the no-unmeasured-confounding assumption** — it is not, and the identification theorem does not grant, unconditional proof that AI use causes a change in schoolwork hours. That qualifier is doing real work here rather than serving as boilerplate: the graph is asserted from domain reasoning and not verified; W is measured only as employment-driven time pressure, with no assignment-load item in the instrument; the trait-procrastination sub-node of A cannot be separated from the post-treatment procrastination node M2 by this questionnaire; the outcome is self-reported and top-coded, with 51.3 % of respondents in an open "more than 5 hours" band; and the sample is a single Colombian campus, so any of unmeasured confounding, measurement error in Z, or censoring in Y could move this estimate in either direction.

