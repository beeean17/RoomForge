# 01 · Sign In

> Auth entry. The first impression of RoomForge: calm, trustworthy, fast to get past.
> **Mockups:** [desktop](../screens/desktop/01-sign-in.html) · [mobile](../screens/mobile/01-sign-in.html)
> **Catalog ref:** `auth` — Brand panel, Provider button, Config notice, Error banner.

## Purpose
Get a returning or new user authenticated with the least friction, while quietly
establishing product credibility ("a photo becomes an editable room"). One provider
(Google) for the MVP — no password surface to design.

## Layout
| Breakpoint | Structure |
|---|---|
| **Desktop (≥860px)** | Split card: left **brand panel** (charcoal hero surface + muted accent mini floor-plan), right **form side** (heading, provider button, legal, state preview). |
| **Mobile (<860px)** | Full-bleed charcoal **hero** with the mini floor-plan, auth presented as a **bottom sheet** that slides up. Provider button is a 54px touch target. |

## Components
| Component | Behavior |
|---|---|
| **Brand panel** | Charcoal surface (`--rf-grad-brand`) with a subtle grid mask and a floating mini floor-plan (bed + desk gently bob). Trust pills: secure login, auto reconstruction, manual fallback. |
| **Provider button** | Color Google mark + label. On click → spinner + "로그인 중…", border/bg shift to muted primary gradient. Idle / busy / disabled states. |
| **Config notice** | Shown only when Firebase config is missing — separates a developer-facing code hint from a user-facing message. (Not in default render; documented state.) |
| **Error banner** | `rf-notice--error`, `role="alert"`. Safe copy for popup-blocked / permission / network failures. No internal error codes. |

## States
| State | Chip | Trigger | Treatment |
|---|---|---|---|
| `idle` | candidate | default | Button enabled, no banner. |
| `signing in` | save, live pulse | click | Spinner in button, button disabled, banner cleared. |
| `failed` | error | popup blocked / auth error | Error banner appears, button returns to idle. |
| `config missing` | warning | env not set | Warning notice with dev hint; provider disabled. |

## Motion
- Card / sheet entrance: `data-reveal="scale"` (desktop) and slide-up spring (mobile, `rf-sheet-up`).
- Floating furniture in the preview: 5–6s ease loop, **disabled under `prefers-reduced-motion`**.
- Button press: ripple + spring scale; busy state swaps to a rotating spinner.

## Accessibility
- `main[aria-labelledby]`, error banner is `role="alert"`.
- Provider button has an explicit `aria-label`.
- Focus-visible ring on the button; legal links are reachable by keyboard.
- State preview chips are `aria-hidden` (decorative); real state is conveyed by the banner text.
- Color never carries state alone — every chip pairs a dot + word.

## Copy (ko)
- Headline: "사진 한 장으로 시작하는 방 설계"
- Button: "Google 계정으로 계속하기" / mobile "Google로 계속하기"
- Error: "로그인이 완료되지 않았어요 · 팝업이 차단되었을 수 있어요…"

## Implementation notes (Flutter)
- Map the provider button to `signInWithPopup` / redirect; reflect `signing in` by disabling and showing a `CircularProgressIndicator`.
- Keep the error map → friendly-copy translation in one place; never surface raw `FirebaseAuthException` codes.
- The brand preview is purely decorative — render a static asset if motion budget is tight.
