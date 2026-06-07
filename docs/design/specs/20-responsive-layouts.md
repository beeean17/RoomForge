# 20 · Responsive Layouts

> 모바일 촬영, 태블릿 리뷰, 데스크톱 정밀 편집의 layout 전환을 정리합니다.
> **Mockups:** [desktop](../screens/desktop/20-responsive-layouts.html) · [mobile](../screens/mobile/20-responsive-layouts.html)
> **Catalog ref:** `adaptive`

## Purpose
모바일 촬영, 태블릿 리뷰, 데스크톱 정밀 편집의 layout 전환을 정리합니다.

## Components
| Component | Behavior |
|---|---|
| **Mobile** | 촬영, 업로드, 상태 확인. 큰 터치 타겟과 단일 컬럼. |
| **Tablet** | 캔버스와 접히는 inspector. 후보 tray는 하단. |
| **Desktop** | 넓은 캔버스, 좌측 도구, 우측 inspector, 하단 status. |
| **Wide** | admin table과 detail split view를 동시에 표시. |
| **Reduced motion** | 카메라 easing과 panel transition을 최소화. |

## States
| State | Treatment |
|---|---|
| `mobile` | Uses `rf-chip--candidate`, text label, and non-color outline/fill treatment. |
| `tablet` | Uses `rf-chip--measure`, text label, and non-color outline/fill treatment. |
| `desktop` | Uses `rf-chip--confirmed`, text label, and non-color outline/fill treatment. |
| `reduced motion` | Uses `rf-chip--admin`, text label, and non-color outline/fill treatment. |

## Motion
- Page section reveal uses shared `data-reveal`.
- Buttons use the shared ripple/press behavior from `system/motion.js`.
- Canvas-like elements keep subtle hover/selection feedback and collapse under `prefers-reduced-motion`.

## Accessibility
- Status is never color alone; every state pairs color with text.
- Main actions are real buttons with visible focus.
- Mobile layouts keep primary and secondary actions in the bottom action area.
