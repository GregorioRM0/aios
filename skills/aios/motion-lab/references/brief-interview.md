# The brief interview — from "make me a 3D animation of X" to a brief worth rendering

A one-line ask gives the model almost nothing, and the model fills every gap with its default look.
Measured in public: 27 words of adjectives came back as the stock look; 448 words of numbers came
back as the brief. So the first thing this skill does with a short ask is **help the operator write
the long brief**, one element at a time, each with a recommended answer the operator can accept with
one word.

## How to run it

1. **Read the context first, then propose; never interrogate.** Before asking anything, gather what
   the session already knows: the operator's words, the venture or project the piece is for, its
   `design.md` (colours, type) if there is one, earlier pieces in `03 - export/motion/`, the house
   contract and BANNED list. Every recommendation below is derived from that.
2. **One message, the whole brief, recommendations filled in.** Recommend at the house bar (SKILL.md § The bar): a dark ground, a moving camera, real proportions, landings on springs. Lower it only when the operator asks, and write the lower bar into the brief. Show all eleven elements at once, each as
   *the recommended answer* plus *why* in a few words. Mark the two or three that genuinely need the
   operator (usually GOAL, the story beats, and anything about their brand) as questions; the rest
   are proposals they can wave through.
3. **They answer in one go:** "yes", or edits by element ("2: the card should go to the laptop, not
   the panel"). One round of edits, then a final read-back. Do not render before a yes.
4. **Save it** as `{slug}.brief.md` beside the piece. It is the first line of the receipts.
5. **Nobody present** (a routine, an unattended worker): use the recommendations, mark every one you
   could not confirm as `assumed`, and say so at the top of the receipts.

## The eleven elements, and how to recommend each

| # | Element | Ask (only if you can't recommend) | Recommend from |
|---|---|---|---|
| 1 | **GOAL** — what the viewer should feel or do at the end, one sentence | "Who watches this, and what should they do after?" | The purpose behind the ask: a launch (want it), a pitch (believe it), an explainer (understand step N), a social loop (stop scrolling: **seamless**, whole cycles, `seam` in QA). |
| 2 | **STORY** — 3 to 6 beats, each one thing happening, each with its frame range (the shots) | "What has to happen, in order?" | The nouns in the ask become actors; give them one cause and one effect, and end on a resolved state. |
| 3 | **TIME** — seconds, fps, BPM if scored, the frame each beat starts on | — | 6 s for one idea, 10–12 s for a small story; 60 fps; 120 BPM (a beat every 30 frames) so beats land on a grid. Hold the last state ≥ 1 s; a loop instead returns to frame 0 exactly. |
| 4 | **HERO MOVE** — the one move the piece is about | "Which moment is the point?" | The beat where the cause meets the effect. Everything else is secondary (50–70% of its travel, 100–200 ms later). |
| 5 | **LOOK** — ground, palette with hex, type, lights, lens, materials | — | The venture's `design.md`; else a dark ground, neutral greys, **one accent that means one thing** (the event). Three lights with numbers (key, fill, rim). The subject **floats on the dark ground**: no floor plane or lit sweep unless asked (a contact shadow is fine). Objects at **real size in metres**, with detail on every surface the camera sees. |
| 6 | **CAMERA** — lens, start and end position, the one camera move and its frames | — | A ~35 mm lens at a **three-quarter view** (15–35° off front), objects at different depths. **Frame the event, not the inventory**: at each beat the objects that act fill the frame. One move: a slow push-in (10–15% closer) or a 10–25° orbit, eased in-out (a closed path in a loop). The hero fills **≥ 1/3 of the frame height** at its beat; nothing within **3%** of an edge. Locked off only when asked. |
| 7 | **MOTION** — easing and springs as numbers, per move, distances in metres (3D) or px (flat) | — | `references/numbers.md`: **every landing on a spring** (damping ratio 0.7–0.85 "premium", 0.4–0.6 "playful"); a move from rest starts in-out or on a spring; ease-out only for something already moving (entering from off frame). |
| 8 | **BANNED** — defaults you don't want, by name | "Anything you've seen in AI motion that you hate?" | The house BANNED list, plus: particles, lens flares, glow halos, invented logos or company names, a spinning turntable, an invented tagline. |
| 9 | **ENGINE** — plain HTML/canvas, or Three.js pinned | — | One idea, flat → plain HTML. Anything with depth, a product, a device → Three.js at an exact version (`references/three-d.md`). |
| 10 | **QA** — what must be true, as numbers | — | One assertion per beat (*"by f402 the card sits in the slot, offset 0"*, *"the check peaks on f480"*), plus *everything at rest* during the hold, plus contract, pops, determinism, `framing`, `speed` with no corners, `seam` for a loop; `audio` only when scored (else N/A). |
| 11 | **OUTPUT & LIMITS** — sizes, where it lands, rounds | — | 1920×1080 (and, if social, a 1080×1080 cut **rendered with its own camera**, never cropped), MP4 (+ GIF if wanted), `03 - export/motion/`; 2–4 rounds; nothing published or sent. |

## What "good" looks like (a neutral example)

`references/example-brief.md` is a complete brief for a fictional product, written the way this
interview should end. Read it before your first interview: it shows the level of specificity that
separates a piece from a demo.

## Why the interview, and not a longer template

The template already exists (`references/prompt-template.md`). What was missing is that a session
handed a one-liner did not know to **expand** it, or how far. The interview makes the expansion the
first visible step, puts the operator's taste where only they can supply it, and lets the numbers
come from the skill where they can.
