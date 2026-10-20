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

## How the workflow file maps to a run

| Line in `ci.yml` | What GitHub does |
|---|---|
| `on: [push, pull_request, workflow_dispatch]` | Start a run on every push, every pull request, or when **Run workflow** is clicked |
| `runs-on: ubuntu-latest` | Rent a fresh Ubuntu virtual machine; it is deleted after the run |
| `actions/checkout` | Download this repository at the pushed commit |
| `actions/setup-python` with `3.11` | Install Python 3.11 |
| `pip install -r requirements.txt` | Install numpy, pandas, pytest |
| `pytest -q tests/python` | Run the tests. Any failing test → exit code ≠ 0 → run fails |

Every step must succeed for the run to pass. The first failing step stops the
run and is marked with a red cross.

## Run and check CI yourself

**Start a run**

- Push any commit (`git push`), or
- GitHub → **Actions** → **ci** (left sidebar) → **Run workflow** → branch
  `main` → **Run workflow**, or
- Open an existing run → **Re-run all jobs**.

**See that it is running**

- Actions tab: the newest run has a yellow spinning circle.
- Click the run → job **test** → each step's log appears live.
- A run takes about 30–60 s.

**Read the result**

| Result | Actions / commit icon | README badge |
|---|---|---|
| Passed | green tick | `ci: passing` |
| Failed | red cross | `ci: failing` (GitHub also emails you) |

On failure, open the run → job → the step marked with a red cross; for a test
failure the end of the `pytest` log names the test and the reason.

**From the terminal** (after `gh auth login` once): `gh run list`,
`gh run watch`, `gh run view --log-failed`.

## CI self-test: prove a red run is possible

A green tick only means something if the pipeline can also go red. Run this
once after setting up CI, and again after any major change to `ci.yml`. Use a
throwaway branch so `main` and the badge stay green.

| # | Do | Expected |
|---|---|---|
| 1 | `git switch -c ci-try` | New local branch |
| 2 | In `tests/python/test_smoke.py` change `(3, 10)` to `(9, 0)` | Test now demands Python 9 |
| 3 | `git commit -am "try CI fail"` then `git push -u origin ci-try` | Run for `ci-try` appears in Actions |
| 4 | Open the run → job **test** | Steps up to install ✅, **Run pytest** ❌ with `1 failed` and the failing assert; email notification |
| 5 | Change `(9, 0)` back to `(3, 10)`; `git commit -am "try CI pass"`; `git push` | New run ✅ |
| 6 | `git switch main`, `git branch -D ci-try`, `git push origin --delete ci-try` | Branch removed locally and on GitHub |

Pass criterion: step 4 is red at the pytest step and step 5 is green. If step 4
is green, CI is not actually running the tests; fix `ci.yml` before trusting
any badge.

## Running the same checks locally

```bash
python -m venv .venv
# Windows: .venv\Scripts\activate    Linux/macOS: source .venv/bin/activate
pip install -r requirements.txt
pytest -q tests/python
```
