# Changelog

All notable changes to this project are recorded here, one line per commit.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Version plan: each completed milestone is tagged as a minor release
(M0 → `v0.1.0`, M1 → `v0.2.0`, … M5 → `v0.6.0`); M6 completes the project as `v1.0.0`.

## [Unreleased]

### Added
- M5 tools: `src/matlab/generate_controller_code.m` (GRT code generation with
  settings applied in memory only, `packNGo`, provenance with SHA-256 of model
  and parameter files; restores the workspace `P`), `src/python/build_controller.py`
  (gcc `-O2 -ffp-contract=off`, finds MATLAB's MinGW-w64, rejects 32-bit gcc),
  `src/python/controller_lib.py` (ctypes wrapper), `src/python/back_to_back.py`
  (replay of all MiL logs → `results/back_to_back.json`), `conftest.py`.
- `tests/python/test_back_to_back.py`: REQ-V-01 replay per log, header/wrapper
  interface, re-initialization, code up to date, exact log parsing, committed
  record matches model, parameters and logs (CI).
- Decisions D27 (code-generation settings) and D28 (back-to-back evidence and
  CI); `docs/mil_to_sil.md` rules 5.5/5.6 and M5 workflow.

### Changed
- D10 revised: generated code is git-ignored (MathWorks academic license
  banner); README licensing note, `src/generated/README.md`.
- `run_tests.m`: builds the generated code and writes the back-to-back record
  before pytest.

## [0.5.0] - 2026-10-23

M4: requirement-based verification and traceability.

### Added
- `results/traceability.md` generated at 07cbfd7: 11 Pass, 1 Fail (known,
  REQ-P-02), 1 Unverified (REQ-V-01, closed in M5).
- M4 start: requirement tags on every functional and safety test
  (REQ-F-01…05, REQ-S-01/02; 17 tests), REQ-F-05 input sweep incl.
  v_rel in [-2ε, 2ε] in every mode, REQ-F-02 on logged time steps.
- `tests/matlab/record_evidence.m`: tests record measured values for the
  traceability report (active only when run by the report script).
- `tests/matlab/TestPerformance.m`: REQ-P-01 (18.9 % comfort gain), REQ-P-02
  (+31.0 % tire load, tagged KnownFail), REQ-P-03 (66.3 mm on the bump),
  REQ-P-04 (all public vehicles, smallest gain 16.0 %); measured values
  recorded as evidence.
- `tests/matlab/TestPlausibility.m`: flat road → no motion in every mode,
  damper only dissipates (power ≥ 0, damping within [c_min, c_max]),
  regression of C80 KPIs against the committed comparison.
- `.gitignore`: local research material (`docs/ResearchInfo/`) and raw test
  output (`results/test/`).
- `src/matlab/run_tests.m`: runs all MATLAB tests (KnownFail included) and
  pytest, exports JUnit XML, links tests to requirements by tag / name and
  writes `results/traceability.md` (verdict, measured values, commit);
  `run_tests('dev')` runs without KnownFail. REQ.md points to the report.

### Changed
- REQ-F-02 log evidence recorded in s (same unit as the acceptance).
- `my_study.m`: example study name set to `Test`.
- Commit history rewritten: attribution trailers removed from all commit
  messages (all commit IDs and tags changed).
- MiL reference log metadata regenerated: `git_commit` now points to the
  rewritten v0.4.0 commit; logged data byte-identical.

### Fixed
- v0.4.0 notes: TestSafety has 8 tests (not 9).

## [0.4.0] - 2026-10-22

M3: controller and MiL harness.

### Added
- Controller skeleton `model/controller/controller.slx` (built by the author):
  `Control_law` (placeholder passive) → `Damping_to_current` (clip, inverse
  damper map) → `Safety_and_limits` (placeholder) → registered outputs.
- Decision D24: one controller with extensible law slots; laws output
  requested damping `c_req`.
- `tests/matlab/TestController.m`: interface, types, discrete 1 ms solver,
  REQ-F-03 initial output, D19 delay, passive current, no plant parameters,
  no logging blocks (9 tests).
- MiL harness `model/harness/harness.slx` (built by the author): plant and
  controller as Model blocks, road and fault from workspace (`road_in`,
  `fault_in`, held after the last value), `mode_sel` parameter, 9 logged
  outputs (3 KPI signals + 6 controller I/O signals).
- `tests/matlab/TestHarness.m`: references, outputs, solver, passive closed
  loop vs M2 baseline, mode by parameter, controller I/O logged every ms,
  fault pulse not smoothed (7 tests).
- Decision D25: control-law parameters c_sky, c_gnd, alpha, eps with
  literature check; added to `setup_params.m`.
- `Law_1_Skyhook` (built by the author): semi-active skyhook with eps guard
  and safe division; Multiport Switch on `mode` (indices [0 1], default →
  passive) with an integer check; `tests/matlab/TestControlLaws.m` (9 tests,
  hand-computed points, REQ-F-05, mode routing).
- `tests/matlab/reference_closed_loop.m`: independent plain-MATLAB closed
  loop (RK4 plant, discrete delayed controller) used as oracle by
  `TestHarness` (closed loop vs reference, no algebraic loop).
- Decision D26: minimize artificial algebraic loops in the controller model
  (fixes up to 1.3 A deviations); explicit integer check for `mode`.
- `Law_2_Groundhook` and `Law_3_Hybrid` (built by the author); Multiport
  indices [0 1 2 3]; hybrid and groundhook tests (α = 1 → skyhook,
  α = 0 → groundhook, blend, inactive part = 0), slot-naming test, closed
  loop vs reference in all four modes.
- `setup_params.m`: `P.dI_max` = 0.13 A per step (REQ-F-04 rate limit).
- `Safety_and_limits` (built by the author): current saturation, rate limit
  (feedback of the previous `i_cmd`), fault latch (feedback of the previous
  `fault_active`), fault target I_default; `fault_active` is double.
- `tests/matlab/TestSafety.m`: REQ-F-01, REQ-F-04, REQ-S-01 (measured 5 ms),
  REQ-S-02, fault at step 0 (8 tests, tagged with requirement IDs).
- Reference closed loop extended with saturation, rate limit and fault latch;
  `TestHarness` closed loop with mid-run fault; `TestController` checks both
  outputs are double.
- Harness `Mode` from workspace (`mode_in`, held, no interpolation): constant
  or scheduled mode per run.
- `src/matlab/simulate_harness.m` and `src/matlab/run_comparison.m` (written
  by the author): passive, skyhook, groundhook, hybrid on the 9 baseline
  scenarios → `results/comparison/kpi_comparison_sedan_ref.csv` and 2 plots.
- `tests/matlab/TestComparison.m` (completeness, passive = M2 baseline,
  deltas, file names, no hard-coded paths); mode-schedule test in
  `TestHarness`; reference closed loop accepts a mode per sample.
- Flexible study runner: `src/matlab/my_study.m` (edit roads, strategies,
  vehicle, duration, time plots), `src/matlab/run_study.m` (runs every
  combination, passive always added, CSV, Markdown summary, delta bars,
  trade-off and time plots), `src/matlab/law_names.m` (strategy names read
  from the controller's Law_<n>_<Name> slots); results in `results/studies/`
  (git-ignored); `tests/matlab/TestStudy.m` (6 tests).
- `results/comparison/comparison_sedan_ref.md`: summary table and the
  author's interpretation (incl. REQ-P-02 failing for skyhook).
- `src/matlab/log_mil_reference.m`: MiL reference logs for M5 (SC-C80 with
  every law slot and invalid modes, SC-BUMP, SC-FAULT with pulse and
  toggling); refuses uncommitted code; CSV `%.17g` + JSON metadata.
- `tests/matlab/TestMilLogs.m` (bit-exact controller replay of every log,
  log rules, coverage) and `tests/python/test_mil_metadata.py` (REQ-V-02,
  runs in CI).
- MiL reference logs `tests/data/mil_SC-C80`, `mil_SC-BUMP`, `mil_SC-FAULT`
  (CSV + JSON).

### Changed
- `interface/signals.md`: mode table maps modes to law slots; slots 3…N
  reserved for additional strategies; how to add one.
- Mode mapping: 2 = groundhook, 3 = hybrid (was 2), first free slot 4;
  logged in `signals.md`; D20 revised to "any value without a law slot".
- `run_baseline.m`: explanatory comments (no logic change); baseline re-run,
  KPI CSV identical (reproducible), plots re-rendered.
- `.gitignore`: local-only milestone reports (`docs/milestones/`).

### Fixed
- REQ.md: t_react rationale (5 samples, not 5 + 1); threshold unchanged.

## [0.3.0] - 2026-10-22

M2: plant, passive baseline, roads, KPIs.

### Added
- Passive baseline: `src/matlab/simulate_plant.m`, `src/matlab/run_baseline.m`
  (roads A–D at 50/80 km/h and SC-BUMP, passive current `P.I_passive`),
  results `results/baseline/kpi_baseline_sedan_ref.csv` and 3 plots, and
  `tests/matlab/TestBaseline.m` (6 tests).
- Model-referencing setup, controller I/O tables and harness wiring in
  `docs/mil_to_sil.md` (section 0).
- Decision D21: private vehicle data (eROD) kept local only; `.gitignore`
  rules for `src/matlab/vehicles/private/` and eROD-derived results.
- MATLAB Project `semiactive-damper-function.prj` (+ `resources/project/`)
  that puts `src/matlab`, `src/matlab/vehicles`, `model/*` and
  `tests/matlab` on the path when opened.
- Vehicle parameter files (`src/matlab/vehicles/`: `sedan_ref`, `small_car`,
  `suv`, `light_van`), common struct, D16 solver, selector `get_vehicle` with
  clear error for missing private vehicles, `project_config.m`, natural
  frequency function, `tests/matlab/TestVehicles.m`, and
  `results/vehicles/vehicle_overview.csv` (public vehicles only).
- Decision D22: damping values from body-mode damping ratio (0.1 / 0.3 / 0.8).
- `.gitignore` entries for personal learning PDFs in `docs/` (kept local only).
- Plant model `model/plant/plant.slx`, built by hand: quarter car with gravity
  preloads, tire lift-off, damper map and actuator lag; decision D23.
- `src/matlab/setup_params.m`: shared parameter struct `P` (vehicle + current
  range, actuator lag, preloads, static tire load).
- `tests/matlab/TestPlant.m`: interface, solver, rest, poles vs analytic
  quarter car for all public vehicles, road-step signs, current effect,
  tire lift-off (10 tests).
- Road generators `src/matlab/road_iso8608.m` (ISO 8608-based random road,
  classes A–D, harmonic superposition with fixed seed and frequencies
  randomized inside each bin, 1 s fade-in) and `src/matlab/road_bump.m`
  (half-sine bump, SC-BUMP); `tests/matlab/TestRoads.m` (band power vs
  target PSD, class scaling, seeds, distance-based profile, no repetition,
  bump geometry; 12 tests).
- KPI function `src/matlab/kpi.m` (RMS body acceleration and dynamic tire
  load over t ≥ 2 s, normalized tire load, max suspension travel in mm) and
  `tests/matlab/TestKPI.m` (known-answer and error cases; 8 tests).

### Changed
- REQ.md SC-BUMP shape wording: half-cosine → half-sine (logged in REQ.md).

## [0.2.0] - 2026-10-20

M1: requirements and signal interface.

### Added
- `interface/signals.md`: controller I/O (order, unit, type, rate, range,
  init), sign convention, mode semantics, input handling; decisions D19
  (registered outputs) and D20 (invalid mode → passive).
- `docs/mil_to_sil.md`: MiL modelling and logging rules for the
  generated-code back-to-back.
- `docs/DECISIONS.md` (D1–D15: scope, toolchain, vehicle set and switching,
  proposed reference-vehicle parameters) and `docs/DEVLOG.md`.
- Manual **Run workflow** trigger (`workflow_dispatch`) in CI, and a
  "run and check CI yourself" section in `docs/ci.md`.
- CI self-test procedure (deliberate red run on a throwaway branch) in
  `docs/ci.md`.
- Draft requirements `requirements/REQ.md`: REQ-F-01…05, REQ-P-01…04 with
  literature check of every threshold.
- Requirements primer (`docs/requirements_primer.md`).
- Safety and verification requirements REQ-S-01/02, REQ-V-01/02 and fault
  scenario SC-FAULT; decisions D17 (fault transition) and D18 (fault reset).
- Verification ladder (MiL → SiL → PIL → HiL) in `docs/ci.md`.

### Changed
- CI self-test rewritten as a cheatsheet (where / do / signal / why); the
  test branch is kept for reuse instead of deleted.
- D14 (reference sedan, Golden Car ratios) accepted; D15 (scaled variants,
  replaced by published data when found) accepted.
- D16 scaled variant targets (small car, SUV, light van) added to
  `docs/DECISIONS.md`.
- `requirements/REQ.md` baselined; REQ-F-03 reworded for registered outputs.
- README: M1 marked done.

## [0.1.0] - 2026-10-20

M0: repository skeleton and CI.

### Added
- Folder structure with a purpose `README.md` per folder, `.gitignore`,
  `.gitattributes` (LF line endings) and MIT `LICENSE`.
- This changelog.
- README skeleton with honest status table, `requirements.txt`
  (numpy, pandas, pytest) and Python smoke test.
- `.gitignore` entries for local planning documents.
- GitHub Actions CI workflow (`.github/workflows/ci.yml`) running pytest on
  Python 3.11, and `docs/ci.md` explaining CI and the smoke test.
- CI badge in the README; M0 marked done.

### Fixed
- Removed a nested-repo link (`semiactive-damper-function`) committed by mistake.

[Unreleased]: https://github.com/Thnktech/semiactive-damper-function/compare/v0.5.0...HEAD
[0.5.0]: https://github.com/Thnktech/semiactive-damper-function/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/Thnktech/semiactive-damper-function/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/Thnktech/semiactive-damper-function/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/Thnktech/semiactive-damper-function/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/Thnktech/semiactive-damper-function/releases/tag/v0.1.0
