# The render contract

Paste these lines under every motion prompt. `hooks/motion-check.py contract` lints a page against the
first six; the seventh is checked by `seam`.

1. **One self-contained file.** HTML, CSS and JS inline; assets as data URIs or files beside it.
2. **Only pinned libraries**, from a known CDN, with an exact version in the URL (`three@0.160.0`).
3. **No network** at render time except web fonts and those libraries. No `fetch`, no XHR, no sockets.
4. **Every frame is a pure function of t.** Rendering frame 84 alone gives the same pixels as reaching it
   from frame 0.
5. **`window.renderAt(t)`** draws the frame at t seconds if JS drives any motion. CSS animations are
   frozen through `document.getAnimations()`; JS animation is not, unless it reads t.
6. **No clock, no timers, no unseeded randomness.** No `Date.now`, `performance.now`, `setTimeout`,
   `setInterval`, `requestAnimationFrame` loops, or bare `Math.random`. Use a seeded PRNG.
7. **Loops render frames 0..N−1 only**, built from `phase = frame / N` with whole cycles: frame N is
   frame 0, and rendering both puts a stutter at the seam.

Also expose, when they apply: `window.__duration` and `window.__fps` (so the renderer needs no flags),
`window.__ready` (set when assets are loaded), `window.__probe(t)` returning the numbers the brief sets
(scale, position, opacity) so `assert` and `speed` can read them, and `?t=` in the URL to freeze any frame
in a normal browser.

**Opened directly, it must not look blank.** With no `?t=`, the page renders its **hero frame** (the resolved hold, or the most telling moment of a loop), never frame 0 of a piece that opens on an empty ground. Someone double-clicking the file sees the piece, not a black page; the renderer always sets t itself, so this changes no frame it captures.

## Fixes table (each line is a failure that will happen to you)

| Symptom | Cause | Fix |
|---|---|---|
| First frames blank or white | the browser had not painted yet | the renderer warms up until two shots agree; if a piece loads assets, set `__ready` after they load |
| Frame differs between renders | a clock, a timer or `Math.random` | contract rules 4 and 6; `determinism` finds it |
| Hiccup where the loop wraps | rendered frame N, or a cycle that is not whole | rule 7; `seam` finds it |
| One frame jumps | a branch at an exact t, an easing evaluated outside 0..1 | clamp; `pops` names the frame |
| Text reflows mid-shot | the web font arrived after frame 0 | the renderer waits for `document.fonts.ready`; preload fonts |
| GIF runs 4% slow | 41.67 ms delays rounded to 40 | export at 25 fps, or 24 fps with the 40/40/40/40/40/50 ms pattern (`export --gif-fps 24`) |
| Hits feel late | sound files peak after their start | measure with `audio --events`; shift each hit to land 1 frame after its picture |

*Add a row every time a fix works. The house copy of this file is the one that grows.*
