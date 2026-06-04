# 16 · Admin Route Guard

> 관리자 권한 확인, 거부, stale role 상태를 민감 정보 없이 처리합니다.
> **Mockups:** [desktop](../screens/desktop/16-admin-route-guard.html) · [mobile](../screens/mobile/16-admin-route-guard.html)
> **Catalog ref:** `authz`

## Purpose
관리자 권한 확인, 거부, stale role 상태를 민감 정보 없이 처리합니다.

## Components
| Component | Behavior |
|---|---|
| **Role check state** | 관리자 권한 확인 중 skeleton과 짧은 상태 문구. |
| **Denied panel** | 민감 정보 없이 접근 거부 사유와 계정 전환/새로고침 제공. |
| **Stale role notice** | 토큰 갱신 또는 권한 변경 반영 지연 안내. |

## States
| State | Treatment |
|---|---|
| `checking` | Uses `rf-chip--save`, text label, and non-color outline/fill treatment. |
| `denied` | Uses `rf-chip--error`, text label, and non-color outline/fill treatment. |
| `stale role` | Uses `rf-chip--warning`, text label, and non-color outline/fill treatment. |

## Motion
- Page section reveal uses shared `data-reveal`.
- Buttons use the shared ripple/press behavior from `system/motion.js`.
- Canvas-like elements keep subtle hover/selection feedback and collapse under `prefers-reduced-motion`.

## Accessibility
- Status is never color alone; every state pairs color with text.
- Main actions are real buttons with visible focus.
- Mobile layouts keep primary and secondary actions in the bottom action area.
