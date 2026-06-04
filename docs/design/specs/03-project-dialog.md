# 03 · Project Dialog

> 프로젝트 생성, 편집, 삭제 확인을 한 흐름 안에서 처리합니다.
> **Mockups:** [desktop](../screens/desktop/03-project-dialog.html) · [mobile](../screens/mobile/03-project-dialog.html)
> **Catalog ref:** `modal`

## Purpose
프로젝트 생성, 편집, 삭제 확인을 한 흐름 안에서 처리합니다.

## Components
| Component | Behavior |
|---|---|
| **Name field** | 필수 입력, 글자 수, 중복 또는 빈 값 검증. |
| **Description** | 선택 입력. 방 이름만으로 부족할 때 메모를 남김. |
| **Danger zone** | 삭제 확인은 별도 강조 영역과 최종 확인 버튼. |
| **Save footer** | 취소, 저장, 저장 중, 실패 재시도 상태. |

## States
| State | Treatment |
|---|---|
| `create` | Uses `rf-chip--candidate`, text label, and non-color outline/fill treatment. |
| `edit` | Uses `rf-chip--save`, text label, and non-color outline/fill treatment. |
| `delete confirm` | Uses `rf-chip--error`, text label, and non-color outline/fill treatment. |

## Motion
- Page section reveal uses shared `data-reveal`.
- Buttons use the shared ripple/press behavior from `system/motion.js`.
- Canvas-like elements keep subtle hover/selection feedback and collapse under `prefers-reduced-motion`.

## Accessibility
- Status is never color alone; every state pairs color with text.
- Main actions are real buttons with visible focus.
- Mobile layouts keep primary and secondary actions in the bottom action area.
