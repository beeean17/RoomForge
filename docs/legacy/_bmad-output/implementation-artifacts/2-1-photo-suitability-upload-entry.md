# Story 2.1: Photo Suitability Upload Entry

## Status

review

## Story

As a signed-in user,
I want guidance before uploading a room photo,
So that I can choose an image likely to work with OpenCV reconstruction.

## Acceptance Criteria

- Given I open a room project, when I reach the photo intake step, then I see upload guidance for blur, lighting, visible boundaries, occlusion, distortion, and supported image types.
- The uploader supports empty, selecting, uploading, uploaded, rejected, and low-quality warning states.
- Given I select an unsupported or invalid image, when the client validates it, then the upload is rejected with action-oriented guidance and no reconstruction job is created.

## Tasks / Subtasks

- [x] Add photo suitability guidance to the selected project detail panel.
- [x] Add browser file selection for JPEG, PNG, and WebP source photos.
- [x] Add client-side rejection for unsupported image types and oversize files.
- [x] Add low-quality warning state for very small image files.
- [x] Connect valid source photos to the authenticated upload API without creating reconstruction jobs.

## Dev Notes

- This story intentionally does not start reconstruction jobs; job creation belongs to Epic 3.
- The Flutter MVP target is web, so source image selection uses browser file APIs.
- Drag/drop and file selection both use the same client validation and upload path.

## Dev Agent Record

### Debug Log

- Implemented source photo intake inside `ProjectDetailPanel`.
- Added empty, selecting, uploading, uploaded, rejected, and low-quality warning UI states.
- Added browser drag/drop handling for source image upload.
- Ran `flutter analyze`; initial web-library lints were resolved with a file-level web-only ignore because the MVP client is Flutter web.

### Completion Notes

- Users now see photo suitability guidance when a project is selected.
- Users can choose or drag/drop a supported room photo.
- Unsupported image types and files larger than 10 MB are rejected client-side.
- Accepted images are read in the browser and uploaded to the source image API as base64 JSON.

### File List

- `app/lib/main.dart`
- `app/lib/src/projects/project_api.dart`

## Change Log

- 2026-05-19: Implemented photo suitability upload entry and moved story to review.
