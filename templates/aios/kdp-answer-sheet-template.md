---
tags:
  - template
  - publishing
  - kdp
target: next to the book — its project note's folder or the book's repo ({slug}-kdp-answer-sheet.md)
created: '2026-10-11'
updated: '2026-10-11'
---

# KDP Answer Sheet — {{book title}}

> **Why this file exists.** KDP asks the same ~25 questions per format for every title, and the author-level answers have to be **identical across every book**. Amazon builds one author page by matching the author-name string, and a disclosure that differs between books invites a question nobody wants later. Answer once, then copy this sheet for the next book, so the second upload is transcription instead of judgment.
>
> Filled by the `kdp-publisher` agent with the author. **Only confirmed values are transcribed.** Anything unconfirmed stays blank and goes under *Open questions*. A blank-but-true field beats a full-but-false one.
>
> **Mode:** {{LIVE | DRY RUN — nothing was uploaded or submitted}} · **Last updated:** {{date}}
>
> Do **not** record KDP credentials, tax IDs, bank details or payment details here.

---

## Part A — Author-level (identical on every title; copy from the previous book's sheet)

### Author name

| KDP field | Value |
|---|---|
| Prefix | {{usually empty}} |
| First name | {{ }} |
| Middle name | {{ }} |
| Last name | {{ }} |
| Suffix | {{ }} |
| **Renders as** | {{ }} — must match the printed cover |

**Never fill Prefix and Suffix together** (an honorific in both is redundant). A string that differs on any title splits the books across two author pages.

### AI-generated content disclosure

Amazon distinguishes **AI-generated** (an AI created it) from **AI-assisted** (you created it and AI refined it), and asks about the first. It's internal metadata, not shown on the listing. Name **the tool that actually generated each thing**: an assistant that wrote the image prompts didn't make the pixels, so name the image model.

| Field | Answer (amount + editing level, as the form words it) | Tool(s) |
|---|---|---|
| Texts | {{ }} | {{ }} |
| Images | {{ }} | {{ }} |
| Translations | {{ }} | {{ }} |

Provenance kept at: {{path to the prompt/imagery log, if any}}

### Defaults the author has settled for every book

| Setting | Value | Why |
|---|---|---|
| Publishing rights | {{ }} | |
| Publisher / imprint (Kindle) | {{blank, or the imprint}} | |
| ISBN source (print) | {{free KDP ISBN / own ISBN}} | |
| Reading age | {{blank for adult titles}} | The field is for children's/YA; filling it can push an adult title into the wrong browse categories |
| Expanded Distribution | {{on / off}} | |
| DRM policy | {{ }} | **Irreversible per title.** Record the reasoning so every book answers the same way |
| KDP Select policy | {{ }} | Rule: *will you hand out or sell the file elsewhere in the next 90 days?* |
| Accessibility stance | answer honestly, per title | |

---

## Part B — This book

### Files (checked by the pre-flight; record the hash so a stale build is detectable)

| Upload | File | sha256 (first 12) | Pre-flight |
|---|---|---|---|
| Print interior | `{{slug}}-interior-{{trim}}.pdf` — **never the cover-to-cover digital edition** | | |
| Print cover wrap | `{{slug}}-cover-wrap-*.pdf` — **PDF only**, lossless | | |
| Kindle manuscript | `{{slug}}-kindle.epub` — back cover as final page, no barcode reserve | | |
| Kindle cover | `{{slug}}-cover-front-kindle.jpg` — **JPG/TIFF only, PNG is rejected** | | |

### Print options

| Setting | Value |
|---|---|
| Ink & paper | {{ }} |
| Trim size | {{ }} |
| Bleed | {{Bleed / No Bleed}} — full-page art **requires** Bleed (No Bleed is hard-rejected: *"This image is outside the margins"*) |
| Interior page size | {{trim, or trim + 0.125 in outside/top/bottom with bleed; the gutter never bleeds}} |
| Page count | {{ }} |
| Spine width | {{ }} in — white paper, B&W: `pages × 0.002252 in`; other paper/ink: check KDP's cover calculator |
| Cover finish | {{ }} |
| Print ISBN | {{assigned by KDP — record once issued}} |
| Primary marketplace | {{ }} |
| Territories | {{ }} |

### Kindle — what differs from print

Create the Kindle from the **paperback's Bookshelf row**, never as a new title, so both formats share one detail page.

| Field | Value |
|---|---|
| ISBN | **blank** — Kindle uses an ASIN; never reuse the paperback's ISBN |
| Publisher | {{ }} |
| DRM | {{ }} — ⚠️ **permanent** |
| KDP Select | {{ }} — locked 90 days once on |
| Accessibility | {{honest answer}} — why: {{ }} |
| File size after conversion | {{read off the pricing page, not the EPUB on disk}} |

### Listing metadata (the author's words; this agent transcribes approved text only)

| Field | Value / where the approved text lives |
|---|---|
| Title | {{ }} |
| Subtitle | {{ }} |
| Series | {{ }} |
| Description | {{path to the approved text — voice-gated}} |
| Keywords (7 slots) | {{ }} |

### Categories (3 per format — the print and Kindle trees are different trees)

Rules: never a `› General` leaf · choose by subject, not by audience · slot 3 on a different, less contested shelf · read the paths off the **live picker**.

| Slot | Paperback path | Kindle path |
|---|---|---|
| 1 | {{ }} | {{ }} |
| 2 | {{ }} | {{ }} |
| 3 | {{ }} | {{ }} |

### Pricing (read band limits, rates and the delivery fee off the form)

| Marketplace | Paperback | Kindle | Hand-set or auto? | Rate shown on form |
|---|---|---|---|---|
| {{ }} | | | | |

---

## The five doors (decisions + reasons)

| Decision | Reversible? | Decided | Reason |
|---|---|---|---|
| DRM | **Never** | {{ }} | |
| KDP Select | 90 days | {{ }} | |
| Categories | Anytime | {{ }} | |
| Pricing | Anytime | {{ }} | |
| Accessibility | Anytime | {{ }} | |

## Release log

| Step | Date | Evidence |
|---|---|---|
| Device read by the author | | |
| Paperback submitted for review | | |
| Proof ordered (24 h checkout window) | | |
| Kindle submitted for review | | |
| Paperback live — ASIN | | opened the listing: {{ }} |
| Kindle live — ASIN | | opened the listing: {{ }} |
| Formats linked on one detail page | | |
| Proof received — in-book QR scanned | | |
| Announced (author's call) | | |

## Open questions

- {{every `[CONFIRM]` or blank field, and who answers it}}

## Re-verified against KDP's help pages

- {{page · date · what was confirmed or changed}}
