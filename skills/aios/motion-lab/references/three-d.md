# 3D with Three.js — the recipe that renders deterministically

What worked for a 12-second, 1920×1080 product piece rendered frame by frame in headless Chromium,
with every check green. Use it as the starting skeleton; change the scene, keep the plumbing.

## Plumbing (do not improvise this part)

```html
<script>window.__ready = false; window.__duration = 12; window.__fps = 60;</script>
<script type="importmap">
{ "imports": {
  "three": "https://cdn.jsdelivr.net/npm/three@0.160.0/build/three.module.js",
  "three/addons/": "https://cdn.jsdelivr.net/npm/three@0.160.0/examples/jsm/" } }
</script>
<script type="module">
import * as THREE from 'three';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';

const renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true }); // screenshots see the frame
renderer.setPixelRatio(1);                         // the viewport IS the output size
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.setSize(innerWidth, innerHeight); document.body.appendChild(renderer.domElement);

const scene = new THREE.Scene();
const pmrem = new THREE.PMREMGenerator(renderer);  // reflections only; the lights below do the lighting
scene.environment = pmrem.fromScene(new RoomEnvironment(renderer), 0.04).texture;
const camera = new THREE.PerspectiveCamera(37.8, innerWidth / innerHeight, 0.1, 100); // ~35 mm

// ... build the scene ...

window.renderAt = (t) => { setScene(state(t)); renderer.render(scene, camera); }; // synchronous, pure in t
window.__probe = (t) => { /* the numbers QA asserts */ };
const q = new URLSearchParams(location.search).get('t');
window.renderAt(q !== null ? Number(q) : window.__duration - 0.5);   // opened by hand: the hero frame
window.__ready = true;                              // only after every texture is drawn
</script>
```

- **Pin the version** in the import map (`three@0.160.0`); `motion-check contract` reads import maps.
- **WebGL works in stock headless Chromium** (software renderer, deterministic). No flags needed.
- **`state(t)` computes everything; `setScene` only applies it.** No `clock.getDelta()`, no
  animation mixer advancing on its own, no physics stepping: frame 400 must render alone.

## Lights, as numbers

A three-light studio, each as a direction (azimuth, elevation in degrees) and an intensity:

```js
function dirLight(color, intensity, az, el) {
  const L = new THREE.DirectionalLight(color, intensity), D = Math.PI / 180;
  L.position.set(Math.sin(az*D)*Math.cos(el*D), Math.sin(el*D), Math.cos(az*D)*Math.cos(el*D)).multiplyScalar(10);
  scene.add(L); return L;
}
dirLight(0xfff4ea, 2.6, -40, 38);  // key: warm, front-left, high
dirLight(0xdfe6ff, 0.55, 55, 8);   // fill: cool, right, low
dirLight(0xffffff, 3.2, 160, 32);  // rim: behind, separates the object from a dark ground
```

## Ground, scale and camera

- **No floor by default.** `scene.background = new THREE.Color(0x0a0a0c)` and nothing under the
  subject. If it must rest on something, give it a **contact shadow only**: a plane with
  `THREE.ShadowMaterial({ opacity: 0.35 })`, which draws the shadow and nothing else.
- **Metres, real size** (a phone 0.147 m tall). Camera distance follows: a 35 mm lens frames a
  0.15 m object at a third of the height from about 0.9 m.
- **The camera is a function of t too**: compute its position and target in `state(t)` (an in-out
  push-in, or a short orbit around the target) and call `camera.lookAt` in `setScene`.
- **Frame the beat, not the scene.** A three-quarter view (15–35° off front), the acting objects
  close and large, the others behind or out of frame. Move the camera target between beats if the
  action moves.
- **Report the hero's own share of the frame** so `assert` can check it (`framing` only sees all
  non-ground pixels together):

  ```js
  function screenHeight(obj) {               // the object's projected height, 0..1 of the frame
    const b = new THREE.Box3().setFromObject(obj), ys = [];
    for (const x of [b.min.x, b.max.x]) for (const y of [b.min.y, b.max.y]) for (const z of [b.min.z, b.max.z])
      ys.push(new THREE.Vector3(x, y, z).project(camera).y);
    return (Math.max(...ys) - Math.min(...ys)) / 2;
  }
  // in __probe(t), after renderAt(t): heroH: screenHeight(cup)  -> assert heroH >= 0.33 on the hero frame
  ```
- **The square cut** reads `?aspect=1`: set the camera aspect to 1, then move the camera back (or
  widen the fov) **and re-lay out the objects** where the wide arrangement does not fit a square
  (bring them closer together, or stack them in depth), until the widest moment fits inside the
  margins. Render at `--size 1080x1080`, with the URL carrying `?aspect=1`.

## Objects without models

Devices, cards and panels are **rounded rectangles**, flat or extruded, built in code, so nothing
is downloaded and nothing infringes a product's design:

- `THREE.Shape` with quadratic corners → `ShapeGeometry` (a flat face, set UVs to 0..1 so a texture
  maps cleanly) or `ExtrudeGeometry` with a small bevel (a slab: a phone, a card, a tablet).
- **Build every part the camera sees**: a phone has its camera bump, side buttons and a screen
  with a real interface state; a cup has its rim, sleeve and lid lip. Lathe (`LatheGeometry`) a
  profile curve for anything round. A plain primitive reads as a placeholder.
- Glass: `MeshPhysicalMaterial({ roughness: 0.08, clearcoat: 1, envMapIntensity: 0.35 })`.
  Metal frame: `metalness: 0.85, roughness: 0.3`. Keep `envMapIntensity` low on a dark ground, or
  everything turns grey.

## Text and UI on screens

Draw screens and labels into a **canvas**, then use it as a `CanvasTexture`
(`colorSpace = SRGBColorSpace`, `anisotropy = 8`). Draw every state the story needs up front, or
redraw a screen as a pure function of t inside `setScene` and set `tex.needsUpdate = true`.
System font stacks need no network; a web font must be loaded (`document.fonts.load`) before
`__ready`.

## The lab loop in 3D

The first contact sheet usually shows the same three faults; look for them by frame:

- **Too small in frame**: the hero object or the event is a few pixels; move the camera in before
  touching anything else (`framing` reports the hero height).
- **Mud**: a floor or sweep catches the key light and the frame goes mid-grey (`framing`, ground
  stays ground). Remove it; keep a contact shadow.
- **The hero move reads as a slide**: lift it off its surface (a dip, then an arc) so it separates
  from what it leaves.
- **It arrives early or late**: give the travel its own easing and let a spring do the last
  centimetres; assert where it is on the landing frame.
