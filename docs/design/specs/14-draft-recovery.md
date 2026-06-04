# 14 · Draft Recovery And Conflict

> 로컬 draft와 클라우드 저장본의 차이를 비교하고 명시적으로 복구합니다.
> **Mockups:** [desktop](../screens/desktop/14-draft-recovery.html) · [mobile](../screens/mobile/14-draft-recovery.html)
> **Catalog ref:** `draft`

## Purpose
로컬 draft와 클라우드 저장본의 차이를 비교하고 명시적으로 복구합니다.

## Components
| Component | Behavior |
|---|---|
| **Recovery banner** | 로컬 draft 발견 시 복원, 폐기, 클라우드 버전 계속하기를 동등한 선택지로 제시. |
| **Diff summary** | 수정 시간, 가구 수, 방 치수 차이를 사람이 이해 가능한 문장으로 비교. |
| **Choice dialog** | 충돌 해결은 자동 병합 대신 명시적 선택을 기본값으로 함. |

## States
| State | Treatment |
|---|---|
| `local draft` | Uses `rf-chip--warning`, text label, and non-color outline/fill treatment. |
| `cloud newer` | Uses `rf-chip--candidate`, text label, and non-color outline/fill treatment. |
| `restored` | Uses `rf-chip--confirmed`, text label, and non-color outline/fill treatment. |

## Motion
- Page section reveal uses shared `data-reveal`.
- Buttons use the shared ripple/press behavior from `system/motion.js`.
- Canvas-like elements keep subtle hover/selection feedback and collapse under `prefers-reduced-motion`.

## Accessibility
- Status is never color alone; every state pairs color with text.
- Main actions are real buttons with visible focus.
- Mobile layouts keep primary and secondary actions in the bottom action area.
