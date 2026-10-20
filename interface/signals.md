# Controller Signal Interface

Interface of the controller model `model/controller/controller.slx` and of
the generated C code. Simulink root ports and the generated I/O structs
(`controller_U`, `controller_Y`) follow this table **in this order**.

Status: **Baseline** (M1). Input ranges marked [G] are placeholders, to be
checked against M2 simulations.

## Sign convention

- z positive **upward** for z<sub>s</sub>, z<sub>u</sub> and road z<sub>r</sub>; velocities and accelerations likewise.
- Relative velocity v<sub>rel</sub> = ż<sub>s</sub> − ż<sub>u</sub>, positive in **extension** (rebound).
- Damper force F<sub>d</sub> positive when it resists extension.
- States are measured from **static equilibrium** (zero road input → zero motion).

## Timing and types

- Single rate, discrete, sample time **T<sub>s</sub> = 1 ms** (D8, REQ-F-02).
- All root inputs and outputs are **`double`**. Flags are `double` valued 0 or 1.
- **Registered outputs** (D19): outputs at step k are computed from inputs up
  to step k−1. The output delay state is initialized to the "Init" value below,
  so step 0 returns exactly the initial values (REQ-F-03).
- Sample alignment for logging and replay: row k holds the inputs applied at
  step k and the outputs read at step k (see `docs/mil_to_sil.md`).

## Inputs

| # | Signal | Meaning | Unit | Type | Rate | Range | Init | Notes |
|---|---|---|---|---|---|---|---|---|
| 1 | `zs_dot` | Sprung-mass vertical velocity | m/s | double | 1 ms | ±2 [G] | 0 | Ideal measurement (D5) |
| 2 | `zu_dot` | Unsprung-mass vertical velocity | m/s | double | 1 ms | ±5 [G] | 0 | Ideal measurement (D5) |
| 3 | `fault_flag` | External fault indication | – | double | 1 ms | {0, 1} | 0 | > 0.5 = fault (D6); a single sample is enough to latch |
| 4 | `mode` | Control mode | – | double | 1 ms | {0, 1, 2} | 0 | 0 passive, 1 skyhook, 2 hybrid; see below |

## Outputs

| # | Signal | Meaning | Unit | Type | Rate | Range | Init | Notes |
|---|---|---|---|---|---|---|---|---|
| 1 | `i_cmd` | Damper current command | A | double | 1 ms | [0.3, 1.6] | 0.95 (I<sub>default</sub>) | Saturated (REQ-F-01) and rate-limited to 0.13 A per ms (REQ-F-04) |
| 2 | `fault_active` | Fault mode latched | – | double | 1 ms | {0, 1} | 0 | Stays 1 until re-initialization (REQ-S-02, D18) |

## Mode semantics

| `mode` | Behavior |
|---|---|
| 0 | Passive: constant current I<sub>passive</sub> = inverse damper map of c<sub>passive</sub> (value set in M2) |
| 1 | Skyhook: hybrid law with α = 1 |
| 2 | Hybrid skyhook–groundhook with fixed α (value set in M3) |
| other | Treated as 0 (passive) (D20) |

Mode changes take effect at the next step and pass through the rate limiter.
Fault mode overrides every mode.

## Input handling

- **Velocities:** not clipped. Any finite value is accepted; the output is
  always saturated and rate-limited (REQ-F-01, REQ-F-04). Near v<sub>rel</sub> = 0
  the ε guard selects c<sub>min</sub> (REQ-F-05).
- **`fault_flag`:** compared with 0.5; no debounce (detection is external, D6).
- **`mode`:** values other than exactly 0, 1 or 2 select passive (D20).
- **Non-finite inputs (NaN, Inf):** outside the specified range; behavior not
  specified.

## No reset input

A latched fault is cleared only by re-initialization (`controller_initialize`
in the generated code, a new simulation in Simulink) (D18).

## Parameters (not ports)

Fixed at code generation and shared with the plant through one parameter
struct (D9). Changing any of them requires regenerating the code and new MiL
reference logs.

| Parameter | Value | Source |
|---|---|---|
| I<sub>min</sub>, I<sub>max</sub> | 0.3 A, 1.6 A | REQ.md |
| I<sub>default</sub> | 0.95 A | REQ.md |
| ΔI<sub>max</sub> | 0.13 A per step | REQ.md |
| c<sub>min</sub>, c<sub>max</sub>, c<sub>passive</sub> | TBD | M2 |
| c<sub>sky</sub>, c<sub>gnd</sub>, α, ε | TBD | M3 |
