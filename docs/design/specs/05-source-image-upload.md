# 05 · Source Image Upload

> 원본 방 이미지를 업로드하고 품질, 권한, 진행 상태를 한 화면에서 복구합니다.
> **Mockups:** [desktop](../screens/desktop/05-source-image-upload.html) · [mobile](../screens/mobile/05-source-image-upload.html)
> **Catalog ref:** `upload`

## Purpose
원본 방 이미지를 업로드하고 품질, 권한, 진행 상태를 한 화면에서 복구합니다.

## Components
| Component | Behavior |
|---|---|
| **Drop zone** | 클릭, 드래그, 모바일 촬영 진입을 모두 수용하는 이미지 입력 영역. |
| **File preview** | 파일명, 해상도, 용량, 품질 경고, 교체 액션. |
| **Progress row** | Storage 업로드, metadata 저장, 실패 복구 단계를 분리해서 보여줌. |
| **Recovery controls** | 사진 다시 선택, 업로드 재시도, 권한 오류 안내. |

## States
| State | Treatment |
|---|---|
| `dragging` | Uses `rf-chip--candidate`, text label, and non-color outline/fill treatment. |
| `uploading` | Uses `rf-chip--save`, text label, and non-color outline/fill treatment. |
| `uploaded` | Uses `rf-chip--confirmed`, text label, and non-color outline/fill treatment. |
| `permission denied` | Uses `rf-chip--error`, text label, and non-color outline/fill treatment. |

## Motion
- Page section reveal uses shared `data-reveal`.
- Buttons use the shared ripple/press behavior from `system/motion.js`.
- Canvas-like elements keep subtle hover/selection feedback and collapse under `prefers-reduced-motion`.

## Accessibility
- Status is never color alone; every state pairs color with text.
- Main actions are real buttons with visible focus.
- Mobile layouts keep primary and secondary actions in the bottom action area.
