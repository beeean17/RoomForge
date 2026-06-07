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
      expect(
        layoutDraftRecoveryActions(
          draft: draft,
          latestCloudUpdatedAt: null,
        ).map((action) => action.id),
        [
          LayoutDraftRecoveryActionId.restoreDraft,
          LayoutDraftRecoveryActionId.discardDraft,
        ],
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
      final actions = layoutDraftRecoveryActions(
        draft: draft,
        latestCloudUpdatedAt: cloudUpdatedAt,
      );
      expect(actions.map((action) => action.id), [
        LayoutDraftRecoveryActionId.restoreDraft,
        LayoutDraftRecoveryActionId.discardDraft,
        LayoutDraftRecoveryActionId.continueSavedVersion,
      ]);
      expect(actions[1].requiresConfirmation, isTrue);
    });

    test('exposes destructive discard confirmation copy', () {
      final draft = _draft();
      final discard =
          layoutDraftRecoveryActions(
            draft: draft,
            latestCloudUpdatedAt: null,
          ).singleWhere(
            (action) => action.id == LayoutDraftRecoveryActionId.discardDraft,
          );

      expect(discard.isDestructive, isTrue);
      expect(discard.requiresConfirmation, isTrue);
      expect(draftRecoveryDiscardConfirmationTitle, 'Discard draft?');
      expect(
        draftRecoveryDiscardConfirmationMessage,
        'This removes the local draft only.',
      );
    });

    test('adds retry action and readable summary for sync failure', () {
      final draft = _draft(syncState: LayoutDraftSyncState.syncFailed);

      final actions = layoutDraftRecoveryActions(
        draft: draft,
        latestCloudUpdatedAt: null,
      );
      final summary = layoutDraftRecoveryAccessibilitySummary(
        draft: draft,
        latestCloudUpdatedAt: null,
      );

      expect(draft.label, 'Sync failed');
      expect(
        actions.map((action) => action.id),
        contains(LayoutDraftRecoveryActionId.retrySave),
      );
      expect(summary, contains('Sync failed'));
      expect(summary, contains('Retry save'));
    });

    test('maps draft sync states to user-visible labels', () {
      expect(
        _draft(syncState: LayoutDraftSyncState.unsavedDraft).label,
        'Unsaved draft',
      );
      expect(_draft(syncState: LayoutDraftSyncState.saving).label, 'Saving');
      expect(
        _draft(syncState: LayoutDraftSyncState.syncFailed).label,
        'Sync failed',
      );
      expect(_draft(syncState: LayoutDraftSyncState.saved).label, 'Saved');
    });
  });
}

LayoutDraft _draft({
  DateTime? baseCloudUpdatedAt,
  String syncState = LayoutDraftSyncState.unsavedDraft,
}) {
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
    baseCloudUpdatedAt: baseCloudUpdatedAt,
    createdAt: DateTime.utc(2026, 5, 25, 12),
    updatedAt: DateTime.utc(2026, 5, 25, 12),
  );
}
