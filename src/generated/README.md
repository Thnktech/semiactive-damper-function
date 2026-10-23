# src/generated

Simulink Coder (GRT) C code of the controller, extracted with `packNGo`, goes
to `src/generated/controller/`. **That folder is git-ignored** (D10 rev.
2026-10-24): every generated file carries the MathWorks academic license
banner ("for use in teaching, academic research ... only"), which does not fit
this repository's MIT license. The code is therefore generated and tested
locally; it is not part of the MIT-licensed content.

| Step | Command (MATLAB) |
|---|---|
| Generate code + provenance | `generate_controller_code()` (refuses uncommitted changes) |
| Build, replay, record, report | `run_tests()` |

What reaches the repository is the **result**: `results/back_to_back.json`
(pass/fail per MiL log, maximum deviation, SHA-256 of model, parameter files
and logs). CI checks that this record still matches the committed model,
parameters and logs (`tests/python/test_back_to_back.py`, D28).
