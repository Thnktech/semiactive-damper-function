# Controller comparison: sedan_ref (M3)

Generated data: [`kpi_comparison_sedan_ref.csv`](kpi_comparison_sedan_ref.csv)
(script `src/matlab/run_comparison.m`), plots
[`comparison_tradeoff_sedan_ref.png`](comparison_tradeoff_sedan_ref.png) and
[`comparison_C80_time_sedan_ref.png`](comparison_C80_time_sedan_ref.png).

Setup: reference vehicle, MiL harness (plant + controller), ISO 8608-based
roads A–D at 50 and 80 km/h (30 s, seed 1) and the SC-BUMP bump; every mode
sees identical inputs (passive rows equal the M2 baseline). Change versus
passive on the same road; negative = better.

## Summary (range over the 8 random roads; bump in brackets)

| Strategy | Δ RMS body acceleration (comfort) | Δ RMS dynamic tire load (road holding) | Δ max suspension travel |
|---|---|---|---|
| Skyhook (mode 1) | −16 % to −19 % (−29 %) | +25 % to +33 % (+48 %) | +5 % to +16 % (+24 %) |
| Groundhook (mode 2) | +31 % to +33 % (+45 %) | −5 % to −6 % (+3 %) | −3 % to 0 % (−28 %) |
| Hybrid, α = 0.5 (mode 3) | +16 % to +17 % (+13 %) | −4 % to −5 % (−4 %) | −25 % to −27 % (−10 %) |

## Interpretation

Skyhook gives clearly better comfort than passive on every road but loses
road holding: the dynamic tire load rises by about a third, and by about half
on the bump. Groundhook does the opposite: slightly better grip than passive,
at the cost of much lower comfort. The hybrid law with α = 0.5 lies between
the two: it is more comfortable than groundhook and grips almost as well,
and it cuts suspension travel by about a quarter, but it remains less
comfortable than passive. In the C80 time plot its current never drops below
about 0.86 A, because with any relative velocity at least one of its two
parts can act, so the blend never chooses soft damping; this follows from
the chosen parameters (c_gnd = c_max, α = 0.5, D25), not from a model error
(the law matches its hand calculation exactly).

Requirement preview (formal verdicts in M4, scenario SC-C80 / SC-BUMP):
REQ-P-01 (skyhook comfort ≥ 10 % better) would pass with −18.9 %; REQ-P-03
(travel ≤ 100 mm, all modes) would pass with at most 66 mm; REQ-P-02
(skyhook tire load ≤ +10 %) would **fail** with +31.0 %. The failure is
reported as is: it shows that the skyhook strategy needs further development
to bound its road-holding penalty, not that the threshold should be loosened.

*Interpretation by the author, 2026-10-22.*
