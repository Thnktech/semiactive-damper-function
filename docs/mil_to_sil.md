# MiL → SiL: Rules for a Smooth Back-to-Back

How to build and log the MiL simulation so that the generated-code
back-to-back test (REQ-V-01, open-loop replay, D7) works without rework.

**Principle:** the MiL log is the *answer key*. The generated code receives
exactly the inputs the Simulink controller saw and must reproduce exactly the
outputs it produced. Anything that makes "exactly the inputs" or "exactly the
outputs" uncertain breaks the comparison.

## 1. Controller model structure (M3)

| # | Rule | Why |
|---|---|---|
| 1.1 | Controller is its own model, `model/controller/controller.slx`, referenced from the harness with a **Model block** | The same file is simulated in MiL and generated in M5; never a copy |
| 1.2 | Root Inports/Outports **named and ordered** exactly as `interface/signals.md` | Port order becomes the field order of `controller_U` / `controller_Y`, which the Python wrapper mirrors |
| 1.3 | All root ports `double`, sample time **0.001** set explicitly on every Inport | Avoids inherited types or rates that differ between MiL and code |
| 1.4 | Controller configuration: fixed-step, **discrete** solver, 0.001 s, single rate | One rate, one step function, no rate transitions inside |
| 1.5 | Only discrete blocks; no continuous states, no From Workspace / To Workspace / Scopes inside the controller | Keeps the generated code self-contained; logging belongs to the harness |
| 1.6 | **Registered outputs** (D19): Unit Delay at each output, initial value I<sub>default</sub> for `i_cmd`, 0 for `fault_active` | Defines step 0 exactly (REQ-F-03) and fixes sample alignment |
| 1.7 | Rate limiter and fault latch as explicit discrete states with defined initial values | No hidden initial conditions; `controller_initialize()` reproduces them |
| 1.8 | Parameters from the shared struct (D9); same values for simulation and code generation; **default parameter behavior: Inlined** in the controller configuration | Simulated and generated code use the same constants |
| 1.9 | Only blocks supported by Simulink Coder (GRT); MATLAB Function blocks without dynamic memory | Code generation succeeds without edits |
| 1.10 | No plant signals other than the four inputs (REQ, M3 checklist) | The controller is a closed unit; the replay can drive it completely |

## 2. Harness and logging (M3)

| # | Rule | Why |
|---|---|---|
| 2.1 | Harness: fixed-step `ode4`, 1 ms (D8) | Plant and controller steps coincide |
| 2.2 | Log the controller's root inputs and outputs **at the Model block boundary**, every 1 ms | The values the controller actually saw and produced, not plant-side signals |
| 2.3 | One row per controller step, starting at k = 0 (t = 0); no decimation, no interpolation | Row k must equal step k of the replay |
| 2.4 | **Alignment check:** row k = inputs applied at step k and outputs read at step k. With registered outputs, `i_cmd`(0) = I<sub>default</sub> exactly | The replay sets `controller_U` = row k, calls `controller_step()`, reads `controller_Y`; must give row k's outputs |
| 2.5 | CSV columns in this order: `t, zs_dot, zu_dot, fault_flag, mode, i_cmd, fault_active` | Matches the wrapper and the test |
| 2.6 | Write numbers with **`%.17g`** | Full double precision; shorter formats introduce errors far above 1e-9 |
| 2.7 | File name `tests/data/mil_<scenario>.csv`, e.g. `mil_SC-C80.csv`, `mil_SC-BUMP.csv`, `mil_SC-FAULT.csv` | Scenario IDs from REQ.md |
| 2.8 | Keep files small: a 10 s window per scenario (10 001 rows) is enough for back-to-back | Fast CI, small repository; KPI tests use full-length runs locally |

## 3. Metadata JSON (REQ-V-02)

Write `tests/data/mil_<scenario>.json` next to every CSV, from the same script:

| Field | How to get it |
|---|---|
| `git_commit` | `system('git rev-parse HEAD')` |
| `git_dirty` | `system('git status --porcelain')` non-empty → true. **Commit before logging** so this is false |
| `model` | `controller` (and harness name) |
| `scenario` | Scenario ID from REQ.md |
| `vehicle` | Selected vehicle (D13) |
| `seed`, `speed_kmh` | Road generator inputs |
| `sample_time_s` | 0.001 |
| `matlab_release` | `version('-release')` |
| `generated` | `datetime('now','TimeZone','UTC')`, ISO 8601 |

## 4. Exercise the logic in the logged scenarios

The replay only proves what the logs contain. Make sure the logged windows
include:

- saturation at I<sub>min</sub> and I<sub>max</sub> and active rate limiting;
- v<sub>rel</sub> crossing zero (ε guard, REQ-F-05);
- all three modes (`mode` 0, 1, 2) and at least one mode change;
- a fault: step, single-sample pulse and toggling (SC-FAULT).

## 5. Before generating code (M5)

| # | Rule | Why |
|---|---|---|
| 5.1 | Generate code from the **same commit** that produced the MiL logs | `git_commit` in the JSON must match the code's provenance README |
| 5.2 | After any change to the controller or its parameters: regenerate code **and** re-log MiL | Logs and code must come from the same model |
| 5.3 | Inspect `controller.h`: entry points and `controller_U` / `controller_Y` field order | The Python `ctypes` structs must match exactly |
| 5.4 | Build with `-ffp-contract=off` | Prevents fused multiply-add from changing results vs MATLAB |

## 6. If the back-to-back fails

Check in this order: (1) sample offset (compare row k with replay k±1),
(2) CSV precision (`%.17g`), (3) struct field order, (4) FMA flag,
(5) initial states. Loosen the tolerance only with a documented cause.
