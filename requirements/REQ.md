# Requirements – Semi-Active Damper Function

Status of this document: **Draft** (M1). Safety (REQ-S) and verification
(REQ-V) requirements follow in a later revision.

## Conventions

- **Vehicle:** all verdicts use the reference vehicle (D12, D14). Variants are
  evaluated for comparison and for REQ-P-04 only.
- **Thresholds** marked *(PA)* are **proposed project assumptions** (D11):
  chosen and justified for this project, not industry figures. They are fixed
  before any controlled-mode results exist and are not tuned afterwards; a
  missed threshold is reported as **Fail**.
- **Status:** Unverified → Pass / Fail. Evidence (test ID) is filled in M4.
- **Signals and units:** as in `interface/signals.md` (M1). Sign convention:
  z positive upward; v<sub>rel</sub> = ż<sub>s</sub> − ż<sub>u</sub> positive in extension.

## Parameters referenced by requirements

| Symbol | Value | Meaning | Rationale |
|---|---|---|---|
| I<sub>min</sub> | 0.3 A *(PA)* | Minimum commanded current (softest damping, c<sub>min</sub>) | Soft setting of production semi-active valves ≈ 0.3–0.4 A [L1, L2] |
| I<sub>max</sub> | 1.6 A *(PA)* | Maximum commanded current (firmest damping, c<sub>max</sub>) | Hard setting ≈ 1.6 A, up to 1.8 A [L1, L2, L3] |
| I<sub>default</sub> | 0.95 A *(PA)* | Default current (initialization and fault) | Mid-range damping; a "medium" fail-safe setting exists in production valve designs [L2]. Note: this is the controller's commanded default, not the valve's unpowered (0 A) fail-safe state, which is a hardware property |
| ΔI<sub>max</sub> | 0.13 A per ms *(PA)* | Maximum change of `i_cmd` per sample | Full range (1.3 A) in ≥ 10 ms; avoids force steps faster than the assumed actuator lag (τ = 10 ms, guide M6). No literature value found |
| T<sub>s</sub> | 1 ms | Controller sample time | D8 |

The damper map becomes c(I) = c<sub>min</sub> + (c<sub>max</sub> − c<sub>min</sub>)·(I − I<sub>min</sub>)/(I<sub>max</sub> − I<sub>min</sub>) (generalizes the guide's map, which assumed I<sub>min</sub> = 0).

## Scenarios referenced by requirements

| ID | Definition | Rationale |
|---|---|---|
| SC-C80 | ISO 8608-based random road, class C, 80 km/h, fixed seed, 30 s simulated; KPIs over t ≥ 2 s | 80 km/h is the IRI reference speed [L6]. Transient: with body-mode damping ratio ζ ≈ 0.3, the decay time constant 1/(ζω<sub>n</sub>) ≈ 0.44 s, so 2 s ≈ 4.5 time constants (< 2 % of the initial transient left). 30 s ≈ 36 body-mode periods for a stable RMS. Derived, not from literature |
| SC-BUMP | Single half-cosine bump, 50 mm high, 0.5 m long, 18 km/h *(PA)*; KPIs over the whole run | Matches a semi-active quarter-car bump case in the literature (0.05 m, 0.5 m, 18 km/h) [L4]; similar published cases: 0.0275 m × 1.4 m at 10 km/h, 0.075 m × 0.5 m at 17.5 km/h [L4] |
| SC-ALL | All scenarios run in M2–M4 (roads A–D, both speeds, bump, fault), all modes | – |

## KPI definitions

| KPI | Definition |
|---|---|
| RMS body acceleration | RMS(z̈<sub>s</sub>) in m/s² |
| RMS dynamic tire load | RMS(F<sub>tire</sub> − F<sub>static</sub>) in N |
| Max suspension travel | max \|z<sub>s</sub> − z<sub>u</sub>\| in mm |

Passive baseline: same vehicle, scenario, seed and initial conditions with the
fixed passive damping c<sub>passive</sub> (defined in M2).

## Requirements

### Functional (REQ-F)

| ID | Title | Statement | Rationale | Verification | Acceptance | Evidence | Status |
|---|---|---|---|---|---|---|---|
| REQ-F-01 | Current limits | The function shall keep the current command `i_cmd` within [I<sub>min</sub>, I<sub>max</sub>] for all inputs. | The valve has a physical operating range | Test, SC-ALL, plus out-of-range input injection | I<sub>min</sub> ≤ `i_cmd` ≤ I<sub>max</sub> at every sample; no tolerance | – | Unverified |
| REQ-F-02 | Sample time | The function shall execute at a fixed sample time of T<sub>s</sub> = 1 ms. | Back-to-back comparison and discrete design assume a fixed rate (D8) | Inspection (model configuration) + test (logged time steps) | Configured sample time = 0.001 s; all logged controller time steps = 0.001 s ± 1e-12 s | – | Unverified |
| REQ-F-03 | Initialization | After initialization and before the first controller step, the function shall output `i_cmd` = I<sub>default</sub>. | Defined output before any sensor data has been processed | Test (MiL initial output; generated code after `initialize`) | `i_cmd` = I<sub>default</sub> exactly at the initial sample | – | Unverified |
| REQ-F-04 | Rate limit | The function shall limit the change of `i_cmd` between consecutive samples to ΔI<sub>max</sub>. | Protects the valve and avoids force steps faster than the actuator can follow | Test, SC-ALL, plus step inputs | \|`i_cmd`(k) − `i_cmd`(k−1)\| ≤ ΔI<sub>max</sub> + 1e-12 A at every sample | – | Unverified |
| REQ-F-05 | Finite output | For any finite input, including v<sub>rel</sub> = 0, the function shall produce finite outputs. | The control law divides by v<sub>rel</sub>; the ε guard must prevent NaN/Inf | Test: input sweep including v<sub>rel</sub> ∈ [−2ε, 2ε] and exact 0 | No NaN or Inf in `i_cmd` or `fault_active` | – | Unverified |

### Performance (REQ-P)

| ID | Title | Statement | Rationale | Verification | Acceptance | Evidence | Status |
|---|---|---|---|---|---|---|---|
| REQ-P-01 | Ride comfort | In skyhook mode on SC-C80, the function shall reduce RMS body acceleration compared with the passive baseline. | Ride comfort is the primary purpose of skyhook control | KPI test, SC-C80, reference vehicle | Reduction ≥ **10 %** *(PA)*: published semi-active skyhook simulations report ≈ 10 % (9.7 % [L5], 10.6 % [L7]) | – | Unverified |
| REQ-P-02 | Road holding penalty | In skyhook mode on SC-C80, the function shall not increase RMS dynamic tire load by more than a bounded amount compared with the passive baseline. | Skyhook is reported to worsen road holding [L5, L8]; the trade-off must be bounded | KPI test, SC-C80, reference vehicle | Increase ≤ **10 %** *(PA)*: no published figure found; literature supports only the direction of the effect | – | Unverified |
| REQ-P-03 | Suspension travel | In every mode on SC-BUMP, the function shall keep the maximum suspension travel within the available travel. | Exceeding the travel means hitting the bump stops | KPI test, SC-BUMP, reference vehicle, all modes | max \|z<sub>s</sub> − z<sub>u</sub>\| ≤ **100 mm** *(PA)*: a 10 cm deflection limit is used in a quarter-car bump study [L4]; another study requires ≥ 125 mm total travel [L9] | – | Unverified |
| REQ-P-04 | Robustness across vehicles | In skyhook mode on SC-C80, the function shall not degrade ride comfort on any vehicle variant compared with that variant's passive baseline. | Shows the controller is not tuned to the reference vehicle only (D12) | KPI test, SC-C80, all variants (D16) | RMS body acceleration ≤ passive (reduction ≥ **0 %**) *(PA)* on every variant | – | Unverified |

## Literature check of thresholds

Verification level: **F** = value read in the full text · **A** = abstract or
publisher page only · **S** = search-result excerpt only (full text not
accessible); **S** values must be confirmed against the full text before they
are cited in the README.

| Ref | Source | Supports | Level |
|---|---|---|---|
| L1 | *Semi-active suspension systems from research to mass-market*. SAGE journal article, doi:10.1177/1461348419876392 (authors and volume to be confirmed) | Soft ≈ 0.3 A, hard ≈ 1.6 A; passive-like characteristic at 0 A (Tenneco-type) | S |
| L2 | Solero Technologies, eCDV EVO valves for semi-active damping (product page) | Current 0.35/0.4 A (soft) – 1.6 A (1.8 A); fail-safe options incl. medium setting at 0 A | S |
| L3 | Research of solenoid valve CDC damper performance data, Atlantis Press | Orifice controlled by current 0–1.8 A | S |
| L4 | Search excerpts of quarter-car bump studies (ResearchGate: performance investigation of active/semi-active/passive suspension; review of PID active suspension on bumps; speed hump estimation) and *LMI-based robust model predictive control for a quarter car with series active variable geometry suspension*, arXiv:2401.06650 (raised cosine 0.0275 m × 1.4 m, 10 km/h) | Bump dimensions and speed; 10 cm deflection limit | S |
| L5 | Search excerpt: fuzzy vs skyhook semi-active comparison (cited within a hybrid skyhook–groundhook paper) | Skyhook comfort +9.7 % vs passive, with handling compromise | S |
| L6 | Sayers, M. W. (1995). On the calculation of International Roughness Index from longitudinal road profile. *Transportation Research Record* 1501, 1–12 | 80 km/h reference speed | F |
| L7 | Search excerpt: MR damper quarter car with clipped-optimal skyhook | Body acceleration RMS 2.64 → 2.36 m/s² (−10.6 %) | S |
| L8 | Search excerpt: review of semi-active control methods | Skyhook improves comfort but worsens road holding | S |
| L9 | Search excerpt: nonlinear quarter car–seat–driver optimization, citing Baumal et al. | ≥ 125 mm suspension travel required | S |

Changes after the literature check (2026-10-20): I<sub>min</sub>/I<sub>max</sub>
0/2.0 A → 0.3/1.6 A; I<sub>default</sub> 1.0 → 0.95 A; REQ-P-01 15 % → 10 %;
REQ-P-03 80 → 100 mm; bump 1.0 m at 30 km/h → 0.5 m at 18 km/h. Added
REQ-F-04, REQ-F-05, REQ-P-04. The original proposals were engineering
judgment, not literature values.
