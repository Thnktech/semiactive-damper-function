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
| 4 | `mode` | Control mode | – | double | 1 ms | {0, 1, 2, 3, 4, 5, 6} | 0 | 0 passive, 1 skyhook, 2 groundhook, 3 hybrid, 4 LQR, 5 MPC, 6 preview MPC; see below |
| 5 | `zs` | Sprung-mass vertical position | m | double | 1 ms | ±0.2 [G] | 0 | v2 · Ideal measurement, deviation from static equilibrium (D30) |
| 6 | `zu` | Unsprung-mass vertical position | m | double | 1 ms | ±0.2 [G] | 0 | v2 · Ideal measurement, deviation from static equilibrium (D30) |
| 7 | `zr` | Road height under the tire | m | double | 1 ms | ±0.2 [G] | 0 | v2 · Ideal measurement (D30); its backward difference gives ż<sub>r</sub> for the MPC |
| 8 | `F_d` | Damper force | N | double | 1 ms | ±10 000 [G] | 0 | v2 · Ideal measurement, positive when resisting extension (D30) |
| 9 | `zr_preview` | Road height ahead of the wheel | m | double | 1 ms | ±0.2 [G] | 0 | v2.2 · Ideal look-ahead sensor: z<sub>r</sub>(t + T<sub>L</sub>), T<sub>L</sub> = (p + 1)·T<sub>s,MPC</sub> of `P.mpcp` (205 ms at p = 40, D39, D42); used by mode 6 only |

## Outputs

| # | Signal | Meaning | Unit | Type | Rate | Range | Init | Notes |
|---|---|---|---|---|---|---|---|---|
| 1 | `i_cmd` | Damper current command | A | double | 1 ms | [0.3, 1.6] | 0.95 (I<sub>default</sub>) | Saturated (REQ-F-01) and rate-limited to 0.13 A per ms (REQ-F-04) |
| 2 | `fault_active` | Fault mode latched | – | double | 1 ms | {0, 1} | 0 | Stays 1 until re-initialization (REQ-S-02, D18) |

## Mode semantics

Each mode selects one **control-law slot** inside `Control_law` (D24). Every
law outputs a requested damping `c_req` [N·s/m]; the shared block
`Damping_to_current` clips it to [c<sub>min</sub>, c<sub>max</sub>] (semi-active
feasibility) and converts it with the inverse damper map to `i_req`.

| `mode` | Law slot | Behavior |
|---|---|---|
| 0 | `Law_0_Passive` | c<sub>req</sub> = c<sub>passive</sub> → I<sub>passive</sub> (D22) |
| 1 | `Law_1_Skyhook` | Skyhook: c<sub>sky</sub>·ż<sub>s</sub>/v<sub>rel</sub> where the damper can act, else c<sub>min</sub> |
| 2 | `Law_2_Groundhook` | Groundhook: c<sub>gnd</sub>·(−ż<sub>u</sub>)/v<sub>rel</sub> where the damper can act, else c<sub>min</sub> |
| 3 | `Law_3_Hybrid` | α·skyhook part + (1−α)·groundhook part (inactive part = 0), α = 0.5 (D25); α = 1 reproduces skyhook |
| 4 | `Law_4_LQR` | F<sub>cmd</sub> = −K·x (D34), then Force_to_damping: F<sub>cmd</sub>/v<sub>rel</sub> if dissipative, else c<sub>passive</sub> (D32) |
| 5 | `Law_5_MPC` | Classic MPC at 5 ms, p = 10, m = 5, force limits [c<sub>min</sub>, c<sub>max</sub>]·v<sub>rel</sub> inside the QP (D31, D32, D33), then Force_to_damping; solver failure → c<sub>passive</sub> |
| 6 | `Law_6_MPC_Preview` | As mode 5 with its own settings `P.mpcp` (p = 40, weights 1 / 0.25 / 0.1, D42), and the road velocity over the horizon from `zr_preview` instead of held constant: (p + 1)×1 preview of forward differences (D39, D40) |
| 7 … N | `Law_<n>_<Name>` | Reserved for additional strategies (D24) |
| other | – | Treated as 0 (passive) (D20) |

Mode changes take effect at the next step and pass through the rate limiter.
Fault mode overrides every mode.

**Adding a strategy (D24):** copy a law subsystem, keep its ports (inputs
`zs_dot`, `zu_dot`; output `c_req`), add its index to the Multiport Switch,
add a row to this table. A law may use only the controller inputs and its own
discrete states; a new input signal is an interface change to this file.
Since v2 the model-based laws (4, 5) also take `zs`, `zu`, `zr`, `F_d`; they
form the states of `qc_prediction_model` (D30) inside the slot. Since v2.2
the preview MPC (6) also takes `zr_preview` (D39).

## Input handling

- **Velocities:** not clipped. Any finite value is accepted; the output is
  always saturated and rate-limited (REQ-F-01, REQ-F-04). Near v<sub>rel</sub> = 0
  the ε guard selects c<sub>min</sub> (REQ-F-05).
- **`fault_flag`:** compared with 0.5; no debounce (detection is external, D6).
- **`mode`:** any value without a law slot (non-integer, or an integer not in the Multiport Switch indices, currently 0–3) selects passive (D20, D26).
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
| `P.mbc`, `P.lqr`, `P.mpc`, `P.mpcp` (weights, K, T<sub>s,MPC</sub>, p, m) | `setup_params.m` | v2 (D30, D31, D34, D40) |
| MPC objects `mpc_law5`, `mpc_law6` | built from `P` by `design_mpc.m` | v2 (D31, D40) |

## Changes after baseline

- 2026-10-22: mode mapping changed by the author's decision: mode 2 =
  groundhook (new), mode 3 = hybrid (was 2); skyhook implemented as its own
  law (equal to hybrid with α = 1, verified by test). First free slot: 4.
- 2026-11-01 (**interface v2**, D29, D36): inputs 5–8 appended (`zs`, `zu`,
  `zr`, `F_d`, ideal measurements); modes 4 = LQR and 5 = MPC added. Inputs
  1–4 and both outputs unchanged. First free slot: 6.
- 2026-11-04 (**interface v2.2**, D29 rev., D39): input 9 `zr_preview` appended (ideal
  look-ahead sensor); mode 6 = preview MPC added. Inputs 1–8 and both outputs
  unchanged. First free slot: 7.
