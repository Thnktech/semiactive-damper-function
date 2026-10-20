# Design Decisions

Decisions that fix the project scope and setup. Each entry is changed only by
a new dated revision, never silently.

Status: **Accepted** = in force · **Proposed** = awaiting confirmation · **Open** = not decided yet.

| # | Decision | Value | Rationale | Status | Date |
|---|---|---|---|---|---|
| D1 | Repository name | `semiactive-damper-function` | Uses the search keywords; links to the author's AIP papers | Accepted | 2026-10-20 |
| D2 | MATLAB release | R2026a (MATLAB 26.1): Simulink, MATLAB Coder, Simulink Coder. **No Embedded Coder** | GRT and `packNGo` details depend on the release; every code-generation setting (M5) is checked against R2026a documentation | Accepted | 2026-10-20 |
| D3 | License | MIT | Simple and employer-friendly for a portfolio project | Accepted | 2026-10-20 |
| D4 | Spelling | US English ("tire") everywhere | Consistency | Accepted | 2026-10-20 |
| D5 | Controller sensor inputs | Ideal velocities ż<sub>s</sub>, ż<sub>u</sub> as inputs | State estimation is out of scope; stated as an explicit assumption, not hidden in the model | Accepted | 2026-10-20 |
| D6 | Fault detection | External `fault_flag` input (double, > 0.5 = fault) | The project verifies the **reaction** to a fault, not its detection | Accepted | 2026-10-20 |
| D7 | Back-to-back scope | Open-loop replay at controller level: logged MiL controller inputs → generated code → outputs compared. No closed-loop SiL | Achievable without Embedded Coder; isolates the controller as the unit under test | Accepted | 2026-10-20 |
| D8 | Solver | Whole harness fixed-step `ode4`, 1 ms; controller discrete, 1 ms | Sample-aligned logging for back-to-back; 1 ms resolves wheel hop (≈ 10–15 Hz) well | Accepted | 2026-10-20 |
| D9 | Damper map | One parameter struct shared by plant and controller | Single source of truth; avoids silent mismatch between plant and controller | Accepted | 2026-10-20 |
| D10 | Generated-code policy | Commit `packNGo`-extracted sources in `src/generated/`; never commit `*_grt_rtw/`, `slprj/` or object files | CI needs sources, not build output | Accepted | 2026-10-20 |
| D11 | Thresholds | Every requirement threshold is marked **proposed project assumption** with its rationale | No invented "industry" numbers | Accepted | 2026-10-20 |
| D12 | Vehicle set | One **reference vehicle** for requirements, MiL tests, back-to-back and all verdicts; **variants** for baseline runs and a robustness comparison (same controller). Reference: mid-size sedan. Planned variants: small car, SUV, light van, eROD | One fixed vehicle keeps requirements and regression tests unambiguous; variants show the controller is not tuned to one car | Accepted | 2026-10-20 |
| D13 | Vehicle switching | Each vehicle is one parameter file under `src/matlab/vehicles/`, all with the same fields. One selector (`vehicle` in the project configuration) chooses the vehicle; no other file names a vehicle. The vehicle name is written into every result file and MiL metadata JSON | Changing the reference or running a variant is a one-line change; results always show which vehicle produced them | Accepted | 2026-10-20 |
| D14 | Reference vehicle parameters | Mass and stiffness ratios of the IRI **Golden Car** (Sayers 1995): k<sub>s</sub>/m<sub>s</sub> = 63.3 s⁻², k<sub>t</sub>/m<sub>s</sub> = 653 s⁻², m<sub>u</sub>/m<sub>s</sub> = 0.15; with m<sub>s</sub> = 230 kg as in Múčka (2018) → m<sub>u</sub> = 34.5 kg, k<sub>s</sub> = 14 559 N/m, k<sub>t</sub> = 150 190 N/m. Natural frequencies 1.21 Hz (body), 11.0 Hz (wheel). Damping range c<sub>min</sub>, c<sub>max</sub> and c<sub>passive</sub>: separate project assumptions (M2) | Published, openly available and widely used reference; frequencies in the expected bands. Caveat (Sayers): Golden Car spring rates match typical body/axle frequencies but its damping (c/m<sub>s</sub> = 6.0 s⁻¹) is higher than in most cars and it is not an "average car", so its damping is **not** adopted as the passive baseline | Accepted | 2026-10-20 |
| D15 | Variant vehicle parameters | **Mixed approach.** Each variant starts as a **scaled variant**: sprung mass m<sub>s</sub>, mass ratio m<sub>u</sub>/m<sub>s</sub> and target body/wheel frequencies are chosen as project assumptions, and k<sub>s</sub>, k<sub>t</sub> are solved so the undamped quarter car has exactly those frequencies. A scaled variant is labelled "scaled variant (project assumption)", never as a real vehicle. When a published, verifiable parameter set for that class is found, it replaces the scaled variant and the change is logged here. eROD uses author-supplied data once publication is confirmed | No openly verifiable class-specific sets found; scaling unblocks M2 while staying honest about provenance | Accepted | 2026-10-20 |
| D17 | Fault transition | On fault, `i_cmd` moves to I<sub>default</sub> through the normal rate limiter (REQ-F-04), not by an instant jump or a separate ramp | One mechanism for all current changes; avoids a force step; worst case 0.65 A in 5 ms, inside REQ-S-01 | Accepted | 2026-10-20 |
| D18 | Fault reset | No reset input. A latched fault is cleared only by re-initialization (`initialize`) | Keeps the interface minimal; a fault must not clear itself when `fault_flag` drops (REQ-S-02) | Accepted | 2026-10-20 |
| D19 | Registered outputs | Each controller output passes through a one-sample delay initialized to its "Init" value (`i_cmd` = I<sub>default</sub>, `fault_active` = 0) | Makes step 0 exactly defined in Simulink and C (REQ-F-03) and fixes sample alignment for back-to-back; costs 1 ms latency, small against the 10 ms actuator lag and already counted in REQ-S-01 | Accepted | 2026-10-20 |
| D20 | Invalid mode | `mode` values other than exactly 0, 1 or 2 select passive | Defined behavior for every input; passive is the least demanding mode | Accepted | 2026-10-20 |
| D21 | Private vehicle data | eROD data is **private**: publication not cleared. Stored only in the git-ignored `src/matlab/vehicles/private/`; results and MiL logs derived from it (`*erod*` in `results/` and `tests/data/`) are git-ignored too. Two local variants: front and rear corner. No eROD values appear in committed files. The vehicle selector must work in a fresh clone without the private folder; CI never uses eROD. REQ-P-04 verdicts in the repository cover the published variants only | Respects data ownership (project rule: no employer or doctoral vehicle data) while still allowing local robustness checks | Accepted | 2026-10-20 |
| D22 | Damping values | Per vehicle from body-mode damping ratio, c = 2ζ√(k<sub>s</sub>m<sub>s</sub>): ζ<sub>passive</sub> = 0.3, ζ<sub>max</sub> = 0.8, ζ<sub>min</sub> = 0.1 *(PA)*. Vehicles with supplied damping keep their values (eROD front range and passive; eROD rear passive) | ζ = 0.3 is the typical effective mean for passenger cars and 0.8 the upper end for optimum handling (Ślaski 2011, *Transport Problems* 6(2), full text read). ζ<sub>min</sub> = 0.1 is a project assumption below the ≈ 0.2 optimum-ride value, giving the controller a soft end; weaker support (search excerpt: optimal semi-active minimum ≈ 0.2 × passive) | Accepted | 2026-10-20 |

## D16 – Scaled variant targets

Status: **Accepted** · 2026-10-20 · Method: D15.

Inputs (m<sub>s</sub>, m<sub>u</sub>/m<sub>s</sub>, f<sub>body</sub>, f<sub>wheel</sub>)
are **project assumptions** (engineering estimates per vehicle class).
k<sub>s</sub> and k<sub>t</sub> are solved so the undamped 2-DOF quarter car
has exactly the target frequencies (softer-suspension root). Each variant is
labelled "scaled variant (project assumption)", not a real vehicle.

| Variant | m<sub>s</sub> [kg] | m<sub>u</sub>/m<sub>s</sub> | f<sub>body</sub> [Hz] | f<sub>wheel</sub> [Hz] | m<sub>u</sub> [kg] | k<sub>s</sub> [N/m] | k<sub>t</sub> [N/m] | Rationale |
|---|---|---|---|---|---|---|---|---|
| Small car | 190 | 0.16 | 1.35 | 12.0 | 30.4 | 14 989 | 157 621 | Light body → firmer, higher body frequency; light wheels |
| Sedan (reference) | 230 | 0.15 | 1.21 | 11.0 | 34.5 | 14 559 | 150 190 | Published values (D14), not scaled; listed for comparison |
| SUV | 420 | 0.14 | 1.15 | 10.5 | 58.8 | 24 259 | 231 342 | Heavy body tuned for comfort; large wheels → lower wheel frequency |
| Light van | 480 | 0.16 | 1.45 | 11.0 | 76.8 | 45 633 | 320 305 | Stiff springs for payload; heavy axle |
| eROD front / rear | – | – | – | – | – | – | – | Author-supplied private data, local only (D21); values not published |

Solver check: solving for the reference's own frequencies reproduces its
k<sub>s</sub> within 1 % (difference from rounding f<sub>wheel</sub> to 11.0 Hz).

Caveats:
- The van is a single load state; empty vs laden differ strongly. A "van laden"
  variant can be added later as a separate entry.
- Inputs are not validated against real vehicles; D15 replaces them with
  published data when found.
- Damping (c<sub>min</sub>, c<sub>max</sub>, c<sub>passive</sub>) is not part of
  this table; set per vehicle in M2 as project assumptions.

## Notes

- **D13, changing the reference vehicle:** switching is a one-line change, but
  requirement thresholds (REQ-P) and the regression baseline were derived for
  the old reference. After a switch they must be re-derived and re-run; record
  the switch as a new decision revision.
- **D12, eROD:** parameters supplied by the author (2026-10-20); publication
  not cleared, so kept local only (D21). If publication is cleared later,
  record it as a new decision with the full thesis reference before
  committing any eROD value.

## References

- Sayers, M. W. (1995). On the calculation of International Roughness Index
  from longitudinal road profile. *Transportation Research Record* 1501, 1–12.
  <https://onlinepubs.trb.org/Onlinepubs/trr/1995/1501/1501-001.pdf>
- Múčka, P. (2018). Simulated road profiles according to ISO 8608 in vibration
  analysis. *Journal of Testing and Evaluation* 46(1). [verify volume/pages
  against the published article]
- Ślaski, G. (2011). Damping parameters of suspension of passenger vehicle
  equipped with semi-active dampers with by-pass valve. *Transport Problems*
  6(2). <http://transportproblems.polsl.pl/pl/archiwum/2011/zeszyt2/2011t6z2_05.pdf>
