# 06 · Reconstruction Status

> 재구성 job의 상태, 실패, 재시도, 검토 필요 전환을 타임라인으로 보여줍니다.
> **Mockups:** [desktop](../screens/desktop/06-reconstruction-status.html) · [mobile](../screens/mobile/06-reconstruction-status.html)
> **Catalog ref:** `jobs`

## Purpose
재구성 job의 상태, 실패, 재시도, 검토 필요 전환을 타임라인으로 보여줍니다.

## Components
| Component | Behavior |
|---|---|
| **Status timeline** | `created`부터 `retrying`까지 단계별 점검표. `review_required`는 `Needs review`로 표시. |
| **Job detail strip** | job id, provider, source image, updated time을 compact하게 제공. |
| **Retry action** | 실패/타임아웃 시 재시도 조건과 버튼. |
| **Continue CTA** | 성공 또는 검토 필요 상태에서 리뷰 화면으로 이어지는 명령. |

## States
| State | Treatment |
|---|---|
| `created` | Uses `rf-chip--admin`, text label, and non-color outline/fill treatment. |
| `processing` | Uses `rf-chip--save`, text label, and non-color outline/fill treatment. |
| `Needs review` | Uses `rf-chip--warning`, text label, and non-color outline/fill treatment. |
| `succeeded` | Uses `rf-chip--confirmed`, text label, and non-color outline/fill treatment. |
| `failed` | Uses `rf-chip--error`, text label, and non-color outline/fill treatment. |

## Motion
- Page section reveal uses shared `data-reveal`.
- Buttons use the shared ripple/press behavior from `system/motion.js`.
- Canvas-like elements keep subtle hover/selection feedback and collapse under `prefers-reduced-motion`.

## Accessibility
- Status is never color alone; every state pairs color with text.
- Main actions are real buttons with visible focus.
- Mobile layouts keep primary and secondary actions in the bottom action area.
