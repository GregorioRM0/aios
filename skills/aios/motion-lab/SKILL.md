---
name: motion-lab
description: 'Use when making motion that will be rendered to video or GIF — starting from a one-line ask like "make me a 3D animation of X": it first interviews the operator element by element (goal, story, time, hero move, look, motion, banned, engine, QA, output), each with a recommended answer, then renders. For a loop, a logo sting, a title card, a product shot, a launch film, an explainer film, a deck component exported for social. Code-drawn motion where every frame is a pure function of t: the render contract, the directed-prompt template (GOAL · OUTPUT · TIME · LOOK · MOTION · SHOTS · BANNED · QA), the numbers (easing, springs as damping ratio, stagger, beat grid, holds), and the render → look → fix loop run on hooks/motion-render.py and hooks/motion-check.py. NOT for reading someone else''s video (watch-video) and NOT for live UI motion inside a product.'
---

# Motion Lab

**Direction is numbers, and review is measurement.** Every adjective left in a brief is a decision handed back to the model's default look; every check left to "watching it" is a check that does not happen, because the model sees only the frames it is shown and cannot hear. Measured in public: the same model given 27 words of adjectives and 448 words of numbers for the same subject came back with its stock look for the first and the brief for the second.

The engine is plain: **one self-contained HTML file whose every frame is a pure function of t**, frozen frame by frame in a headless browser (`hooks/motion-render.py`), checked by instruments (`hooks/motion-check.py`), stitched by ffmpeg. Frames are reproducible, an edit is one number and a re-render, and the model can look at its own work.

## Who calls this

The **GOAL belongs to the caller**: `explainer` (rung 3: the reader understands one step), a launch (the viewer wants the product), a deck (`animation-composer`, for a component exported as a clip). Take the GOAL from them. A standalone piece with no caller (a sting, a loop) has the operator as its caller: ask for the GOAL.

> **Promotion rule.** If this skill is loaded three times for standalone pieces with no explainer, launch or deck purpose, the orphan domain is real: propose a `motion-designer` agent that owns `03 - export/motion/` and the house contract. Until then, no agent.

## Step 0 — interview for the brief (always, for any short ask)

A one-line ask (*"make me a 3D animation of X"*) is never rendered as given: the model fills every gap with its default look. **Your first reply is the whole brief, proposed**: ten elements, each with a recommended answer derived from the session's context (the purpose, the venture's `design.md`, the house contract and BANNED list) and a few words of why. Mark as questions only the two or three only the operator can answer (usually the goal, the story beats, anything about their brand). They answer once ("yes", or edits by element); read the final brief back; render nothing before a yes. Save it as `{slug}.brief.md`. How to recommend each element, and what a finished brief looks like: **`references/brief-interview.md`** and **`references/example-brief.md`**. Nobody present → use the recommendations and mark each one `assumed` in the receipts.

## Before the first frame

1. **The brief from Step 0 fills the template** (`references/prompt-template.md`). **GOAL first**, one sentence: what the viewer should feel or do. If nobody can say it, stop and ask; no easing curve rescues a missing GOAL. **TIME second**: every other number hangs off the frame count. One hero move per shot.
2. **Append the house contract and BANNED list.** They live in the vault at `03 - export/motion/_contract.md`; if it does not exist, seed it from `references/contract.md`. The contract is the lab's memory: every line is a failure you no longer have to see.
3. **Pick the engine by the rule.** One idea under 10 s → plain HTML + canvas/SVG/CSS. Anything 3D → Three.js, pinned to a version, built from **`references/three-d.md`** (the plumbing, lights, objects without models, text on screens, and the faults the first contact sheet shows). Name it in OUTPUT with its numbers. Take numbers from `references/numbers.md`, never adjectives.
4. **Start from the example**, `examples/loop-6s.html`: it already has `__duration`, `__fps`, a closed-form spring, a seeded PRNG, `renderAt(t)`, `__probe(t)` and `?t=`.

## The loop

```bash
R(){ python3 "$HOME/aios/hooks/motion-render.py" "$@"; }   # functions, not strings: zsh does not
C(){ python3 "$HOME/aios/hooks/motion-check.py" "$@"; }    # word-split "$R", and ~ does not expand in quotes
C contract piece.html                                     # lint against the contract first
R frames piece.html --out frames --frames 0,90,180,270    # stills at the shot boundaries
R frames piece.html --out frames --all                    # then every frame (a loop renders 0..N-1)
R sheet frames --out sheet.png                            # 12 frames on one page: READ it
C seam frames ; C pops frames                            # the cut back to frame 0; one-frame glitches
C determinism piece.html --frames 0,84                    # same frame twice, same pixels?
C assert piece.html checks.json                           # the brief's numbers, against __probe(t)
R onion frames --range 80:92 --out onion.png              # spacing should tighten near the keys
R speed piece.html --out speed.png                        # corners = dead starts, straight = linear
R export frames --out piece.mp4 [--audio score.wav] [--gif piece.gif --gif-fps 24]
C audio piece.mp4 --events hits.json                      # loudness, true peak, hits 1 frame late
```

**Look, then write notes that name frames** ("at f84 the ring overshoots past 1.08"), one or two per round; fix; re-render only what changed. Turn feelings into numbers before acting ("make it pop" → scale 1.0 → 1.08 → 1.0 over 6 frames, peak on the beat). Give notes as the problem plus the result you want, not the fix. **Two to four rounds is normal; report the count.**

**Sound is last**, scored from frame numbers (each hit one frame after its picture), synthesized or from licensed files, and checked by `audio`, never by "listening": the model cannot hear.

**Every check says PASS or FAIL with its numbers.** A check that could not run exits 2 and says why; never report it as passed.

## After

- **When a fix works, append its line to the house contract.** When the first render used a default you did not want, add it to BANNED **by name**.
- **Ship the receipts:** the prompt and every follow-up go beside the piece as `{slug}.receipts.md`, with the round count and the final check output.
- **Where it lands** (CLAUDE.md § File Placement Router): audience-facing pieces in `03 - export/motion/` (or the venture's export folder); frames and scratch renders in a temp directory, never the vault.

## References

- `references/contract.md` — the render contract + the fixes table (seed of the house contract)
- `references/numbers.md` — easings, the closed-form spring, damping ratios, durations, stagger, beat grid, holds, accessibility limits, loudness targets
- `references/brief-interview.md` — Step 0: turning a one-line ask into a full brief with the operator
- `references/example-brief.md` — a finished brief for a fictional product, at the level of detail to aim for
- `references/three-d.md` — Three.js that renders deterministically: plumbing, lights, objects, text, first faults
- `references/prompt-template.md` — the eight lines, how to fill them, a worked example
- `references/launch-film.md` — what is specific to a product launch film
- `references/explainer-film.md` — the silent, captioned film rung of `explainer`
