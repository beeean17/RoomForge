# 11 · 2D / 3D Editor Shell

> The product's centerpiece. The canvas is the hero; tools, status, and inspector serve it.
> **Mockups:** [desktop](../screens/desktop/11-editor.html) · [mobile](../screens/mobile/11-editor.html)
> **Catalog ref:** `editor` — View switch, Canvas toolbar, Scene canvas, Inspector dock.

## Purpose
Give the user a precise, calm workspace to refine a reconstructed room in 2D/3D:
move, resize, rotate furniture; toggle layers; see validity and warnings; save without
thinking about it.

## Layout
| Breakpoint | Structure |
|---|---|
| **Desktop (≥1100px)** | Three columns inside a full-height shell: **tool rail** (64px) · **canvas** (flex) · **inspector dock** (320px). Top bar (project + undo/redo + save chip + export) and a bottom **status bar** (validity, counts, area, coords). |
| **Tablet (<1100px)** | Inspector collapses; canvas + rail remain. Inspector opens on selection as an overlay. |
| **Mobile** | Canvas fills the screen. **View switch** floats top-center, action FABs float right. Inspector is a **draggable bottom sheet** (collapsed → expanded); tools live in a dock inside the sheet. |

## Components
| Component | Behavior |
|---|---|
| **View switch** | Segmented control 2D / 3D / Split. Sliding spring thumb. Switching tilts the scene (perspective) and **preserves selection**. |
| **Tool rail** | Select / move / add furniture / measure / layers. Single active tool, pressed = muted status tint + border. Tooltips on hover. |
| **Canvas toolbar** | Floating glass bar: fit-to-room, reset camera, snap toggle, grid toggle. Sits *over* the canvas, never boxes it. |
| **Scene canvas** | Gridded work surface. Room outline + fixtures (window/door) + furniture objects. Selected object gets a bright outline + corner handles + dimension labels. |
| **Inspector dock** | Title syncs with selection. Position steppers, size unit-inputs, rotation slider (15° snap), placement warning notice, delete action. |
| **Status bar** | Validity chip, object/fixture counts, area, live cursor coords (mono). |

## States
| State | Treatment |
|---|---|
| `2D` / `3D` / `Split` | Scene transform changes; thumb slides; selection kept (`selection preserved` chip). |
| object `candidate` / `confirmed` / `selected` / `collision` | Muted status border + fill + label; selected adds outline + handles; collision adds warning notice. |
| `saving` → `saved` | Save chip in top bar transitions from live pulse → confirmed. |
| `invalid layout` | Status validity chip switches to error treatment; export guarded. |

## Motion
- View switch: spring thumb + scene perspective ease (`--rf-dur-3`).
- Object select: spring outline + handle fade-in; inspector title swaps.
- Tool/icon press: ripple + spring.
- Autosave: chip morphs from "저장 중…" to "저장됨" after settle.
- Mobile sheet: spring slide between collapsed (peek 88px) and expanded.
- All scene easing collapses under `prefers-reduced-motion`.

## Accessibility
- Tool rail buttons are `aria-pressed` with tooltips + `aria-label`.
- Objects are focusable (`tabindex="0"`); focus selects and syncs the inspector.
- Selection is conveyed by outline + handles + inspector title + chip — never color alone.
- Status bar exposes counts/area/validity as text (screen-reader friendly).
- Mobile grab handle is a real `role="button"` with Enter/Space support.

## Implementation notes (Flutter / Three.js)
- Canvas is a `Three.js`/`flutter_gl` surface filling the center cell; do **not** wrap it in a Material `Card`.
- Keep a single selection model shared between scene + inspector + status bar.
- Rotation slider snaps to 15°; size inputs validate against room bounds and emit the placement warning.
- Autosave debounced; reflect remote-fail as a top-bar chip state (see screen 13).
