# Example — the brief the interview should end with

A fictional product, to show the level of detail. The operator asked: *"make a short 3D animation of
our bottle for the product page"*. After the interview (two questions asked, the rest accepted as
recommended), the brief read:

```
GOAL    A shopper sees the bottle keep a drink cold all day and wants one (product page, muted autoplay).
STORY   1 the bottle turns in from its side · 2 the cap lifts and twists off · 3 a cold-blue level ring
        fills to 100% on the bottle's band · 4 a small "12 h cold" tag (the figure from the product's own spec sheet, which the operator supplied; never invent a claim) settles on the beat · 5 hold.
TIME    10 s = 600 frames at 60 fps, 120 BPM (30 frames a beat). Beats start f0, f120, f240, f390, f480.
HERO    Beat 3: the level ring sweeps 0 -> 100% over 60 frames, ease-out (0.16,1,0.3,1), peak on f330.
LOOK    Ground #0e0f12. Bottle: brushed steel, metalness 0.9, roughness 0.35. ONE accent, cold blue
        #4fb3ff, used only for the level ring and the tag. Inter 600 for the tag, 64 px.
        Lights: key warm 2.4 at (-35°, 40°), fill cool 0.5 at (50°, 10°), rim 3.0 at (165°, 30°). Lens ~35 mm.
MOTION  Turn-in: rotation.y 90° -> 15° over 120 f, spring zeta 0.8, w 9. Cap: lift 0.4 units then
        twist 120°, 40 f each, ease-in-out. Tag: rises 24 px -> 0, spring zeta 0.75.
BANNED  condensation droplets, splashes, particles, lens flare, glow, a spinning turntable, any logo
        or slogan not supplied, a white studio sweep.
ENGINE  Three.js 0.160.0 via an import map; the bottle as a lathe of a profile curve; text on a canvas texture.
QA      contract, pops, determinism (f0, f300, f540); assert: f330 ring = 1.0; f480 tag at rest (y 0 ±0.5 px);
        f540-599 every probed value constant; speed graph of the ring: one smooth bell, no corners.
OUTPUT  1920x1080 MP4 and a 1080x1080 cut (re-framed, not cropped) to 03 - export/motion/;
        2-4 rounds; receipts beside it; nothing published.
```

What makes it work: every adjective became a number, the story has one cause (the cap comes off)
and one effect (the level fills), the accent means one thing, and QA can fail.
