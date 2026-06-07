# 04 · Room Dimensions

> 방의 실제 가로, 세로, 높이를 meters 기준으로 입력하고 비율을 즉시 확인합니다.
> **Mockups:** [desktop](../screens/desktop/04-room-dimensions.html) · [mobile](../screens/mobile/04-room-dimensions.html)
> **Catalog ref:** `measure`

## Purpose
방의 실제 가로, 세로, 높이를 meters 기준으로 입력하고 비율을 즉시 확인합니다.

## Components
| Component | Behavior |
|---|---|
| **Dimension inputs** | 가로, 세로, 높이를 meters 기준으로 입력. 높이는 MVP 기본값을 명확히 표시. |
| **Unit lock** | 현재 MVP는 meters 중심. 단위 선택이 생겨도 저장 스키마는 meter로 변환. |
| **Room preview** | 입력값에 따라 비율이 바뀌는 미니 평면도. |
| **Validation copy** | 0 이하 값, 비현실적 치수, 누락 값을 입력 바로 아래에서 표시. |

## States
| State | Treatment |
|---|---|
| `metric` | Uses `rf-chip--measure`, text label, and non-color outline/fill treatment. |
| `default height` | Uses `rf-chip--warning`, text label, and non-color outline/fill treatment. |
| `invalid` | Uses `rf-chip--error`, text label, and non-color outline/fill treatment. |

## Motion
- Page section reveal uses shared `data-reveal`.
- Buttons use the shared ripple/press behavior from `system/motion.js`.
- Canvas-like elements keep subtle hover/selection feedback and collapse under `prefers-reduced-motion`.

## Accessibility
- Status is never color alone; every state pairs color with text.
- Main actions are real buttons with visible focus.
- Mobile layouts keep primary and secondary actions in the bottom action area.
