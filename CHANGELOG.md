# Changelog

All notable changes to this project are recorded here, one line per commit.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Version plan: each completed milestone is tagged as a minor release
(M0 → `v0.1.0`, M1 → `v0.2.0`, … M5 → `v0.6.0`); M6 completes the project as `v1.0.0`.

## [Unreleased]

### Changed
- `run_baseline.m`: explanatory comments (no logic change); baseline re-run,
  KPI CSV identical (reproducible), plots re-rendered.
- `.gitignore`: local-only milestone reports (`docs/milestones/`).

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

[Unreleased]: https://github.com/Thnktech/semiactive-damper-function/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/Thnktech/semiactive-damper-function/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/Thnktech/semiactive-damper-function/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/Thnktech/semiactive-damper-function/releases/tag/v0.1.0
