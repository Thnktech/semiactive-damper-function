# Changelog

All notable changes to this project are recorded here, one line per commit.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Version plan: each completed milestone is tagged as a minor release
(M0 → `v0.1.0`, M1 → `v0.2.0`, … M5 → `v0.6.0`); M6 completes the project as `v1.0.0`.

## [Unreleased]

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
- One-page PDF of the CI self-test cheatsheet
  (`docs/ci_selftest_cheatsheet.pdf`).
- Draft requirements `requirements/REQ.md`: REQ-F-01…05, REQ-P-01…04 with
  literature check of every threshold.
- Requirements primer (`docs/requirements_primer.md` + PDF) and one-page
  `docs/requirements_cheatsheet.pdf`.
- Safety and verification requirements REQ-S-01/02, REQ-V-01/02 and fault
  scenario SC-FAULT; decisions D17 (fault transition) and D18 (fault reset).
- Verification ladder (MiL → SiL → PIL → HiL) in `docs/ci.md` and one-page
  `docs/verification_ladder.pdf`.

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

[Unreleased]: https://github.com/Thnktech/semiactive-damper-function/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/Thnktech/semiactive-damper-function/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/Thnktech/semiactive-damper-function/releases/tag/v0.1.0
