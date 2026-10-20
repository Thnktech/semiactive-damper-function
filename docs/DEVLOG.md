# Development Log

One line per session: what was done, what is next, what blocks progress.

| Date | Done | Next | Blocker |
|---|---|---|---|
| 2026-10-19 | Repo initialized; folder structure with purpose READMEs; `.gitignore`, `.gitattributes`, MIT license; changelog | Push to GitHub; README, Python env, smoke test | – |
| 2026-10-20 | Pushed to GitHub; README skeleton, `requirements.txt`, smoke test (Python 3.11); CI workflow green; planning docs kept local and removed from history; **M0 done, `v0.1.0` tagged** | Design decisions, parameter source, devlog | – |
| 2026-10-20 | Manual CI trigger; `docs/ci.md` (CI, smoke test, self-test cheatsheet + PDF); CI self-test performed (red on purpose, then green) | `docs/DECISIONS.md` | – |
| 2026-10-20 | `docs/DECISIONS.md` D1–D15; reference vehicle proposed (Golden Car ratios, m<sub>s</sub> = 230 kg; 1.21 Hz / 11.0 Hz); this devlog | Confirm D14; choose variant sources (D15); draft REQ-F and REQ-P | No openly verifiable class-specific parameters for variants yet |
| 2026-10-20 | D14 accepted (reference sedan); D15 accepted (scaled variants now, replaced by published data when found) | Agree variant targets (m<sub>s</sub>, m<sub>u</sub>/m<sub>s</sub>, frequencies); draft REQ-F and REQ-P | eROD parameters pending from author |
| 2026-10-20 | D16 accepted: scaled variant targets (small car, SUV, light van) with solved k<sub>s</sub>, k<sub>t</sub> | Draft REQ-F and REQ-P in `requirements/REQ.md` | eROD parameters pending from author |
