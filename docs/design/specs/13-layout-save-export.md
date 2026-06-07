# 13 · Layout Save / Load / Export

> 저장, 로드, JSON 내보내기의 상태와 round-trip 검증을 표시합니다.
> **Mockups:** [desktop](../screens/desktop/13-layout-save-export.html) · [mobile](../screens/mobile/13-layout-save-export.html)
> **Catalog ref:** `persistence`

## Purpose
저장, 로드, JSON 내보내기의 상태와 round-trip 검증을 표시합니다.

## Components
| Component | Behavior |
|---|---|
| **Save status** | unsaved, saving, saved, remote failed를 상단과 하단 모두에서 확인. |
| **Load selector** | 최신 저장본, 로컬 draft, 이전 export를 명확히 구분. |
| **Export preview** | JSON 내보내기 전 포함 데이터, 좌표계, 누락 경고 표시. |
| **Round-trip notice** | 저장/로드/내보내기 결과가 일관적인지 검증 상태를 표시. |

## States
| State | Treatment |
|---|---|
| `unsaved` | Uses `rf-chip--warning`, text label, and non-color outline/fill treatment. |
| `saving` | Uses `rf-chip--save`, text label, and non-color outline/fill treatment. |
| `saved` | Uses `rf-chip--confirmed`, text label, and non-color outline/fill treatment. |
| `export failed` | Uses `rf-chip--error`, text label, and non-color outline/fill treatment. |

## Motion
- Page section reveal uses shared `data-reveal`.
- Buttons use the shared ripple/press behavior from `system/motion.js`.
- Canvas-like elements keep subtle hover/selection feedback and collapse under `prefers-reduced-motion`.

## Accessibility
- Status is never color alone; every state pairs color with text.
- Main actions are real buttons with visible focus.
- Mobile layouts keep primary and secondary actions in the bottom action area.
