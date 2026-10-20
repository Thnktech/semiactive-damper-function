# Changelog

All notable changes to this project are recorded here, one line per commit.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Version plan: each completed milestone is tagged as a minor release
(M0 → `v0.1.0`, M1 → `v0.2.0`, … M5 → `v0.6.0`); M6 completes the project as `v1.0.0`.

## [Unreleased]

### Added
- Implementation guide (`IMPLEMENTATION_GUIDE.md`, PDF copy in `docs/`) and this changelog.
- Folder structure with a purpose `README.md` per folder, `.gitignore`,
  `.gitattributes` (LF line endings) and MIT `LICENSE`.
- README skeleton with honest status table, `requirements.txt`
  (numpy, pandas, pytest) and Python smoke test.
- GitHub Actions CI workflow (`.github/workflows/ci.yml`) running pytest on
  Python 3.11, and `docs/ci.md` explaining CI and the smoke test.

### Removed
- Implementation guide (`.md` and PDF) from version control; kept local only
  and listed in `.gitignore`.

### Fixed
- Removed a nested-repo link (`semiactive-damper-function`) committed by mistake.

[Unreleased]: https://github.com/Thnktech/semiactive-damper-function/commits/main
