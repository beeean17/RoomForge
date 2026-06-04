# 02 · Project Workspace

> The home base after sign-in. List + detail on desktop; a scannable feed + FAB on mobile.
> **Mockups:** [desktop](../screens/desktop/02-project-workspace.html) · [mobile](../screens/mobile/02-project-workspace.html)
> **Catalog ref:** `projects` — Project list, Detail panel, Empty state, Search/filter.

## Purpose
Let users find a project fast, understand its status at a glance, and resume work in
one tap. This screen carries the **app shell** (top bar, account, new-project CTA) that
the rest of the product inherits.

## Layout
| Breakpoint | Structure |
|---|---|
| **Desktop (≥1000px)** | Two columns: left **project list** (search + status filters + cards), right **sticky detail panel** (3D-ish preview, dimensions, save state, resume actions). |
| **Mobile** | Single-column card feed inside a device frame, sticky **search + horizontal filter chips**, floating **FAB** for new project, bottom tab nav. Detail opens as a pushed screen/sheet. |

## Components
| Component | Behavior |
|---|---|
| **App shell top bar** | Brand, context chip, notifications, **새 프로젝트** primary CTA, account avatar. Glass surface, sticky. |
| **Project card** | Thumbnail (mini plan), name, dimensions, furniture count, last-saved time, status chip. Hover lift + selected ring. Keyboard focusable (`tabindex="0"`). |
| **Search** | Filters by name/status; debounced in implementation. |
| **Status filters** | Toggle chips (전체 / 처리 중 / 검토 필요 / 완료). Active chip inverts to ink. |
| **Detail panel** | Pseudo-3D preview, dimension key-values, save notice, resume + reupload + export actions. |
| **Empty state** | (Documented) When no projects: centered illustration + single "새 프로젝트" CTA, minimal copy. |

## States
| State | Treatment |
|---|---|
| `empty` | Empty-state card with one CTA. |
| `loading` | Card skeletons (`rf-skeleton`) in place of list rows. |
| `selected` | `rf-card--selected` ring + `aria-current`, detail panel populated. |
| `load error` | Inline error notice with retry; never blocks the whole list. |
| Per-project: `처리 중` (live pulse), `검토 필요` (warning), `완료` (confirmed), `초안` (neutral). |

## Motion
- List cards reveal with a staggered rise (`data-stagger`).
- Card hover: `translateY(-3px)` + shadow; press settles.
- "처리 중" chip uses the live pulsing dot.
- FAB press: spring scale-down.

## Accessibility
- Filter chips are real `<button aria-pressed>` inside a labeled `role="group"`.
- Cards are focusable and announce selection via `aria-current`.
- Status is text + dot + outline/surface treatment, never tone alone.
- Search input has an explicit label.

## Implementation notes (Flutter)
- Bind list to a `projects` stream ordered by `updatedAt desc`; map status enum → chip.
- Detail panel reads the selected project's latest layout summary; "이어서 작업" routes to the editor (11).
- Keep thumbnails cheap — render the stored room polygon, not a full 3D scene.
