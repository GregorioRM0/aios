# The directed brief: eleven lines

The same eleven elements the Step 0 interview proposes (`brief-interview.md`), in the same order.
Write **GOAL** first, then **TIME**; everything else hangs off them. Every adjective is a decision
handed to the model's default look, so each line ends in numbers or names.

```
GOAL    One sentence: what the viewer should feel or do when it ends.
STORY   3-6 beats, each one thing happening, with its frame range (these are the shots).
TIME    Duration in seconds and frames; fps; BPM if scored; the frame each beat starts on. A loop
        says so and returns to frame 0 exactly.
HERO    The one move the piece is about: property, from -> to, frames, and the frame it lands on.
LOOK    Ground, palette (hex), type (family, weight, size in px), materials if 3D (roughness,
        metalness), lights (count, angle, colour, intensity). What is under the subject (by default
        nothing: it floats).
CAMERA  Lens (mm or FOV), the angle (a three-quarter view, 15-35° off front, unless flat), start and
        end position, the one move and its frames; what fills the frame at the hero beat and its
        share of the frame height; the 3% safe margin.
MOTION  Every other move: property, from -> to, easing name or spring (zeta, w), frames, distance in
        metres (3D) or px (flat). Secondary moves 50-70% of the hero's travel, 100-200 ms later.
BANNED  Named defaults you do not want: e.g. "no floor plane, no lens flare, no particles, no glow,
        no invented tagline, no real-world marks, no spinning turntable".
ENGINE  Plain HTML/canvas, or Three.js at an exact version; how objects are built.
QA      The checks that must pass, as numbers: contract, pops, determinism at the beat frames,
        framing, speed with no corners, seam for a loop; one assertion per beat; audio, or
        "audio N/A (silent)".
OUTPUT  Size(s) (1920x1080; a square cut is its own render), MP4 / GIF, file names, where it lands,
        rounds; nothing published or sent.
```

## A worked example (a 6 s logo sting, flat)

```
GOAL    The viewer reads the wordmark and feels it "lock in" on the last beat.
STORY   1 f0-119 the mark draws on · 2 f120-239 the wordmark rises in · 3 f240-359 lock and hold.
TIME    6 s = 360 frames at 60 fps, 120 BPM (30 frames a beat). Not a loop.
HERO    Beat 3: the mark scales 1.0 -> 1.06 -> 1.0 over 8 frames, peak on f300 (the downbeat).
LOOK    Background #0e0f12. One accent #ff5d4d, used only for the mark. Wordmark Inter 600,
        112 px, tracking -1%. No gradients.
CAMERA  Flat, so a 2D push: the whole stage scales 1.00 -> 1.04 over 360 frames, in-out. The
        mark and wordmark together span 46% of the width; nothing within 3% of an edge.
MOTION  The mark draws on, stroke 0 -> 100% over 90 frames, in-out (0.65,0,0.35,1).
        Letters rise 24 px -> 0, stagger 4 frames, spring zeta 0.75, w 14.
BANNED  No glow, no particles, no camera shake, no tagline, no 3D extrusion.
ENGINE  Plain HTML + canvas; Inter loaded before __ready.
QA      contract, pops, determinism (f0, f120, f300), framing green; speed: no corners; assert f300
        mark.scale 1.06 +-0.005; f359 every element at rest (speed 0); contrast >= 4.5:1;
        audio N/A (silent).
OUTPUT  1920x1080 sting.mp4 and a 1080x1080 cut (its own layout via ?aspect=1); a 24 fps GIF.
```

The follow-ups are where the piece is made: name the frame, state the problem and the result you want,
one or two per round, and keep them in `{slug}.receipts.md`.
