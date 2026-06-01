import 'firebase_models.dart';

typedef FirebaseTimestampEncoder = Object Function(DateTime value);

Object _firestoreTimestamp(DateTime value) => value;

Object _exportTimestamp(DateTime value) => value.toUtc().toIso8601String();

class FirebaseSerializationOptions {
  const FirebaseSerializationOptions({required this.timestampEncoder});

  static final firestore = FirebaseSerializationOptions(
    timestampEncoder: _firestoreTimestamp,
  );

  static final exportJson = FirebaseSerializationOptions(
    timestampEncoder: _exportTimestamp,
  );

  final FirebaseTimestampEncoder timestampEncoder;
}

class FirebaseSerializerValidators {
  FirebaseSerializerValidators._();

  static final RegExp _snakeCase = RegExp(r'^[a-z0-9]+(_[a-z0-9]+)*$');
  static final RegExp _camelCase = RegExp(r'^[a-z][A-Za-z0-9]*$');

  static bool isSnakeCaseKey(String key) => _snakeCase.hasMatch(key);

  static bool isCamelCaseKey(String key) {
    return _camelCase.hasMatch(key) && !key.contains('_');
  }

  static void requireSnakeCasePayload(Object? payload, String context) {
    _requireKeys(payload, context, isSnakeCaseKey, 'snake_case');
  }

  static void requireCamelCasePayload(Object? payload, String context) {
    _requireKeys(payload, context, isCamelCaseKey, 'camelCase');
  }

  static void _requireKeys(
    Object? value,
    String context,
    bool Function(String key) predicate,
    String expectedCase,
  ) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key;
        if (key is! String || !predicate(key)) {
          throw FirebaseContractException(
            '$context must use $expectedCase keys. Invalid key: "$key".',
          );
        }
        _requireKeys(entry.value, '$context.$key', predicate, expectedCase);
      }
      return;
    }

    if (value is Iterable) {
      var index = 0;
      for (final item in value) {
        _requireKeys(item, '$context[$index]', predicate, expectedCase);
        index += 1;
      }
    }
  }
}

class FirebaseModelSerializers {
  FirebaseModelSerializers._();

  static FirebaseRoomProject roomProjectFromFirestore(FirebaseJson json) {
    return FirebaseRoomProject(
      projectId: _requiredString(json, 'project_id'),
      ownerUid: _requiredString(json, 'owner_uid'),
      name: _requiredString(json, 'name'),
      description: _optionalString(json, 'description'),
      schemaVersion: _requiredInt(json, 'schema_version'),
      createdAt: _requiredDate(json, 'created_at'),
      updatedAt: _requiredDate(json, 'updated_at'),
      deletedAt: _optionalDate(json, 'deleted_at'),
      latestSourceImageId: _optionalString(json, 'latest_source_image_id'),
      latestJobId: _optionalString(json, 'latest_job_id'),
      latestFloorPlanId: _optionalString(json, 'latest_floor_plan_id'),
      latestLayoutId: _optionalString(json, 'latest_layout_id'),
      currentReconstructionStatus: json['current_reconstruction_status'] == null
          ? null
          : FirebaseJobStatus.fromWireValue(
              json['current_reconstruction_status'],
            ),
      lastOpenedAt: _optionalDate(json, 'last_opened_at'),
    );
  }

  static FirebaseSourceImage sourceImageFromFirestore(FirebaseJson json) {
    return FirebaseSourceImage(
      sourceImageId: _requiredString(json, 'source_image_id'),
      projectId: _requiredString(json, 'project_id'),
      ownerUid: _requiredString(json, 'owner_uid'),
      storagePath: _requiredString(json, 'storage_path'),
      originalFilename: _optionalString(json, 'original_filename'),
      storedFilename: _requiredString(json, 'stored_filename'),
      contentType: FirebaseImageContentType.fromWireValue(json['content_type']),
      byteSize: _requiredInt(json, 'byte_size'),
      sha256Hex: _requiredString(json, 'sha256_hex'),
      widthPx: _requiredInt(json, 'width_px'),
      heightPx: _requiredInt(json, 'height_px'),
      captureSource: _optionalString(json, 'capture_source'),
      captureSessionId: _optionalString(json, 'capture_session_id'),
      captureImageId: _optionalString(json, 'capture_image_id'),
      captureImageRole: json['capture_image_role'] == null
          ? null
          : FirebaseCaptureImageRole.fromWireValue(json['capture_image_role']),
      retentionStatus: FirebaseRetentionStatus.fromWireValue(
        json['retention_status'],
      ),
      uploadedAt: _requiredDate(json, 'uploaded_at'),
      createdAt: _requiredDate(json, 'created_at'),
      updatedAt: _requiredDate(json, 'updated_at'),
      schemaVersion: _requiredInt(json, 'schema_version'),
    );
  }

  static FirebaseReconstructionJob reconstructionJobFromFirestore(
    FirebaseJson json,
  ) {
    return FirebaseReconstructionJob(
      jobId: _requiredString(json, 'job_id'),
      projectId: _requiredString(json, 'project_id'),
      ownerUid: _requiredString(json, 'owner_uid'),
      sourceImageId: _requiredString(json, 'source_image_id'),
      roomDimensionsId: _requiredString(json, 'room_dimensions_id'),
      status: FirebaseJobStatus.fromWireValue(json['status']),
      statusUpdatedAt: _requiredDate(json, 'status_updated_at'),
      providerType: _requiredString(json, 'provider_type'),
      providerId: _optionalString(json, 'provider_id'),
      algorithmId: _optionalString(json, 'algorithm_id'),
      openCvVersion: _optionalString(json, 'opencv_version'),
      createdByUid: _requiredString(json, 'created_by_uid'),
      retryOfJobId: _optionalString(json, 'retry_of_job_id'),
      rootJobId: _optionalString(json, 'root_job_id'),
      retryCount: _requiredInt(json, 'retry_count'),
      latestTransitionId: _optionalString(json, 'latest_transition_id'),
      latestResultId: _optionalString(json, 'latest_result_id'),
      latestConfirmedGeometryId: _optionalString(
        json,
        'latest_confirmed_geometry_id',
      ),
      latestFloorPlanId: _optionalString(json, 'latest_floor_plan_id'),
      failureReasonCode: _optionalString(json, 'failure_reason_code'),
      failureReason: _optionalString(json, 'failure_reason'),
      qualityStatus: json['quality_status'] == null
          ? null
          : FirebaseQualityStatus.fromWireValue(json['quality_status']),
      artifactRefs: _artifactRefList(json, 'artifact_refs'),
      startedAt: _optionalDate(json, 'started_at'),
      completedAt: _optionalDate(json, 'completed_at'),
      timeoutAt: _optionalDate(json, 'timeout_at'),
      createdAt: _requiredDate(json, 'created_at'),
      updatedAt: _requiredDate(json, 'updated_at'),
      schemaVersion: _requiredInt(json, 'schema_version'),
    );
  }

  static FirebaseJobStatusTransition jobStatusTransitionFromFirestore(
    FirebaseJson json,
  ) {
    return FirebaseJobStatusTransition(
      transitionId: _requiredString(json, 'transition_id'),
      projectId: _requiredString(json, 'project_id'),
      ownerUid: _requiredString(json, 'owner_uid'),
      jobId: _requiredString(json, 'job_id'),
      fromStatus: json['from_status'] == null
          ? null
          : FirebaseJobStatus.fromWireValue(json['from_status']),
      toStatus: FirebaseJobStatus.fromWireValue(json['to_status']),
      occurredAt: _requiredDate(json, 'occurred_at'),
      actorType: FirebaseActorType.fromWireValue(json['actor_type']),
      actorUid: _optionalString(json, 'actor_uid'),
      reasonCode: _optionalString(json, 'reason_code'),
      reasonMessage: _optionalString(json, 'reason_message'),
      artifactRefs: _artifactRefList(json, 'artifact_refs'),
      retryJobId: _optionalString(json, 'retry_job_id'),
      schemaVersion: _requiredInt(json, 'schema_version'),
    );
  }

  static FirebaseOpenCvResult openCvResultFromFirestore(FirebaseJson json) {
    final coordinateSpace =
        FirebaseContractValidators.requireRawCoordinateSpace(
          json,
          FirebaseCoordinateSpace.imagePixels,
          'opencv_results',
        );
    return FirebaseOpenCvResult(
      resultId: _requiredString(json, 'result_id'),
      projectId: _requiredString(json, 'project_id'),
      ownerUid: _requiredString(json, 'owner_uid'),
      jobId: _requiredString(json, 'job_id'),
      sourceImageId: _requiredString(json, 'source_image_id'),
      coordinateSpace: coordinateSpace,
      algorithmId: _requiredString(json, 'algorithm_id'),
      openCvVersion: _optionalString(json, 'opencv_version'),
      candidateEdges: _jsonList(json, 'candidate_edges'),
      candidateLines: _jsonList(json, 'candidate_lines'),
      candidateCorners: _point2dList(json, 'candidate_corners'),
      boundaryHints: _jsonList(json, 'boundary_hints'),
      confidenceScore: _optionalDouble(json, 'confidence_score'),
      qualityStatus: FirebaseQualityStatus.fromWireValue(
        json['quality_status'],
      ),
      failureReasonCode: _optionalString(json, 'failure_reason_code'),
      failureReason: _optionalString(json, 'failure_reason'),
      artifactRefs: _artifactRefList(json, 'artifact_refs'),
      processingStartedAt: _optionalDate(json, 'processing_started_at'),
      processingCompletedAt: _optionalDate(json, 'processing_completed_at'),
      createdAt: _requiredDate(json, 'created_at'),
      updatedAt: _requiredDate(json, 'updated_at'),
      schemaVersion: _requiredInt(json, 'schema_version'),
    );
  }

  static FirebaseConfirmedGeometry confirmedGeometryFromFirestore(
    FirebaseJson json,
  ) {
    final coordinateSpace =
        FirebaseContractValidators.requireRawCoordinateSpace(
          json,
          FirebaseCoordinateSpace.imagePixels,
          'confirmed_geometries',
        );
    return FirebaseConfirmedGeometry(
      geometryId: _requiredString(json, 'geometry_id'),
      projectId: _requiredString(json, 'project_id'),
      ownerUid: _requiredString(json, 'owner_uid'),
      jobId: _requiredString(json, 'job_id'),
      sourceImageId: _requiredString(json, 'source_image_id'),
      openCvResultId: _optionalString(json, 'opencv_result_id'),
      coordinateSpace: coordinateSpace,
      boundaryType: FirebaseBoundaryType.fromWireValue(json['boundary_type']),
      boundaryPoints: _point2dList(json, 'boundary_points'),
      correctionMethod: _optionalString(json, 'correction_method'),
      confirmedByUid: _requiredString(json, 'confirmed_by_uid'),
      createdAt: _requiredDate(json, 'created_at'),
      updatedAt: _requiredDate(json, 'updated_at'),
      schemaVersion: _requiredInt(json, 'schema_version'),
    );
  }

  static FirebaseRoomDimensions roomDimensionsFromFirestore(FirebaseJson json) {
    final model = FirebaseRoomDimensions(
      projectId: _requiredString(json, 'project_id'),
      ownerUid: _requiredString(json, 'owner_uid'),
      widthM: _requiredDouble(json, 'width_m'),
      depthM: _requiredDouble(json, 'depth_m'),
      heightM: _requiredDouble(json, 'height_m'),
      unit: _requiredString(json, 'unit'),
      source: _requiredString(json, 'source'),
      createdAt: _requiredDate(json, 'created_at'),
      updatedAt: _requiredDate(json, 'updated_at'),
      schemaVersion: _requiredInt(json, 'schema_version'),
    );
    model.validate();
    return model;
  }

  static FirebaseFloorPlan floorPlanFromFirestore(FirebaseJson json) {
    final coordinateSpace =
        FirebaseContractValidators.requireRawCoordinateSpace(
          json,
          FirebaseCoordinateSpace.meters,
          'floor_plans',
        );
    final model = FirebaseFloorPlan(
      floorPlanId: _requiredString(json, 'floor_plan_id'),
      projectId: _requiredString(json, 'project_id'),
      ownerUid: _requiredString(json, 'owner_uid'),
      jobId: _requiredString(json, 'job_id'),
      sourceImageId: _requiredString(json, 'source_image_id'),
      confirmedGeometryId: _requiredString(json, 'confirmed_geometry_id'),
      roomDimensionsId: _requiredString(json, 'room_dimensions_id'),
      coordinateSpace: coordinateSpace,
      roomDimensions: roomDimensionsFromFirestore(
        _requiredJson(json, 'room_dimensions'),
      ),
      floorPolygon: _point2dList(json, 'floor_polygon'),
      walls: _jsonList(json, 'walls'),
      calibration: _requiredJson(json, 'calibration'),
      qualityStatus: FirebaseQualityStatus.fromWireValue(
        json['quality_status'],
      ),
      warnings: _stringList(json, 'warnings'),
      artifactRefs: _artifactRefList(json, 'artifact_refs'),
      createdAt: _requiredDate(json, 'created_at'),
      updatedAt: _requiredDate(json, 'updated_at'),
      schemaVersion: _requiredInt(json, 'schema_version'),
    );
    model.validate();
    return model;
  }

  static FirebaseCaptureSession captureSessionFromFirestore(FirebaseJson json) {
    return FirebaseCaptureSession(
      captureSessionId: _requiredString(json, 'capture_session_id'),
      projectId: _requiredString(json, 'project_id'),
      ownerUid: _requiredString(json, 'owner_uid'),
      roomDimensionsId: _requiredString(json, 'room_dimensions_id'),
      captureMethod: FirebaseCaptureMethod.fromWireValue(
        json['capture_method'],
      ),
      depthEnabled: _requiredBool(json, 'depth_enabled'),
      startedAt: _optionalDate(json, 'started_at'),
      completedAt: _optionalDate(json, 'completed_at'),
      notes: _optionalString(json, 'notes'),
      createdAt: _requiredDate(json, 'created_at'),
      updatedAt: _requiredDate(json, 'updated_at'),
      schemaVersion: _requiredInt(json, 'schema_version'),
    );
  }

  static FirebaseCaptureImage captureImageFromFirestore(FirebaseJson json) {
    final model = FirebaseCaptureImage(
      captureImageId: _requiredString(json, 'capture_image_id'),
      captureSessionId: _requiredString(json, 'capture_session_id'),
      projectId: _requiredString(json, 'project_id'),
      ownerUid: _requiredString(json, 'owner_uid'),
      sourceImageId: _requiredString(json, 'source_image_id'),
      role: FirebaseCaptureImageRole.fromWireValue(json['role']),
      storagePath: _requiredString(json, 'storage_path'),
      contentType: FirebaseImageContentType.fromWireValue(json['content_type']),
      widthPx: _requiredInt(json, 'width_px'),
      heightPx: _requiredInt(json, 'height_px'),
      captureOrder: json['capture_order'] == null
          ? null
          : _requiredInt(json, 'capture_order'),
      depthArtifactRefs: _artifactRefList(json, 'depth_artifact_refs'),
      cameraPose: json['camera_pose'] == null
          ? null
          : _requiredJson(json, 'camera_pose'),
      guidanceState: _optionalString(json, 'guidance_state'),
      createdAt: _requiredDate(json, 'created_at'),
      updatedAt: _requiredDate(json, 'updated_at'),
      schemaVersion: _requiredInt(json, 'schema_version'),
    );
    model.validate();
    return model;
  }

  static FirebaseSceneUnderstandingResult sceneUnderstandingResultFromFirestore(
    FirebaseJson json,
  ) {
    final model = FirebaseSceneUnderstandingResult(
      resultId: _requiredString(json, 'result_id'),
      projectId: _requiredString(json, 'project_id'),
      ownerUid: _requiredString(json, 'owner_uid'),
      captureSessionId: _requiredString(json, 'capture_session_id'),
      jobId: _optionalString(json, 'job_id'),
      providerType: FirebaseSceneUnderstandingProviderType.fromWireValue(
        json['provider_type'],
      ),
      algorithmId: _requiredString(json, 'algorithm_id'),
      modelId: _optionalString(json, 'model_id'),
      confidenceScore: _optionalDouble(json, 'confidence_score'),
      qualityStatus: FirebaseQualityStatus.fromWireValue(
        json['quality_status'],
      ),
      failureReasonCode: json['failure_reason_code'] == null
          ? null
          : FirebaseSceneUnderstandingFailureReason.fromWireValue(
              json['failure_reason_code'],
            ),
      failureReason: _optionalString(json, 'failure_reason'),
      coverage: json['coverage'] == null
          ? const {}
          : _requiredJson(json, 'coverage'),
      candidateObjects: _candidateSceneObjectList(json, 'candidate_objects'),
      placedObjects: _placedSceneObjectList(json, 'placed_objects'),
      confirmedObjects: _confirmedSceneObjectList(json, 'confirmed_objects'),
      structuralFixtures: _structuralFixtureList(json, 'structural_fixtures'),
      artifactRefs: _artifactRefList(json, 'artifact_refs'),
      processingStartedAt: _optionalDate(json, 'processing_started_at'),
      processingCompletedAt: _optionalDate(json, 'processing_completed_at'),
      createdAt: _requiredDate(json, 'created_at'),
      updatedAt: _requiredDate(json, 'updated_at'),
      schemaVersion: _requiredInt(json, 'schema_version'),
    );
    model.validate();
    return model;
  }

  static FirebaseSavedLayout savedLayoutFromFirestore(FirebaseJson json) {
    final coordinateSpace =
        FirebaseContractValidators.requireRawCoordinateSpace(
          json,
          FirebaseCoordinateSpace.meters,
          'layouts',
        );
    final model = FirebaseSavedLayout(
      layoutId: _requiredString(json, 'layout_id'),
      projectId: _requiredString(json, 'project_id'),
      ownerUid: _requiredString(json, 'owner_uid'),
      name: _optionalString(json, 'name'),
      sourceImageId: _requiredString(json, 'source_image_id'),
      reconstructionJobId: _requiredString(json, 'reconstruction_job_id'),
      reconstructionStatus: FirebaseContractValidators.requireRawJobStatus(
        json,
        'reconstruction_status',
        'layouts',
      ),
      reviewRequired: _requiredBool(json, 'review_required'),
      floorPlanId: _requiredString(json, 'floor_plan_id'),
      coordinateSpace: coordinateSpace,
      roomDimensions: roomDimensionsFromFirestore(
        _requiredJson(json, 'room_dimensions'),
      ),
      sourceMetadata: _requiredJson(json, 'source_metadata'),
      floorPlan: floorPlanFromFirestore(_requiredJson(json, 'floor_plan')),
      editorScene: _requiredJson(json, 'editor_scene'),
      furnitureObjects: _furnitureObjectList(json, 'furniture_objects'),
      baseFloorPlanUpdatedAt: _optionalDate(json, 'base_floor_plan_updated_at'),
      savedAt: _requiredDate(json, 'saved_at'),
      createdAt: _requiredDate(json, 'created_at'),
      updatedAt: _requiredDate(json, 'updated_at'),
      schemaVersion: _requiredInt(json, 'schema_version'),
      exportVersion: _requiredInt(json, 'export_version'),
    );
    model.validate();
    return model;
  }

  static FirebaseAdminAction adminActionFromFirestore(FirebaseJson json) {
    return FirebaseAdminAction(
      actionId: _requiredString(json, 'action_id'),
      projectId: _requiredString(json, 'project_id'),
      ownerUid: _requiredString(json, 'owner_uid'),
      createdByUid: _requiredString(json, 'created_by_uid'),
      createdByRole: FirebaseAdminRole.fromWireValue(json['created_by_role']),
      actionType: _requiredString(json, 'action_type'),
      targetType: _requiredString(json, 'target_type'),
      targetId: _requiredString(json, 'target_id'),
      reasonCode: _optionalString(json, 'reason_code'),
      reasonMessage: _optionalString(json, 'reason_message'),
      permissionOutcome: _optionalString(json, 'permission_outcome'),
      retryJobId: _optionalString(json, 'retry_job_id'),
      metadata: json['metadata'] == null
          ? const {}
          : _requiredJson(json, 'metadata'),
      createdAt: _requiredDate(json, 'created_at'),
      schemaVersion: _requiredInt(json, 'schema_version'),
    );
  }
}

extension FirebaseArtifactRefSerializers on FirebaseArtifactRef {
  FirebaseJson toFirestoreJson({FirebaseSerializationOptions? options}) {
    final resolved = options ?? FirebaseSerializationOptions.firestore;
    return _snakeCasePayload({
      'artifact_id': artifactId,
      'storage_path': storagePath,
      'artifact_type': artifactType,
      'content_type': contentType.wireValue,
      'byte_size': byteSize,
      'sha256_hex': sha256Hex,
      'width_px': widthPx,
      'height_px': heightPx,
      'created_at': _timestamp(createdAt, resolved),
      'description': description,
    }, 'artifact_ref');
  }

  FirebaseJson toExportJson() {
    return toFirestoreJson(options: FirebaseSerializationOptions.exportJson);
  }
}

extension FirebaseUserProfileSerializers on FirebaseUserProfile {
  FirebaseJson toFirestoreJson({FirebaseSerializationOptions? options}) {
    final resolved = options ?? FirebaseSerializationOptions.firestore;
    return _snakeCasePayload({
      'uid': uid,
      'email': email,
      'display_name': displayName,
      'photo_url': photoUrl,
      'created_at': resolved.timestampEncoder(createdAt),
      'updated_at': resolved.timestampEncoder(updatedAt),
      'last_seen_at': _timestamp(lastSeenAt, resolved),
      'schema_version': schemaVersion,
      'role': role?.wireValue,
      'role_updated_at': _timestamp(roleUpdatedAt, resolved),
      'role_updated_by_uid': roleUpdatedByUid,
    }, 'users');
  }
}

extension FirebaseRoomProjectSerializers on FirebaseRoomProject {
  FirebaseJson toFirestoreJson({FirebaseSerializationOptions? options}) {
    final resolved = options ?? FirebaseSerializationOptions.firestore;
    return _snakeCasePayload({
      'project_id': projectId,
      'owner_uid': ownerUid,
      'name': name,
      'description': description,
      'schema_version': schemaVersion,
      'created_at': resolved.timestampEncoder(createdAt),
      'updated_at': resolved.timestampEncoder(updatedAt),
      'deleted_at': _timestamp(deletedAt, resolved),
      'latest_source_image_id': latestSourceImageId,
      'latest_job_id': latestJobId,
      'latest_floor_plan_id': latestFloorPlanId,
      'latest_layout_id': latestLayoutId,
      'current_reconstruction_status': currentReconstructionStatus?.wireValue,
      'last_opened_at': _timestamp(lastOpenedAt, resolved),
    }, 'projects');
  }
}

extension FirebaseSourceImageSerializers on FirebaseSourceImage {
  FirebaseJson toFirestoreJson({FirebaseSerializationOptions? options}) {
    final resolved = options ?? FirebaseSerializationOptions.firestore;
    return _snakeCasePayload({
      'source_image_id': sourceImageId,
      'project_id': projectId,
      'owner_uid': ownerUid,
      'storage_path': storagePath,
      'original_filename': originalFilename,
      'stored_filename': storedFilename,
      'content_type': contentType.wireValue,
      'byte_size': byteSize,
      'sha256_hex': sha256Hex,
      'width_px': widthPx,
      'height_px': heightPx,
      'capture_source': captureSource,
      'capture_session_id': captureSessionId,
      'capture_image_id': captureImageId,
      'capture_image_role': captureImageRole?.wireValue,
      'retention_status': retentionStatus.wireValue,
      'uploaded_at': resolved.timestampEncoder(uploadedAt),
      'created_at': resolved.timestampEncoder(createdAt),
      'updated_at': resolved.timestampEncoder(updatedAt),
      'schema_version': schemaVersion,
    }, 'source_images');
  }
}

extension FirebaseRoomDimensionsSerializers on FirebaseRoomDimensions {
  FirebaseJson toFirestoreJson({FirebaseSerializationOptions? options}) {
    validate();
    final resolved = options ?? FirebaseSerializationOptions.firestore;
    return _snakeCasePayload({
      'project_id': projectId,
      'owner_uid': ownerUid,
      'width_m': widthM,
      'depth_m': depthM,
      'height_m': heightM,
      'unit': unit,
      'source': source,
      'created_at': resolved.timestampEncoder(createdAt),
      'updated_at': resolved.timestampEncoder(updatedAt),
      'schema_version': schemaVersion,
    }, 'room_dimensions');
  }

  FirebaseJson toExportJson() {
    return toFirestoreJson(options: FirebaseSerializationOptions.exportJson);
  }
}

extension FirebaseReconstructionJobSerializers on FirebaseReconstructionJob {
  FirebaseJson toFirestoreJson({FirebaseSerializationOptions? options}) {
    final resolved = options ?? FirebaseSerializationOptions.firestore;
    return _snakeCasePayload({
      'job_id': jobId,
      'project_id': projectId,
      'owner_uid': ownerUid,
      'source_image_id': sourceImageId,
      'room_dimensions_id': roomDimensionsId,
      'status': status.wireValue,
      'status_updated_at': resolved.timestampEncoder(statusUpdatedAt),
      'provider_type': providerType,
      'provider_id': providerId,
      'algorithm_id': algorithmId,
      'opencv_version': openCvVersion,
      'created_by_uid': createdByUid,
      'retry_of_job_id': retryOfJobId,
      'root_job_id': rootJobId,
      'retry_count': retryCount,
      'latest_transition_id': latestTransitionId,
      'latest_result_id': latestResultId,
      'latest_confirmed_geometry_id': latestConfirmedGeometryId,
      'latest_floor_plan_id': latestFloorPlanId,
      'failure_reason_code': failureReasonCode,
      'failure_reason': failureReason,
      'quality_status': qualityStatus?.wireValue,
      'artifact_refs': artifactRefs
          .map((ref) => ref.toFirestoreJson(options: resolved))
          .toList(),
      'started_at': _timestamp(startedAt, resolved),
      'completed_at': _timestamp(completedAt, resolved),
      'timeout_at': _timestamp(timeoutAt, resolved),
      'created_at': resolved.timestampEncoder(createdAt),
      'updated_at': resolved.timestampEncoder(updatedAt),
      'schema_version': schemaVersion,
    }, 'reconstruction_jobs');
  }
}

extension FirebaseJobStatusTransitionSerializers
    on FirebaseJobStatusTransition {
  FirebaseJson toFirestoreJson({FirebaseSerializationOptions? options}) {
    final resolved = options ?? FirebaseSerializationOptions.firestore;
    return _snakeCasePayload({
      'transition_id': transitionId,
      'project_id': projectId,
      'owner_uid': ownerUid,
      'job_id': jobId,
      'from_status': fromStatus?.wireValue,
      'to_status': toStatus.wireValue,
      'occurred_at': resolved.timestampEncoder(occurredAt),
      'actor_type': actorType.wireValue,
      'actor_uid': actorUid,
      'reason_code': reasonCode,
      'reason_message': reasonMessage,
      'artifact_refs': artifactRefs
          .map((ref) => ref.toFirestoreJson(options: resolved))
          .toList(),
      'retry_job_id': retryJobId,
      'schema_version': schemaVersion,
    }, 'job_transitions');
  }
}

extension FirebaseOpenCvResultSerializers on FirebaseOpenCvResult {
  FirebaseJson toFirestoreJson({FirebaseSerializationOptions? options}) {
    validate();
    final resolved = options ?? FirebaseSerializationOptions.firestore;
    return _snakeCasePayload({
      'result_id': resultId,
      'project_id': projectId,
      'owner_uid': ownerUid,
      'job_id': jobId,
      'source_image_id': sourceImageId,
      'coordinate_space': coordinateSpace.wireValue,
      'algorithm_id': algorithmId,
      'opencv_version': openCvVersion,
      'candidate_edges': candidateEdges,
      'candidate_lines': candidateLines,
      'candidate_corners': candidateCorners
          .map((point) => point.toFirestoreJson())
          .toList(),
      'boundary_hints': boundaryHints,
      'confidence_score': confidenceScore,
      'quality_status': qualityStatus.wireValue,
      'failure_reason_code': failureReasonCode,
      'failure_reason': failureReason,
      'artifact_refs': artifactRefs
          .map((ref) => ref.toFirestoreJson(options: resolved))
          .toList(),
      'processing_started_at': _timestamp(processingStartedAt, resolved),
      'processing_completed_at': _timestamp(processingCompletedAt, resolved),
      'created_at': resolved.timestampEncoder(createdAt),
      'updated_at': resolved.timestampEncoder(updatedAt),
      'schema_version': schemaVersion,
    }, 'opencv_results');
  }
}

extension FirebaseConfirmedGeometrySerializers on FirebaseConfirmedGeometry {
  FirebaseJson toFirestoreJson({FirebaseSerializationOptions? options}) {
    validate();
    final resolved = options ?? FirebaseSerializationOptions.firestore;
    return _snakeCasePayload({
      'geometry_id': geometryId,
      'project_id': projectId,
      'owner_uid': ownerUid,
      'job_id': jobId,
      'source_image_id': sourceImageId,
      'opencv_result_id': openCvResultId,
      'coordinate_space': coordinateSpace.wireValue,
      'boundary_type': boundaryType.wireValue,
      'boundary_points': boundaryPoints
          .map((point) => point.toFirestoreJson())
          .toList(),
      'correction_method': correctionMethod,
      'confirmed_by_uid': confirmedByUid,
      'created_at': resolved.timestampEncoder(createdAt),
      'updated_at': resolved.timestampEncoder(updatedAt),
      'schema_version': schemaVersion,
    }, 'confirmed_geometries');
  }
}

extension FirebaseFloorPlanSerializers on FirebaseFloorPlan {
  FirebaseJson toFirestoreJson({FirebaseSerializationOptions? options}) {
    validate();
    final resolved = options ?? FirebaseSerializationOptions.firestore;
    return _snakeCasePayload({
      'floor_plan_id': floorPlanId,
      'project_id': projectId,
      'owner_uid': ownerUid,
      'job_id': jobId,
      'source_image_id': sourceImageId,
      'confirmed_geometry_id': confirmedGeometryId,
      'room_dimensions_id': roomDimensionsId,
      'coordinate_space': coordinateSpace.wireValue,
      'room_dimensions': roomDimensions.toFirestoreJson(options: resolved),
      'floor_polygon': floorPolygon
          .map((point) => point.toFirestoreJson())
          .toList(),
      'walls': walls,
      'calibration': calibration,
      'quality_status': qualityStatus.wireValue,
      'warnings': warnings,
      'artifact_refs': artifactRefs
          .map((ref) => ref.toFirestoreJson(options: resolved))
          .toList(),
      'created_at': resolved.timestampEncoder(createdAt),
      'updated_at': resolved.timestampEncoder(updatedAt),
      'schema_version': schemaVersion,
    }, 'floor_plans');
  }

  FirebaseJson toExportJson() {
    return toFirestoreJson(options: FirebaseSerializationOptions.exportJson);
  }
}

extension FirebaseCaptureSessionSerializers on FirebaseCaptureSession {
  FirebaseJson toFirestoreJson({FirebaseSerializationOptions? options}) {
    final resolved = options ?? FirebaseSerializationOptions.firestore;
    return _snakeCasePayload({
      'capture_session_id': captureSessionId,
      'project_id': projectId,
      'owner_uid': ownerUid,
      'room_dimensions_id': roomDimensionsId,
      'capture_method': captureMethod.wireValue,
      'depth_enabled': depthEnabled,
      'started_at': _timestamp(startedAt, resolved),
      'completed_at': _timestamp(completedAt, resolved),
      'notes': notes,
      'created_at': resolved.timestampEncoder(createdAt),
      'updated_at': resolved.timestampEncoder(updatedAt),
      'schema_version': schemaVersion,
    }, 'capture_sessions');
  }
}

extension FirebaseCaptureImageSerializers on FirebaseCaptureImage {
  FirebaseJson toFirestoreJson({FirebaseSerializationOptions? options}) {
    validate();
    final resolved = options ?? FirebaseSerializationOptions.firestore;
    return _snakeCasePayload({
      'capture_image_id': captureImageId,
      'capture_session_id': captureSessionId,
      'project_id': projectId,
      'owner_uid': ownerUid,
      'source_image_id': sourceImageId,
      'role': role.wireValue,
      'storage_path': storagePath,
      'content_type': contentType.wireValue,
      'width_px': widthPx,
      'height_px': heightPx,
      'capture_order': captureOrder,
      'depth_artifact_refs': depthArtifactRefs
          .map((ref) => ref.toFirestoreJson(options: resolved))
          .toList(),
      'camera_pose': _nestedValue(cameraPose, resolved),
      'guidance_state': guidanceState,
      'created_at': resolved.timestampEncoder(createdAt),
      'updated_at': resolved.timestampEncoder(updatedAt),
      'schema_version': schemaVersion,
    }, 'capture_images');
  }
}

extension FirebaseBoundingBoxSerializers on FirebaseBoundingBox {
  FirebaseJson toFirestoreJson() {
    validate();
    return _snakeCasePayload({
      'x': x,
      'y': y,
      'width': width,
      'height': height,
    }, 'bounding_box');
  }
}

extension FirebaseCandidateSceneObjectSerializers
    on FirebaseCandidateSceneObject {
  FirebaseJson toFirestoreJson({FirebaseSerializationOptions? options}) {
    validate();
    final resolved = options ?? FirebaseSerializationOptions.firestore;
    return _snakeCasePayload({
      'candidate_id': candidateId,
      'object_type': objectType.wireValue,
      'category': category,
      'label': label,
      'source_image_id': sourceImageId,
      'capture_image_id': captureImageId,
      'source_image_role': sourceImageRole.wireValue,
      'coordinate_space': coordinateSpace.wireValue,
      'bounding_box': boundingBox.toFirestoreJson(),
      'confidence_score': confidenceScore,
      'review_state': reviewState.wireValue,
      'suggested_asset_id': suggestedAssetId,
      'suggested_position_m': suggestedPositionM?.toFirestoreJson(),
      'suggested_size_m': suggestedSizeM?.toFirestoreJson(),
      'suggested_rotation_deg': suggestedRotationDeg,
      'mask_artifact_ref': maskArtifactRef?.toFirestoreJson(options: resolved),
      'notes': notes,
    }, 'candidate_scene_objects');
  }
}

extension FirebasePlacedSceneObjectSerializers on FirebasePlacedSceneObject {
  FirebaseJson toFirestoreJson() {
    validate();
    return _snakeCasePayload({
      'object_id': objectId,
      'candidate_id': candidateId,
      'object_type': objectType.wireValue,
      'category': category,
      'asset_id': assetId,
      'label': label,
      'position_m': positionM.toFirestoreJson(),
      'size_m': sizeM.toFirestoreJson(),
      'rotation_deg': rotationDeg,
      'confidence_score': confidenceScore,
      'locked': locked,
    }, 'placed_scene_objects');
  }
}

extension FirebaseConfirmedSceneObjectSerializers
    on FirebaseConfirmedSceneObject {
  FirebaseJson toFirestoreJson({FirebaseSerializationOptions? options}) {
    validate();
    final resolved = options ?? FirebaseSerializationOptions.firestore;
    return _snakeCasePayload({
      'object_id': objectId,
      'candidate_id': candidateId,
      'object_type': objectType.wireValue,
      'category': category,
      'asset_id': assetId,
      'label': label,
      'position_m': positionM.toFirestoreJson(),
      'size_m': sizeM.toFirestoreJson(),
      'rotation_deg': rotationDeg,
      'confirmed_by_uid': confirmedByUid,
      'confirmed_at': resolved.timestampEncoder(confirmedAt),
      'locked': locked,
    }, 'confirmed_scene_objects');
  }
}

extension FirebaseStructuralFixtureSerializers on FirebaseStructuralFixture {
  FirebaseJson toFirestoreJson() {
    validate();
    return _snakeCasePayload({
      'fixture_id': fixtureId,
      'candidate_id': candidateId,
      'category': category.wireValue,
      'wall_id': wallId,
      'label': label,
      'position_m': positionM.toFirestoreJson(),
      'size_m': sizeM.toFirestoreJson(),
      'rotation_deg': rotationDeg,
      'confidence_score': confidenceScore,
      'locked': locked,
    }, 'structural_fixtures');
  }
}

extension FirebaseSceneUnderstandingResultSerializers
    on FirebaseSceneUnderstandingResult {
  FirebaseJson toFirestoreJson({FirebaseSerializationOptions? options}) {
    validate();
    final resolved = options ?? FirebaseSerializationOptions.firestore;
    return _snakeCasePayload({
      'result_id': resultId,
      'project_id': projectId,
      'owner_uid': ownerUid,
      'capture_session_id': captureSessionId,
      'job_id': jobId,
      'provider_type': providerType.wireValue,
      'algorithm_id': algorithmId,
      'model_id': modelId,
      'confidence_score': confidenceScore,
      'quality_status': qualityStatus.wireValue,
      'failure_reason_code': failureReasonCode?.wireValue,
      'failure_reason': failureReason,
      'coverage': _nestedValue(coverage, resolved),
      'candidate_objects': candidateObjects
          .map((object) => object.toFirestoreJson(options: resolved))
          .toList(),
      'placed_objects': placedObjects
          .map((object) => object.toFirestoreJson())
          .toList(),
      'confirmed_objects': confirmedObjects
          .map((object) => object.toFirestoreJson(options: resolved))
          .toList(),
      'structural_fixtures': structuralFixtures
          .map((fixture) => fixture.toFirestoreJson())
          .toList(),
      'artifact_refs': artifactRefs
          .map((ref) => ref.toFirestoreJson(options: resolved))
          .toList(),
      'processing_started_at': _timestamp(processingStartedAt, resolved),
      'processing_completed_at': _timestamp(processingCompletedAt, resolved),
      'created_at': resolved.timestampEncoder(createdAt),
      'updated_at': resolved.timestampEncoder(updatedAt),
      'schema_version': schemaVersion,
    }, 'scene_understanding_results');
  }
}

extension FirebaseSavedLayoutSerializers on FirebaseSavedLayout {
  FirebaseJson toFirestoreJson({FirebaseSerializationOptions? options}) {
    validate();
    final resolved = options ?? FirebaseSerializationOptions.firestore;
    return _snakeCasePayload({
      'layout_id': layoutId,
      'project_id': projectId,
      'owner_uid': ownerUid,
      'name': name,
      'source_image_id': sourceImageId,
      'reconstruction_job_id': reconstructionJobId,
      'reconstruction_status': reconstructionStatus.wireValue,
      'review_required': reviewRequired,
      'floor_plan_id': floorPlanId,
      'coordinate_space': coordinateSpace.wireValue,
      'room_dimensions': roomDimensions.toFirestoreJson(options: resolved),
      'source_metadata': _nestedValue(sourceMetadata, resolved),
      'floor_plan': floorPlan.toFirestoreJson(options: resolved),
      'editor_scene': _nestedValue(editorScene, resolved),
      'furniture_objects': furnitureObjects
          .map((object) => object.toFirestoreJson())
          .toList(),
      'base_floor_plan_updated_at': _timestamp(
        baseFloorPlanUpdatedAt,
        resolved,
      ),
      'saved_at': resolved.timestampEncoder(savedAt),
      'created_at': resolved.timestampEncoder(createdAt),
      'updated_at': resolved.timestampEncoder(updatedAt),
      'schema_version': schemaVersion,
      'export_version': exportVersion,
    }, 'layouts');
  }

  FirebaseJson toExportJson() {
    return toFirestoreJson(options: FirebaseSerializationOptions.exportJson);
  }
}

extension FirebaseAdminActionSerializers on FirebaseAdminAction {
  FirebaseJson toFirestoreJson({FirebaseSerializationOptions? options}) {
    final resolved = options ?? FirebaseSerializationOptions.firestore;
    return _snakeCasePayload({
      'action_id': actionId,
      'project_id': projectId,
      'owner_uid': ownerUid,
      'created_by_uid': createdByUid,
      'created_by_role': createdByRole.wireValue,
      'action_type': actionType,
      'target_type': targetType,
      'target_id': targetId,
      'reason_code': reasonCode,
      'reason_message': reasonMessage,
      'permission_outcome': permissionOutcome,
      'retry_job_id': retryJobId,
      'metadata': metadata,
      'created_at': resolved.timestampEncoder(createdAt),
      'schema_version': schemaVersion,
    }, 'admin_actions');
  }
}

extension FirebaseFurnitureObjectSerializers on FirebaseFurnitureObject {
  FirebaseJson toFirestoreJson() {
    return _snakeCasePayload({
      'furniture_id': furnitureId,
      'category': category.wireValue,
      'position_m': positionM.toFirestoreJson(),
      'size_m': sizeM.toFirestoreJson(),
      'rotation_deg': rotationDeg,
      'color': color,
      'label': label,
      'locked': locked,
    }, 'furniture_objects');
  }
}

extension FirebasePoint2dSerializers on FirebasePoint2d {
  FirebaseJson toFirestoreJson() {
    return {'x': x, 'y': y};
  }
}

extension FirebasePoint3dSerializers on FirebasePoint3d {
  FirebaseJson toFirestoreJson() {
    return {'x': x, 'y': y, 'z': z};
  }
}

FirebaseJson _snakeCasePayload(FirebaseJson json, String context) {
  final compact = _withoutNulls(json);
  FirebaseSerializerValidators.requireSnakeCasePayload(compact, context);
  return compact;
}

FirebaseJson _withoutNulls(FirebaseJson json) {
  return {
    for (final entry in json.entries)
      if (entry.value != null) entry.key: entry.value,
  };
}

Object? _timestamp(DateTime? value, FirebaseSerializationOptions options) {
  return value == null ? null : options.timestampEncoder(value);
}

Object? _nestedValue(Object? value, FirebaseSerializationOptions options) {
  if (value is DateTime) {
    return options.timestampEncoder(value);
  }
  if (value is Map) {
    return {
      for (final entry in value.entries)
        entry.key.toString(): _nestedValue(entry.value, options),
    };
  }
  if (value is Iterable) {
    return value.map((entry) => _nestedValue(entry, options)).toList();
  }
  return value;
}

String _requiredString(FirebaseJson json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw FirebaseContractException('$key must be a non-empty string.');
}

String? _optionalString(FirebaseJson json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is String) {
    return value;
  }
  throw FirebaseContractException('$key must be a string when present.');
}

bool _requiredBool(FirebaseJson json, String key) {
  final value = json[key];
  if (value is bool) {
    return value;
  }
  throw FirebaseContractException('$key must be a boolean.');
}

int _requiredInt(FirebaseJson json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  if (value is num && value % 1 == 0) {
    return value.toInt();
  }
  throw FirebaseContractException('$key must be an integer.');
}

double _requiredDouble(FirebaseJson json, String key) {
  final value = json[key];
  if (value is num) {
    return value.toDouble();
  }
  throw FirebaseContractException('$key must be a number.');
}

double? _optionalDouble(FirebaseJson json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  throw FirebaseContractException('$key must be a number when present.');
}

DateTime _requiredDate(FirebaseJson json, String key) {
  final value = _optionalDate(json, key);
  if (value == null) {
    throw FirebaseContractException('$key must be a timestamp.');
  }
  return value;
}

DateTime? _optionalDate(FirebaseJson json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.parse(value);
  }
  throw FirebaseContractException('$key must be a timestamp.');
}

FirebaseJson _requiredJson(FirebaseJson json, String key) {
  final value = json[key];
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return Map<String, Object?>.from(value);
  }
  throw FirebaseContractException('$key must be a map.');
}

FirebasePoint2d _point2dFromJson(Object? value, String context) {
  final json = _jsonFromObject(value, context);
  return FirebasePoint2d(
    x: _requiredDouble(json, 'x'),
    y: _requiredDouble(json, 'y'),
  );
}

FirebasePoint3d _point3dFromJson(Object? value, String context) {
  final json = _jsonFromObject(value, context);
  return FirebasePoint3d(
    x: _requiredDouble(json, 'x'),
    y: _requiredDouble(json, 'y'),
    z: _requiredDouble(json, 'z'),
  );
}

FirebaseBoundingBox _boundingBoxFromJson(Object? value, String context) {
  final json = _jsonFromObject(value, context);
  final model = FirebaseBoundingBox(
    x: _requiredDouble(json, 'x'),
    y: _requiredDouble(json, 'y'),
    width: _requiredDouble(json, 'width'),
    height: _requiredDouble(json, 'height'),
  );
  model.validate();
  return model;
}

FirebaseArtifactRef _artifactRefFromJson(Object? value, String context) {
  final json = _jsonFromObject(value, context);
  return FirebaseArtifactRef(
    artifactId: _requiredString(json, 'artifact_id'),
    storagePath: _requiredString(json, 'storage_path'),
    artifactType: _requiredString(json, 'artifact_type'),
    contentType: FirebaseArtifactContentType.fromWireValue(
      json['content_type'],
    ),
    byteSize: json['byte_size'] == null
        ? null
        : _requiredInt(json, 'byte_size'),
    sha256Hex: _optionalString(json, 'sha256_hex'),
    widthPx: json['width_px'] == null ? null : _requiredInt(json, 'width_px'),
    heightPx: json['height_px'] == null
        ? null
        : _requiredInt(json, 'height_px'),
    createdAt: _optionalDate(json, 'created_at'),
    description: _optionalString(json, 'description'),
  );
}

FirebaseFurnitureObject _furnitureObjectFromJson(
  Object? value,
  String context,
) {
  final json = _jsonFromObject(value, context);
  return FirebaseFurnitureObject(
    furnitureId: _requiredString(json, 'furniture_id'),
    category: FirebaseFurnitureCategory.fromWireValue(json['category']),
    positionM: _point3dFromJson(json['position_m'], '$context.position_m'),
    sizeM: _point3dFromJson(json['size_m'], '$context.size_m'),
    rotationDeg: _requiredDouble(json, 'rotation_deg'),
    color: _optionalString(json, 'color'),
    label: _optionalString(json, 'label'),
    locked: json['locked'] == null ? null : _requiredBool(json, 'locked'),
  );
}

FirebaseCandidateSceneObject _candidateSceneObjectFromJson(
  Object? value,
  String context,
) {
  final json = _jsonFromObject(value, context);
  return FirebaseCandidateSceneObject(
    candidateId: _requiredString(json, 'candidate_id'),
    objectType: FirebaseSceneObjectType.fromWireValue(json['object_type']),
    category: _requiredString(json, 'category'),
    label: _optionalString(json, 'label'),
    sourceImageId: _requiredString(json, 'source_image_id'),
    captureImageId: _requiredString(json, 'capture_image_id'),
    sourceImageRole: FirebaseCaptureImageRole.fromWireValue(
      json['source_image_role'],
    ),
    coordinateSpace: FirebaseCoordinateSpace.fromWireValue(
      json['coordinate_space'],
    ),
    boundingBox: _boundingBoxFromJson(
      json['bounding_box'],
      '$context.bounding_box',
    ),
    confidenceScore: _requiredDouble(json, 'confidence_score'),
    reviewState: FirebaseCandidateReviewState.fromWireValue(
      json['review_state'],
    ),
    suggestedAssetId: _optionalString(json, 'suggested_asset_id'),
    suggestedPositionM: json['suggested_position_m'] == null
        ? null
        : _point3dFromJson(
            json['suggested_position_m'],
            '$context.suggested_position_m',
          ),
    suggestedSizeM: json['suggested_size_m'] == null
        ? null
        : _point3dFromJson(
            json['suggested_size_m'],
            '$context.suggested_size_m',
          ),
    suggestedRotationDeg: _optionalDouble(json, 'suggested_rotation_deg'),
    maskArtifactRef: json['mask_artifact_ref'] == null
        ? null
        : _artifactRefFromJson(
            json['mask_artifact_ref'],
            '$context.mask_artifact_ref',
          ),
    notes: _optionalString(json, 'notes'),
  );
}

FirebasePlacedSceneObject _placedSceneObjectFromJson(
  Object? value,
  String context,
) {
  final json = _jsonFromObject(value, context);
  return FirebasePlacedSceneObject(
    objectId: _requiredString(json, 'object_id'),
    candidateId: _optionalString(json, 'candidate_id'),
    objectType: FirebaseSceneObjectType.fromWireValue(json['object_type']),
    category: _requiredString(json, 'category'),
    assetId: _optionalString(json, 'asset_id'),
    label: _optionalString(json, 'label'),
    positionM: _point3dFromJson(json['position_m'], '$context.position_m'),
    sizeM: _point3dFromJson(json['size_m'], '$context.size_m'),
    rotationDeg: _requiredDouble(json, 'rotation_deg'),
    confidenceScore: _optionalDouble(json, 'confidence_score'),
    locked: json['locked'] == null ? null : _requiredBool(json, 'locked'),
  );
}

FirebaseConfirmedSceneObject _confirmedSceneObjectFromJson(
  Object? value,
  String context,
) {
  final json = _jsonFromObject(value, context);
  return FirebaseConfirmedSceneObject(
    objectId: _requiredString(json, 'object_id'),
    candidateId: _optionalString(json, 'candidate_id'),
    objectType: FirebaseSceneObjectType.fromWireValue(json['object_type']),
    category: _requiredString(json, 'category'),
    assetId: _optionalString(json, 'asset_id'),
    label: _optionalString(json, 'label'),
    positionM: _point3dFromJson(json['position_m'], '$context.position_m'),
    sizeM: _point3dFromJson(json['size_m'], '$context.size_m'),
    rotationDeg: _requiredDouble(json, 'rotation_deg'),
    confirmedByUid: _requiredString(json, 'confirmed_by_uid'),
    confirmedAt: _requiredDate(json, 'confirmed_at'),
    locked: json['locked'] == null ? null : _requiredBool(json, 'locked'),
  );
}

FirebaseStructuralFixture _structuralFixtureFromJson(
  Object? value,
  String context,
) {
  final json = _jsonFromObject(value, context);
  return FirebaseStructuralFixture(
    fixtureId: _requiredString(json, 'fixture_id'),
    candidateId: _optionalString(json, 'candidate_id'),
    category: FirebaseStructuralFixtureCategory.fromWireValue(json['category']),
    wallId: _requiredString(json, 'wall_id'),
    label: _optionalString(json, 'label'),
    positionM: _point3dFromJson(json['position_m'], '$context.position_m'),
    sizeM: _point3dFromJson(json['size_m'], '$context.size_m'),
    rotationDeg: _requiredDouble(json, 'rotation_deg'),
    confidenceScore: _optionalDouble(json, 'confidence_score'),
    locked: json['locked'] == null ? null : _requiredBool(json, 'locked'),
  );
}

FirebaseJson _jsonFromObject(Object? value, String context) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return Map<String, Object?>.from(value);
  }
  throw FirebaseContractException('$context must be a map.');
}

List<FirebaseJson> _jsonList(FirebaseJson json, String key) {
  final value = json[key];
  if (value == null) {
    return const [];
  }
  if (value is! List) {
    throw FirebaseContractException('$key must be a list.');
  }
  return [
    for (var index = 0; index < value.length; index += 1)
      _jsonFromObject(value[index], '$key[$index]'),
  ];
}

List<String> _stringList(FirebaseJson json, String key) {
  final value = json[key];
  if (value == null) {
    return const [];
  }
  if (value is! List) {
    throw FirebaseContractException('$key must be a list.');
  }
  return [
    for (var index = 0; index < value.length; index += 1)
      if (value[index] is String)
        value[index] as String
      else
        throw FirebaseContractException('$key[$index] must be a string.'),
  ];
}

List<FirebasePoint2d> _point2dList(FirebaseJson json, String key) {
  final value = json[key];
  if (value == null) {
    return const [];
  }
  if (value is! List) {
    throw FirebaseContractException('$key must be a list.');
  }
  return [
    for (var index = 0; index < value.length; index += 1)
      _point2dFromJson(value[index], '$key[$index]'),
  ];
}

List<FirebaseArtifactRef> _artifactRefList(FirebaseJson json, String key) {
  final value = json[key];
  if (value == null) {
    return const [];
  }
  if (value is! List) {
    throw FirebaseContractException('$key must be a list.');
  }
  return [
    for (var index = 0; index < value.length; index += 1)
      _artifactRefFromJson(value[index], '$key[$index]'),
  ];
}

List<FirebaseFurnitureObject> _furnitureObjectList(
  FirebaseJson json,
  String key,
) {
  final value = json[key];
  if (value == null) {
    return const [];
  }
  if (value is! List) {
    throw FirebaseContractException('$key must be a list.');
  }
  return [
    for (var index = 0; index < value.length; index += 1)
      _furnitureObjectFromJson(value[index], '$key[$index]'),
  ];
}

List<FirebaseCandidateSceneObject> _candidateSceneObjectList(
  FirebaseJson json,
  String key,
) {
  final value = json[key];
  if (value == null) {
    return const [];
  }
  if (value is! List) {
    throw FirebaseContractException('$key must be a list.');
  }
  return [
    for (var index = 0; index < value.length; index += 1)
      _candidateSceneObjectFromJson(value[index], '$key[$index]'),
  ];
}

List<FirebasePlacedSceneObject> _placedSceneObjectList(
  FirebaseJson json,
  String key,
) {
  final value = json[key];
  if (value == null) {
    return const [];
  }
  if (value is! List) {
    throw FirebaseContractException('$key must be a list.');
  }
  return [
    for (var index = 0; index < value.length; index += 1)
      _placedSceneObjectFromJson(value[index], '$key[$index]'),
  ];
}

List<FirebaseConfirmedSceneObject> _confirmedSceneObjectList(
  FirebaseJson json,
  String key,
) {
  final value = json[key];
  if (value == null) {
    return const [];
  }
  if (value is! List) {
    throw FirebaseContractException('$key must be a list.');
  }
  return [
    for (var index = 0; index < value.length; index += 1)
      _confirmedSceneObjectFromJson(value[index], '$key[$index]'),
  ];
}

List<FirebaseStructuralFixture> _structuralFixtureList(
  FirebaseJson json,
  String key,
) {
  final value = json[key];
  if (value == null) {
    return const [];
  }
  if (value is! List) {
    throw FirebaseContractException('$key must be a list.');
  }
  return [
    for (var index = 0; index < value.length; index += 1)
      _structuralFixtureFromJson(value[index], '$key[$index]'),
  ];
}
