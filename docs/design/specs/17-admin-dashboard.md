# 17 · Admin Dashboard And Search

> 운영자가 job을 검색, 필터, 스캔하고 실패 상태를 빠르게 찾는 화면입니다.
> **Mockups:** [desktop](../screens/desktop/17-admin-dashboard.html) · [mobile](../screens/mobile/17-admin-dashboard.html)
> **Catalog ref:** `ops`

## Purpose
운영자가 job을 검색, 필터, 스캔하고 실패 상태를 빠르게 찾는 화면입니다.

## Components
| Component | Behavior |
|---|---|
| **Status filters** | created, processing, Needs review, failed, timeout 등을 빠르게 필터. |
| **Job table** | job id, user, project, status, provider, updated time, action. |
| **Global search** | user id, project id, job id, status 검색과 no results 상태. |
| **Permission row** | 권한 실패는 데이터 누출 없이 행 단위 상태로 표시. |

## States
| State | Treatment |
|---|---|
| `empty` | Uses `rf-chip--admin`, text label, and non-color outline/fill treatment. |
| `filtered` | Uses `rf-chip--candidate`, text label, and non-color outline/fill treatment. |
| `permission denied` | Uses `rf-chip--error`, text label, and non-color outline/fill treatment. |

## Motion
- Page section reveal uses shared `data-reveal`.
- Buttons use the shared ripple/press behavior from `system/motion.js`.
- Canvas-like elements keep subtle hover/selection feedback and collapse under `prefers-reduced-motion`.

## Accessibility
- Status is never color alone; every state pairs color with text.
- Main actions are real buttons with visible focus.
- Mobile layouts keep primary and secondary actions in the bottom action area.
