"""Generated-code back-to-back (REQ-V-01): shared helpers and the local result record (M5).

    python src/python/back_to_back.py

replays every MiL log (tests/data/mil_*.csv) through the compiled generated
code (build/, see build_controller.py) and writes results/back_to_back.json.

Why a record: the generated code stays local (academic license banner, D10
rev. 2026-10-24), so CI cannot run the replay. The record is committed; CI
recomputes the SHA-256 of the model, parameter files and logs and checks
that they equal the record (tests/python/test_back_to_back.py). So CI proves
that the committed local result belongs to exactly the committed model.

The record is only written for code that matches the checked-out model and
parameters; otherwise the script stops with an error.
"""
import hashlib
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "tests" / "data"
GEN = ROOT / "src" / "generated" / "controller"
RECORD = ROOT / "results" / "back_to_back.json"
INPUTS = ["zs_dot", "zu_dot", "fault_flag", "mode"]
ATOL = RTOL = 1e-9          # REQ-V-01 acceptance (requirements/REQ.md)


def logs():
    """The MiL reference logs, sorted by name."""
    return sorted(DATA.glob("mil_*.csv"))


def read_log(csv):
    """MiL log with every number parsed EXACTLY. pandas' default CSV parser
    is fast but not correctly rounded: it turns e.g. '0.42999999999999994'
    into the neighbouring double 0.4299999999999999 (about 1 in 3 values of
    these logs). The logs are written with 17 digits so that they round-trip;
    float_precision='round_trip' keeps that promise."""
    return pd.read_csv(csv, float_precision="round_trip")


def sha256(path):
    """SHA-256 as in generate_controller_code.m: text files without CR bytes,
    so Windows and Linux checkouts give the same hash; .slx as is."""
    data = Path(path).read_bytes()
    if Path(path).suffix.lower() != ".slx":
        data = data.replace(b"\r", b"")
    return hashlib.sha256(data).hexdigest()


def compare(code, mil):
    """Per-log result: max |i_cmd| deviation, samples outside the tolerance,
    fault_active identical. `code` is (N, 2) from Controller.run, `mil` the log."""
    mil_i, mil_f = mil["i_cmd"].to_numpy(), mil["fault_active"].to_numpy()
    dev = np.abs(code[:, 0] - mil_i)
    outside = int(np.count_nonzero(dev > ATOL + RTOL * np.abs(mil_i)))
    fault_equal = bool(np.array_equal(code[:, 1], mil_f))
    return {"rows": len(mil), "max_abs_dev_i_cmd": float(dev.max()), "samples_outside_tolerance": outside,
            "fault_active_identical": fault_equal,
            "pass": len(code) == len(mil) and outside == 0 and fault_equal}


def git(*args):
    return subprocess.run(["git", "-C", str(ROOT), *args], capture_output=True, text=True, check=True).stdout.strip()


def main():
    from src.python.build_controller import FLAGS, find_gcc
    from src.python.controller_lib import Controller

    # 1. The code must belong to the checked-out model and parameters
    prov = json.loads((GEN / "provenance.json").read_text(encoding="utf-8"))
    if prov["git_dirty"]:
        sys.exit("Code was generated from uncommitted files: commit, then run generate_controller_code()")
    stale = [s["path"] for s in prov["sources"] if sha256(ROOT / s["path"]) != s["sha256"]]
    if stale:
        sys.exit(f"Changed since code generation: {stale}: run generate_controller_code() again")

    # 2. The logs must come from the same model content (mil_to_sil.md 5.1):
    #    no change to the model or parameter files between the logs' commit and now
    log_commits = {json.loads(p.with_suffix(".json").read_text(encoding="utf-8"))["git_commit"] for p in logs()}
    for c in log_commits:
        changed = git("diff", "--name-only", c, "HEAD", "--", *[s["path"] for s in prov["sources"]])
        if changed:
            sys.exit(f"Model/parameters changed since the MiL logs ({c[:7]}): {changed}: re-log MiL first")

    # 3. Replay every log
    ctrl = Controller()
    results = []
    for csv in logs():
        mil = read_log(csv)
        r = compare(ctrl.run(mil[INPUTS].to_numpy()), mil)
        results.append({"log": csv.relative_to(ROOT).as_posix(), "sha256": sha256(csv), **r})
        print(f"{csv.stem:13s} max |di_cmd| = {r['max_abs_dev_i_cmd']:.3g} A, "
              f"fault_active identical: {r['fault_active_identical']} -> {'PASS' if r['pass'] else 'FAIL'}")

    gcc = find_gcc()
    record = {
        "requirement": "REQ-V-01",
        "method": "generated-code back-to-back (GRT), open-loop replay of MiL logs (D7); run locally (D10 rev.)",
        "pass": all(r["pass"] for r in results),
        "tolerance": {"atol": ATOL, "rtol": RTOL},
        "recorded": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "git_commit": git("rev-parse", "HEAD"),
        "code_generated_from": prov["git_commit"],
        "matlab_release": prov["matlab_release"],
        "simulink_coder_version": prov["simulink_coder_version"],
        "compiler": subprocess.run([gcc, "--version"], capture_output=True, text=True).stdout.splitlines()[0],
        "compiler_flags": FLAGS,
        "sources": prov["sources"],
        "logs": results,
    }
    RECORD.parent.mkdir(exist_ok=True)
    RECORD.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8", newline="\n")   # LF as in git
    print(f"-> {RECORD.relative_to(ROOT).as_posix()}: {'PASS' if record['pass'] else 'FAIL'}")
    sys.exit(0 if record["pass"] else 1)


if __name__ == "__main__":
    sys.path.insert(0, str(ROOT))      # run as a script: make 'src.python' importable
    main()
