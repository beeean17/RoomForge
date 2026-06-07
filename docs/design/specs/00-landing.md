# 00 · Landing (Home)

> Marketing home page with a restrained charcoal-and-accent cursor interaction that *is* the product pitch:
> move the mouse and the **real room photo wipes away to reveal a live Three.js 3D viewer**
> of the same room.
> **Mockup:** [landing.html](../landing.html) · **Assets:** `assets/room.png` (photo),
> `assets/vendor/three.min.js` (Three.js r128, vendored for offline use)

## The interaction
A cinematic charcoal hero with a muted scan accent holds an interactive **stage**.
Two layers are stacked:
1. `layer-photo` — the **real bedroom photo** (the "before").
2. `layer-proc` — a **`<canvas>` running a real-time Three.js scene** of the room rebuilt as
   3D geometry (floor, walls, ceiling, bed + headboard + pillows, nightstands + lamps, desk +
   monitor + chair, dresser, door, a bright daylight window, art, rug, lighting).

The pointer's **X position** drives a smoothed (lerp) value:
- A glowing **scan line** sits at the cursor. `layer-proc` is revealed via
  `clip-path: inset(0 …% 0 0)` **left of the line** — so moving right *wipes the photo away*
  and exposes the live 3D model underneath.
- **The 3D camera is fixed** (no cursor parallax). Its pose + FOV are **calibrated to the
  photo** so the 3D room and its objects (bed, desk, window, floor, walls) line up in
  position and size with the photograph — the wipe reads as a clean photo→3D match, not a
  drifting view.
- A **mode badge** ("Live 3D model") rides the line; the photo badge ("Original photo") is pinned right.
- A muted blue/teal vertical light band adds depth; two **pips** reflect the dominant side.
- Fine-pointer devices add subtle stage tilt, magnetic button movement, and card tilt/sheen micro-interactions.

Because the 3D camera roughly matches the photo's viewpoint, the wipe reads as the photo
literally *becoming* a navigable 3D space.

## Performance
- Render buffer is **capped at 960px wide** and **pixelRatio 1**, then CSS-upscaled to fill the
  stage — smooth even on software WebGL / low-end GPUs with no visible quality loss.
- **Render-on-demand**: the scene only renders while the view is changing (a `settle` counter
  keeps ~16 frames alive after the last movement, then idles) — no constant GPU/CPU burn.
- **Graceful fallback**: if WebGL is unavailable the `try/catch` hides `layer-proc`, leaving the
  plain photo. `prefers-reduced-motion` disables tilt/magnetic motion and snaps the lerp.

## Inputs & fallbacks
| Input | Behavior |
|---|---|
| Mouse move / drag | Wipes the photo and adds subtle stage surface response. |
| Keyboard (←/→) | Stage is `role="slider"`, focusable; arrows step the reveal; `aria-valuenow` updates. |
| Touch / no-hover | Auto-demo: the scan line gently sweeps until the user interacts. |
| No WebGL | Photo-only fallback. |

## How the 3D scene is built (`landing.html`)
- A small `box(w,h,d,color,opts)` / `plane(w,h,color,opts)` helper assembles ~40 meshes with
  `MeshStandardMaterial`. Room coordinate system in meters; camera near the doorway looking in.
- Lighting: `HemisphereLight` + a window `DirectionalLight` + a ceiling `PointLight` + two warm
  lamp `PointLight`s. The window and lamps use emissive materials.
- One rAF loop owns: lerp, scan/clip/badge/light band/pips. The 3D camera is static, so the scene
  is rendered only on load + resize (a small `settle` counter), not every frame — the wipe
  just clips the already-rendered canvas.

## Production path
- Replace the hand-built scene with the **live reconstruction** of the user's uploaded room
  (Three.js mesh from the pipeline), and `assets/room.png` with the **user's own photo**, using
  the **estimated camera pose** so the wipe aligns perfectly. The interaction code (clip-path
  reveal, scan line, ARIA, throttling) stays identical.
- Swap the stock photo for a licensed/owned asset before shipping.
