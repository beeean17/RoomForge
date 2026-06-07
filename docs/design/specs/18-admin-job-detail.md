# 18 · Admin Job Detail

> 단일 재구성 job의 메타데이터, 상태 전환, artifact, CV 요약을 조사합니다.
> **Mockups:** [desktop](../screens/desktop/18-admin-job-detail.html) · [mobile](../screens/mobile/18-admin-job-detail.html)
> **Catalog ref:** `diagnostics`

## Purpose
단일 재구성 job의 메타데이터, 상태 전환, artifact, CV 요약을 조사합니다.

## Components
| Component | Behavior |
|---|---|
| **Metadata header** | owner, project, job, provider, attempt, status를 고정 영역에 표시. |
| **Transition timeline** | 상태 변화와 발생 시간을 줄 단위로 스캔 가능하게 표시. |
| **Artifact panels** | source, overlay, mask, depth, floor plan, layout refs의 존재/접근/실패 상태. |
| **OpenCV summary** | candidate count, runtime, confidence, failure reason. |

## States
| State | Treatment |
|---|---|
| `available` | Uses `rf-chip--confirmed`, text label, and non-color outline/fill treatment. |
| `missing` | Uses `rf-chip--warning`, text label, and non-color outline/fill treatment. |
| `restricted` | Uses `rf-chip--error`, text label, and non-color outline/fill treatment. |

## Motion
- Page section reveal uses shared `data-reveal`.
- Buttons use the shared ripple/press behavior from `system/motion.js`.
- Canvas-like elements keep subtle hover/selection feedback and collapse under `prefers-reduced-motion`.

## Accessibility
- Status is never color alone; every state pairs color with text.
- Main actions are real buttons with visible focus.
- Mobile layouts keep primary and secondary actions in the bottom action area.
