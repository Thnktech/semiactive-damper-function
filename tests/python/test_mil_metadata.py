"""REQ-V-02: every MiL reference log carries complete provenance metadata.

Runs in CI (no MATLAB). Each tests/data/mil_<scenario>.csv must have a
mil_<scenario>.json produced by src/matlab/log_mil_reference.m.
"""
import json
import re
from pathlib import Path

import numpy as np
import pandas as pd
import pytest

DATA = Path(__file__).resolve().parents[1] / "data"
LOGS = sorted(DATA.glob("mil_*.csv"))
COLUMNS = ["t", "zs_dot", "zu_dot", "fault_flag", "mode", "i_cmd", "fault_active"]
# Fields without which a log cannot be traced to the model version and
# scenario that produced it (REQ-V-02 acceptance).
REQUIRED = ["scenario", "vehicle", "git_commit", "model", "sample_time_s",
            "matlab_release", "generated", "rows", "columns", "road", "mode_schedule"]


# Without logs every parametrized test below would silently run zero times.
def test_reference_logs_exist():
    assert LOGS, "no tests/data/mil_*.csv: run log_mil_reference in MATLAB"


@pytest.mark.parametrize("csv", LOGS, ids=[p.stem for p in LOGS])
def test_REQ_V_02_metadata_complete(csv):
    meta_file = csv.with_suffix(".json")
    assert meta_file.is_file(), f"{meta_file.name} missing"
    meta = json.loads(meta_file.read_text(encoding="utf-8"))
    missing = [k for k in REQUIRED if meta.get(k) in (None, "", [], {})]
    assert not missing, f"{meta_file.name}: empty or missing fields {missing}"
    assert re.fullmatch(r"[0-9a-f]{40}", meta["git_commit"]), "git_commit must be a full SHA-1"
    # A log from uncommitted code names a commit that did not produce it.
    assert meta["git_dirty"] is False, "log was produced from uncommitted code"
    assert csv.stem == f"mil_{meta['scenario']}", "file name and scenario differ"
    # Logs are public: private eROD data must never end up in them (D21).
    assert "erod" not in meta["vehicle"].lower(), "private vehicle data must not be logged (D21)"
    assert meta["sample_time_s"] == pytest.approx(1e-3)


@pytest.mark.parametrize("csv", LOGS, ids=[p.stem for p in LOGS])
# The metadata must describe the file it belongs to: columns, row count, 1 ms
# steps from t = 0. Tolerance 1e-9 on the steps, so pandas' default parser is
# good enough here (exact parsing matters for the back-to-back, D28).
def test_log_matches_its_metadata(csv):
    meta = json.loads(csv.with_suffix(".json").read_text(encoding="utf-8"))
    df = pd.read_csv(csv)
    assert list(df.columns) == COLUMNS == meta["columns"]
    assert len(df) == meta["rows"]
    t = df["t"].to_numpy()
    assert t[0] == 0.0
    np.testing.assert_allclose(np.diff(t), 1e-3, atol=1e-9, err_msg="rows must be 1 ms apart")
