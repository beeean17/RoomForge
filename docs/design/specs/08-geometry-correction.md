# 08 · Geometry Correction

> 방 윤곽 꼭짓점과 벽 세그먼트를 조정해 저장 가능한 폐곡선을 만듭니다.
> **Mockups:** [desktop](../screens/desktop/08-geometry-correction.html) · [mobile](../screens/mobile/08-geometry-correction.html)
> **Catalog ref:** `outline`

## Purpose
방 윤곽 꼭짓점과 벽 세그먼트를 조정해 저장 가능한 폐곡선을 만듭니다.

## Components
| Component | Behavior |
|---|---|
| **Corner handles** | 방 윤곽 꼭짓점을 드래그. 선택 핸들은 크기와 outline으로 구분. |
| **Edge controls** | 벽 세그먼트 추가/삭제, 직각 보정, undo/redo. |
| **Validity panel** | 닫히지 않은 윤곽, self-intersection, 3점 미만을 저장 전 차단. |
| **Summary** | 현재 점 개수, 면적, 좌표계가 image pixels인지 meters인지 명시. |

## States
| State | Treatment |
|---|---|
| `calibrating` | Uses `rf-chip--measure`, text label, and non-color outline/fill treatment. |
| `invalid polygon` | Uses `rf-chip--error`, text label, and non-color outline/fill treatment. |
| `valid` | Uses `rf-chip--confirmed`, text label, and non-color outline/fill treatment. |

## Motion
- Page section reveal uses shared `data-reveal`.
- Buttons use the shared ripple/press behavior from `system/motion.js`.
- Canvas-like elements keep subtle hover/selection feedback and collapse under `prefers-reduced-motion`.

## Accessibility
- Status is never color alone; every state pairs color with text.
- Main actions are real buttons with visible focus.
- Mobile layouts keep primary and secondary actions in the bottom action area.
