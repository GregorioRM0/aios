---
tags:
  - quarter
  - plan
  - vault
created: '{{date}}'
updated: '{{date}}'
quarter: '{{YYYY}}-Q{{N}}'
status: draft                  # draft | set | scored — leaves draft only on the operator's explicit say-so
review: '{{last Friday of the quarter, YYYY-MM-DD}}'
---
# {{YYYY}}-Q{{N}} — Objectives

> **Derived surface.** This note references roadmap keys and project notes; it owns no tasks and carries **zero checkboxes**. Status lives on the truth surfaces it cites (CLAUDE.md § Ship-time truth-flip). It is set in the quarter's first week, read by `/7plan` when the week's bet is chosen, and scored **once**, on the quarter's last Friday, in the same sitting as `/weekly-learnings quarter` and INTENT.md's via negativa. No mid-quarter score, no progress bar, no daily line.
>
> **Lives at** `vault/01 - calendar/{YYYY-MM}/{YYYY}-Q{N}-plan.md`, in the folder of the quarter's **first** month, beside that week's `{YYYY}-W{WW}-plan.md`. Find it by globbing `01 - calendar/*/{YYYY}-Q{N}-plan.md`, never by a remembered path.
>
> **Caps:** at most **three** objectives, at most **three** key results each. A fourth objective is refused with the trade stated.
>
> **Every KR names its instrument** (where the number is read from) **and cites a key or a project note**. A KR whose baseline cannot be measured from the vault today says `baseline: confirm` — or becomes a *build the instrument first* KR. A baseline is never estimated to fill the slot.

<!-- Compass line: write ONE sentence connecting the quarter to the compass ONLY when growth.md carries a `## Compass` with content under it. Otherwise delete this comment and write nothing about purpose anywhere in this note. -->

## Diagnosis
{{The real challenge this quarter, in one or two sentences — the constraint underneath the to-do list. Confirmed by the operator before any objective is written.}}

## O1 · {{qualitative objective, 12 words or fewer}}
- KR 1.1 · {{baseline}} → {{target}} by {{YYYY-MM-DD}} · instrument: {{where the number comes from}} · keys: `{{KEY-n}}` · → [[{{project-note}}]]
- KR 1.2 · baseline: confirm → {{target}} by {{YYYY-MM-DD}} · instrument: {{source, or "build first"}} · → [[{{project-note}}]]
- **Says no to:** {{what this objective displaces this quarter}}

## O2 · {{qualitative objective}}
- KR 2.1 · …
- **Says no to:** …

## O3 · {{qualitative objective}} *(optional — three is the cap, not the target)*
- KR 3.1 · …
- **Says no to:** …

## B- this quarter (intentional)
{{Fronts, projects, or lanes deliberately run at maintenance this quarter, each with one line on why. Naming them is what makes the objectives above honest.}}
- {{front}} — {{why it is B- this quarter}}

## Pressure test
{{The leading objective, inverted: how this quarter fails, the most likely failure, and the one to prevent first. Plus any objective that breaks one of INTENT.md's tradeoff rules, named plainly.}}

## Open questions for the operator
{{Every `baseline: confirm` and `target: confirm`, every instrument the coach could not find or had to choose between, every `key: none (propose)`, every objective the coach was unsure belonged in the three. Cleared before `status: set`.}}

## Review — {{last Friday of the quarter}}
<!-- Written at scoring only. Leave empty until then. -->
{{Per KR: the number read from its instrument, then a grade 0.0–1.0. A stretch KR at ~0.7 is the healthy shape; 1.0 on every KR means the quarter was under-set.}}
- KR 1.1 · {{read value}} · {{instrument, read on YYYY-MM-DD}} · **{{0.0–1.0}}**

{{Per objective, one line on what it meant, not only what landed — in the compass's terms only if a compass exists.}}

**Via negativa (same sitting):** {{INTENT.md § Via negativa, answered — what gets removed next quarter.}}

**Next quarter re-sets.** No objective rolls forward automatically; one that keeps rolling has become a goal that never completes.
