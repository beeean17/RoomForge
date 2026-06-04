# 07 · OpenCV Candidate Review

> 원본 이미지 위에서 CV 후보를 검토하고, 틀린 후보를 즉시 수동 보정합니다.
> **Mockups:** [desktop](../screens/desktop/07-opencv-candidate-review.html) · [mobile](../screens/mobile/07-opencv-candidate-review.html)
> **Catalog ref:** `cv`

## Purpose
원본 이미지 위에서 CV 후보를 검토하고, 틀린 후보를 즉시 수동 보정합니다.

## Components
| Component | Behavior |
|---|---|
| **Image canvas** | 원본 이미지 위 후보 박스, 벽/바닥 후보, 고정 요소 후보를 레이어로 표시. |
| **Candidate tray** | 침대, 책상, 창문, 문 등 감지 후보를 confidence와 함께 나열. |
| **Layer toggles** | 가구, 구조물, 경계선, 낮은 신뢰도 후보를 켜고 끄는 토글. |
| **Manual fallback** | 자동 결과가 틀렸을 때 후보 추가, 삭제, 라벨 변경을 즉시 제공. |

## States
| State | Treatment |
|---|---|
| `candidate` | Uses `rf-chip--candidate`, text label, and non-color outline/fill treatment. |
| `low confidence` | Uses `rf-chip--warning`, text label, and non-color outline/fill treatment. |
| `accepted` | Uses `rf-chip--confirmed`, text label, and non-color outline/fill treatment. |

## Motion
- Page section reveal uses shared `data-reveal`.
- Buttons use the shared ripple/press behavior from `system/motion.js`.
- Canvas-like elements keep subtle hover/selection feedback and collapse under `prefers-reduced-motion`.

## Accessibility
- Status is never color alone; every state pairs color with text.
- Main actions are real buttons with visible focus.
- Mobile layouts keep primary and secondary actions in the bottom action area.
