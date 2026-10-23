"""ctypes wrapper around the generated controller library (M5).

The generated code (GRT, 'Nonreusable function') has one global instance:
    controller_U   inputs  (struct ExtU_controller_T in controller.h)
    controller_Y   outputs (struct ExtY_controller_T)
    controller_initialize(), controller_step(), controller_terminate()
One step = one 1 ms controller sample: write U, call step, read Y.

Usage:
    from src.python.controller_lib import Controller
    y = Controller().run(inputs)     # inputs (N, 4), returns (N, 2)
"""
import ctypes as ct
import os
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
LIB = ROOT / "build" / ("controller.dll" if os.name == "nt" else "libcontroller.so")


class U(ct.Structure):
    """Controller inputs. Order and types must equal ExtU_controller_T in
    controller.h exactly (checked by test_interface_matches_header): ctypes
    maps fields by position, so a swapped order would swap two signals."""
    _fields_ = [("zs_dot", ct.c_double), ("zu_dot", ct.c_double),
                ("fault_flag", ct.c_double), ("mode", ct.c_double)]


class Y(ct.Structure):
    """Controller outputs, as ExtY_controller_T in controller.h."""
    _fields_ = [("i_cmd", ct.c_double), ("fault_active", ct.c_double)]


class Controller:
    def __init__(self, lib=LIB):
        lib = Path(lib)
        if not lib.exists():
            raise FileNotFoundError(f"{lib} missing: run python src/python/build_controller.py first")
        self._lib = ct.CDLL(str(lib))
        for f in ("controller_initialize", "controller_step", "controller_terminate"):
            fn = getattr(self._lib, f)
            fn.argtypes, fn.restype = [], None
        # Views onto the library's global structs (no copies)
        self.u = U.in_dll(self._lib, "controller_U")
        self.y = Y.in_dll(self._lib, "controller_Y")

    def run(self, inputs):
        """Replay inputs (N, 4: zs_dot, zu_dot, fault_flag, mode) from a fresh
        initialization; returns (N, 2: i_cmd, fault_active).

        Row k of the output is read right after step k, i.e. the output of the
        same sample k as in the MiL log (outputs are registered, D19: the step
        writes the delayed value first, then updates the state)."""
        inputs = np.asarray(inputs, dtype=float)
        out = np.empty((len(inputs), 2))
        self._lib.controller_initialize()      # resets all states: every replay starts at k = 0
        try:
            for k, (zs, zu, fault, mode) in enumerate(inputs):
                self.u.zs_dot, self.u.zu_dot, self.u.fault_flag, self.u.mode = zs, zu, fault, mode
                self._lib.controller_step()
                out[k] = (self.y.i_cmd, self.y.fault_active)
        finally:
            self._lib.controller_terminate()
        return out
