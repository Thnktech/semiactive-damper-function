# Continuous Integration (CI)

## What CI is

Continuous Integration means every push to GitHub is checked automatically.
GitHub Actions starts a fresh Linux machine, checks out the repository,
installs the dependencies from `requirements.txt` and runs the test suite.
The result, pass or fail, is shown on the commit, in the **Actions** tab and
in the badge at the top of the README.

The recipe is [`.github/workflows/ci.yml`](../.github/workflows/ci.yml).

Analogy: an independent test bench. If the code passes on a clean machine
that has never seen the developer's laptop, the result does not depend on
local files, local settings or a local MATLAB installation.

## Why this project uses CI

CI is the only part of the verification chain that runs **without MATLAB**:

| Stage | What CI checks | Requirement |
|---|---|---|
| M0 (now) | Python environment installs and the smoke test passes | – |
| M5 | Generated C code (Simulink Coder, GRT) builds with gcc, and replaying logged MiL controller inputs reproduces the MiL outputs | REQ-V-01 |

Running this on every push means the claim "the generated code matches the
model" is re-checked automatically after every change, not only on the
developer's machine.

What CI does **not** do: run Simulink, run the MiL tests, or prove real-time
behavior. MATLAB-based tests run locally (see the README, *CI vs local
verification*).

## Smoke test

[`tests/python/test_smoke.py`](../tests/python/test_smoke.py) checks only
that the Python version is 3.10 or newer.

The name comes from hardware testing: power the device on and check that
nothing smokes. It proves nothing about the damper function. It proves the
test infrastructure works: the workflow triggers, Python installs, the
dependencies install, `pytest` finds and runs tests, and the result is
reported. When the real back-to-back tests arrive in M5, the plumbing is
already known to work, so any failure points at the tests or the code, not
at the CI setup.

## Running the same checks locally

```bash
python -m venv .venv
# Windows: .venv\Scripts\activate    Linux/macOS: source .venv/bin/activate
pip install -r requirements.txt
pytest -q tests/python
```
