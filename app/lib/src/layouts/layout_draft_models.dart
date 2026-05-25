typedef DraftJson = Map<String, Object?>;

const roomForgeDraftDatabaseName = 'roomforge_drafts';
const roomForgeDraftDatabaseVersion = 1;
const layoutDraftsStoreName = 'layout_drafts';
const projectCacheStoreName = 'project_cache';
const layoutDraftSchemaVersion = 1;
const projectCacheSchemaVersion = 1;

String layoutDraftKey({
  required String ownerUid,
  required String projectId,
  String? layoutId,
}) {
  final layoutSegment = layoutId == null || layoutId.isEmpty
      ? 'current'
      : layoutId;
  return '$ownerUid/$projectId/$layoutSegment';
}

String projectCacheKey({required String ownerUid}) {
  return '$ownerUid/projects';
}

class LayoutDraft {
  const LayoutDraft({
    required this.draftKey,
    required this.ownerUid,
    required this.projectId,
    required this.localRevision,
    required this.schemaVersion,
    required this.roomDimensionsSnapshot,
    required this.floorPlanSnapshot,
    required this.sourceMetadataSnapshot,
    required this.editorScene,
    required this.furnitureObjects,
    required this.reconstructionStatus,
    required this.reviewRequired,
    required this.dirtyFields,
    required this.syncState,
    required this.createdAt,
    required this.updatedAt,
    this.layoutId,
    this.baseCloudLayoutId,
    this.baseCloudUpdatedAt,
    this.baseCloudHash,
    this.lastErrorCode,
    this.lastErrorMessage,
    this.lastAccessedAt,
  });

  final String draftKey;
  final String ownerUid;
  final String projectId;
  final String? layoutId;
  final String? baseCloudLayoutId;
  final DateTime? baseCloudUpdatedAt;
  final String? baseCloudHash;
  final int localRevision;
  final int schemaVersion;
  final DraftJson roomDimensionsSnapshot;
  final DraftJson floorPlanSnapshot;
  final DraftJson sourceMetadataSnapshot;
  final DraftJson editorScene;
  final List<DraftJson> furnitureObjects;
  final String reconstructionStatus;
  final bool reviewRequired;
  final List<String> dirtyFields;
  final String syncState;
  final String? lastErrorCode;
  final String? lastErrorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastAccessedAt;

  String get label => syncState == LayoutDraftSyncState.unsavedDraft
      ? 'Unsaved draft'
      : syncState;

  bool get isCloudSourceOfTruth => false;

  bool get isRecoverable => syncState != LayoutDraftSyncState.saved;

  DraftJson toJson() {
    return _withoutNulls({
      'draft_key': draftKey,
      'uid': ownerUid,
      'project_id': projectId,
      'layout_id': layoutId,
      'base_cloud_layout_id': baseCloudLayoutId,
      'base_cloud_updated_at': baseCloudUpdatedAt?.toUtc().toIso8601String(),
      'base_cloud_hash': baseCloudHash,
      'local_revision': localRevision,
      'schema_version': schemaVersion,
      'room_dimensions_snapshot': roomDimensionsSnapshot,
      'floor_plan_snapshot': floorPlanSnapshot,
      'source_metadata_snapshot': sourceMetadataSnapshot,
      'editor_scene': editorScene,
      'furniture_objects': furnitureObjects,
      'reconstruction_status': reconstructionStatus,
      'review_required': reviewRequired,
      'dirty_fields': dirtyFields,
      'sync_state': syncState,
      'last_error_code': lastErrorCode,
      'last_error_message': lastErrorMessage,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'last_accessed_at': lastAccessedAt?.toUtc().toIso8601String(),
    });
  }

  factory LayoutDraft.fromJson(DraftJson json) {
    return LayoutDraft(
      draftKey: _requiredString(json, 'draft_key'),
      ownerUid: _requiredString(json, 'uid'),
      projectId: _requiredString(json, 'project_id'),
      layoutId: _optionalString(json, 'layout_id'),
      baseCloudLayoutId: _optionalString(json, 'base_cloud_layout_id'),
      baseCloudUpdatedAt: _optionalDate(json, 'base_cloud_updated_at'),
      baseCloudHash: _optionalString(json, 'base_cloud_hash'),
      localRevision: _intValue(json['local_revision'], 1),
      schemaVersion: _intValue(json['schema_version'], 1),
      roomDimensionsSnapshot: _recordValue(json['room_dimensions_snapshot']),
      floorPlanSnapshot: _recordValue(json['floor_plan_snapshot']),
      sourceMetadataSnapshot: _recordValue(json['source_metadata_snapshot']),
      editorScene: _recordValue(json['editor_scene']),
      furnitureObjects: _listValue(
        json['furniture_objects'],
      ).map(_recordValue).toList(),
      reconstructionStatus: _stringValue(
        json['reconstruction_status'],
        'created',
      ),
      reviewRequired: json['review_required'] == true,
      dirtyFields: _listValue(
        json['dirty_fields'],
      ).map((value) => value.toString()).toList(),
      syncState: _stringValue(
        json['sync_state'],
        LayoutDraftSyncState.unsavedDraft,
      ),
      lastErrorCode: _optionalString(json, 'last_error_code'),
      lastErrorMessage: _optionalString(json, 'last_error_message'),
      createdAt: _requiredDate(json, 'created_at'),
      updatedAt: _requiredDate(json, 'updated_at'),
      lastAccessedAt: _optionalDate(json, 'last_accessed_at'),
    );
  }
}

class ProjectCache {
  const ProjectCache({
    required this.cacheKey,
    required this.ownerUid,
    required this.projects,
    required this.updatedAt,
    required this.schemaVersion,
  });

  final String cacheKey;
  final String ownerUid;
  final List<DraftJson> projects;
  final DateTime updatedAt;
  final int schemaVersion;

  DraftJson toJson() {
    return {
      'cache_key': cacheKey,
      'uid': ownerUid,
      'projects': projects,
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'schema_version': schemaVersion,
    };
  }

  factory ProjectCache.fromJson(DraftJson json) {
    return ProjectCache(
      cacheKey: _requiredString(json, 'cache_key'),
      ownerUid: _requiredString(json, 'uid'),
      projects: _listValue(json['projects']).map(_recordValue).toList(),
      updatedAt: _requiredDate(json, 'updated_at'),
      schemaVersion: _intValue(json['schema_version'], 1),
    );
  }
}

class LayoutDraftSyncState {
  const LayoutDraftSyncState._();

  static const unsavedDraft = 'unsaved_draft';
  static const saving = 'saving';
  static const syncFailed = 'sync_failed';
  static const conflict = 'conflict';
  static const saved = 'saved';
}

DraftJson _withoutNulls(DraftJson json) {
  return {
    for (final entry in json.entries)
      if (entry.value != null) entry.key: entry.value,
  };
}

DraftJson _recordValue(Object? value) {
  return value is Map ? Map<String, Object?>.from(value) : {};
}

List<Object?> _listValue(Object? value) {
  return value is List ? value.cast<Object?>() : const [];
}

String _requiredString(DraftJson json, String field) {
  final value = json[field];
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw FormatException('Draft field $field is required.');
}

String? _optionalString(DraftJson json, String field) {
  final value = json[field];
  return value?.toString();
}

String _stringValue(Object? value, String fallback) {
  return value == null ? fallback : value.toString();
}

int _intValue(Object? value, int fallback) {
  return value is num ? value.toInt() : fallback;
}

DateTime _requiredDate(DraftJson json, String field) {
  final value = _optionalDate(json, field);
  if (value != null) {
    return value;
  }
  throw FormatException('Draft field $field is required.');
}

DateTime? _optionalDate(DraftJson json, String field) {
  final value = json[field];
  if (value is DateTime) {
    return value.toUtc();
  }
  if (value is String && value.isNotEmpty) {
    return DateTime.parse(value).toUtc();
  }
  return null;
}
