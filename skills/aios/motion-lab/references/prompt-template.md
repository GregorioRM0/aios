# The directed prompt: eight lines

Write **GOAL** first, then **TIME**; everything else hangs off them. Every adjective is a decision
handed to the model's default look, so each line ends in numbers or names.

```
GOAL    One sentence: what the viewer should feel or do when it ends.
OUTPUT  Engine (plain HTML / Three.js@x.y.z), size(s), fps, loop or not, file name.
TIME    Duration in seconds and frames; BPM if scored; the beat each shot starts on.
LOOK    Background, palette (hex), type (family, weight, size in px), materials if 3D
        (roughness, metalness), lights (count, angle, colour), lens (mm or FOV).
MOTION  The hero move per shot: property, from -> to, easing name or spring (zeta, w), frames.
        Secondary moves: 50-70% of the travel, 100-200 ms later.
SHOTS   Numbered, each with its frame range and the one thing that happens.
BANNED  Named defaults you do not want: e.g. "no lens flare, no particles, no glow halo,
        no invented tagline, no spinning turntable".
QA      The checks that must pass: contract, seam, pops, determinism, plus assertions
        (e.g. "f90: ring scale 1.08 +-0.01") and, if scored, audio targets.
```

## A worked example (a 6 s logo sting)

```
GOAL    The viewer reads the wordmark and feels it "lock in" on the last beat.
OUTPUT  Plain HTML + canvas, 1080x1080 and 1920x1080 from one source, 60 fps, not a loop,
        sting.html; also a 24 fps GIF.
TIME    6 s = 360 frames, 120 BPM (30 frames a beat). Shots start on f0, f120, f240.
LOOK    Background #0e0f12. One accent #ff5d4d, used only for the mark. Wordmark Inter 600,
        112 px, tracking -1%. No gradients.
MOTION  Shot 1: the mark draws on, stroke 0 -> 100% over 90 frames, ease out (0.16,1,0.3,1).
        Shot 2: letters rise 24 px -> 0, stagger 4 frames, spring zeta 0.75, w 14.
        Shot 3: the mark scales 1.0 -> 1.06 -> 1.0 over 8 frames, peak on f300 (the downbeat).
SHOTS   1 f0-119 draw-on · 2 f120-239 wordmark in · 3 f240-359 lock and hold (>= 1 s still).
BANNED  No glow, no particles, no camera shake, no tagline, no 3D extrusion.
QA      contract, pops, determinism green; assert f300 mark.scale 1.06 +-0.005;
        f359 every element at rest (speed 0); contrast >= 4.5:1.
```

The follow-ups are where the piece is made: name the frame, state the problem and the result you want,
one or two per round, and keep them in `{slug}.receipts.md`.
