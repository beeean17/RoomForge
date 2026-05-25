import 'package:app/src/layouts/layout_draft_models.dart';
import 'package:app/src/layouts/layout_draft_recovery.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('layout draft recovery', () {
    test('does not mark a draft as conflicted without cloud revision', () {
      final draft = _draft(baseCloudUpdatedAt: DateTime.utc(2026, 5, 24, 12));

      expect(layoutDraftHasCloudConflict(draft, null), isFalse);
      expect(
        layoutDraftRecoveryMessage(draft: draft, latestCloudUpdatedAt: null),
        draftRecoveryUnsavedMessage,
      );
    });

    test('detects cloud/draft conflict when cloud revision diverges', () {
      final draft = _draft(baseCloudUpdatedAt: DateTime.utc(2026, 5, 24, 12));
      final cloudUpdatedAt = DateTime.utc(2026, 5, 25, 12);

      expect(layoutDraftHasCloudConflict(draft, cloudUpdatedAt), isTrue);
      expect(
        layoutDraftRecoveryMessage(
          draft: draft,
          latestCloudUpdatedAt: cloudUpdatedAt,
        ),
        draftRecoveryConflictMessage,
      );
    });
  });
}

LayoutDraft _draft({DateTime? baseCloudUpdatedAt}) {
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
    syncState: LayoutDraftSyncState.unsavedDraft,
    baseCloudUpdatedAt: baseCloudUpdatedAt,
    createdAt: DateTime.utc(2026, 5, 25, 12),
    updatedAt: DateTime.utc(2026, 5, 25, 12),
  );
}
