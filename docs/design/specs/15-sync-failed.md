# 15 · Sync Failed And Reupload

> 네트워크, 권한, 서버 실패를 구분하고 재시도와 재업로드를 연결합니다.
> **Mockups:** [desktop](../screens/desktop/15-sync-failed.html) · [mobile](../screens/mobile/15-sync-failed.html)
> **Catalog ref:** `failure`

## Purpose
네트워크, 권한, 서버 실패를 구분하고 재시도와 재업로드를 연결합니다.

## Components
| Component | Behavior |
|---|---|
| **Sync issue panel** | 네트워크, 권한, 서버 실패를 구분하고 안전한 다음 액션을 제공. |
| **Retry cluster** | 재시도, 로컬 유지, 로그 보기, 프로젝트 다시 열기를 묶음. |
| **Reupload bridge** | 새 사진 업로드 시 기존 치수/후보/수정값이 무엇을 유지하는지 표시. |

## States
| State | Treatment |
|---|---|
| `permission` | Uses `rf-chip--error`, text label, and non-color outline/fill treatment. |
| `network` | Uses `rf-chip--warning`, text label, and non-color outline/fill treatment. |
| `retrying` | Uses `rf-chip--save`, text label, and non-color outline/fill treatment. |

## Motion
- Page section reveal uses shared `data-reveal`.
- Buttons use the shared ripple/press behavior from `system/motion.js`.
- Canvas-like elements keep subtle hover/selection feedback and collapse under `prefers-reduced-motion`.

## Accessibility
- Status is never color alone; every state pairs color with text.
- Main actions are real buttons with visible focus.
- Mobile layouts keep primary and secondary actions in the bottom action area.
