import 'package:app/src/layouts/layout_draft_models.dart';
import 'package:app/src/layouts/layout_remote_update_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('layout remote update guard', () {
    test('holds remote layout updates while a recoverable draft exists', () {
      expect(
        shouldHoldRemoteLayoutForDraft(
          draft: _draft(LayoutDraftSyncState.unsavedDraft),
          forceApplyCloud: false,
        ),
        isTrue,
      );
    });

    test('allows forced cloud apply and saved drafts', () {
      expect(
        shouldHoldRemoteLayoutForDraft(
          draft: _draft(LayoutDraftSyncState.unsavedDraft),
          forceApplyCloud: true,
        ),
        isFalse,
      );
      expect(
        shouldHoldRemoteLayoutForDraft(
          draft: _draft(LayoutDraftSyncState.saved),
          forceApplyCloud: false,
        ),
        isFalse,
      );
    });

    test('exposes sync failed and retry copy', () {
      expect(layoutSyncFailedLabel, 'Sync failed');
      expect(layoutRetryAvailableLabel, 'Retry available');
    });
  });
}

LayoutDraft _draft(String syncState) {
  return LayoutDraft(
    draftKey: 'user-1/project-1/current',
    ownerUid: 'user-1',
    projectId: 'project-1',
    localRevision: 1,
    schemaVersion: 1,
    roomDimensionsSnapshot: const {'unit': 'meters'},
    floorPlanSnapshot: const {'floor_plan_id': 'floor-plan-1'},
    sourceMetadataSnapshot: const {'source_image_id': 'source-1'},
    editorScene: const {'scene_id': 'scene-1'},
    furnitureObjects: const [],
    reconstructionStatus: 'succeeded',
    reviewRequired: false,
    dirtyFields: const ['editor_scene'],
    syncState: syncState,
    createdAt: DateTime.utc(2026, 5, 25, 12),
    updatedAt: DateTime.utc(2026, 5, 25, 12),
  );
}
