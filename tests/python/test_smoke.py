# Smoke test (M0): proves that CI can set up Python, install the packages and
# run pytest at all. If only this fails, the problem is the environment, not
# the project.
import sys


def test_python_version():
    # 3.10 or newer: the project code uses features that 3.9 lacks (e.g. the
    # newline argument of Path.write_text); CI and .venv use 3.11.
    assert sys.version_info >= (3, 10)
