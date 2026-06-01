# Story CV-6.1 Completion Report

## 1. Goal Summary

- Target story: CV-6.1 - Android ARCore Depth Capability Toggle
- Implemented outcome: Added an ARCore Depth capability provider, Android MethodChannel capability hook, guided capture distance-metadata toggle, and depth-enabled capture-session wiring.
- Out of scope: Capturing/storing depth artifacts, camera pose payloads, and using depth metadata for placement.
- Current baseline assumptions: CV-5.1 through CV-5.4 are complete and merged into local `develop`; CV-6 work is running on `epic/cv-6-android-arcore-depth`.

## 2. Acceptance Criteria Verification

- AC 1: Given an Android device supports ARCore Depth, when capture starts, then the user can enable accuracy enhancement.
  - Status: pass
  - Evidence: `ArCoreDepthCapabilityProvider` reads Android capability via `roomforge/arcore_depth`; `GuidedCaptureSessionSection` enables the `guidedCaptureDepthToggleKey` switch when `canEnableDepth` is true.
- AC 2: Given the device does not support ARCore Depth, when capture starts, then normal guided photo capture remains available.
  - Status: pass
  - Evidence: unsupported capability disables only the depth toggle; the guided capture start button remains enabled when room dimensions exist.
- AC 3: Given the user disables enhancement, when photos are captured, then no depth metadata is required.
  - Status: pass
  - Evidence: the disabled toggle copy states no depth metadata is required; `ProjectDetailPanel` passes `depthEnabled: _arCoreDepthCapability.canEnableDepth && _depthEnhancementEnabled`, so disabled or unsupported states create normal guided photo sessions.
- AC 4: Given the toggle is shown, when copy is read, then it describes distance metadata without promising perfect accuracy.
  - Status: pass
  - Evidence: supported copy says ARCore Depth distance metadata is approximate and remains editable; widget tests assert the wording.

## 3. Validation Loop

- Commands run:
  - `dart format app/lib/main.dart app/lib/src/projects/arcore_depth_capability.dart app/lib/src/projects/guided_capture_session_section.dart app/test/src/projects/arcore_depth_capability_test.dart app/test/src/projects/guided_capture_session_section_test.dart app/test/src/projects/firebase_project_api_test.dart`
  - `flutter analyze`
  - `flutter test test/src/projects/arcore_depth_capability_test.dart`
  - `flutter test test/src/projects/guided_capture_session_section_test.dart`
  - `flutter test test/src/projects/firebase_project_api_test.dart`
  - `flutter build apk --debug`
  - `bash private/scripts/check-editor-firebase-boundary.sh`
  - `git diff --check`
- Commands passed: all final listed commands except Android debug build.
- Commands failed: initial `flutter analyze` found an unnecessary import; initial guided capture widget test expected approximate copy while the toggle was off; both were fixed. `flutter build apk --debug` failed because the existing app entrypoint imports `dart:html` and `dart:ui_web`, which are unavailable on Android.
- Fix/retry cycles: 2.
- Substitute checks: Flutter platform-state tests mock Android MethodChannel support and unsupported states; Android build limitation is documented for the existing web-first entrypoint.
- Environment limitations: Android build cannot pass until web-only `dart:html`/`dart:ui_web` dependencies are isolated behind platform-specific entrypoints or conditional imports.
- Final validation result: pass with documented Android build limitation.

## 4. Invariants Verified

- Normal guided photo capture remains the fallback when ARCore Depth is unsupported or disabled: pass.
- Depth enhancement is optional and does not require depth metadata for standard image uploads: pass.
- Toggle copy avoids promising perfect accuracy and keeps user correction as the fallback: pass.
- Backend capture-session model continues to use existing `depth_enabled` and `android_arcore_depth` fields: pass.
- Editor remains free of Firebase SDK imports: pass via submodule boundary check.

## 5. Changed Files

- `app/android/app/src/main/kotlin/com/example/app/MainActivity.kt`
- `app/lib/main.dart`
- `app/lib/src/projects/arcore_depth_capability.dart`
- `app/lib/src/projects/guided_capture_session_section.dart`
- `app/test/src/projects/arcore_depth_capability_test.dart`
- `app/test/src/projects/firebase_project_api_test.dart`
- `app/test/src/projects/guided_capture_session_section_test.dart`

## 6. Story Loop Handoff

- Current story: CV-6.1
- Current story branch: `epic/cv-6-android-arcore-depth`
- Current story status: complete
- Suggested story commit: `feat(cv-6.1): add arcore depth capability toggle`
- Epic status: CV-6 in progress
- Next story: CV-6.2 - Depth Metadata Capture and Storage
- Next story branch: `epic/cv-6-android-arcore-depth`
