# RoomForge — Screen Design System

Screen-by-screen UI designs derived from
[`screen-component-catalog.html`](screen-component-catalog.html). Every screen ships as
**three artifacts**: a desktop HTML mockup, a dedicated mobile HTML mockup, and a
markdown spec.

> **Visual direction:** premium charcoal work-tool UI — restrained surfaces,
> thin lines, crisp type, muted state accents, and small micro-interactions,
> all honoring `prefers-reduced-motion`.

## Layout
```
docs/design/
├── landing.html               ← marketing home page: charcoal + accent cursor interaction
├── index.html                 ← gallery: links every screen (start here)
├── README.md                  ← this file
├── screen-component-catalog.html  ← original component catalog (source of truth)
├── system/
│   ├── tokens.css             ← color, type, spacing, elevation, motion tokens
│   ├── base.css               ← shared components (buttons, fields, chips, cards, ...)
│   ├── screen-mockups.css     ← shared layout primitives for generated screen mockups
│   └── motion.js              ← reveal, ripple, segmented control, toast (no deps)
├── screens/
│   ├── desktop/NN-name.html
│   └── mobile/NN-name.html    ← dedicated phone layouts (device frame)
└── specs/NN-name.md           ← purpose, layout, components, states, motion, a11y
```

Open [`index.html`](index.html) in a browser to browse everything.

Production implementation is tracked in
[`production-ui-migration-plan.md`](production-ui-migration-plan.md): **1 screen =
1 goal = 1 validation loop = 1 local commit**.

## The shared system
- **Tokens** (`system/tokens.css`) — one source of truth. Status roles still map 1:1 to
  `packages/design-tokens.json` (candidate/confirmed/selected/warning/error/measure/save/admin),
  but the mockups express them as muted accents paired with surfaces, dots, labels, and outlines.
- **Base components** (`system/base.css`) — `rf-btn`, `rf-icon-btn`, `rf-input`,
  `rf-stepper`, `rf-slider`, `rf-toggle`, `rf-chip`, `rf-card`, `rf-panel`, `rf-notice`,
  `rf-segment`, `rf-progress`, `rf-skeleton`, `rf-timeline`, `rf-dialog`, `rf-toast`,
  tooltips, and the desktop app shell.
- **Screen mockups** (`system/screen-mockups.css`) — reusable desktop/mobile mockup scaffolding
  for screens 03-10 and 12-21.
- **Motion** (`system/motion.js`) — IntersectionObserver reveal/stagger, press ripples,
  the sliding segmented-control thumb, animated progress fills, and `window.rfToast()`.

## Design principles
1. **Canvas is the hero.** 2D/3D work surfaces are never trapped in decorative cards.
2. **State is never color alone.** Every status pairs color + dot + word (+ outline/icon).
3. **Manual fallback is always near.** CV results can be wrong; correction is one tap away.
4. **Data boundary.** User screens never expose Firebase/Firestore terms; only admin
   screens show ids, artifacts, providers, rule states.
5. **Density over decoration.** It's a work tool — scan-ability beats marketing flourish.
6. **Motion with restraint.** Spring + ease for feedback, fully collapsible under
   reduced-motion.

## Status
| # | Screen | Desktop | Mobile | Spec |
|---|--------|:------:|:------:|:----:|
| 01 | Sign In | ✅ | ✅ | ✅ |
| 02 | Project Workspace | ✅ | ✅ | ✅ |
| 03 | Project Dialog | ✅ | ✅ | ✅ |
| 04 | Room Dimensions | ✅ | ✅ | ✅ |
| 05 | Source Image Upload | ✅ | ✅ | ✅ |
| 06 | Reconstruction Status | ✅ | ✅ | ✅ |
| 07 | OpenCV Candidate Review | ✅ | ✅ | ✅ |
| 08 | Geometry Correction | ✅ | ✅ | ✅ |
| 09 | Scale Calibration | ✅ | ✅ | ✅ |
| 10 | Floor Plan Review | ✅ | ✅ | ✅ |
| 11 | 2D / 3D Editor Shell | ✅ | ✅ | ✅ |
| 12 | Furniture And Inspector | ✅ | ✅ | ✅ |
| 13 | Layout Save / Load / Export | ✅ | ✅ | ✅ |
| 14 | Draft Recovery And Conflict | ✅ | ✅ | ✅ |
| 15 | Sync Failed And Reupload | ✅ | ✅ | ✅ |
| 16 | Admin Route Guard | ✅ | ✅ | ✅ |
| 17 | Admin Dashboard And Search | ✅ | ✅ | ✅ |
| 18 | Admin Job Detail | ✅ | ✅ | ✅ |
| 19 | Admin Retry And Audit | ✅ | ✅ | ✅ |
| 20 | Responsive Layouts | ✅ | ✅ | ✅ |
| 21 | Templates And A11y | ✅ | ✅ | ✅ |

All 21 catalog screens are implemented as static HTML mockups in both desktop and
mobile forms. The remaining production work is to map these artifacts into the
Flutter / Three.js / FastAPI boundaries defined in the product architecture.
