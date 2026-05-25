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

enum FirebaseFurnitureCategory {
  bed('bed'),
  desk('desk'),
  chair('chair'),
  wardrobe('wardrobe'),
  sofa('sofa'),
  table('table'),
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
