# 12 · Furniture And Inspector

> 가구 프록시를 추가하고 위치, 회전, 크기, 충돌 상태를 편집합니다.
> **Mockups:** [desktop](../screens/desktop/12-furniture-inspector.html) · [mobile](../screens/mobile/12-furniture-inspector.html)
> **Catalog ref:** `objects`

## Purpose
가구 프록시를 추가하고 위치, 회전, 크기, 충돌 상태를 편집합니다.

## Components
| Component | Behavior |
|---|---|
| **Furniture catalog** | 침대, 책상, 의자, 수납장 등 대표 프록시 오브젝트를 크기 prior와 함께 제공. |
| **Object chip** | 후보/확정/선택/잠금 상태를 텍스트와 outline으로 구분. |
| **Transform controls** | x/y 위치, 회전, width/depth/height, stepper와 slider 조합. |
| **Placement warning** | 벽 밖 배치, 겹침, 문/창문 충돌을 저장 전 경고. |

## States
| State | Treatment |
|---|---|
| `candidate` | Uses `rf-chip--candidate`, text label, and non-color outline/fill treatment. |
| `confirmed` | Uses `rf-chip--confirmed`, text label, and non-color outline/fill treatment. |
| `selected` | Uses `rf-chip--selected`, text label, and non-color outline/fill treatment. |
| `collision` | Uses `rf-chip--error`, text label, and non-color outline/fill treatment. |

## Motion
- Page section reveal uses shared `data-reveal`.
- Buttons use the shared ripple/press behavior from `system/motion.js`.
- Canvas-like elements keep subtle hover/selection feedback and collapse under `prefers-reduced-motion`.

## Accessibility
- Status is never color alone; every state pairs color with text.
- Main actions are real buttons with visible focus.
- Mobile layouts keep primary and secondary actions in the bottom action area.
