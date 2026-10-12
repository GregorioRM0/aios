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

**An ease-out starts at full speed.** Launched from a standstill it is a corner: the thing jumps from
rest to its top speed in one frame, and `motion-render.py speed` fails it. Use ease-out only for
something already moving (entering from off frame, continuing a previous move); from rest, start
in-out or on a spring. The same goes for a wind-up: after an anticipation the move must leave from the
speed the wind-up ended at, so **let a spring do the move and the landing**.

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

## Scale and framing (3D)

- **Model in metres, at real size**: a phone 0.147 × 0.071 m, a cup 0.12 m, a bottle 0.26 m. Then a
  spring, a light distance and a camera move mean the same thing in every scene.
- **The hero fills ≥ 1/3 of the frame height** at its beat; nothing comes within **3%** of an edge
  (`motion-check.py framing`).
- **One camera move**: a push-in of 10–15% of the distance, or an orbit of 10–25°, in-out, over the
  whole piece or one shot.

## Durations and stagger

- Micro (a tick, a toggle): 120–200 ms. Small moves: 200–350 ms. Large moves: 400–700 ms.
- **One hero move per shot.** Secondary moves travel 50–70% as far and start 100–200 ms later; a move that must happen first (something clearing the way) ends 100–200 ms before the hero starts, and is still the smaller move.
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
