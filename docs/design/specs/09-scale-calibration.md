# 09 · Scale Calibration

> 이미지 픽셀 좌표를 meters 좌표계로 변환하기 위한 기준선을 설정합니다.
> **Mockups:** [desktop](../screens/desktop/09-scale-calibration.html) · [mobile](../screens/mobile/09-scale-calibration.html)
> **Catalog ref:** `metric`

## Purpose
이미지 픽셀 좌표를 meters 좌표계로 변환하기 위한 기준선을 설정합니다.

## Components
| Component | Behavior |
|---|---|
| **Reference line** | 사용자가 알고 있는 벽 길이를 이미지나 평면도에서 선택. |
| **Length input** | 실측 길이 입력, 단위, 허용 범위 검증. |
| **Scale summary** | 픽셀-미터 변환 결과와 예상 오차를 표시. |
| **Recalculate notice** | 이미지/윤곽/치수 변경으로 재계산이 필요할 때 명확히 안내. |

## States
| State | Treatment |
|---|---|
| `reference selected` | Uses `rf-chip--measure`, text label, and non-color outline/fill treatment. |
| `recalculate` | Uses `rf-chip--warning`, text label, and non-color outline/fill treatment. |
| `invalid length` | Uses `rf-chip--error`, text label, and non-color outline/fill treatment. |

## Motion
- Page section reveal uses shared `data-reveal`.
- Buttons use the shared ripple/press behavior from `system/motion.js`.
- Canvas-like elements keep subtle hover/selection feedback and collapse under `prefers-reduced-motion`.

## Accessibility
- Status is never color alone; every state pairs color with text.
- Main actions are real buttons with visible focus.
- Mobile layouts keep primary and secondary actions in the bottom action area.
