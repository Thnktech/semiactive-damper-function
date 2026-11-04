# Semi-Active Damper Function

![ci](https://github.com/Thnktech/semiactive-damper-function/actions/workflows/ci.yml/badge.svg)

Requirements-driven development of a semi-active suspension damper controller,
from written requirements through Simulink model-in-the-loop (MiL) verification
to generated C code that is checked sample by sample against the model.

## Problem

A passive damper fixes one compromise between ride comfort and road holding.
A semi-active damper can change its damping every millisecond but can only take
energy out of the motion, so the control strategy has to work within that limit,
safely, and in code that behaves exactly like the model it was designed in.

## Architecture

```mermaid
flowchart LR
    REQ["Requirements<br/>17 REQs, signal interface"]
    subgraph MIL["Model-in-the-loop (MATLAB / Simulink)"]
        CTRL["controller.slx<br/>5 law slots + safety"]
        PLANT["plant.slx<br/>quarter car"]
        HAR["harness.slx<br/>closed loop"]
        CTRL --> HAR
        PLANT --> HAR
    end
    subgraph CODE["Generated code (local)"]
        GEN["Simulink Coder<br/>GRT"] --> GCC["gcc<br/>-ffp-contract=off"] --> B2B["Python replay<br/>back-to-back"]
    end
    REQ --> CTRL
    REQ --> TESTS["Tests tagged by REQ ID<br/>matlab.unittest + pytest"]
    HAR --> KPI["KPIs: comparison,<br/>lag sensitivity"]
    HAR --> LOGS["MiL logs<br/>tests/data"]
    HAR --> TESTS
    KPI --> TESTS
    CTRL --> GEN
    LOGS --> B2B
    TESTS --> TRACE["traceability.md"]
    B2B --> REC["back_to_back.json"]
    REC --> CI["GitHub Actions CI<br/>Python + MATLAB tests"]
    TRACE --> CI
```

Left side of the V-model: requirements and interface first (M1), with every
threshold marked as a project assumption before any result existed. Then the
plant and passive baseline (M2), the controller with four strategies in one
model (M3), requirement-based tests with a generated traceability report (M4),
and generated C code verified back-to-back against the MiL logs (M5).

**Version 2 (in progress)** extends the same workflow to model-based control:
a full-state controller interface (body, wheel and road positions plus the
damper force), a linear prediction model with the damper lag, and an LQR law
slot that runs through the same safety logic, tests, code generation and
back-to-back (M7). A classic model predictive controller (MPC) with the
damper's limits inside its optimization follows the same path, including
generated QP solver code verified back-to-back (M8).

## Results

### Measured

Passive versus every control strategy, reference vehicle (mid-size sedan),
change versus passive on the same road; **negative = better**.

<!-- BEGIN generated:comparison (src/python/readme_results.py; do not edit by hand) -->
**Random road, class C, 80 km/h (SC-C80)**

| Strategy | RMS body acc. [m/s²] | Δ comfort | RMS dyn. tire load [N] | Δ road holding | Max travel [mm] | Δ travel |
|---|---|---|---|---|---|---|
| Passive | 1.51 | – | 669 | – | 35.9 | – |
| Skyhook | 1.22 | −18.9 % | 876 | +31.0 % | 40.5 | +12.9 % |
| Groundhook | 2.00 | +32.5 % | 630 | −5.7 % | 35.9 | +0.0 % |
| Hybrid (α = 0.5) | 1.75 | +16.1 % | 632 | −5.4 % | 26.0 | −27.4 % |
| LQR (v2) | 1.57 | +4.2 % | 654 | −2.2 % | 41.1 | +14.7 % |
| MPC (v2) | 1.45 | −4.0 % | 739 | +10.5 % | 48.0 | +33.8 % |

**Bump 50 mm × 0.5 m at 18 km/h (SC-BUMP)**

| Strategy | RMS body acc. [m/s²] | Δ comfort | RMS dyn. tire load [N] | Δ road holding | Max travel [mm] | Δ travel |
|---|---|---|---|---|---|---|
| Passive | 1.22 | – | 448 | – | 53.3 | – |
| Skyhook | 0.87 | −28.8 % | 664 | +48.3 % | 66.3 | +24.4 % |
| Groundhook | 1.76 | +44.8 % | 463 | +3.5 % | 38.4 | −28.0 % |
| Hybrid (α = 0.5) | 1.38 | +13.2 % | 431 | −3.8 % | 48.0 | −9.9 % |
| LQR (v2) | 1.22 | +0.2 % | 445 | −0.6 % | 53.3 | +0.0 % |
| MPC (v2) | 0.99 | −18.3 % | 553 | +23.6 % | 65.2 | +22.3 % |

<sub>Source: [`results/comparison/kpi_comparison_sedan_ref.csv`](results/comparison/kpi_comparison_sedan_ref.csv)</sub>
<!-- END generated:comparison -->

![Comfort vs road holding](results/comparison/comparison_tradeoff_sedan_ref.png)

Verification:

<!-- BEGIN generated:verification (src/python/readme_results.py; do not edit by hand) -->
| Check | Result |
|---|---|
| Requirements (17) | **14 Pass, 3 Fail (3 known), 0 Unverified** (commit `638812c`) |
| Fault reaction, REQ-S-01 (limit 10 ms) | **5 ms** |
| Generated C code vs MiL, REQ-V-01 | **max \|Δ i_cmd\| = 8.90399e-14 A** over 26,003 samples (SC-BUMP, SC-C80, SC-FAULT); fault_active identical: yes |

<sub>Source: [`results/traceability.md`](results/traceability.md)</sub> · <sub>Source: [`results/back_to_back.json`](results/back_to_back.json)</sub>
<!-- END generated:verification -->

Actuator-lag sensitivity: the damper valve follows the current command with a
first-order lag τ (nominal 10 ms). Change versus passive at the same lag, SC-C80:

<!-- BEGIN generated:lag (src/python/readme_results.py; do not edit by hand) -->
| Actuator lag τ | Skyhook Δ comfort | Skyhook Δ road holding | Groundhook Δ comfort | Groundhook Δ road holding | Hybrid Δ comfort | Hybrid Δ road holding |
|---|---|---|---|---|---|---|
| 5 ms | −22.1 % | +36.4 % | +35.8 % | −5.3 % | +15.6 % | −5.2 % |
| 10 ms (nominal) | −18.9 % | +31.0 % | +32.5 % | −5.7 % | +16.1 % | −5.4 % |
| 20 ms | −15.1 % | +26.3 % | +29.7 % | −6.2 % | +17.5 % | −5.8 % |

<sub>Source: [`results/sensitivity/lag_sensitivity_sedan_ref.csv`](results/sensitivity/lag_sensitivity_sedan_ref.csv)</sub>
<!-- END generated:lag -->

![Actuator-lag sensitivity](results/sensitivity/lag_sensitivity_sedan_ref.png)

### Assumptions

- **Vehicle:** quarter car of a mid-size sedan with the IRI Golden Car ratios and
  m<sub>s</sub> = 230 kg (D14); three further vehicles are scaled variants (D16).
- **Roads:** ISO 8608-based random profiles (classes A–D) and a half-sine bump,
  generated with a fixed seed so every strategy sees the same road.
- **Sensors and faults:** ideal measurements, no estimator (D5): velocities for
  the v1 laws; for the model-based laws also body, wheel and road position and
  the damper force (D30). Fault detection is an external flag, only the
  reaction is verified (D6).
- **Actuator:** linear damper map 0.3–1.6 A ↔ c<sub>min</sub>–c<sub>max</sub>,
  first-order lag 10 ms (varied in the sensitivity study).
- **Thresholds:** every requirement threshold is a *proposed project assumption*
  with its rationale and literature check in
  [requirements/REQ.md](requirements/REQ.md) (D11).
- **Control-law parameters:** c<sub>sky</sub> = c<sub>gnd</sub> = c<sub>max</sub>,
  α = 0.5 (D25); not tuned. LQR: weights 1 / 1 / 0.1 on scaled body
  acceleration, tire load and travel, the same goal as the MPC (D34). MPC:
  5 ms, prediction horizon 10 steps (50 ms), control horizon 5, same weights,
  road velocity held constant over the horizon (no preview); the tuning
  study behind these defaults is in D38.

### Interpretation

*By the author.* Skyhook gives clearly better comfort than passive but loses
road holding: the dynamic tire load rises by about a third, which fails
REQ-P-02. This is reported, not hidden: the strategy needs further development
to bound its road-holding penalty, and the threshold stays. Groundhook does the
opposite, and the hybrid law lies between them with much less suspension travel
but less comfort than passive (its parts never let it go soft with the chosen
parameters).

The actuator lag matters most for skyhook, which switches often between soft
and firm: the slower the valve, the smaller both its comfort gain and its
road-holding penalty. Within the studied range skyhook still meets the comfort
requirement. Groundhook's comfort loss also shrinks with a slower valve; the
hybrid law changes least.

The LQR (v2) stays close to passive. It is designed as if the damper could
push and pull; on SC-C80 its requested force cannot be produced in about
60 % of the samples, so the safety rule falls back to passive damping there
(D32), and a further 21 % is clipped. This is the known weakness of
"design unconstrained, clip afterwards" and the reason for the next step: an
MPC that has the damper's limits inside its optimization.

The classic MPC (v2) respects the damper's limits in every solve, but the
limits decide the force in about 81 % of them. It improves comfort slightly
(−4 %) at a tire-load increase just above the bound (+10.5 %), so REQ-P-05
and REQ-P-06 both fail. A tuning study shows the reason: the weights trade
comfort against road holding along one curve that never reaches both limits
(comfort −10 % costs about +22 % tire load), and a longer horizon moves the
MPC toward the LQR and loses comfort at every weight. Neither weights nor
horizon fix it; what the classic MPC lacks is knowledge of the road ahead,
which is the next formulation: a preview MPC (D38).

## Traceability

Every requirement is linked to its tests by ID; the report with tests,
acceptance criteria and measured values is generated by `run_tests()`:
[results/traceability.md](results/traceability.md).

<!-- BEGIN generated:traceability (src/python/readme_results.py; do not edit by hand) -->
| Requirement | Title | Verdict |
|---|---|---|
| REQ-F-01 | Current limits | **Pass** |
| REQ-F-02 | Sample time | **Pass** |
| REQ-F-03 | Initialization | **Pass** |
| REQ-F-04 | Rate limit | **Pass** |
| REQ-F-05 | Finite output | **Pass** |
| REQ-F-06 | Semi-active request of model-based laws | **Pass** |
| REQ-F-07 | MPC respects the semi-active limits | **Pass** |
| REQ-P-01 | Ride comfort | **Pass** |
| REQ-P-02 | Road holding penalty | **Fail (known)** |
| REQ-P-03 | Suspension travel | **Pass** |
| REQ-P-04 | Robustness across vehicles | **Pass** |
| REQ-P-05 | MPC ride comfort | **Fail (known)** |
| REQ-P-06 | MPC road holding penalty | **Fail (known)** |
| REQ-S-01 | Fault reaction | **Pass** |
| REQ-S-02 | Fault latch | **Pass** |
| REQ-V-01 | Generated code matches model | **Pass** |
| REQ-V-02 | Reference data provenance | **Pass** |

<sub>Source: [`results/traceability.md`](results/traceability.md)</sub>
<!-- END generated:traceability -->

## Run it

### Without MATLAB (what the CI job `test` runs)

Python 3.11, in a virtual environment named `.venv` in the repository folder
(`run_tests()` in MATLAB uses exactly this one):

```bash
py -3.11 -m venv .venv            # Linux/macOS: python3.11 -m venv .venv
.venv\Scripts\activate            # Linux/macOS: source .venv/bin/activate
pip install -r requirements.txt
pytest -q tests/python
```

On Windows use the `py -3.11` launcher: a plain `python` may start another
installation (other tools often bring their own Python). All tests pass; the
six back-to-back tests that need the locally generated code are skipped with the
reason shown by `pytest -rs`.

### With MATLAB

Requirements: MATLAB R2026a with Simulink, Simulink Control Design (plant
linearization test), Control System Toolbox and Model Predictive Control
Toolbox (v2 laws) and Simulink Coder (code generation); the Add-On
*MATLAB Support for MinGW-w64 C/C++ Compiler*; the Python environment above.

| Step | Command (MATLAB) | Result |
|---|---|---|
| 1 | `openProject('<repo folder>')` | path set (the scripts also open it themselves) |
| 2 | `generate_controller_code()` | C code in `src/generated/controller/` (local; needs a clean git tree) |
| 3 | `R = run_tests()` | all MATLAB and Python tests, back-to-back record, `results/traceability.md` |
| 4 | `run_comparison()`, `run_lag_sensitivity()` | regenerate the committed results |
| 5 | edit and run `my_study` | your own roads × strategies in `results/studies/` |

Without step 2, `run_tests()` still runs everything else and reports REQ-V-01
as *Unverified*.

## What is verified where

| Verified | Local (MATLAB) | CI job `matlab` | CI job `test` (Python) |
|---|---|---|---|
| Plant, roads, KPIs, controller laws, safety logic (unit and model tests) | ✓ | ✓ | – |
| Closed loop against an independent plain-MATLAB reference | ✓ | ✓ | – |
| Requirement tests (all except the accepted KnownFail) | ✓ | ✓ | – |
| Traceability report (verdicts incl. KnownFail and REQ-V-01) | ✓ `run_tests()` | – | – |
| Generated C code bit-identical to MiL (REQ-V-01) | ✓ replay | – | ✓ committed record matches model, parameters and logs |
| MiL log provenance (REQ-V-02) | ✓ | – | ✓ |
| README results equal the committed result files | ✓ | – | ✓ |

CI runs both jobs on every push. The `matlab` job uses MATLAB R2026a with
Simulink, Simulink Control Design, Control System Toolbox and Model Predictive
Control Toolbox, which MathWorks licenses at no cost for
public repositories; code generation (Simulink Coder) is not part of that, so
the generated-code back-to-back runs locally.

The generated C code carries the MathWorks **academic license** banner, so it is
**not committed** and not covered by this repository's MIT license; it is
generated, built and replayed locally, and only the result is committed
([src/generated/README.md](src/generated/README.md), decisions D10 rev. and D28).

## Limitations

This project does **not** demonstrate:

- **State estimation:** the controller gets ideal measurements (velocities,
  and in v2 positions, road height and damper force); a real system needs an
  estimator from accelerometers.
- **Model-based control:** an LQR with clipping and passive fallback and a
  classic MPC without road preview; the MPC misses REQ-P-05/06 (known,
  reported, D38).
- **Real time and hardware:** no real-time execution, no PiL/HiL, no target
  hardware; the back-to-back replays logged inputs open loop.
- **Vehicle validation:** a linear quarter car with tire lift-off, not a
  validated vehicle model; three of four vehicles are scaled variants.
- **Functional safety:** no ISO 26262 process or certification; fault
  detection is outside the scope.
- **Road holding:** REQ-P-02 fails for skyhook (known, reported).

## Next steps

**v2 (in progress):** full-state interface and LQR (M7) and the classic
receding-horizon MPC (M8) done; next a preview MPC that uses the road ahead
over its horizon, then further MPC formulations and strategies.
Afterwards **v3** a half car and **v4** a full vehicle, each adapting the whole
workflow of this project. v1.0.0 stays available on the `release/1.x` branch.

## Repository

| Path | Content |
|---|---|
| [requirements/](requirements/) | requirements REQ-F/P/S/V with acceptance criteria |
| [interface/](interface/) | controller signal interface |
| [model/](model/) | `plant.slx`, `controller.slx`, `harness.slx` |
| [src/matlab/](src/matlab/) | simulation, study and test scripts |
| [src/python/](src/python/) | build, back-to-back replay, README results |
| [tests/](tests/) | MATLAB and Python tests, MiL reference logs |
| [results/](results/) | committed results (all script-generated) |
| [docs/](docs/) | decisions, MiL-to-SiL rules, CI notes, development log |

Toolchain: MATLAB R2026a · Simulink · Simulink Coder (GRT, no Embedded Coder) ·
Control System and Model Predictive Control Toolboxes · Python 3.11 · gcc. History of every change: [CHANGELOG.md](CHANGELOG.md).

## License

[MIT](LICENSE), except the locally generated C code (see above).
