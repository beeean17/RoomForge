# Story 3.1: Spike/Enabler - Editor Bridge and OpenCV Runtime Packaging

## Status

review

## Story

As a developer,
I want the Flutter shell to load the Three.js editor with a typed bridge and packaged OpenCV.js worker runtime,
So that client-side CV processing can run outside the lightweight API server.

## Acceptance Criteria

- Given a room project with a source image, when the Flutter app opens the reconstruction step, then the Three.js editor loads through the chosen embedding approach and Flutter/editor messages use `type`, `version`, `payload`, and optional `requestId`.
- Given OpenCV processing is requested, when the editor runtime starts, then OpenCV.js and WASM assets load in the browser/editor layer, preferably inside a Web Worker, and no heavy CV processing executes on the 1GB FastAPI server.
- Given the Flutter shell and editor are integrated, when a minimal bridge round trip is exercised, then Flutter sends a message with `type`, `version`, `payload`, and `requestId`, and the editor returns a matching response or event that proves asset loading, layout sizing, focus behavior, and bridge messaging work together.

## Tasks / Subtasks

- [x] Replace the placeholder editor screen with a Three.js-backed reconstruction viewport.
- [x] Add typed editor bridge message definitions with `type`, `version`, `payload`, and optional `requestId`.
- [x] Add a browser Web Worker that loads packaged OpenCV runtime assets.
- [x] Add Flutter reconstruction shell entry from the selected project detail panel.
- [x] Embed the editor in Flutter web and send a bridge round-trip message.
- [x] Add local editor URL configuration for Flutter.
- [x] Run Flutter, editor, and server verification.

## Dev Notes

- The Flutter shell embeds the editor through a web iframe using `HtmlElementView`.
- The OpenCV runtime assets are packaged as MVP stub assets under `editor/public/opencv`; actual OpenCV.js/WASM replacement can keep the same manifest contract.
- The FastAPI server remains outside CV processing for this story.

## Dev Agent Record

### Debug Log

- Added Three.js and type definitions to the editor package.
- Added `BridgeMessage` utilities and editor message response handling.
- Added an OpenCV worker bootstrap that fetches the runtime manifest, JavaScript asset, and WASM asset.
- Added `EditorBridgeScreen` in Flutter with iframe embedding and bridge status display.

### Completion Notes

- Flutter can open the reconstruction shell from a selected project.
- Editor posts `roomforge.editor.ready` and OpenCV runtime load events back to Flutter.
- Flutter sends `roomforge.reconstruction.open` and manual `roomforge.editor.ping` messages with `requestId`.
- Editor responds with matching `.response` messages and viewport/runtime payloads.

### File List

- `app/.env.example`
- `app/lib/main.dart`
- `app/lib/src/editor/editor_config.dart`
- `editor/package.json`
- `editor/package-lock.json`
- `editor/public/opencv/opencv-runtime-manifest.json`
- `editor/public/opencv/opencv.js`
- `editor/public/opencv/opencv.wasm`
- `editor/src/bridge.ts`
- `editor/src/main.ts`
- `editor/src/opencvWorker.ts`
- `editor/src/style.css`
- `_bmad-output/implementation-artifacts/3-1-spike-enabler-editor-bridge-and-opencv-runtime-packaging.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`

## Change Log

- 2026-05-19: Implemented editor bridge/OpenCV runtime packaging spike and moved story to review.
