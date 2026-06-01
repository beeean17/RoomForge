typedef FirebaseJson = Map<String, Object?>;

class FirebaseContractException implements Exception {
  const FirebaseContractException(this.message);

  final String message;

  @override
  String toString() => message;
}

enum FirebaseCollectionContract {
  userProfile('users/{uid}', 'FirebaseUserProfile'),
  roomProject('projects/{project_id}', 'FirebaseRoomProject'),
  sourceImage(
    'projects/{project_id}/source_images/{source_image_id}',
    'FirebaseSourceImage',
  ),
  roomDimensions(
    'projects/{project_id}/room_dimensions/current',
    'FirebaseRoomDimensions',
  ),
  reconstructionJob(
    'projects/{project_id}/reconstruction_jobs/{job_id}',
    'FirebaseReconstructionJob',
  ),
  jobStatusTransition(
    'projects/{project_id}/reconstruction_jobs/{job_id}/transitions/{transition_id}',
    'FirebaseJobStatusTransition',
  ),
  openCvResult(
    'projects/{project_id}/opencv_results/{result_id}',
    'FirebaseOpenCvResult',
  ),
  confirmedGeometry(
    'projects/{project_id}/confirmed_geometries/{geometry_id}',
    'FirebaseConfirmedGeometry',
  ),
  floorPlan(
    'projects/{project_id}/floor_plans/{floor_plan_id}',
    'FirebaseFloorPlan',
  ),
  captureSession(
    'projects/{project_id}/capture_sessions/{capture_session_id}',
    'FirebaseCaptureSession',
  ),
  captureImage(
    'projects/{project_id}/capture_sessions/{capture_session_id}/images/{capture_image_id}',
    'FirebaseCaptureImage',
  ),
  sceneUnderstandingResult(
    'projects/{project_id}/scene_understanding_results/{result_id}',
    'FirebaseSceneUnderstandingResult',
  ),
  savedLayout(
    'projects/{project_id}/layouts/{layout_id}',
    'FirebaseSavedLayout',
  ),
  adminAction(
    'projects/{project_id}/admin_actions/{action_id}',
    'FirebaseAdminAction',
  );

  const FirebaseCollectionContract(this.pathPattern, this.modelName);

  final String pathPattern;
  final String modelName;
}

enum FirebaseJobStatus {
  created('created'),
  uploading('uploading'),
  processing('processing'),
  reviewRequired('review_required'),
  succeeded('succeeded'),
  failed('failed'),
  timeout('timeout'),
  cancelled('cancelled'),
  retrying('retrying');

  const FirebaseJobStatus(this.wireValue);

  final String wireValue;

  bool get isTerminal {
    return switch (this) {
      FirebaseJobStatus.succeeded ||
      FirebaseJobStatus.failed ||
      FirebaseJobStatus.timeout ||
      FirebaseJobStatus.cancelled => true,
      _ => false,
    };
  }

  String get displayLabel {
    return this == FirebaseJobStatus.reviewRequired
        ? 'Needs review'
        : wireValue;
  }

  static FirebaseJobStatus fromWireValue(Object? value) {
    return _enumFromWireValue(
      value,
      FirebaseJobStatus.values,
      (status) => status.wireValue,
      'job_status',
    );
  }
}

enum FirebaseCoordinateSpace {
  imagePixels('image_pixels'),
  meters('meters');

  const FirebaseCoordinateSpace(this.wireValue);

  final String wireValue;

  static FirebaseCoordinateSpace fromWireValue(Object? value) {
    return _enumFromWireValue(
      value,
      FirebaseCoordinateSpace.values,
      (space) => space.wireValue,
      'coordinate_space',
    );
  }
}

enum FirebaseImageContentType {
  jpeg('image/jpeg'),
  png('image/png'),
  webp('image/webp');

  const FirebaseImageContentType(this.wireValue);

  final String wireValue;

  static FirebaseImageContentType fromWireValue(Object? value) {
    return _enumFromWireValue(
      value,
      FirebaseImageContentType.values,
      (type) => type.wireValue,
      'image_content_type',
    );
  }
}

enum FirebaseArtifactContentType {
  jpeg('image/jpeg'),
  png('image/png'),
  webp('image/webp'),
  json('application/json');

  const FirebaseArtifactContentType(this.wireValue);

  final String wireValue;

  static FirebaseArtifactContentType fromWireValue(Object? value) {
    return _enumFromWireValue(
      value,
      FirebaseArtifactContentType.values,
      (type) => type.wireValue,
      'artifact_content_type',
    );
  }
}

enum FirebaseRetentionStatus {
  active('active'),
  markedForDelete('marked_for_delete'),
  deleted('deleted');

  const FirebaseRetentionStatus(this.wireValue);

  final String wireValue;

  static FirebaseRetentionStatus fromWireValue(Object? value) {
    return _enumFromWireValue(
      value,
      FirebaseRetentionStatus.values,
      (status) => status.wireValue,
      'retention_status',
    );
  }
}

enum FirebaseQualityStatus {
  success('success'),
  reviewRequired('review_required'),
  failed('failed');

  const FirebaseQualityStatus(this.wireValue);

  final String wireValue;

  String get displayLabel {
    return this == FirebaseQualityStatus.reviewRequired
        ? 'Needs review'
        : wireValue;
  }

  static FirebaseQualityStatus fromWireValue(Object? value) {
    return _enumFromWireValue(
      value,
      FirebaseQualityStatus.values,
      (status) => status.wireValue,
      'quality_status',
    );
  }
}

enum FirebaseActorType {
  user('user'),
  system('system'),
  admin('admin'),
  worker('worker');

  const FirebaseActorType(this.wireValue);

  final String wireValue;

  static FirebaseActorType fromWireValue(Object? value) {
    return _enumFromWireValue(
      value,
      FirebaseActorType.values,
      (type) => type.wireValue,
      'actor_type',
    );
  }
}

enum FirebaseAdminRole {
  admin('admin');

  const FirebaseAdminRole(this.wireValue);

  final String wireValue;

  static FirebaseAdminRole fromWireValue(Object? value) {
    return _enumFromWireValue(
      value,
      FirebaseAdminRole.values,
      (role) => role.wireValue,
      'admin_role',
    );
  }
}

enum FirebaseBoundaryType {
  rectangle('rectangle'),
  simplePolygon('simple_polygon');

  const FirebaseBoundaryType(this.wireValue);

  final String wireValue;

  static FirebaseBoundaryType fromWireValue(Object? value) {
    return _enumFromWireValue(
      value,
      FirebaseBoundaryType.values,
      (type) => type.wireValue,
      'boundary_type',
    );
  }
}

enum FirebaseCaptureMethod {
  androidGuidedPhoto('android_guided_photo'),
  androidArcoreDepth('android_arcore_depth'),
  desktopUpload('desktop_upload');

  const FirebaseCaptureMethod(this.wireValue);

  final String wireValue;

  static FirebaseCaptureMethod fromWireValue(Object? value) {
    return _enumFromWireValue(
      value,
      FirebaseCaptureMethod.values,
      (method) => method.wireValue,
      'capture_method',
    );
  }
}

enum FirebaseCaptureImageRole {
  overview('overview'),
  frontWall('front_wall'),
  rightWall('right_wall'),
  backWall('back_wall'),
  leftWall('left_wall'),
  extra('extra');

  const FirebaseCaptureImageRole(this.wireValue);

  final String wireValue;

  static FirebaseCaptureImageRole fromWireValue(Object? value) {
    return _enumFromWireValue(
      value,
      FirebaseCaptureImageRole.values,
      (role) => role.wireValue,
      'capture_image_role',
    );
  }
}

enum FirebaseFurnitureCategory {
  bed('bed'),
  desk('desk'),
  chair('chair'),
  wardrobe('wardrobe'),
  sofa('sofa'),
  table('table'),
  shelf('shelf'),
  cabinet('cabinet'),
  custom('custom');

  const FirebaseFurnitureCategory(this.wireValue);

  final String wireValue;

  static FirebaseFurnitureCategory fromWireValue(Object? value) {
    return _enumFromWireValue(
      value,
      FirebaseFurnitureCategory.values,
      (category) => category.wireValue,
      'furniture_category',
    );
  }
}

enum FirebaseSceneObjectType {
  furniture('furniture'),
  structuralFixture('structural_fixture');

  const FirebaseSceneObjectType(this.wireValue);

  final String wireValue;

  static FirebaseSceneObjectType fromWireValue(Object? value) {
    return _enumFromWireValue(
      value,
      FirebaseSceneObjectType.values,
      (type) => type.wireValue,
      'scene_object_type',
    );
  }
}

enum FirebaseCandidateReviewState {
  suggested('suggested'),
  placed('placed'),
  rejected('rejected'),
  confirmed('confirmed'),
  reviewRequired('review_required');

  const FirebaseCandidateReviewState(this.wireValue);

  final String wireValue;

  String get displayLabel {
    return this == FirebaseCandidateReviewState.reviewRequired
        ? 'Needs review'
        : wireValue;
  }

  static FirebaseCandidateReviewState fromWireValue(Object? value) {
    return _enumFromWireValue(
      value,
      FirebaseCandidateReviewState.values,
      (state) => state.wireValue,
      'candidate_review_state',
    );
  }
}

enum FirebaseStructuralFixtureCategory {
  door('door'),
  window('window'),
  builtIn('built_in'),
  closet('closet'),
  custom('custom');

  const FirebaseStructuralFixtureCategory(this.wireValue);

  final String wireValue;

  static FirebaseStructuralFixtureCategory fromWireValue(Object? value) {
    return _enumFromWireValue(
      value,
      FirebaseStructuralFixtureCategory.values,
      (category) => category.wireValue,
      'structural_fixture_category',
    );
  }
}

enum FirebaseSceneUnderstandingProviderType {
  browserCv('browser_cv'),
  androidArcoreDepth('android_arcore_depth'),
  cloudGpu('cloud_gpu'),
  manual('manual');

  const FirebaseSceneUnderstandingProviderType(this.wireValue);

  final String wireValue;

  static FirebaseSceneUnderstandingProviderType fromWireValue(Object? value) {
    return _enumFromWireValue(
      value,
      FirebaseSceneUnderstandingProviderType.values,
      (provider) => provider.wireValue,
      'scene_understanding_provider_type',
    );
  }
}

enum FirebaseSceneUnderstandingFailureReason {
  noSourceImages('no_source_images'),
  unsupportedRuntime('unsupported_runtime'),
  detectorFailed('detector_failed'),
  lowConfidence('low_confidence'),
  insufficientCoverage('insufficient_coverage'),
  providerUnavailable('provider_unavailable');

  const FirebaseSceneUnderstandingFailureReason(this.wireValue);

  final String wireValue;

  static FirebaseSceneUnderstandingFailureReason fromWireValue(Object? value) {
    return _enumFromWireValue(
      value,
      FirebaseSceneUnderstandingFailureReason.values,
      (reason) => reason.wireValue,
      'scene_understanding_failure_reason',
    );
  }
}

T _enumFromWireValue<T>(
  Object? value,
  List<T> values,
  String Function(T value) wireValueFor,
  String fieldName,
) {
  if (value is! String) {
    throw FirebaseContractException('$fieldName must be a string.');
  }

  for (final candidate in values) {
    if (wireValueFor(candidate) == value) {
      return candidate;
    }
  }

  throw FirebaseContractException('$fieldName has unsupported value "$value".');
}

class FirebaseContractValidators {
  const FirebaseContractValidators._();

  static void requireCoordinateSpace(
    FirebaseCoordinateSpace actual,
    FirebaseCoordinateSpace expected,
    String documentType,
  ) {
    if (actual != expected) {
      throw FirebaseContractException(
        '$documentType must use coordinate_space "${expected.wireValue}".',
      );
    }
  }

  static FirebaseCoordinateSpace requireRawCoordinateSpace(
    FirebaseJson json,
    FirebaseCoordinateSpace expected,
    String documentType,
  ) {
    final actual = FirebaseCoordinateSpace.fromWireValue(
      json['coordinate_space'],
    );
    requireCoordinateSpace(actual, expected, documentType);
    return actual;
  }

  static FirebaseJobStatus requireRawJobStatus(
    FirebaseJson json,
    String fieldName,
    String documentType,
  ) {
    final status = FirebaseJobStatus.fromWireValue(json[fieldName]);
    if (status == FirebaseJobStatus.reviewRequired &&
        fieldName == 'reconstruction_status' &&
        json['review_required'] != true) {
      throw FirebaseContractException(
        '$documentType must set review_required when reconstruction_status is review_required.',
      );
    }
    return status;
  }
}

class FirebaseSceneUnderstandingQualityResolver {
  const FirebaseSceneUnderstandingQualityResolver._();

  static FirebaseQualityStatus fromSignal({
    required double? confidenceScore,
    required bool hasCandidateObjects,
    required FirebaseSceneUnderstandingFailureReason? failureReasonCode,
  }) {
    if (failureReasonCode != null || !hasCandidateObjects) {
      return FirebaseQualityStatus.failed;
    }
    if (confidenceScore == null || confidenceScore < 0.68) {
      return FirebaseQualityStatus.reviewRequired;
    }
    return FirebaseQualityStatus.success;
  }
}

class FirebasePoint2d {
  const FirebasePoint2d({required this.x, required this.y});

  final double x;
  final double y;
}

class FirebasePoint3d {
  const FirebasePoint3d({required this.x, required this.y, required this.z});

  final double x;
  final double y;
  final double z;
}

class FirebaseBoundingBox {
  const FirebaseBoundingBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;

  void validate() {
    if (width <= 0 || height <= 0) {
      throw const FirebaseContractException(
        'bounding_box width and height must be positive.',
      );
    }
  }
}

class FirebaseArtifactRef {
  const FirebaseArtifactRef({
    required this.artifactId,
    required this.storagePath,
    required this.artifactType,
    required this.contentType,
    this.byteSize,
    this.sha256Hex,
    this.widthPx,
    this.heightPx,
    this.createdAt,
    this.description,
  });

  final String artifactId;
  final String storagePath;
  final String artifactType;
  final FirebaseArtifactContentType contentType;
  final int? byteSize;
  final String? sha256Hex;
  final int? widthPx;
  final int? heightPx;
  final DateTime? createdAt;
  final String? description;

  void validate({
    required String ownerUid,
    required String projectId,
    required String jobId,
  }) {
    final expectedPrefix =
        'users/$ownerUid/projects/$projectId/artifacts/$jobId/$artifactId/';
    if (!storagePath.startsWith(expectedPrefix)) {
      throw const FirebaseContractException(
        'artifact_refs storage_path must match the owning project, job, and artifact.',
      );
    }
    if (byteSize != null && byteSize! <= 0) {
      throw const FirebaseContractException(
        'artifact_refs byte_size must be positive when provided.',
      );
    }
    if (byteSize != null &&
        contentType == FirebaseArtifactContentType.json &&
        byteSize! > 2 * 1024 * 1024) {
      throw const FirebaseContractException(
        'artifact_refs JSON artifacts must be 2 MB or smaller.',
      );
    }
    if (byteSize != null &&
        contentType != FirebaseArtifactContentType.json &&
        byteSize! > 10 * 1024 * 1024) {
      throw const FirebaseContractException(
        'artifact_refs image artifacts must be 10 MB or smaller.',
      );
    }
  }
}

class FirebaseUserProfile {
  const FirebaseUserProfile({
    required this.uid,
    required this.createdAt,
    required this.updatedAt,
    required this.schemaVersion,
    this.email,
    this.displayName,
    this.photoUrl,
    this.lastSeenAt,
    this.role,
    this.roleUpdatedAt,
    this.roleUpdatedByUid,
  });

  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastSeenAt;
  final int schemaVersion;
  final FirebaseAdminRole? role;
  final DateTime? roleUpdatedAt;
  final String? roleUpdatedByUid;
}

class FirebaseRoomProject {
  const FirebaseRoomProject({
    required this.projectId,
    required this.ownerUid,
    required this.name,
    required this.schemaVersion,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.deletedAt,
    this.latestSourceImageId,
    this.latestJobId,
    this.latestFloorPlanId,
    this.latestLayoutId,
    this.currentReconstructionStatus,
    this.lastOpenedAt,
  });

  final String projectId;
  final String ownerUid;
  final String name;
  final String? description;
  final int schemaVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String? latestSourceImageId;
  final String? latestJobId;
  final String? latestFloorPlanId;
  final String? latestLayoutId;
  final FirebaseJobStatus? currentReconstructionStatus;
  final DateTime? lastOpenedAt;
}

class FirebaseSourceImage {
  const FirebaseSourceImage({
    required this.sourceImageId,
    required this.projectId,
    required this.ownerUid,
    required this.storagePath,
    required this.storedFilename,
    required this.contentType,
    required this.byteSize,
    required this.sha256Hex,
    required this.widthPx,
    required this.heightPx,
    required this.retentionStatus,
    required this.uploadedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.schemaVersion,
    this.originalFilename,
    this.captureSource,
    this.captureSessionId,
    this.captureImageId,
    this.captureImageRole,
  });

  final String sourceImageId;
  final String projectId;
  final String ownerUid;
  final String storagePath;
  final String? originalFilename;
  final String storedFilename;
  final FirebaseImageContentType contentType;
  final int byteSize;
  final String sha256Hex;
  final int widthPx;
  final int heightPx;
  final String? captureSource;
  final String? captureSessionId;
  final String? captureImageId;
  final FirebaseCaptureImageRole? captureImageRole;
  final FirebaseRetentionStatus retentionStatus;
  final DateTime uploadedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;
}

class FirebaseRoomDimensions {
  const FirebaseRoomDimensions({
    required this.projectId,
    required this.ownerUid,
    required this.widthM,
    required this.depthM,
    required this.heightM,
    required this.unit,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
    required this.schemaVersion,
  });

  final String projectId;
  final String ownerUid;
  final double widthM;
  final double depthM;
  final double heightM;
  final String unit;
  final String source;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;

  void validate() {
    if (unit != 'meters') {
      throw const FirebaseContractException(
        'room_dimensions/current must use unit "meters".',
      );
    }
    if (widthM <= 0 || depthM <= 0 || heightM <= 0) {
      throw const FirebaseContractException(
        'room_dimensions/current values must be positive.',
      );
    }
  }
}

class FirebaseReconstructionJob {
  const FirebaseReconstructionJob({
    required this.jobId,
    required this.projectId,
    required this.ownerUid,
    required this.sourceImageId,
    required this.roomDimensionsId,
    required this.status,
    required this.statusUpdatedAt,
    required this.providerType,
    required this.createdByUid,
    required this.retryCount,
    required this.createdAt,
    required this.updatedAt,
    required this.schemaVersion,
    this.providerId,
    this.algorithmId,
    this.openCvVersion,
    this.retryOfJobId,
    this.rootJobId,
    this.latestTransitionId,
    this.latestResultId,
    this.latestConfirmedGeometryId,
    this.latestFloorPlanId,
    this.failureReasonCode,
    this.failureReason,
    this.qualityStatus,
    this.artifactRefs = const [],
    this.startedAt,
    this.completedAt,
    this.timeoutAt,
  });

  final String jobId;
  final String projectId;
  final String ownerUid;
  final String sourceImageId;
  final String roomDimensionsId;
  final FirebaseJobStatus status;
  final DateTime statusUpdatedAt;
  final String providerType;
  final String? providerId;
  final String? algorithmId;
  final String? openCvVersion;
  final String createdByUid;
  final String? retryOfJobId;
  final String? rootJobId;
  final int retryCount;
  final String? latestTransitionId;
  final String? latestResultId;
  final String? latestConfirmedGeometryId;
  final String? latestFloorPlanId;
  final String? failureReasonCode;
  final String? failureReason;
  final FirebaseQualityStatus? qualityStatus;
  final List<FirebaseArtifactRef> artifactRefs;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? timeoutAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;
}

class FirebaseJobStatusTransition {
  const FirebaseJobStatusTransition({
    required this.transitionId,
    required this.projectId,
    required this.ownerUid,
    required this.jobId,
    required this.toStatus,
    required this.occurredAt,
    required this.actorType,
    required this.schemaVersion,
    this.fromStatus,
    this.actorUid,
    this.reasonCode,
    this.reasonMessage,
    this.artifactRefs = const [],
    this.retryJobId,
  });

  final String transitionId;
  final String projectId;
  final String ownerUid;
  final String jobId;
  final FirebaseJobStatus? fromStatus;
  final FirebaseJobStatus toStatus;
  final DateTime occurredAt;
  final FirebaseActorType actorType;
  final String? actorUid;
  final String? reasonCode;
  final String? reasonMessage;
  final List<FirebaseArtifactRef> artifactRefs;
  final String? retryJobId;
  final int schemaVersion;
}

class FirebaseOpenCvResult {
  const FirebaseOpenCvResult({
    required this.resultId,
    required this.projectId,
    required this.ownerUid,
    required this.jobId,
    required this.sourceImageId,
    required this.coordinateSpace,
    required this.algorithmId,
    required this.qualityStatus,
    required this.createdAt,
    required this.updatedAt,
    required this.schemaVersion,
    this.openCvVersion,
    this.candidateEdges = const [],
    this.candidateLines = const [],
    this.candidateCorners = const [],
    this.boundaryHints = const [],
    this.confidenceScore,
    this.failureReasonCode,
    this.failureReason,
    this.artifactRefs = const [],
    this.processingStartedAt,
    this.processingCompletedAt,
  });

  final String resultId;
  final String projectId;
  final String ownerUid;
  final String jobId;
  final String sourceImageId;
  final FirebaseCoordinateSpace coordinateSpace;
  final String algorithmId;
  final String? openCvVersion;
  final List<FirebaseJson> candidateEdges;
  final List<FirebaseJson> candidateLines;
  final List<FirebasePoint2d> candidateCorners;
  final List<FirebaseJson> boundaryHints;
  final double? confidenceScore;
  final FirebaseQualityStatus qualityStatus;
  final String? failureReasonCode;
  final String? failureReason;
  final List<FirebaseArtifactRef> artifactRefs;
  final DateTime? processingStartedAt;
  final DateTime? processingCompletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;

  void validate() {
    FirebaseContractValidators.requireCoordinateSpace(
      coordinateSpace,
      FirebaseCoordinateSpace.imagePixels,
      'opencv_results',
    );
  }
}

class FirebaseConfirmedGeometry {
  const FirebaseConfirmedGeometry({
    required this.geometryId,
    required this.projectId,
    required this.ownerUid,
    required this.jobId,
    required this.sourceImageId,
    required this.coordinateSpace,
    required this.boundaryType,
    required this.boundaryPoints,
    required this.confirmedByUid,
    required this.createdAt,
    required this.updatedAt,
    required this.schemaVersion,
    this.openCvResultId,
    this.correctionMethod,
  });

  final String geometryId;
  final String projectId;
  final String ownerUid;
  final String jobId;
  final String sourceImageId;
  final String? openCvResultId;
  final FirebaseCoordinateSpace coordinateSpace;
  final FirebaseBoundaryType boundaryType;
  final List<FirebasePoint2d> boundaryPoints;
  final String? correctionMethod;
  final String confirmedByUid;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;

  void validate() {
    FirebaseContractValidators.requireCoordinateSpace(
      coordinateSpace,
      FirebaseCoordinateSpace.imagePixels,
      'confirmed_geometries',
    );
    if (boundaryPoints.length < 3) {
      throw const FirebaseContractException(
        'confirmed_geometries must include at least three boundary points.',
      );
    }
  }
}

class FirebaseFloorPlan {
  const FirebaseFloorPlan({
    required this.floorPlanId,
    required this.projectId,
    required this.ownerUid,
    required this.jobId,
    required this.sourceImageId,
    required this.confirmedGeometryId,
    required this.roomDimensionsId,
    required this.coordinateSpace,
    required this.roomDimensions,
    required this.floorPolygon,
    required this.calibration,
    required this.qualityStatus,
    required this.createdAt,
    required this.updatedAt,
    required this.schemaVersion,
    this.walls = const [],
    this.warnings = const [],
    this.artifactRefs = const [],
  });

  final String floorPlanId;
  final String projectId;
  final String ownerUid;
  final String jobId;
  final String sourceImageId;
  final String confirmedGeometryId;
  final String roomDimensionsId;
  final FirebaseCoordinateSpace coordinateSpace;
  final FirebaseRoomDimensions roomDimensions;
  final List<FirebasePoint2d> floorPolygon;
  final FirebaseJson calibration;
  final FirebaseQualityStatus qualityStatus;
  final List<FirebaseJson> walls;
  final List<String> warnings;
  final List<FirebaseArtifactRef> artifactRefs;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;

  void validate() {
    FirebaseContractValidators.requireCoordinateSpace(
      coordinateSpace,
      FirebaseCoordinateSpace.meters,
      'floor_plans',
    );
    roomDimensions.validate();
    if (floorPolygon.length < 3) {
      throw const FirebaseContractException(
        'floor_plans must include at least three floor polygon points.',
      );
    }
    for (final artifactRef in artifactRefs) {
      artifactRef.validate(
        ownerUid: ownerUid,
        projectId: projectId,
        jobId: jobId,
      );
    }
  }
}

class FirebaseCaptureSession {
  const FirebaseCaptureSession({
    required this.captureSessionId,
    required this.projectId,
    required this.ownerUid,
    required this.roomDimensionsId,
    required this.captureMethod,
    required this.depthEnabled,
    required this.createdAt,
    required this.updatedAt,
    required this.schemaVersion,
    this.startedAt,
    this.completedAt,
    this.notes,
  });

  final String captureSessionId;
  final String projectId;
  final String ownerUid;
  final String roomDimensionsId;
  final FirebaseCaptureMethod captureMethod;
  final bool depthEnabled;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;
}

class FirebaseCaptureImage {
  const FirebaseCaptureImage({
    required this.captureImageId,
    required this.captureSessionId,
    required this.projectId,
    required this.ownerUid,
    required this.sourceImageId,
    required this.role,
    required this.storagePath,
    required this.contentType,
    required this.widthPx,
    required this.heightPx,
    required this.createdAt,
    required this.updatedAt,
    required this.schemaVersion,
    this.captureOrder,
    this.depthArtifactRefs = const [],
    this.cameraPose,
    this.guidanceState,
  });

  final String captureImageId;
  final String captureSessionId;
  final String projectId;
  final String ownerUid;
  final String sourceImageId;
  final FirebaseCaptureImageRole role;
  final String storagePath;
  final FirebaseImageContentType contentType;
  final int widthPx;
  final int heightPx;
  final int? captureOrder;
  final List<FirebaseArtifactRef> depthArtifactRefs;
  final FirebaseJson? cameraPose;
  final String? guidanceState;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;

  void validate() {
    if (widthPx <= 0 || heightPx <= 0) {
      throw const FirebaseContractException(
        'capture_images width_px and height_px must be positive.',
      );
    }
    for (final artifactRef in depthArtifactRefs) {
      artifactRef.validate(
        ownerUid: ownerUid,
        projectId: projectId,
        jobId: captureSessionId,
      );
    }
  }
}

class FirebaseCandidateSceneObject {
  const FirebaseCandidateSceneObject({
    required this.candidateId,
    required this.objectType,
    required this.category,
    required this.sourceImageId,
    required this.captureImageId,
    required this.sourceImageRole,
    required this.coordinateSpace,
    required this.boundingBox,
    required this.confidenceScore,
    required this.reviewState,
    this.label,
    this.suggestedAssetId,
    this.suggestedPositionM,
    this.suggestedSizeM,
    this.suggestedRotationDeg,
    this.maskArtifactRef,
    this.notes,
  });

  final String candidateId;
  final FirebaseSceneObjectType objectType;
  final String category;
  final String? label;
  final String sourceImageId;
  final String captureImageId;
  final FirebaseCaptureImageRole sourceImageRole;
  final FirebaseCoordinateSpace coordinateSpace;
  final FirebaseBoundingBox boundingBox;
  final double confidenceScore;
  final FirebaseCandidateReviewState reviewState;
  final String? suggestedAssetId;
  final FirebasePoint3d? suggestedPositionM;
  final FirebasePoint3d? suggestedSizeM;
  final double? suggestedRotationDeg;
  final FirebaseArtifactRef? maskArtifactRef;
  final String? notes;

  void validate() {
    FirebaseContractValidators.requireCoordinateSpace(
      coordinateSpace,
      FirebaseCoordinateSpace.imagePixels,
      'candidate_scene_objects',
    );
    boundingBox.validate();
    if (confidenceScore < 0 || confidenceScore > 1) {
      throw const FirebaseContractException(
        'candidate_scene_objects confidence_score must be between 0 and 1.',
      );
    }
  }
}

class FirebasePlacedSceneObject {
  const FirebasePlacedSceneObject({
    required this.objectId,
    required this.objectType,
    required this.category,
    required this.positionM,
    required this.sizeM,
    required this.rotationDeg,
    this.candidateId,
    this.assetId,
    this.label,
    this.confidenceScore,
    this.locked,
  });

  final String objectId;
  final String? candidateId;
  final FirebaseSceneObjectType objectType;
  final String category;
  final String? assetId;
  final String? label;
  final FirebasePoint3d positionM;
  final FirebasePoint3d sizeM;
  final double rotationDeg;
  final double? confidenceScore;
  final bool? locked;

  void validate() {
    if (sizeM.x <= 0 || sizeM.y <= 0 || sizeM.z <= 0) {
      throw const FirebaseContractException(
        'placed_scene_objects size_m values must be positive.',
      );
    }
    if (confidenceScore != null &&
        (confidenceScore! < 0 || confidenceScore! > 1)) {
      throw const FirebaseContractException(
        'placed_scene_objects confidence_score must be between 0 and 1.',
      );
    }
  }
}

class FirebaseConfirmedSceneObject {
  const FirebaseConfirmedSceneObject({
    required this.objectId,
    required this.objectType,
    required this.category,
    required this.positionM,
    required this.sizeM,
    required this.rotationDeg,
    required this.confirmedByUid,
    required this.confirmedAt,
    this.candidateId,
    this.assetId,
    this.label,
    this.locked,
  });

  final String objectId;
  final String? candidateId;
  final FirebaseSceneObjectType objectType;
  final String category;
  final String? assetId;
  final String? label;
  final FirebasePoint3d positionM;
  final FirebasePoint3d sizeM;
  final double rotationDeg;
  final String confirmedByUid;
  final DateTime confirmedAt;
  final bool? locked;

  void validate() {
    if (sizeM.x <= 0 || sizeM.y <= 0 || sizeM.z <= 0) {
      throw const FirebaseContractException(
        'confirmed_scene_objects size_m values must be positive.',
      );
    }
  }
}

class FirebaseStructuralFixture {
  const FirebaseStructuralFixture({
    required this.fixtureId,
    required this.category,
    required this.wallId,
    required this.positionM,
    required this.sizeM,
    required this.rotationDeg,
    this.candidateId,
    this.label,
    this.confidenceScore,
    this.locked,
  });

  final String fixtureId;
  final String? candidateId;
  final FirebaseStructuralFixtureCategory category;
  final String wallId;
  final String? label;
  final FirebasePoint3d positionM;
  final FirebasePoint3d sizeM;
  final double rotationDeg;
  final double? confidenceScore;
  final bool? locked;

  void validate() {
    if (sizeM.x <= 0 || sizeM.y <= 0 || sizeM.z <= 0) {
      throw const FirebaseContractException(
        'structural_fixtures size_m values must be positive.',
      );
    }
    if (confidenceScore != null &&
        (confidenceScore! < 0 || confidenceScore! > 1)) {
      throw const FirebaseContractException(
        'structural_fixtures confidence_score must be between 0 and 1.',
      );
    }
  }
}

class FirebaseSceneUnderstandingResult {
  const FirebaseSceneUnderstandingResult({
    required this.resultId,
    required this.projectId,
    required this.ownerUid,
    required this.captureSessionId,
    required this.providerType,
    required this.algorithmId,
    required this.qualityStatus,
    required this.createdAt,
    required this.updatedAt,
    required this.schemaVersion,
    this.jobId,
    this.modelId,
    this.confidenceScore,
    this.failureReasonCode,
    this.failureReason,
    this.coverage = const {},
    this.candidateObjects = const [],
    this.placedObjects = const [],
    this.confirmedObjects = const [],
    this.structuralFixtures = const [],
    this.artifactRefs = const [],
    this.processingStartedAt,
    this.processingCompletedAt,
  });

  final String resultId;
  final String projectId;
  final String ownerUid;
  final String captureSessionId;
  final String? jobId;
  final FirebaseSceneUnderstandingProviderType providerType;
  final String algorithmId;
  final String? modelId;
  final double? confidenceScore;
  final FirebaseQualityStatus qualityStatus;
  final FirebaseSceneUnderstandingFailureReason? failureReasonCode;
  final String? failureReason;
  final FirebaseJson coverage;
  final List<FirebaseCandidateSceneObject> candidateObjects;
  final List<FirebasePlacedSceneObject> placedObjects;
  final List<FirebaseConfirmedSceneObject> confirmedObjects;
  final List<FirebaseStructuralFixture> structuralFixtures;
  final List<FirebaseArtifactRef> artifactRefs;
  final DateTime? processingStartedAt;
  final DateTime? processingCompletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;

  void validate() {
    if (confidenceScore != null &&
        (confidenceScore! < 0 || confidenceScore! > 1)) {
      throw const FirebaseContractException(
        'scene_understanding_results confidence_score must be between 0 and 1.',
      );
    }
    if (qualityStatus == FirebaseQualityStatus.failed &&
        failureReasonCode == null) {
      throw const FirebaseContractException(
        'scene_understanding_results must include failure_reason_code when quality_status is failed.',
      );
    }
    for (final candidate in candidateObjects) {
      candidate.validate();
    }
    for (final object in placedObjects) {
      object.validate();
    }
    for (final object in confirmedObjects) {
      object.validate();
    }
    for (final fixture in structuralFixtures) {
      fixture.validate();
    }
    for (final artifactRef in artifactRefs) {
      artifactRef.validate(
        ownerUid: ownerUid,
        projectId: projectId,
        jobId: captureSessionId,
      );
    }
  }
}

class FirebaseFurnitureObject {
  const FirebaseFurnitureObject({
    required this.furnitureId,
    required this.category,
    required this.positionM,
    required this.sizeM,
    required this.rotationDeg,
    this.color,
    this.label,
    this.locked,
  });

  final String furnitureId;
  final FirebaseFurnitureCategory category;
  final FirebasePoint3d positionM;
  final FirebasePoint3d sizeM;
  final double rotationDeg;
  final String? color;
  final String? label;
  final bool? locked;
}

class FirebaseSavedLayout {
  const FirebaseSavedLayout({
    required this.layoutId,
    required this.projectId,
    required this.ownerUid,
    required this.sourceImageId,
    required this.reconstructionJobId,
    required this.reconstructionStatus,
    required this.reviewRequired,
    required this.floorPlanId,
    required this.coordinateSpace,
    required this.roomDimensions,
    required this.sourceMetadata,
    required this.floorPlan,
    required this.editorScene,
    required this.furnitureObjects,
    required this.savedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.schemaVersion,
    required this.exportVersion,
    this.name,
    this.baseFloorPlanUpdatedAt,
  });

  final String layoutId;
  final String projectId;
  final String ownerUid;
  final String? name;
  final String sourceImageId;
  final String reconstructionJobId;
  final FirebaseJobStatus reconstructionStatus;
  final bool reviewRequired;
  final String floorPlanId;
  final FirebaseCoordinateSpace coordinateSpace;
  final FirebaseRoomDimensions roomDimensions;
  final FirebaseJson sourceMetadata;
  final FirebaseFloorPlan floorPlan;
  final FirebaseJson editorScene;
  final List<FirebaseFurnitureObject> furnitureObjects;
  final DateTime? baseFloorPlanUpdatedAt;
  final DateTime savedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;
  final int exportVersion;

  void validate() {
    FirebaseContractValidators.requireCoordinateSpace(
      coordinateSpace,
      FirebaseCoordinateSpace.meters,
      'layouts',
    );
    if (reconstructionStatus == FirebaseJobStatus.reviewRequired &&
        !reviewRequired) {
      throw const FirebaseContractException(
        'layouts must set reviewRequired when reconstructionStatus is review_required.',
      );
    }
    roomDimensions.validate();
    floorPlan.validate();
  }
}

class FirebaseAdminAction {
  const FirebaseAdminAction({
    required this.actionId,
    required this.projectId,
    required this.ownerUid,
    required this.createdByUid,
    required this.createdByRole,
    required this.actionType,
    required this.targetType,
    required this.targetId,
    required this.createdAt,
    required this.schemaVersion,
    this.reasonCode,
    this.reasonMessage,
    this.permissionOutcome,
    this.retryJobId,
    this.metadata = const {},
  });

  final String actionId;
  final String projectId;
  final String ownerUid;
  final String createdByUid;
  final FirebaseAdminRole createdByRole;
  final String actionType;
  final String targetType;
  final String targetId;
  final String? reasonCode;
  final String? reasonMessage;
  final String? permissionOutcome;
  final String? retryJobId;
  final FirebaseJson metadata;
  final DateTime createdAt;
  final int schemaVersion;
}
