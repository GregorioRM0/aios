---
tags:
  - template
  - publishing
  - errata
target: next to the book — its project note's folder or the book's repo (ERRATA.md)
created: '2026-10-11'
updated: '2026-10-11'
---

# ERRATA — post-publication corrections ledger

> One entry per known discrepancy between a **published** edition and what is now believed to be true. A correction logged here can't be lost and doesn't get re-argued: it's logged when discovered, it carries an explicit class and status, and it's closed only once it has actually shipped in a named printing.
>
> **This isn't a defect list.** Many entries won't be errors. They'll be claims that were correct against the evidence at press time and were later narrowed, sharpened, or superseded by a fuller record. The `class` field says which is which, and that distinction is why this file exists instead of a vague "fix later" note.
>
> Instantiated by the `kdp-publisher` agent on the first post-publication correction. One ledger can hold several books, with one `##` section per book.

## How to use it

- **Log on discovery, not on decision.** An entry with `status: open` is a known thing, not a commitment to change it.
- **`wont-fix` is a legitimate way to close an entry**, as long as it gives a reason. An overreach that a later chapter already corrects is a different thing from a factual error in a load-bearing claim.
- **Close only against a named printing.** `applied-in:` takes a printing or edition identifier, never just a date. *"We fixed it"* can't be checked; *"shipped in the 2nd paperback printing"* can.
- **Spoken-word carve-out.** A talk, podcast or interview that draws on an affected passage uses the corrected framing **immediately**, whatever the printed status. A live audience can push back, and print can't be interrupted. Note this under `spoken:` where it applies.

### Class vocabulary

| Class | Means |
|---|---|
| `error` | The text asserts something that isn't true. It was wrong when written, whether or not that was knowable. |
| `overreach` | The claim is stronger than the evidence supports: right in direction, but overstated. |
| `superseded-figure` | A number or date that a later authoritative source revises. The revision often *strengthens* the point. |
| `citation-update` | The claim stands, but the sourcing is incomplete because a better or primary source has since appeared. |

### Status vocabulary

`open` · `applied-in: <printing>` · `wont-fix: <reason>` · `superseded: <entry id>`

### Disposition rule — check before any re-upload

A print interior re-upload **resets KDP review** and **re-locks the page count and spine** (a page-count change means rebuilding the cover wrap). It can also force a reconciliation between the reviewed manuscript and the build source. So:

- **Most entries queue for the next printing**, whenever one happens for any reason.
- Re-upload now only when an `error` sits in a load-bearing claim and the cost of leaving it outweighs the reset. Record the decision and its reason under *Recommended disposition*, so nobody argues it again.
- Ebook corrections are cheaper (no spine), but they still go back through review. Batch them.
- A finding that is **new material** rather than a correction belongs in a future edition as an addition. Note it separately; it isn't an erratum.

---

## {{Book title}}

**Published {{date}}** — paperback `{{ASIN}}` ({{pages}} pp, ISBN {{ }}) · Kindle `{{ASIN}}`.

{{One line on the context that the entries below share, if they share one.}}

---

### {{PREFIX}}-01 · "{{short quote of the affected text}}"

- **class:** `{{error | overreach | superseded-figure | citation-update}}`
- **status:** `open`
- **locus:** {{chapter, section, paragraph}}
- **says:** {{what the published text says}}
- **now known:** {{what is now believed true}}
- **source:** {{the source, with date}}
- **note:** {{why this class; effect on the argument; whether the book self-corrects elsewhere}}
- **spoken:** {{the corrected phrasing for talks, if applicable}}

---

### Recommended disposition ({{date}})

{{Re-upload now, or queue for the next printing, and why. Record the reasoning so it isn't re-argued.}}

**New material, not errata:** {{findings that belong in a future edition as additions}}

---

## {{Next book title}}

_No entries._
