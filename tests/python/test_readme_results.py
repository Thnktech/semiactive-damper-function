"""README numbers = committed results (M6 checklist: every number traceable).

The results tables in README.md are written by src/python/readme_results.py
from the committed result files. If someone edits a number by hand, or a
result file changes without regenerating the README, this test fails in CI.
"""
from src.python.readme_results import README, render


def test_readme_results_match_committed_files():
    text = README.read_text(encoding="utf-8")
    assert render(text) == text, ("README results tables differ from the committed result files: "
                                  "run python src/python/readme_results.py and commit README.md")
