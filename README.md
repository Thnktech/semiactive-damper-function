# Semi-Active Damper Function

Requirements-driven development of a semi-active suspension damper controller:
from requirements through Simulink model-in-the-loop (MiL) verification to
generated C code verified back-to-back in a MATLAB-free CI pipeline.

> **Status: in development.** Nothing below is implemented yet unless the
> status table says so. There are no results yet.

## Problem

A passive damper fixes one trade-off between ride comfort and road holding.
A semi-active damper can change its damping in real time but can only
dissipate energy, so the control law has to respect that limit.

## Objectives

- Write measurable requirements for the damper control function, with
  thresholds marked as project assumptions.
- Model a quarter-car plant and verify a passive baseline on ISO 8608-based
  road profiles and a bump.
- Implement passive, skyhook and hybrid skyhook–groundhook control in Simulink
  under identical test inputs.
- Link every requirement to an automated test with a pass/fail verdict.
- Generate C code (Simulink Coder, GRT) and verify it back-to-back against the
  MiL controller in CI, without MATLAB.

## Architecture (planned)

Requirements → controller model → harness/plant → MiL logs → code generation
→ gcc build → pytest back-to-back → GitHub Actions CI.

A diagram will be added in M6.

## Workflow

| Step | Where | Tool |
|---|---|---|
| Plant + controller MiL, KPI analysis, `matlab.unittest` | Local | MATLAB/Simulink |
| Code generation, `packNGo`, MiL reference logging | Local | Simulink Coder |
| gcc build of generated code, Python `ctypes` replay, `pytest` | Local + CI | Python, gcc |

## Results (pending)

No results yet. Every number here will come from a file committed under
`results/`.

## Setup

Python side (no MATLAB needed):

```bash
python -m venv .venv
# Windows: .venv\Scripts\activate    Linux/macOS: source .venv/bin/activate
pip install -r requirements.txt
pytest -q tests/python
```

MATLAB steps will be added once the models exist (M2–M3).

## CI vs local verification

| Verified | Local (MATLAB) | CI (no MATLAB) |
|---|---|---|
| Python smoke test | ✓ | planned (M0) |
| MiL requirement tests | planned (M4) | – |
| Generated-code back-to-back (REQ-V-01) | planned (M5) | planned (M5) |

## Limitations

This project does **not** demonstrate real-time execution, hardware
integration, functional safety or production validation. Sensor signals are
ideal velocities (no state estimation), and fault detection is an external
input: only the reaction to a fault is verified.

## Toolchain

MATLAB R2026a (26.1) · Simulink · MATLAB Coder · Simulink Coder (no Embedded
Coder) · Python 3.11 · gcc

## Status

| Milestone | Content | Status |
|---|---|---|
| M0 | Repository skeleton and CI | In progress |
| M1 | Requirements and signal interface | Planned |
| M2 | Plant, passive baseline, roads, KPIs | Planned |
| M3 | Controller and MiL harness | Planned |
| M4 | Requirement-based verification | Planned |
| M5 | Generated-code back-to-back (GRT) | Planned |
| M6 | Documentation, sensitivity, release | Planned |

## License

[MIT](LICENSE)
