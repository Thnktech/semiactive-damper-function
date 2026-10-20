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

When: once after setting up CI, and after any major change to `ci.yml`.
Pass criterion: the run on `ci-try` is red at **Run pytest**. If it is green,
CI is not really running the tests.

| # | Where | Do | Signal | Why |
|---|---|---|---|---|
| 1 | Terminal | `git switch main` · `git status` | `On branch main`, `working tree clean` | Branch starts from clean `main`; uncommitted edits would travel along |
| 2 | Terminal | `git switch -c ci-try` | `Switched to a new branch 'ci-try'`; VS Code bottom-left shows `ci-try` | Experiment off `main`, so `main` and the badge stay green |
| 3 | `tests/python/test_smoke.py` | Change `(3, 10)` → `(9, 0)`, save | Optional: `pytest -q tests/python` → `1 failed` | A test that must fail |
| 4 | Terminal | `git commit -am "try CI fail"` | `1 file changed` | Commit exists only on `ci-try` |
| 5 | Terminal | `git push -u origin ci-try` (first push; later just `git push`) | `* [new branch] ci-try -> ci-try` | Push triggers CI; `-u` links the branch to GitHub |
| 6 | GitHub → Actions | Open the run labeled `ci-try` → **test** | 🟡 → ❌; **Run pytest** ❌ `1 failed`; earlier steps ✅; email | Proves CI runs the tests and can go red |
| 7 | GitHub → repo page | Look at the badge | Still `passing` | Badge tracks `main` only |
| 8 | Terminal | `git switch main` | `Switched to branch 'main'`; file shows `(3, 10)` again | Back to real work; broken version stays on `ci-try` |
| 9 | Terminal | `git branch -a` | `* main`, `ci-try`, `remotes/origin/ci-try` | Confirms which branch you are on and that `ci-try` is kept |

**Reuse later**

| Do | Command |
|---|---|
| Go to the test branch | `git switch ci-try` |
| Bring it up to date with `main` first | `git merge main` |
| Back to work | `git switch main` |
| Delete (optional) | `git branch -D ci-try` · `git push origin --delete ci-try` |

Rule: check you are on `main` before real work (`git status`, first line).

## Running the same checks locally

```bash
python -m venv .venv
# Windows: .venv\Scripts\activate    Linux/macOS: source .venv/bin/activate
pip install -r requirements.txt
pytest -q tests/python
```
