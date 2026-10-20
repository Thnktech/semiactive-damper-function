# Requirements Primer

What a requirement is, why projects use them, how to write a good one, and
how this project applies them.

## 1. What a requirement is

A requirement is one sentence that states what the system must do, written
so that a test can prove it.

| Wish (not testable) | Requirement (testable) |
|---|---|
| The controller should improve comfort. | In skyhook mode on a class C road at 80 km/h, RMS body acceleration shall be at least 10 % lower than passive. |
| The current must be safe. | `i_cmd` shall stay within [0.3, 1.6] A at every sample. |

A good requirement fixes three things: **when** (scenario), **what is
measured** (KPI or signal) and **what counts as pass** (number). Two engineers
who never met should test it the same way and reach the same verdict.

## 2. Why requirements exist

- **They define "done".** Without them, work is never finished, or is
  declared finished by feeling.
- **Tests come from them.** Every test proves one requirement. A test without
  a requirement checks something nobody asked for; a requirement without a
  test is an unproven claim.
- **Traceability.** Requirement → design → code → test → result. When a test
  fails, you know which promise broke. Automotive process standards
  (ASPICE, ISO 26262) audit exactly this chain.
- **Thresholds are fixed before results.** This prevents moving the target
  after seeing the outcome. A missed threshold is a Fail, not a reason to
  change the threshold.

**V-model:** requirements form the left arm (define), verification forms the
right arm (prove). Each requirement on the left has a matching test on the
right. In this project, M1 is the left arm; M4 and M5 are the right arm.

## 3. Properties of a good requirement

| Property | Meaning | Check question |
|---|---|---|
| Necessary | Removing it would leave a real need unmet | What breaks if we delete it? |
| Unambiguous | One interpretation only | Could two testers read it differently? |
| Singular | One requirement, one statement | Does it contain "and" joining two needs? |
| Measurable | Has a number and a unit | What value decides pass/fail? |
| Verifiable | A test, analysis or inspection can prove it | How exactly would we check it? |
| Feasible | Can be met with the given design and tools | Is it physically and technically possible? |
| Traceable | Has a stable ID and links to tests | Which test proves it? |

**Template:** *In [scenario/condition], the function shall [action] [measured
quantity] [comparison] [value with unit].*

Use **shall** for mandatory requirements. Avoid "should", "fast",
"robust", "as much as possible", "etc."

## 4. Fields used in this project

| Field | Content |
|---|---|
| ID | Stable identifier, never reused, e.g. `REQ-F-01` |
| Title | Short name |
| Statement | "The function shall …", measurable |
| Rationale | Why it exists |
| Verification | Test, analysis or inspection, and on which scenario |
| Acceptance | Numeric pass criterion |
| Evidence | Test ID that proves it (filled in M4) |
| Status | Unverified → Pass or Fail |

## 5. Levels of requirements

A production suspension controller has hundreds of requirements split across
levels. Each level refines the one above.

| Level | Example |
|---|---|
| Vehicle | The vehicle shall meet comfort target X on road Y. |
| System | The damping system shall adjust each corner within X ms. |
| Software function | The controller shall keep `i_cmd` within its limits. |
| Hardware | The valve driver shall supply up to X A. |

This project works at the **software function** level with about a dozen
requirements, each fully traced to an automated test. For a portfolio, that
shows the method; hundreds of untested requirements would show nothing.

## 6. Typical categories for a suspension controller

The examples below are generic illustrations, not quotes from any
manufacturer's specification. **In project** marks the categories this
project covers.

| Category | Typical example | In project |
|---|---|---|
| Functional | The current command shall stay within the valve's operating range. | Yes (REQ-F) |
| Functional | The command shall not change faster than X A per ms. | Yes (REQ-F-04) |
| Functional | The controller shall offer Comfort / Normal / Sport modes. | No |
| Performance | Body acceleration shall be ≥ X % lower than passive on road Y. | Yes (REQ-P) |
| Performance | Dynamic tire load shall increase by ≤ X %. | Yes (REQ-P-02) |
| Performance | Suspension travel shall stay within the bump-stop limit. | Yes (REQ-P-03) |
| Robustness | Performance shall hold across vehicle variants or ±X % mass. | Yes (REQ-P-04) |
| Robustness | No NaN or Inf output for any finite input. | Yes (REQ-F-05) |
| Timing | The function shall run every 1 ms. | Yes (REQ-F-02) |
| Timing | Worst-case execution time shall be ≤ X µs on the target ECU. | No (no hardware) |
| Safety | On fault, the current shall reach the default within X ms. | Planned (REQ-S) |
| Safety | Fault mode shall latch until reset. | Planned (REQ-S) |
| Diagnostics | Implausible sensor values for > X ms shall set a fault code. | No (detection is external, D6) |
| Interface | Every signal shall have unit, range, type, rate and initial value. | Yes (`interface/signals.md`) |
| Software quality | Generated code shall match the model within tolerance. | Planned (REQ-V-01) |
| Software quality | Code shall comply with MISRA C. | No (needs Embedded Coder) |

## 7. Where threshold values come from

Each threshold needs a reason. In order of preference:

1. **Physical limits** (valve current range, available suspension travel).
2. **Published literature** (typical improvements reported for the same
   method), with the source and how well it was checked.
3. **Derivation** (e.g., transient decay time from the natural frequency and
   damping ratio).
4. **Project assumption**, clearly labelled, when nothing better exists.

In this project, every threshold is labelled *proposed project assumption*
(D11), and `requirements/REQ.md` lists the supporting literature with its
verification level.

## 8. Rules used in this project

- Every requirement has a stable ID, a rationale and a numeric acceptance
  criterion.
- Thresholds are fixed before controlled-mode results exist and are not
  tuned afterwards.
- A requirement without a passing test stays **Unverified**.
- A missed threshold is reported as **Fail**, with the measured value.
- Every test name and tag carries the requirement ID it proves.
- The traceability table (requirement → test → result → verdict) is
  generated by script, not by hand.
