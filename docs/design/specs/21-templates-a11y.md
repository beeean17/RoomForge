# 21 · Templates And A11y

> empty, loading, error, accessibility 상태 템플릿을 한 화면에 모읍니다.
> **Mockups:** [desktop](../screens/desktop/21-templates-a11y.html) · [mobile](../screens/mobile/21-templates-a11y.html)
> **Catalog ref:** `quality`

## Purpose
empty, loading, error, accessibility 상태 템플릿을 한 화면에 모읍니다.

## Components
| Component | Behavior |
|---|---|
| **Empty template** | 빈 프로젝트, 빈 admin 결과, 빈 candidate tray에 각각 구체 CTA 제공. |
| **Loading template** | skeleton, progress text, 오래 걸릴 때 상태 설명. |
| **Error template** | 재시도 가능/불가능, 권한/네트워크/검증 오류를 구분. |
| **A11y states** | 키보드 포커스, aria-live status, 색상 외 선택 표시, 텍스트 요약. |

## States
| State | Treatment |
|---|---|
| `empty` | Uses `rf-chip--admin`, text label, and non-color outline/fill treatment. |
| `loading` | Uses `rf-chip--save`, text label, and non-color outline/fill treatment. |
| `error` | Uses `rf-chip--error`, text label, and non-color outline/fill treatment. |
| `accessible` | Uses `rf-chip--confirmed`, text label, and non-color outline/fill treatment. |

## Motion
- Page section reveal uses shared `data-reveal`.
- Buttons use the shared ripple/press behavior from `system/motion.js`.
- Canvas-like elements keep subtle hover/selection feedback and collapse under `prefers-reduced-motion`.

## Accessibility
- Status is never color alone; every state pairs color with text.
- Main actions are real buttons with visible focus.
- Mobile layouts keep primary and secondary actions in the bottom action area.
