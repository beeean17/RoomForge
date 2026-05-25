import 'package:app/src/layouts/layout_draft_models.dart';
import 'package:app/src/layouts/layout_draft_recovery.dart';
import 'package:app/src/layouts/layout_draft_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LayoutDraftRepository', () {
    test('stores an Unsaved draft as local recoverable state', () async {
      final store = _MemoryLayoutDraftStore();
      final repository = LayoutDraftRepository(
        store: store,
        clock: () => DateTime.utc(2026, 5, 25, 12),
      );

      final draft = await repository.saveDraft(
        ownerUid: 'user-1',
        projectId: 'project-1',
        roomDimensionsSnapshot: const {'unit': 'meters', 'width_value': 4.2},
        floorPlanSnapshot: const {'floor_plan_id': 'floor-plan-1'},
        sourceMetadataSnapshot: const {'source_image_id': 'source-1'},
        editorScene: const {'scene_id': 'scene-1'},
        furnitureObjects: const [
          {'id': 'chair-1'},
        ],
        reconstructionStatus: 'review_required',
        reviewRequired: true,
      );
      final restored = await repository.getDraft(
        ownerUid: 'user-1',
        projectId: 'project-1',
      );

      expect(draft.draftKey, 'user-1/project-1/current');
      expect(draft.label, 'Unsaved draft');
      expect(draft.isCloudSourceOfTruth, isFalse);
      expect(draft.isRecoverable, isTrue);
      expect(draft.syncState, LayoutDraftSyncState.unsavedDraft);
      expect(draft.reconstructionStatus, 'review_required');
      expect(draft.reviewRequired, isTrue);
      expect(restored?.editorScene, containsPair('scene_id', 'scene-1'));
      expect(restored?.furnitureObjects.single, containsPair('id', 'chair-1'));
    });

    test('increments local revision and preserves created timestamp', () async {
      var now = DateTime.utc(2026, 5, 25, 12);
      final repository = LayoutDraftRepository(
        store: _MemoryLayoutDraftStore(),
        clock: () => now,
      );

      final first = await _saveMinimalDraft(repository);
      now = DateTime.utc(2026, 5, 25, 12, 30);
      final second = await _saveMinimalDraft(repository);

      expect(first.localRevision, 1);
      expect(second.localRevision, 2);
      expect(second.createdAt, first.createdAt);
      expect(second.updatedAt, DateTime.utc(2026, 5, 25, 12, 30));
    });

    test('detects and clears recoverable drafts by layout key', () async {
      final store = _MemoryLayoutDraftStore();
      final repository = LayoutDraftRepository(store: store);

      await _saveMinimalDraft(repository, layoutId: 'layout-1');
      final hasDraft = await repository.hasRecoverableDraft(
        ownerUid: 'user-1',
        projectId: 'project-1',
        layoutId: 'layout-1',
      );
      await repository.clearDraft(
        ownerUid: 'user-1',
        projectId: 'project-1',
        layoutId: 'layout-1',
      );

      expect(hasDraft, isTrue);
      expect(
        await repository.hasRecoverableDraft(
          ownerUid: 'user-1',
          projectId: 'project-1',
          layoutId: 'layout-1',
        ),
        isFalse,
      );
    });

    test(
      'mirrors layout drafts to current key for project reopen detection',
      () async {
        final repository = LayoutDraftRepository(
          store: _MemoryLayoutDraftStore(),
        );

        await _saveMinimalDraft(repository, layoutId: 'layout-1');
        final reopenedDraft = await repository.getDraft(
          ownerUid: 'user-1',
          projectId: 'project-1',
        );

        expect(reopenedDraft?.draftKey, 'user-1/project-1/current');
        expect(reopenedDraft?.layoutId, 'layout-1');
        expect(reopenedDraft?.label, 'Unsaved draft');
        expect(reopenedDraft?.isCloudSourceOfTruth, isFalse);
      },
    );

    test(
      'current mirror exposes conflict when latest cloud layout id changes',
      () async {
        final repository = LayoutDraftRepository(
          store: _MemoryLayoutDraftStore(),
        );

        await _saveMinimalDraft(repository, layoutId: 'layout-1');
        final latestLayoutLookup = await repository.getDraft(
          ownerUid: 'user-1',
          projectId: 'project-1',
          layoutId: 'layout-2',
        );
        final currentMirror = await repository.getDraft(
          ownerUid: 'user-1',
          projectId: 'project-1',
        );

        expect(latestLayoutLookup, isNull);
        expect(currentMirror?.layoutId, 'layout-1');
        expect(
          layoutDraftHasCloudConflict(
            currentMirror!,
            DateTime.utc(2026, 5, 25, 12),
          ),
          isTrue,
        );
      },
    );

    test('stores and clears project cache under the signed-in uid', () async {
      final repository = LayoutDraftRepository(
        store: _MemoryLayoutDraftStore(),
        clock: () => DateTime.utc(2026, 5, 25, 12),
      );

      final cache = await repository.saveProjectCache(
        ownerUid: 'user-1',
        projects: const [
          {'project_id': 'project-1', 'name': 'Studio'},
        ],
      );
      final restored = await repository.getProjectCache(ownerUid: 'user-1');
      await repository.clearProjectCache(ownerUid: 'user-1');

      expect(cache.cacheKey, 'user-1/projects');
      expect(
        restored?.projects.single,
        containsPair('project_id', 'project-1'),
      );
      expect(await repository.getProjectCache(ownerUid: 'user-1'), isNull);
    });
  });
}

Future<LayoutDraft> _saveMinimalDraft(
  LayoutDraftRepository repository, {
  String? layoutId,
}) {
  return repository.saveDraft(
    ownerUid: 'user-1',
    projectId: 'project-1',
    layoutId: layoutId,
    baseCloudLayoutId: layoutId,
    baseCloudUpdatedAt: DateTime.utc(2026, 5, 24, 12),
    roomDimensionsSnapshot: const {'unit': 'meters'},
    floorPlanSnapshot: const {'floor_plan_id': 'floor-plan-1'},
    sourceMetadataSnapshot: const {'source_image_id': 'source-1'},
    editorScene: const {'scene_id': 'scene-1'},
    furnitureObjects: const [],
    reconstructionStatus: 'succeeded',
    reviewRequired: false,
  );
}

class _MemoryLayoutDraftStore implements LayoutDraftStore {
  final layoutDrafts = <String, DraftJson>{};
  final projectCaches = <String, DraftJson>{};

  @override
  Future<void> putLayoutDraft(DraftJson draft) async {
    layoutDrafts[draft['draft_key']! as String] = Map<String, Object?>.from(
      draft,
    );
  }

  @override
  Future<DraftJson?> getLayoutDraft(String draftKey) async {
    final draft = layoutDrafts[draftKey];
    return draft == null ? null : Map<String, Object?>.from(draft);
  }

  @override
  Future<void> deleteLayoutDraft(String draftKey) async {
    layoutDrafts.remove(draftKey);
  }

  @override
  Future<void> putProjectCache(DraftJson cache) async {
    projectCaches[cache['cache_key']! as String] = Map<String, Object?>.from(
      cache,
    );
  }

  @override
  Future<DraftJson?> getProjectCache(String cacheKey) async {
    final cache = projectCaches[cacheKey];
    return cache == null ? null : Map<String, Object?>.from(cache);
  }

  @override
  Future<void> deleteProjectCache(String cacheKey) async {
    projectCaches.remove(cacheKey);
  }
}
