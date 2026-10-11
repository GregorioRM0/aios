# The numbers sheet

Starting values, not laws. A brief that cites these instead of adjectives gets the look it asked for.

## Easing (cubic-bezier)

| Name | Curve | Use |
|---|---|---|
| out | `0.16, 1, 0.3, 1` | things arriving |
| in | `0.7, 0, 0.84, 0` | things leaving |
| in-out | `0.65, 0, 0.35, 1` | things moving across |
| anticipate | `0.36, 0, 0.66, -0.56` | a wind-up before the move |
| linear | `0, 0, 1, 1` | only for continuous rotation or scrolling |

## Springs: one closed form, damping ratio as the unit

```js
// x(0)=0 -> 1. zeta = damping ratio, w = natural frequency (rad/s). A function of t, no simulation,
// so frame 84 renders on its own.
function spring(t, zeta = 0.7, w = 14) {
  if (t <= 0) return 0;
  const wd = w * Math.sqrt(1 - zeta * zeta);
  return 1 - Math.exp(-zeta * w * t) * (Math.cos(wd * t) + (zeta * w / wd) * Math.sin(wd * t));
}
```

Damping ratio translates across every library: **1.0** no bounce · **0.7–0.85** premium, settled ·
**0.4–0.6** playful. (For ζ ≥ 1 use the critically damped form `1 - (1 + w*t) * exp(-w*t)`.)

## Durations and stagger

- Micro (a tick, a toggle): 120–200 ms. Small moves: 200–350 ms. Large moves: 400–700 ms.
- **One hero move per shot.** Secondary moves travel 50–70% as far and start 100–200 ms later.
- Anticipation: about 3 frames at 60 fps before a big move.

## Beat grid

- Frames per beat = `fps × 60 / BPM` (120 BPM at 60 fps = 30 frames). **Round each beat's frame from its
  index** (`round(i × fpb)`), never by adding a rounded step: accumulated rounding drifts off the music.
- Land the payoff on the downbeat; hits one frame after their picture.

## Holds (reading time)

- Text on screen: **0.3 s per word + 0.5 s**, minimum.
- A number that matters: hold it at rest for at least 1 s after it lands.

## Limits

- Text contrast **≥ 4.5:1** (WCAG AA); large display type ≥ 3:1.
- **≤ 3 flashes per second** (photosensitivity).
- Sound: integrated **−14 LUFS**, true peak **≤ −1 dBTP**, most energy above 60 Hz (phone speakers play
  almost none of it). `motion-check.py audio` measures all three.
- Social GIF: keep under the platform's size and frame limits; prefer MP4 where the platform accepts it.
