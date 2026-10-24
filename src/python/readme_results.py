"""Fill the results tables of README.md from the committed result files (M6).

    python src/python/readme_results.py          rewrite the tables in README.md
    python src/python/readme_results.py --check  only compare; exit 1 if different

Why: the README is what people read first, and its numbers must be the
committed results, not numbers typed by hand that drift away from them (M6
checklist: "every number in the README traceable to a committed file").
Each table sits between two markers in README.md:

    <!-- BEGIN generated:comparison ... -->
    ...table written by this script...
    <!-- END generated:comparison -->

Only the text between the markers is replaced; everything else in the README
is written by hand. tests/python/test_readme_results.py runs the same
generation in CI and fails if the README differs from the committed results.

Sources (all committed):
    results/comparison/kpi_comparison_sedan_ref.csv    passive vs controlled (M3)
    results/sensitivity/lag_sensitivity_sedan_ref.csv  actuator-lag study (M6)
    results/traceability.md                             verdicts, fault reaction (M4)
    results/back_to_back.json                           generated-code back-to-back (M5)
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))     # run as a script: make 'src.python' importable
from src.python.back_to_back import read_csv_exact  # noqa: E402  (exact number parsing, D28)

README = ROOT / "README.md"
COMPARISON = ROOT / "results" / "comparison" / "kpi_comparison_sedan_ref.csv"
LAG = ROOT / "results" / "sensitivity" / "lag_sensitivity_sedan_ref.csv"
TRACE = ROOT / "results" / "traceability.md"
B2B = ROOT / "results" / "back_to_back.json"
NAMES = {0: "Passive", 1: "Skyhook", 2: "Groundhook", 3: "Hybrid (α = 0.5)"}


# ---------- number formats ----------
def pct(v):
    """Change in %, with sign and a real minus sign (as in the reports)."""
    return f"{v:+.1f} %".replace("-", "−")


def source(path):
    """Link line under a table: where the numbers come from."""
    rel = path.relative_to(ROOT).as_posix()
    return f"<sub>Source: [`{rel}`]({rel})</sub>"


# ---------- the generated blocks ----------
def comparison():
    """Passive vs the three controllers on SC-C80 and SC-BUMP (absolute KPI and
    change vs passive on the same road; negative = better)."""
    df = read_csv_exact(COMPARISON)
    out = []
    for scen, title in (("C80", "Random road, class C, 80 km/h (SC-C80)"),
                        ("BUMP", "Bump 50 mm × 0.5 m at 18 km/h (SC-BUMP)")):
        out += [f"**{title}**", "",
                "| Strategy | RMS body acc. [m/s²] | Δ comfort | RMS dyn. tire load [N] | Δ road holding "
                "| Max travel [mm] | Δ travel |",
                "|---|---|---|---|---|---|---|"]
        for _, r in df[df.scenario == scen].sort_values("mode").iterrows():
            # Passive is the reference itself: show '–' instead of '+0.0 %'
            d = (["–"] * 3 if r["mode"] == 0 else
                 [pct(r.d_comfort_pct), pct(r.d_tire_pct), pct(r.d_travel_pct)])
            out.append(f"| {NAMES[int(r['mode'])]} | {r.rms_zs_ddot:.2f} | {d[0]} | "
                       f"{r.rms_F_tire_dyn:.0f} | {d[1]} | {r.max_travel_mm:.1f} | {d[2]} |")
        out.append("")
    out.append(source(COMPARISON))
    return out


def traceability_rows():
    """Table rows of results/traceability.md as lists of cells. Cells may
    contain escaped pipes '\\|', so split only on unescaped ones."""
    rows = []
    for line in TRACE.read_text(encoding="utf-8").splitlines():
        if line.startswith("| REQ-"):
            rows.append([c.strip() for c in re.split(r"(?<!\\)\|", line)[1:-1]])
    return rows


def verification():
    """Headline verification results: verdict counts, fault reaction, back-to-back."""
    text = TRACE.read_text(encoding="utf-8")
    result = re.search(r"- Result: \*\*(.+?)\*\* of (\d+) requirements", text)
    commit = re.search(r"- Commit: `([^`]+)`", text)
    rows = {r[0]: r for r in traceability_rows()}
    reaction = re.search(r"fault reaction time: ([\d.]+) ms", rows["REQ-S-01"][4])
    rec = json.loads(B2B.read_text(encoding="utf-8"))
    samples = sum(log["rows"] for log in rec["logs"])
    dev = max(log["max_abs_dev_i_cmd"] for log in rec["logs"])
    logs = ", ".join(Path(log["log"]).stem.replace("mil_", "") for log in rec["logs"])
    fault_same = all(log["fault_active_identical"] for log in rec["logs"])
    return [
        "| Check | Result |",
        "|---|---|",
        f"| Requirements ({result.group(2)}) | **{result.group(1)}** (commit `{commit.group(1)}`) |",
        f"| Fault reaction, REQ-S-01 (limit 10 ms) | **{float(reaction.group(1)):g} ms** |",
        f"| Generated C code vs MiL, REQ-V-01 | **max \\|Δ i_cmd\\| = {dev:g} A** over {samples:,} samples "
        f"({logs}); fault_active identical: {'yes' if fault_same else 'NO'} |",
        "",
        source(TRACE) + " · " + source(B2B),
    ]


def lag():
    """Change vs passive at 5 / 10 / 20 ms actuator lag (SC-C80)."""
    df = read_csv_exact(LAG)
    out = ["| Actuator lag τ | Skyhook Δ comfort | Skyhook Δ road holding | Groundhook Δ comfort "
           "| Groundhook Δ road holding | Hybrid Δ comfort | Hybrid Δ road holding |",
           "|---|---|---|---|---|---|---|"]
    for tau in sorted(df.tau_ms.unique()):
        cells = []
        for m in (1, 2, 3):
            r = df[(df.tau_ms == tau) & (df["mode"] == m)].iloc[0]
            cells += [pct(r.d_comfort_pct), pct(r.d_tire_pct)]
        label = f"{tau:g} ms" + (" (nominal)" if tau == 10 else "")
        out.append(f"| {label} | " + " | ".join(cells) + " |")
    out += ["", source(LAG)]
    return out


def traceability():
    """Requirement, title and verdict for all requirements (details in the report)."""
    out = ["| Requirement | Title | Verdict |", "|---|---|---|"]
    for r in traceability_rows():
        out.append(f"| {r[0]} | {r[1]} | {r[5]} |")
    out += ["", source(TRACE)]
    return out


BLOCKS = {"comparison": comparison, "verification": verification, "lag": lag,
          "traceability": traceability}
MARK = re.compile(r"(<!-- BEGIN generated:(\w+)[^>]*-->\n)(.*?)(<!-- END generated:\2 -->)", re.S)


def render(text):
    """README text with every generated block replaced by fresh content."""
    found = set()

    def fill(m):
        name = m.group(2)
        if name not in BLOCKS:
            raise KeyError(f"README has an unknown generated block '{name}'")
        found.add(name)
        return m.group(1) + "\n".join(BLOCKS[name]()) + "\n" + m.group(4)

    new = MARK.sub(fill, text)
    missing = set(BLOCKS) - found
    if missing:
        raise KeyError(f"README is missing the generated block(s) {sorted(missing)}")
    return new


def main():
    text = README.read_text(encoding="utf-8")
    new = render(text)
    if "--check" in sys.argv:
        if new != text:
            sys.exit("README results differ from the committed result files: "
                     "run python src/python/readme_results.py")
        print("README results match the committed result files")
        return
    README.write_text(new, encoding="utf-8", newline="\n")
    print("README results tables updated" if new != text else "README results already up to date")


if __name__ == "__main__":
    main()
