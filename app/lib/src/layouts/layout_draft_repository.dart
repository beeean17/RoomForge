import 'layout_draft_models.dart';

abstract class LayoutDraftStore {
  Future<void> putLayoutDraft(DraftJson draft);

  Future<DraftJson?> getLayoutDraft(String draftKey);

  Future<void> deleteLayoutDraft(String draftKey);

  Future<void> putProjectCache(DraftJson cache);

  Future<DraftJson?> getProjectCache(String cacheKey);

  Future<void> deleteProjectCache(String cacheKey);
}

class LayoutDraftRepository {
  LayoutDraftRepository({
    required LayoutDraftStore store,
    DateTime Function()? clock,
  }) : _store = store,
       _clock = clock ?? DateTime.now;

  final LayoutDraftStore _store;
  final DateTime Function() _clock;

  Future<LayoutDraft> saveDraft({
    required String ownerUid,
    required String projectId,
    required Map<String, Object?> roomDimensionsSnapshot,
    required Map<String, Object?> floorPlanSnapshot,
    required Map<String, Object?> sourceMetadataSnapshot,
    required Map<String, Object?> editorScene,
    required List<Map<String, Object?>> furnitureObjects,
    required String reconstructionStatus,
    required bool reviewRequired,
    String? layoutId,
    String? baseCloudLayoutId,
    DateTime? baseCloudUpdatedAt,
    String? baseCloudHash,
    String syncState = LayoutDraftSyncState.unsavedDraft,
    String? lastErrorCode,
    String? lastErrorMessage,
    List<String> dirtyFields = const ['editor_scene', 'furniture_objects'],
  }) async {
    final key = layoutDraftKey(
      ownerUid: ownerUid,
      projectId: projectId,
      layoutId: layoutId,
    );
    final existing = await getDraft(
      ownerUid: ownerUid,
      projectId: projectId,
      layoutId: layoutId,
    );
    final now = _clock().toUtc();
    final draft = LayoutDraft(
      draftKey: key,
      ownerUid: ownerUid,
      projectId: projectId,
      layoutId: layoutId,
      baseCloudLayoutId: baseCloudLayoutId,
      baseCloudUpdatedAt: baseCloudUpdatedAt?.toUtc(),
      baseCloudHash: baseCloudHash,
      localRevision: (existing?.localRevision ?? 0) + 1,
      schemaVersion: layoutDraftSchemaVersion,
      roomDimensionsSnapshot: roomDimensionsSnapshot,
      floorPlanSnapshot: floorPlanSnapshot,
      sourceMetadataSnapshot: sourceMetadataSnapshot,
      editorScene: editorScene,
      furnitureObjects: furnitureObjects,
      reconstructionStatus: reconstructionStatus,
      reviewRequired: reviewRequired,
      dirtyFields: dirtyFields,
      syncState: syncState,
      lastErrorCode: lastErrorCode,
      lastErrorMessage: lastErrorMessage,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      lastAccessedAt: now,
    );
    await _store.putLayoutDraft(draft.toJson());
    if (layoutId != null && layoutId.isNotEmpty) {
      await _store.putLayoutDraft(
        LayoutDraft(
          draftKey: layoutDraftKey(ownerUid: ownerUid, projectId: projectId),
          ownerUid: ownerUid,
          projectId: projectId,
          layoutId: layoutId,
          baseCloudLayoutId: baseCloudLayoutId,
          baseCloudUpdatedAt: baseCloudUpdatedAt?.toUtc(),
          baseCloudHash: baseCloudHash,
          localRevision: draft.localRevision,
          schemaVersion: draft.schemaVersion,
          roomDimensionsSnapshot: roomDimensionsSnapshot,
          floorPlanSnapshot: floorPlanSnapshot,
          sourceMetadataSnapshot: sourceMetadataSnapshot,
          editorScene: editorScene,
          furnitureObjects: furnitureObjects,
          reconstructionStatus: reconstructionStatus,
          reviewRequired: reviewRequired,
          dirtyFields: dirtyFields,
          syncState: syncState,
          lastErrorCode: lastErrorCode,
          lastErrorMessage: lastErrorMessage,
          createdAt: existing?.createdAt ?? now,
          updatedAt: now,
          lastAccessedAt: now,
        ).toJson(),
      );
    }
    return draft;
  }

  Future<LayoutDraft?> getDraft({
    required String ownerUid,
    required String projectId,
    String? layoutId,
  }) async {
    final key = layoutDraftKey(
      ownerUid: ownerUid,
      projectId: projectId,
      layoutId: layoutId,
    );
    final json = await _store.getLayoutDraft(key);
    if (json == null) {
      return null;
    }
    final draft = LayoutDraft.fromJson(json);
    if (draft.ownerUid != ownerUid || draft.projectId != projectId) {
      return null;
    }
    return draft;
  }

  Future<bool> hasRecoverableDraft({
    required String ownerUid,
    required String projectId,
    String? layoutId,
  }) async {
    final draft = await getDraft(
      ownerUid: ownerUid,
      projectId: projectId,
      layoutId: layoutId,
    );
    return draft?.isRecoverable ?? false;
  }

  Future<void> clearDraft({
    required String ownerUid,
    required String projectId,
    String? layoutId,
  }) {
    return _store.deleteLayoutDraft(
      layoutDraftKey(
        ownerUid: ownerUid,
        projectId: projectId,
        layoutId: layoutId,
      ),
    );
  }

  Future<ProjectCache> saveProjectCache({
    required String ownerUid,
    required List<Map<String, Object?>> projects,
  }) async {
    final now = _clock().toUtc();
    final cache = ProjectCache(
      cacheKey: projectCacheKey(ownerUid: ownerUid),
      ownerUid: ownerUid,
      projects: projects,
      updatedAt: now,
      schemaVersion: projectCacheSchemaVersion,
    );
    await _store.putProjectCache(cache.toJson());
    return cache;
  }

  Future<ProjectCache?> getProjectCache({required String ownerUid}) async {
    final json = await _store.getProjectCache(
      projectCacheKey(ownerUid: ownerUid),
    );
    if (json == null) {
      return null;
    }
    final cache = ProjectCache.fromJson(json);
    return cache.ownerUid == ownerUid ? cache : null;
  }

  Future<void> clearProjectCache({required String ownerUid}) {
    return _store.deleteProjectCache(projectCacheKey(ownerUid: ownerUid));
  }
}
