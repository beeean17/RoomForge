# 19 · Admin Retry And Audit

> 재시도 가능 조건을 확인하고 관리자 action receipt를 남깁니다.
> **Mockups:** [desktop](../screens/desktop/19-admin-retry-audit.html) · [mobile](../screens/mobile/19-admin-retry-audit.html)
> **Catalog ref:** `action`

## Purpose
재시도 가능 조건을 확인하고 관리자 action receipt를 남깁니다.

## Components
| Component | Behavior |
|---|---|
| **Retry dialog** | 원본 job, 새 job, 재시도 가능 조건을 확인한 뒤 실행. |
| **Unavailable state** | 이미 처리 중, 권한 없음, artifact 없음 등 재시도 불가 사유. |
| **Audit receipt** | 관리자 action id, 시간, 대상, 결과를 저장 후 표시. |

## States
| State | Treatment |
|---|---|
| `confirm` | Uses `rf-chip--warning`, text label, and non-color outline/fill treatment. |
| `unavailable` | Uses `rf-chip--error`, text label, and non-color outline/fill treatment. |
| `audited` | Uses `rf-chip--confirmed`, text label, and non-color outline/fill treatment. |

## Motion
- Page section reveal uses shared `data-reveal`.
- Buttons use the shared ripple/press behavior from `system/motion.js`.
- Canvas-like elements keep subtle hover/selection feedback and collapse under `prefers-reduced-motion`.

## Accessibility
- Status is never color alone; every state pairs color with text.
- Main actions are real buttons with visible focus.
- Mobile layouts keep primary and secondary actions in the bottom action area.
