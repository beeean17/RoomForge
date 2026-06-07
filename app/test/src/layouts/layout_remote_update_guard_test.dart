import 'package:app/src/layouts/layout_draft_models.dart';
import 'package:app/src/layouts/layout_draft_recovery.dart';
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
      final decision = layoutRemoteUpdateDecision(
        draft: _draft(
          LayoutDraftSyncState.unsavedDraft,
          baseCloudUpdatedAt: DateTime.utc(2026, 5, 24, 12),
        ),
        forceApplyCloud: false,
        latestCloudUpdatedAt: DateTime.utc(2026, 5, 25, 12),
      );

      expect(decision.applyRemoteLayout, isFalse);
      expect(decision.holdLocalDraft, isTrue);
      expect(decision.requiresUserChoice, isTrue);
      expect(decision.message, layoutRemoteUpdateHeldMessage);
      expect(
        decision.actions.map((action) => action.id),
        contains(LayoutDraftRecoveryActionId.continueSavedVersion),
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
      expect(
        layoutRemoteUpdateDecision(
          draft: _draft(LayoutDraftSyncState.unsavedDraft),
          forceApplyCloud: true,
        ).applyRemoteLayout,
        isTrue,
      );
      expect(
        layoutRemoteUpdateDecision(
          draft: _draft(LayoutDraftSyncState.saved),
          forceApplyCloud: false,
        ).applyRemoteLayout,
        isTrue,
      );
    });

    test('withholds remote stream payload until explicit user choice', () {
      final remotePayload = {'layout_id': 'layout-2'};

      final held = guardedRemoteLayout(
        layout: remotePayload,
        draft: _draft(LayoutDraftSyncState.unsavedDraft),
        forceApplyCloud: false,
      );
      final forced = guardedRemoteLayout(
        layout: remotePayload,
        draft: _draft(LayoutDraftSyncState.unsavedDraft),
        forceApplyCloud: true,
      );

      expect(held.decision.holdLocalDraft, isTrue);
      expect(held.layout, isNull);
      expect(forced.decision.applyRemoteLayout, isTrue);
      expect(forced.layout, same(remotePayload));
    });

    test('exposes sync failed and retry copy', () {
      expect(layoutSyncFailedLabel, 'Sync failed');
      expect(layoutRetryAvailableLabel, 'Retry available');
    });
  });
}

LayoutDraft _draft(String syncState, {DateTime? baseCloudUpdatedAt}) {
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
