# 10 · Floor Plan Review

> 미터 기반 평면도, 경고, artifact 상태를 확인하고 편집기로 넘깁니다.
> **Mockups:** [desktop](../screens/desktop/10-floor-plan-review.html) · [mobile](../screens/mobile/10-floor-plan-review.html)
> **Catalog ref:** `plan`

## Purpose
미터 기반 평면도, 경고, artifact 상태를 확인하고 편집기로 넘깁니다.

## Components
| Component | Behavior |
|---|---|
| **Metric plan canvas** | 방 윤곽, 문/창문, 후보 가구를 meters 좌표계로 표시. |
| **Warnings rail** | 낮은 confidence, 가려진 벽, 치수 불일치, depth 누락. |
| **Artifact links** | overlay, mask, depth JSON 등 생성물의 존재와 접근 상태. |
| **Proceed controls** | 편집기로 이동, 후보 재검토, 수동 보정으로 돌아가기. |

## States
| State | Treatment |
|---|---|
| `metric ready` | Uses `rf-chip--confirmed`, text label, and non-color outline/fill treatment. |
| `warning` | Uses `rf-chip--warning`, text label, and non-color outline/fill treatment. |
| `artifact missing` | Uses `rf-chip--error`, text label, and non-color outline/fill treatment. |

## Motion
- Page section reveal uses shared `data-reveal`.
- Buttons use the shared ripple/press behavior from `system/motion.js`.
- Canvas-like elements keep subtle hover/selection feedback and collapse under `prefers-reduced-motion`.

## Accessibility
- Status is never color alone; every state pairs color with text.
- Main actions are real buttons with visible focus.
- Mobile layouts keep primary and secondary actions in the bottom action area.
