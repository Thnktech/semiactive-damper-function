"""REQ-V-01: the generated C code reproduces the MiL controller (M5).

Generated-code back-to-back (GRT), open-loop replay (D7): the inputs the
Simulink controller saw in the MiL harness (tests/data/mil_*.csv, written by
log_mil_reference.m) are fed sample by sample into the compiled generated
code; its outputs must equal the logged MiL outputs.

Acceptance (requirements/REQ.md, REQ-V-01), at every sample k:
    |i_cmd_code(k) - i_cmd_MiL(k)| <= atol + rtol * |i_cmd_MiL(k)|,  atol = rtol = 1e-9
    fault_active_code(k) == fault_active_MiL(k)
    same sample index k (no offset)

Where each test runs (D10 rev. 2026-10-24: generated code stays local):
    local only  replay, interface, re-initialization, code up to date
                (need src/generated/controller/ and build/; skipped without)
    everywhere  exact log parsing, and the committed local result
                results/back_to_back.json still matches model, parameters
                and logs (this is what CI checks)
"""
import json
import os
import re

import numpy as np
import pytest

from src.python.back_to_back import (ATOL, GEN, INPUTS, RECORD, ROOT, RTOL, compare, logs, read_log,
                                     sha256)
from src.python.controller_lib import LIB, U, Y, Controller

LOGS = logs()
IDS = [p.stem for p in LOGS]
LOCAL_ONLY = "generated code is kept local (academic license, D10 rev.); checked in CI via back_to_back.json"


# ---------- helpers ----------
@pytest.fixture(scope="module")
def ctrl():
    """The compiled controller, loaded once (one global instance per process)."""
    if not (GEN / "controller.h").exists():
        pytest.skip(LOCAL_ONLY)
    if not LIB.exists():
        pytest.skip(f"{LIB.name} not built: run python src/python/build_controller.py")
    return Controller()


def record_evidence(req, test, quantity, value, unit):
    """Same as tests/matlab/record_evidence.m: one JSON line for the
    traceability report, only when run_tests sets EVIDENCE_FILE."""
    f = os.environ.get("EVIDENCE_FILE")
    if f:
        with open(f, "a", encoding="utf-8") as fh:
            fh.write(json.dumps({"req": req, "test": test, "quantity": quantity,
                                 "value": value, "unit": unit}) + "\n")


def first_deviation(code, mil, t):
    """Readable message for the first sample outside the tolerance, with a
    hint whether the code is exactly one sample early or late (alignment
    error, docs/mil_to_sil.md section 6) rather than numerically different."""
    bad = np.flatnonzero(np.abs(code - mil) > ATOL + RTOL * np.abs(mil))
    if bad.size == 0:
        return None
    k = bad[0]
    msg = (f"{bad.size} samples outside {ATOL:g} + {RTOL:g}*|MiL|; first at k = {k} (t = {t[k]:.3f} s): "
           f"code {code[k]:.17g} vs MiL {mil[k]:.17g}")
    if np.allclose(code[1:], mil[:-1], rtol=RTOL, atol=ATOL):
        msg += ". Code is exactly ONE SAMPLE LATE: check output registration / step order"
    elif np.allclose(code[:-1], mil[1:], rtol=RTOL, atol=ATOL):
        msg += ". Code is exactly ONE SAMPLE EARLY: check input alignment of the log"
    return msg


# ---------- local only: the replay ----------
@pytest.mark.parametrize("csv", LOGS, ids=IDS)
def test_REQ_V_01_generated_code_matches_mil(ctrl, csv):
    """The back-to-back itself: replay one MiL log through the generated code."""
    mil = read_log(csv)
    y = ctrl.run(mil[INPUTS].to_numpy())
    r = compare(y, mil)
    record_evidence("REQ-V-01", f"pytest: test_REQ_V_01_generated_code_matches_mil[{csv.stem}]",
                    f"max |i_cmd code - MiL| ({csv.stem[4:]})", r["max_abs_dev_i_cmd"], "A")

    t = mil["t"].to_numpy()
    assert len(y) == len(mil), "code produced a different number of samples"
    msg = first_deviation(y[:, 0], mil["i_cmd"].to_numpy(), t)
    assert msg is None, f"{csv.stem}: i_cmd: {msg}"
    wrong = np.flatnonzero(y[:, 1] != mil["fault_active"].to_numpy())
    assert wrong.size == 0, (f"{csv.stem}: fault_active differs in {wrong.size} samples, first at "
                             f"k = {wrong[0]} (t = {t[wrong[0]]:.3f} s)")


def test_REQ_V_01_interface_matches_header():
    """ctypes maps struct fields by POSITION. If the generated controller.h
    lists the inputs in another order (e.g. after a port was moved in the
    model), the wrapper would silently feed zu_dot into zs_dot. This test
    reads both structs from the header and compares them with the wrapper."""
    if not (GEN / "controller.h").exists():
        pytest.skip(LOCAL_ONLY)
    h = (GEN / "controller.h").read_text(encoding="utf-8")
    for struct, wrapper in (("ExtU_controller_T", U), ("ExtY_controller_T", Y)):
        # [^{}]* : the struct body itself, not from an earlier struct onwards
        body = re.search(r"typedef struct \{([^{}]*)\}\s*" + struct + ";", h)
        assert body, f"{struct} not found in controller.h"
        fields = re.findall(r"^\s*(\w+)\s+(\w+);", body.group(1), re.M)   # (type, name)
        assert fields == [("real_T", n) for n, _ in wrapper._fields_], (
            f"{struct} in controller.h is {fields}; wrapper expects {[n for n, _ in wrapper._fields_]} "
            f"(all real_T = double)")


def test_REQ_V_01_initialize_resets_state(ctrl):
    """Every replay must start from k = 0 like the MiL run. SC-FAULT ends
    with the fault latch set; a following replay of SC-C80 must still start
    with fault_active = 0 and match its log, so controller_initialize()
    really resets every state (latch, previous current)."""
    fault = read_log(ROOT / "tests" / "data" / "mil_SC-FAULT.csv")
    c80 = read_log(ROOT / "tests" / "data" / "mil_SC-C80.csv")
    y1 = ctrl.run(fault[INPUTS].to_numpy())
    assert y1[-1, 1] == 1, "SC-FAULT should end latched"
    y2 = ctrl.run(c80[INPUTS].to_numpy()[:1000])
    np.testing.assert_array_equal(y2[:, 1], c80["fault_active"].to_numpy()[:1000],
                                  err_msg="latch survived controller_initialize()")
    np.testing.assert_allclose(y2[:, 0], c80["i_cmd"].to_numpy()[:1000], rtol=RTOL, atol=ATOL)
    np.testing.assert_array_equal(ctrl.run(fault[INPUTS].to_numpy()), y1,
                                  err_msg="two replays of the same log differ")


def test_REQ_V_01_code_up_to_date():
    """The local generated code must belong to the checked-out model: the
    SHA-256 of controller.slx and of the parameter files recorded at
    generation time must equal the files now. Fails when the model or a
    parameter was changed without running generate_controller_code() again."""
    if not (GEN / "provenance.json").exists():
        pytest.skip(LOCAL_ONLY)
    prov = json.loads((GEN / "provenance.json").read_text(encoding="utf-8"))
    assert prov["git_dirty"] is False, "code was generated from uncommitted files"
    assert re.fullmatch(r"[0-9a-f]{40}", prov["git_commit"]), "git_commit must be a full SHA-1"
    stale = [s["path"] for s in prov["sources"] if sha256(ROOT / s["path"]) != s["sha256"]]
    assert not stale, f"changed since code generation: {stale}: run generate_controller_code()"
    vehicles = {json.loads(p.with_suffix(".json").read_text(encoding="utf-8"))["vehicle"] for p in LOGS}
    assert vehicles == {prov["vehicle"]}, f"code parameters for {prov['vehicle']}, logs for {vehicles}"


# ---------- everywhere (CI) ----------
@pytest.mark.parametrize("csv", LOGS, ids=IDS)
def test_REQ_V_01_logs_parsed_exactly(csv):
    """Guard for read_log: every number must equal Python's float() of the
    text in the file (float() is correctly rounded). With pandas' default
    parser this fails for thousands of values, and the back-to-back would
    compare the code against slightly wrong reference values."""
    df = read_log(csv)
    lines = csv.read_text(encoding="utf-8").splitlines()[1:]
    exact = np.array([[float(v) for v in line.split(",")] for line in lines])
    wrong = np.argwhere(df.to_numpy() != exact)
    assert wrong.size == 0, (f"{csv.stem}: {len(wrong)} values parsed inexactly, first row {wrong[0][0]}, "
                             f"column {df.columns[wrong[0][1]]}")


def test_REQ_V_01_local_result_up_to_date():
    """What CI can check without the generated code: the committed result of
    the local back-to-back (results/back_to_back.json, written by
    src/python/back_to_back.py) passed, used the REQ-V-01 tolerance, and
    belongs to exactly the model, parameter files and logs of this checkout
    (SHA-256). Changing any of them without re-running the local
    back-to-back makes this test fail."""
    assert RECORD.exists(), "results/back_to_back.json missing: run run_tests() in MATLAB"
    rec = json.loads(RECORD.read_text(encoding="utf-8"))
    assert rec["pass"] is True, "the recorded local back-to-back failed"
    assert rec["tolerance"] == {"atol": ATOL, "rtol": RTOL}, f"recorded tolerance {rec['tolerance']}"
    stale = [s["path"] for s in rec["sources"] if sha256(ROOT / s["path"]) != s["sha256"]]
    assert not stale, f"changed since the local back-to-back: {stale}: regenerate code and run run_tests()"
    recorded = {r["log"]: r for r in rec["logs"]}
    current = {p.relative_to(ROOT).as_posix() for p in LOGS}
    assert set(recorded) == current, f"recorded logs {sorted(recorded)} differ from {sorted(current)}"
    changed = [f for f in current if sha256(ROOT / f) != recorded[f]["sha256"]]
    assert not changed, f"logs changed since the local back-to-back: {changed}"
    assert all(r["pass"] for r in rec["logs"]), "a recorded log did not pass"
