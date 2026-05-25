import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';

import '../auth/auth_repository.dart';
import '../firebase/firebase_models.dart';
import '../firebase/firebase_repositories.dart';
import '../firebase/firebase_serializers.dart';
import 'firebase_source_image_upload.dart';
import 'project_api.dart';

class FirebaseProjectApi extends ProjectApi {
  FirebaseProjectApi({
    required super.authRepository,
    required AuthSession session,
    required FirebaseFloorPlanRepository floorPlanRepository,
    required FirebaseGeometryRepository geometryRepository,
    required FirebaseLayoutRepository layoutRepository,
    required FirebaseProjectRepository projectRepository,
    required FirebaseReconstructionRepository reconstructionRepository,
    required FirebaseRoomDimensionsRepository roomDimensionsRepository,
    required FirebaseSourceImageRepository sourceImageRepository,
    required FirebaseSourceImageUploader sourceImageUploader,
  }) : _session = session,
       _floorPlanRepository = floorPlanRepository,
       _geometryRepository = geometryRepository,
       _layoutRepository = layoutRepository,
       _projectRepository = projectRepository,
       _reconstructionRepository = reconstructionRepository,
       _roomDimensionsRepository = roomDimensionsRepository,
       _sourceImageRepository = sourceImageRepository,
       _sourceImageUploader = sourceImageUploader;

  final AuthSession _session;
  final FirebaseFloorPlanRepository _floorPlanRepository;
  final FirebaseGeometryRepository _geometryRepository;
  final FirebaseLayoutRepository _layoutRepository;
  final FirebaseProjectRepository _projectRepository;
  final FirebaseReconstructionRepository _reconstructionRepository;
  final FirebaseRoomDimensionsRepository _roomDimensionsRepository;
  final FirebaseSourceImageRepository _sourceImageRepository;
  final FirebaseSourceImageUploader _sourceImageUploader;

  @override
  Future<List<RoomProject>> listProjects() async {
    final snapshot = await _projectRepository
        .watchOwnedProjects(_session.uid)
        .first;
    return snapshot.map(_roomProjectFromFirebase).toList();
  }

  @override
  Future<RoomProject> createProject({
    required String name,
    String? description,
  }) async {
    final project = await _projectRepository.createProject(
      ownerUid: _session.uid,
      name: name,
      description: description,
    );
    return _roomProjectFromFirebase(project);
  }

  @override
  Future<RoomProject> getProject(String projectId) async {
    final project = await _projectRepository.getProject(
      ownerUid: _session.uid,
      projectId: projectId,
    );
    return _roomProjectFromFirebase(project);
  }

  @override
  Future<RoomProject> updateProject({
    required String projectId,
    required String name,
    String? description,
  }) async {
    final current = await _projectRepository.getProject(
      ownerUid: _session.uid,
      projectId: projectId,
    );
    final updated = await _projectRepository.updateProject(
      FirebaseRoomProject(
        projectId: current.projectId,
        ownerUid: current.ownerUid,
        name: name,
        description: description,
        schemaVersion: current.schemaVersion,
        createdAt: current.createdAt,
        updatedAt: DateTime.now().toUtc(),
        deletedAt: current.deletedAt,
        latestSourceImageId: current.latestSourceImageId,
        latestJobId: current.latestJobId,
        latestFloorPlanId: current.latestFloorPlanId,
        latestLayoutId: current.latestLayoutId,
        currentReconstructionStatus: current.currentReconstructionStatus,
        lastOpenedAt: current.lastOpenedAt,
      ),
    );
    return _roomProjectFromFirebase(updated);
  }

  @override
  Future<void> deleteProject(String projectId) {
    return _projectRepository.softDeleteProject(
      ownerUid: _session.uid,
      projectId: projectId,
    );
  }

  @override
  Future<RoomDimensions> saveRoomDimensions({
    required String projectId,
    required double widthValue,
    required double depthValue,
    double? heightValue,
  }) async {
    final now = DateTime.now().toUtc();
    final existing = await _roomDimensionsRepository.getCurrent(
      ownerUid: _session.uid,
      projectId: projectId,
    );
    final dimensions = await _roomDimensionsRepository.saveCurrent(
      FirebaseRoomDimensions(
        projectId: projectId,
        ownerUid: _session.uid,
        widthM: widthValue,
        depthM: depthValue,
        heightM: heightValue ?? 2.4,
        unit: 'meters',
        source: heightValue == null ? 'default_height' : 'user_entered',
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
        schemaVersion: existing?.schemaVersion ?? 1,
      ),
    );
    return _roomDimensionsFromFirebase(dimensions);
  }

  @override
  Future<RoomDimensions?> getRoomDimensions({required String projectId}) async {
    final dimensions = await _roomDimensionsRepository.getCurrent(
      ownerUid: _session.uid,
      projectId: projectId,
    );
    return dimensions == null ? null : _roomDimensionsFromFirebase(dimensions);
  }

  @override
  Future<SourceImage> uploadSourceImage({
    required String projectId,
    required String filename,
    required String contentType,
    required Uint8List bytes,
    int? widthPx,
    int? heightPx,
    void Function(double progress)? onProgress,
  }) async {
    if (!FirebaseSourceImageUpload.isAllowedContentType(contentType)) {
      throw const ProjectApiException(
        'Unsupported image type. Use JPEG, PNG, or WebP.',
        code: 'invalid_content_type',
      );
    }
    if (bytes.length > FirebaseSourceImageUpload.maxBytes) {
      throw const ProjectApiException(
        'Room photo must be 10 MB or smaller.',
        code: 'file_too_large',
      );
    }
    if (widthPx == null || widthPx <= 0 || heightPx == null || heightPx <= 0) {
      throw const ProjectApiException(
        'Image dimensions are required before source image metadata can be saved.',
        code: 'missing_image_dimensions',
      );
    }

    late final FirebaseRoomProject project;
    try {
      project = await _projectRepository.getProject(
        ownerUid: _session.uid,
        projectId: projectId,
      );
    } on FirebaseException catch (error) {
      throw _projectAccessException(error);
    } on FirebaseContractException {
      throw const ProjectApiException(
        'Project access is no longer available. Reopen the project or choose another one.',
        code: 'permission_denied',
      );
    }
    final sourceImageId = _sourceImageRepository.newSourceImageId(
      projectId: project.projectId,
    );
    final storedFilename = FirebaseSourceImageUpload.sanitizeFilename(filename);
    final storagePath = FirebaseSourceImageUpload.storagePath(
      ownerUid: _session.uid,
      projectId: project.projectId,
      sourceImageId: sourceImageId,
      storedFilename: storedFilename,
    );
    final sha256Hex = FirebaseSourceImageUpload.sha256Hex(bytes);

    try {
      onProgress?.call(0);
      await _sourceImageUploader.uploadBytes(
        storagePath: storagePath,
        bytes: bytes,
        contentType: contentType,
        metadata: {
          'owner_uid': _session.uid,
          'project_id': project.projectId,
          'source_image_id': sourceImageId,
          'sha256_hex': sha256Hex,
          'uploaded_by_uid': _session.uid,
        },
        onProgress: onProgress,
      );
    } on FirebaseException catch (error) {
      throw _uploadException(error);
    } catch (error) {
      throw ProjectApiException(
        'Source image upload failed: $error',
        code: 'upload_failed',
      );
    }

    final now = DateTime.now().toUtc();
    final sourceImage = FirebaseSourceImage(
      sourceImageId: sourceImageId,
      projectId: project.projectId,
      ownerUid: _session.uid,
      storagePath: storagePath,
      originalFilename: filename,
      storedFilename: storedFilename,
      contentType: FirebaseImageContentType.fromWireValue(contentType),
      byteSize: bytes.length,
      sha256Hex: sha256Hex,
      widthPx: widthPx,
      heightPx: heightPx,
      captureSource: 'file_upload',
      retentionStatus: FirebaseRetentionStatus.active,
      uploadedAt: now,
      createdAt: now,
      updatedAt: now,
      schemaVersion: 1,
    );

    try {
      final metadata = await _sourceImageRepository.createMetadataAfterUpload(
        sourceImage,
      );
      return _sourceImageFromFirebase(metadata);
    } catch (error) {
      throw ProjectApiException(
        'Upload succeeded, but source image metadata could not be saved. Retry the upload or remove the uploaded file.',
        code: 'metadata_save_failed',
      );
    }
  }

  @override
  Future<ReconstructionJob> createReconstructionJob({
    required String projectId,
    required String sourceImageId,
  }) async {
    final project = await _projectRepository.getProject(
      ownerUid: _session.uid,
      projectId: projectId,
    );
    final now = DateTime.now().toUtc();
    final jobId = _reconstructionRepository.newJobId(
      projectId: project.projectId,
    );
    final transitionId = _reconstructionRepository.newTransitionId(
      projectId: project.projectId,
      jobId: jobId,
    );
    final job = FirebaseReconstructionJob(
      jobId: jobId,
      projectId: project.projectId,
      ownerUid: _session.uid,
      sourceImageId: sourceImageId,
      roomDimensionsId: 'current',
      status: FirebaseJobStatus.created,
      statusUpdatedAt: now,
      providerType: 'manual_assisted_opencv',
      algorithmId: 'opencv_lines_corners_v1',
      createdByUid: _session.uid,
      rootJobId: jobId,
      retryCount: 0,
      latestTransitionId: transitionId,
      createdAt: now,
      updatedAt: now,
      schemaVersion: 1,
    );
    final transition = FirebaseJobStatusTransition(
      transitionId: transitionId,
      projectId: project.projectId,
      ownerUid: _session.uid,
      jobId: jobId,
      toStatus: FirebaseJobStatus.created,
      occurredAt: now,
      actorType: FirebaseActorType.user,
      actorUid: _session.uid,
      reasonCode: 'user_submitted',
      reasonMessage: 'Reconstruction job created from source image.',
      schemaVersion: 1,
    );
    final created = await _reconstructionRepository.createJobWithTransition(
      job: job,
      transition: transition,
      project: _projectWithReconstructionState(
        project,
        latestJobId: job.jobId,
        status: job.status,
        updatedAt: now,
      ),
    );
    return _reconstructionJobFromFirebase(created);
  }

  @override
  Future<ReconstructionJob> getReconstructionJob({
    required String projectId,
    required String jobId,
  }) async {
    final job = await _reconstructionRepository.getJob(
      ownerUid: _session.uid,
      projectId: projectId,
      jobId: jobId,
    );
    if (job == null) {
      throw const ProjectApiException(
        'Reconstruction job was not found.',
        code: 'not_found',
      );
    }
    return _reconstructionJobFromFirebase(job);
  }

  @override
  Future<ReconstructionJob> updateReconstructionJobStatus({
    required String projectId,
    required String jobId,
    required String status,
    required String reasonCode,
    required String reasonMessage,
    String? failureReasonCode,
    String? failureReasonMessage,
  }) async {
    final nextStatus = _jobStatusFromWireValue(status);
    if (nextStatus == FirebaseJobStatus.retrying) {
      throw const ProjectApiException(
        'Use retryReconstructionJob to create a linked retry job.',
        code: 'invalid_status_transition',
      );
    }
    final project = await _projectRepository.getProject(
      ownerUid: _session.uid,
      projectId: projectId,
    );
    final current = await _reconstructionRepository.getJob(
      ownerUid: _session.uid,
      projectId: project.projectId,
      jobId: jobId,
    );
    if (current == null) {
      throw const ProjectApiException(
        'Reconstruction job was not found.',
        code: 'not_found',
      );
    }

    final now = DateTime.now().toUtc();
    final transitionId = _reconstructionRepository.newTransitionId(
      projectId: project.projectId,
      jobId: current.jobId,
    );
    final updatedJob = _copyReconstructionJob(
      current,
      status: nextStatus,
      statusUpdatedAt: now,
      latestTransitionId: transitionId,
      failureReasonCode: failureReasonCode,
      failureReason: failureReasonMessage,
      updatedAt: now,
    );
    final transition = FirebaseJobStatusTransition(
      transitionId: transitionId,
      projectId: project.projectId,
      ownerUid: _session.uid,
      jobId: current.jobId,
      fromStatus: current.status,
      toStatus: nextStatus,
      occurredAt: now,
      actorType: FirebaseActorType.user,
      actorUid: _session.uid,
      reasonCode: reasonCode,
      reasonMessage: reasonMessage,
      schemaVersion: 1,
    );
    final updated = await _reconstructionRepository.updateJobWithTransition(
      job: updatedJob,
      transition: transition,
      project: _projectWithReconstructionState(
        project,
        latestJobId: updatedJob.jobId,
        status: updatedJob.status,
        updatedAt: now,
      ),
    );
    return _reconstructionJobFromFirebase(updated);
  }

  @override
  Future<ReconstructionJob> retryReconstructionJob({
    required String projectId,
    required String jobId,
  }) async {
    final project = await _projectRepository.getProject(
      ownerUid: _session.uid,
      projectId: projectId,
    );
    final current = await _reconstructionRepository.getJob(
      ownerUid: _session.uid,
      projectId: project.projectId,
      jobId: jobId,
    );
    if (current == null) {
      throw const ProjectApiException(
        'Reconstruction job was not found.',
        code: 'not_found',
      );
    }

    final now = DateTime.now().toUtc();
    final retryJobId = _reconstructionRepository.newJobId(
      projectId: project.projectId,
    );
    final currentTransitionId = _reconstructionRepository.newTransitionId(
      projectId: project.projectId,
      jobId: current.jobId,
    );
    final retryTransitionId = _reconstructionRepository.newTransitionId(
      projectId: project.projectId,
      jobId: retryJobId,
    );
    final retryJob = FirebaseReconstructionJob(
      jobId: retryJobId,
      projectId: project.projectId,
      ownerUid: _session.uid,
      sourceImageId: current.sourceImageId,
      roomDimensionsId: current.roomDimensionsId,
      status: FirebaseJobStatus.created,
      statusUpdatedAt: now,
      providerType: current.providerType,
      providerId: current.providerId,
      algorithmId: current.algorithmId,
      openCvVersion: current.openCvVersion,
      createdByUid: _session.uid,
      retryOfJobId: current.jobId,
      rootJobId: current.rootJobId ?? current.jobId,
      retryCount: current.retryCount + 1,
      latestTransitionId: retryTransitionId,
      createdAt: now,
      updatedAt: now,
      schemaVersion: 1,
    );
    final updatedCurrent = _copyReconstructionJob(
      current,
      status: FirebaseJobStatus.retrying,
      statusUpdatedAt: now,
      latestTransitionId: currentTransitionId,
      updatedAt: now,
    );

    final currentTransition = FirebaseJobStatusTransition(
      transitionId: currentTransitionId,
      projectId: project.projectId,
      ownerUid: _session.uid,
      jobId: current.jobId,
      fromStatus: current.status,
      toStatus: FirebaseJobStatus.retrying,
      occurredAt: now,
      actorType: FirebaseActorType.user,
      actorUid: _session.uid,
      reasonCode: 'user_retry',
      reasonMessage: 'User requested a reconstruction retry.',
      retryJobId: retryJobId,
      schemaVersion: 1,
    );
    final retryTransition = FirebaseJobStatusTransition(
      transitionId: retryTransitionId,
      projectId: project.projectId,
      ownerUid: _session.uid,
      jobId: retryJobId,
      toStatus: FirebaseJobStatus.created,
      occurredAt: now,
      actorType: FirebaseActorType.user,
      actorUid: _session.uid,
      reasonCode: 'retry_created',
      reasonMessage: 'Retry reconstruction job created.',
      schemaVersion: 1,
    );
    final createdRetry = await _reconstructionRepository
        .retryJobWithTransitions(
          currentJob: updatedCurrent,
          currentTransition: currentTransition,
          retryJob: retryJob,
          retryTransition: retryTransition,
          project: _projectWithReconstructionState(
            project,
            latestJobId: retryJob.jobId,
            status: retryJob.status,
            updatedAt: now,
          ),
        );
    return _reconstructionJobFromFirebase(createdRetry);
  }

  Future<FirebaseOpenCvResult> saveOpenCvResult(
    FirebaseOpenCvResult result,
  ) async {
    await _requireOwnedGeometryProject(
      projectId: result.projectId,
      ownerUid: result.ownerUid,
    );
    return _geometryRepository.saveOpenCvResult(result);
  }

  Future<FirebaseConfirmedGeometry> saveConfirmedGeometry(
    FirebaseConfirmedGeometry geometry,
  ) async {
    await _requireOwnedGeometryProject(
      projectId: geometry.projectId,
      ownerUid: geometry.ownerUid,
    );
    return _geometryRepository.saveConfirmedGeometry(geometry);
  }

  Future<FirebaseOpenCvResult?> getOpenCvResult({
    required String projectId,
    required String resultId,
  }) {
    return _geometryRepository.getOpenCvResult(
      ownerUid: _session.uid,
      projectId: projectId,
      resultId: resultId,
    );
  }

  Future<FirebaseConfirmedGeometry?> getConfirmedGeometry({
    required String projectId,
    required String geometryId,
  }) {
    return _geometryRepository.getConfirmedGeometry(
      ownerUid: _session.uid,
      projectId: projectId,
      geometryId: geometryId,
    );
  }

  Future<FirebaseFloorPlan> saveFloorPlan(FirebaseFloorPlan floorPlan) async {
    await _requireOwnedFirebaseProject(
      projectId: floorPlan.projectId,
      ownerUid: floorPlan.ownerUid,
    );
    return _floorPlanRepository.saveFloorPlan(floorPlan);
  }

  Future<FirebaseFloorPlan?> getFloorPlan({
    required String projectId,
    required String floorPlanId,
  }) {
    return _floorPlanRepository.getFloorPlan(
      ownerUid: _session.uid,
      projectId: projectId,
      floorPlanId: floorPlanId,
    );
  }

  @override
  Future<SavedLayout> saveLayout({
    required String projectId,
    required Map<String, Object?> roomDimensions,
    required Map<String, Object?> floorPlan,
    required Map<String, Object?> sourceMetadata,
    required List<Map<String, Object?>> furnitureObjects,
    required Map<String, Object?> editorScene,
  }) async {
    final now = DateTime.now().toUtc();
    final project = await _projectRepository.getProject(
      ownerUid: _session.uid,
      projectId: projectId,
    );
    final sourceImageId =
        _stringValue(sourceMetadata['source_image_id']) ??
        project.latestSourceImageId;
    final reconstructionJobId =
        _stringValue(sourceMetadata['reconstruction_job_id']) ??
        project.latestJobId;
    final floorPlanId =
        _stringValue(floorPlan['floor_plan_id']) ?? project.latestFloorPlanId;
    if (sourceImageId == null ||
        reconstructionJobId == null ||
        floorPlanId == null) {
      throw const ProjectApiException(
        'Layout requires source image, reconstruction job, and floor plan references before it can be saved.',
        code: 'missing_layout_reference',
      );
    }

    final job = await _reconstructionRepository.getJob(
      ownerUid: _session.uid,
      projectId: projectId,
      jobId: reconstructionJobId,
    );
    final sourceImage = await _sourceImageRepository.getSourceImage(
      ownerUid: _session.uid,
      projectId: projectId,
      sourceImageId: sourceImageId,
    );
    final metricFloorPlan = await _floorPlanRepository.getFloorPlan(
      ownerUid: _session.uid,
      projectId: projectId,
      floorPlanId: floorPlanId,
    );
    if (job == null || sourceImage == null || metricFloorPlan == null) {
      throw const ProjectApiException(
        'Layout references are not available. Reload the project and try saving again.',
        code: 'missing_layout_reference',
      );
    }
    final requestedRoomDimensions = _firebaseRoomDimensionsFromLayoutPayload(
      projectId: projectId,
      ownerUid: _session.uid,
      roomDimensions: roomDimensions,
      now: now,
    );
    if (!_metricRoomDimensionsMatch(
      requestedRoomDimensions,
      metricFloorPlan.roomDimensions,
    )) {
      throw const ProjectApiException(
        'Layout room dimensions must match the saved floor plan.',
        code: 'invalid_layout_payload',
      );
    }

    final layoutId = 'layout-${now.microsecondsSinceEpoch}';
    final normalizedSourceMetadata = _withoutNulls({
      ...sourceMetadata,
      ...sourceImage.toFirestoreJson(),
      'source_image_id': sourceImageId,
      'reconstruction_job_id': reconstructionJobId,
      'reconstruction_status': job.status.wireValue,
    });
    final layout = FirebaseSavedLayout(
      layoutId: layoutId,
      projectId: projectId,
      ownerUid: _session.uid,
      sourceImageId: sourceImageId,
      reconstructionJobId: reconstructionJobId,
      reconstructionStatus: job.status,
      reviewRequired:
          job.status == FirebaseJobStatus.reviewRequired ||
          metricFloorPlan.qualityStatus == FirebaseQualityStatus.reviewRequired,
      floorPlanId: metricFloorPlan.floorPlanId,
      coordinateSpace: FirebaseCoordinateSpace.meters,
      roomDimensions: metricFloorPlan.roomDimensions,
      sourceMetadata: normalizedSourceMetadata,
      floorPlan: metricFloorPlan,
      editorScene: _withoutNulls(editorScene),
      furnitureObjects: furnitureObjects
          .map(_firebaseFurnitureObjectFromLayoutPayload)
          .toList(),
      baseFloorPlanUpdatedAt: metricFloorPlan.updatedAt,
      savedAt: now,
      createdAt: now,
      updatedAt: now,
      schemaVersion: 1,
      exportVersion: 1,
    );
    final saved = await _layoutRepository.saveLayout(layout);
    return _savedLayoutFromFirebase(saved);
  }

  @override
  Future<SavedLayout> loadLatestLayout({required String projectId}) async {
    final layout = await _layoutRepository.loadLatestLayout(
      ownerUid: _session.uid,
      projectId: projectId,
    );
    if (layout == null) {
      throw const ProjectApiException(
        'No saved layout is available for this project.',
        code: 'not_found',
      );
    }
    return _savedLayoutFromFirebase(layout);
  }

  @override
  Future<Map<String, Object?>> exportLatestLayout({
    required String projectId,
  }) async {
    try {
      final exportPayload = await _layoutRepository.exportLatestLayout(
        ownerUid: _session.uid,
        projectId: projectId,
      );
      return Map<String, Object?>.from(
        _layoutPayloadValue(exportPayload) as Map,
      );
    } on FirebaseException catch (error) {
      throw _projectAccessException(error);
    } on FirebaseContractException {
      throw const ProjectApiException(
        'No saved layout is available for export.',
        code: 'not_found',
      );
    }
  }

  FirebaseRoomDimensions _firebaseRoomDimensionsFromLayoutPayload({
    required String projectId,
    required String ownerUid,
    required Map<String, Object?> roomDimensions,
    required DateTime now,
  }) {
    return FirebaseRoomDimensions(
      projectId: projectId,
      ownerUid: ownerUid,
      widthM: _requiredNumber(roomDimensions['width_value'], 'width_value'),
      depthM: _requiredNumber(roomDimensions['depth_value'], 'depth_value'),
      heightM: _requiredNumber(roomDimensions['height_value'], 'height_value'),
      unit: roomDimensions['unit']?.toString() ?? 'meters',
      source: 'layout_save',
      createdAt: now,
      updatedAt: now,
      schemaVersion: 1,
    );
  }

  bool _metricRoomDimensionsMatch(
    FirebaseRoomDimensions requested,
    FirebaseRoomDimensions canonical,
  ) {
    return requested.projectId == canonical.projectId &&
        requested.ownerUid == canonical.ownerUid &&
        requested.widthM == canonical.widthM &&
        requested.depthM == canonical.depthM &&
        requested.heightM == canonical.heightM &&
        requested.unit == canonical.unit;
  }

  FirebaseFurnitureObject _firebaseFurnitureObjectFromLayoutPayload(
    Map<String, Object?> furniture,
  ) {
    final position = _requiredRecordValue(furniture['position'], 'position');
    final size = _requiredRecordValue(furniture['size'], 'size');
    final category = _requiredStringValue(furniture['category'], 'category');
    return FirebaseFurnitureObject(
      furnitureId: _requiredStringValue(furniture['id'], 'id'),
      category: _furnitureCategoryFromWireValue(category),
      positionM: FirebasePoint3d(
        x: _requiredCoordinateValue(position['x'], 'position.x'),
        y: 0,
        z: _requiredCoordinateValue(position['y'], 'position.y'),
      ),
      sizeM: FirebasePoint3d(
        x: _requiredNumber(size['width_meters'], 'size.width_meters'),
        y: _requiredNumber(size['height_meters'], 'size.height_meters'),
        z: _requiredNumber(size['depth_meters'], 'size.depth_meters'),
      ),
      rotationDeg: _requiredCoordinateValue(
        furniture['rotation_degrees'],
        'rotation_degrees',
      ),
      color: furniture['color']?.toString(),
      label: furniture['label']?.toString(),
      locked: furniture['locked'] is bool ? furniture['locked'] as bool : null,
    );
  }

  SavedLayout _savedLayoutFromFirebase(FirebaseSavedLayout layout) {
    return SavedLayout(
      id: layout.layoutId,
      projectId: layout.projectId,
      userId: layout.ownerUid,
      roomDimensions: _roomDimensionsPayloadFromFirebase(layout.roomDimensions),
      floorPlan: _floorPlanPayloadFromFirebase(layout.floorPlan),
      sourceMetadata: _sourceMetadataPayloadFromFirebase(layout.sourceMetadata),
      furnitureObjects: layout.furnitureObjects
          .map(_furniturePayloadFromFirebase)
          .toList(),
      editorScene: layout.editorScene,
      createdAt: layout.createdAt,
      updatedAt: layout.updatedAt,
      schemaVersion: layout.schemaVersion,
      exportVersion: layout.exportVersion,
    );
  }

  Map<String, Object?> _roomDimensionsPayloadFromFirebase(
    FirebaseRoomDimensions dimensions,
  ) {
    return {
      ...dimensions.toFirestoreJson(
        options: FirebaseSerializationOptions.exportJson,
      ),
      'unit': dimensions.unit,
      'width_value': dimensions.widthM,
      'depth_value': dimensions.depthM,
      'height_value': dimensions.heightM,
    };
  }

  Map<String, Object?> _floorPlanPayloadFromFirebase(
    FirebaseFloorPlan floorPlan,
  ) {
    final points = floorPlan.floorPolygon
        .map((point) => {'x': point.x, 'y': point.y})
        .toList();
    return {
      ...floorPlan.toExportJson(),
      'metric_geometry': {
        'coordinate_space': floorPlan.coordinateSpace.wireValue,
        'points': points,
      },
      'points': points,
    };
  }

  Map<String, Object?> _sourceMetadataPayloadFromFirebase(
    FirebaseJson sourceMetadata,
  ) {
    return Map<String, Object?>.from(
      _layoutPayloadValue(sourceMetadata) as Map,
    );
  }

  Map<String, Object?> _furniturePayloadFromFirebase(
    FirebaseFurnitureObject furniture,
  ) {
    return _withoutNulls({
      'id': furniture.furnitureId,
      'category': furniture.category.wireValue,
      'position': {'x': furniture.positionM.x, 'y': furniture.positionM.z},
      'size': {
        'width_meters': furniture.sizeM.x,
        'depth_meters': furniture.sizeM.z,
        'height_meters': furniture.sizeM.y,
      },
      'rotation_degrees': furniture.rotationDeg,
      'color': furniture.color,
      'label': furniture.label,
      'locked': furniture.locked,
    });
  }

  Object? _layoutPayloadValue(Object? value) {
    if (value is DateTime) {
      return value.toUtc().toIso8601String();
    }
    if (value is Map) {
      return {
        for (final entry in value.entries)
          entry.key.toString(): _layoutPayloadValue(entry.value),
      };
    }
    if (value is Iterable) {
      return value.map(_layoutPayloadValue).toList();
    }
    return value;
  }

  RoomProject _roomProjectFromFirebase(FirebaseRoomProject project) {
    return RoomProject(
      id: project.projectId,
      userId: project.ownerUid,
      name: project.name,
      description: project.description,
      createdAt: project.createdAt,
      updatedAt: project.updatedAt,
    );
  }

  RoomDimensions _roomDimensionsFromFirebase(
    FirebaseRoomDimensions dimensions,
  ) {
    return RoomDimensions(
      projectId: dimensions.projectId,
      userId: dimensions.ownerUid,
      widthValue: dimensions.widthM,
      depthValue: dimensions.depthM,
      heightValue: dimensions.heightM,
      unit: dimensions.unit,
      heightSource: dimensions.source == 'default_height' ? 'default' : 'user',
      createdAt: dimensions.createdAt,
      updatedAt: dimensions.updatedAt,
    );
  }

  SourceImage _sourceImageFromFirebase(FirebaseSourceImage sourceImage) {
    return SourceImage(
      id: sourceImage.sourceImageId,
      projectId: sourceImage.projectId,
      userId: sourceImage.ownerUid,
      originalFilename:
          sourceImage.originalFilename ?? sourceImage.storedFilename,
      storedName: sourceImage.storedFilename,
      contentType: sourceImage.contentType.wireValue,
      byteSize: sourceImage.byteSize,
      widthPx: sourceImage.widthPx,
      heightPx: sourceImage.heightPx,
      sha256Hex: sourceImage.sha256Hex,
      retentionStatus: sourceImage.retentionStatus.wireValue,
      uploadedAt: sourceImage.uploadedAt,
    );
  }

  ReconstructionJob _reconstructionJobFromFirebase(
    FirebaseReconstructionJob job,
  ) {
    return ReconstructionJob(
      id: job.jobId,
      projectId: job.projectId,
      userId: job.ownerUid,
      sourceImageId: job.sourceImageId,
      status: job.status.wireValue,
      statusLabel: job.status.displayLabel,
      terminal: job.status.isTerminal,
      provider: job.providerType,
      retryOfJobId: job.retryOfJobId,
      failureReasonCode: job.failureReasonCode,
      failureReasonMessage: job.failureReason,
      createdAt: job.createdAt,
      updatedAt: job.updatedAt,
    );
  }

  FirebaseRoomProject _projectWithReconstructionState(
    FirebaseRoomProject project, {
    required String latestJobId,
    required FirebaseJobStatus status,
    required DateTime updatedAt,
  }) {
    return FirebaseRoomProject(
      projectId: project.projectId,
      ownerUid: project.ownerUid,
      name: project.name,
      description: project.description,
      schemaVersion: project.schemaVersion,
      createdAt: project.createdAt,
      updatedAt: updatedAt,
      deletedAt: project.deletedAt,
      latestSourceImageId: project.latestSourceImageId,
      latestJobId: latestJobId,
      latestFloorPlanId: project.latestFloorPlanId,
      latestLayoutId: project.latestLayoutId,
      currentReconstructionStatus: status,
      lastOpenedAt: project.lastOpenedAt,
    );
  }

  FirebaseReconstructionJob _copyReconstructionJob(
    FirebaseReconstructionJob job, {
    required FirebaseJobStatus status,
    required DateTime statusUpdatedAt,
    required String latestTransitionId,
    String? failureReasonCode,
    String? failureReason,
    required DateTime updatedAt,
  }) {
    return FirebaseReconstructionJob(
      jobId: job.jobId,
      projectId: job.projectId,
      ownerUid: job.ownerUid,
      sourceImageId: job.sourceImageId,
      roomDimensionsId: job.roomDimensionsId,
      status: status,
      statusUpdatedAt: statusUpdatedAt,
      providerType: job.providerType,
      providerId: job.providerId,
      algorithmId: job.algorithmId,
      openCvVersion: job.openCvVersion,
      createdByUid: job.createdByUid,
      retryOfJobId: job.retryOfJobId,
      rootJobId: job.rootJobId,
      retryCount: job.retryCount,
      latestTransitionId: latestTransitionId,
      latestResultId: job.latestResultId,
      latestConfirmedGeometryId: job.latestConfirmedGeometryId,
      latestFloorPlanId: job.latestFloorPlanId,
      failureReasonCode: failureReasonCode ?? job.failureReasonCode,
      failureReason: failureReason ?? job.failureReason,
      qualityStatus: job.qualityStatus,
      artifactRefs: job.artifactRefs,
      startedAt: job.startedAt,
      completedAt: job.completedAt,
      timeoutAt: job.timeoutAt,
      createdAt: job.createdAt,
      updatedAt: updatedAt,
      schemaVersion: job.schemaVersion,
    );
  }

  Future<void> _requireOwnedGeometryProject({
    required String projectId,
    required String ownerUid,
  }) {
    return _requireOwnedFirebaseProject(
      projectId: projectId,
      ownerUid: ownerUid,
    );
  }

  Future<void> _requireOwnedFirebaseProject({
    required String projectId,
    required String ownerUid,
  }) async {
    if (ownerUid != _session.uid) {
      throw const ProjectApiException(
        'Firebase document owner does not match the signed-in user.',
        code: 'permission_denied',
      );
    }
    await _projectRepository.getProject(
      ownerUid: _session.uid,
      projectId: projectId,
    );
  }

  FirebaseJobStatus _jobStatusFromWireValue(String value) {
    try {
      return FirebaseJobStatus.fromWireValue(value);
    } on FirebaseContractException {
      throw const ProjectApiException(
        'Invalid reconstruction job status.',
        code: 'invalid_status',
      );
    }
  }

  FirebaseFurnitureCategory _furnitureCategoryFromWireValue(String value) {
    try {
      return FirebaseFurnitureCategory.fromWireValue(value);
    } on FirebaseContractException {
      return FirebaseFurnitureCategory.custom;
    }
  }

  Map<String, Object?> _requiredRecordValue(Object? value, String field) {
    if (value is Map) {
      return Map<String, Object?>.from(value);
    }
    throw ProjectApiException(
      'Layout field $field must be an object.',
      code: 'invalid_layout_payload',
    );
  }

  String _requiredStringValue(Object? value, String field) {
    final text = _stringValue(value);
    if (text != null) {
      return text;
    }
    throw ProjectApiException(
      'Layout field $field must be a non-empty string.',
      code: 'invalid_layout_payload',
    );
  }

  String? _stringValue(Object? value) {
    final text = value?.toString();
    return text == null || text.isEmpty ? null : text;
  }

  double _requiredCoordinateValue(Object? value, String field) {
    if (value is num) {
      return value.toDouble();
    }
    throw ProjectApiException(
      'Layout field $field must be a number.',
      code: 'invalid_layout_payload',
    );
  }

  double _requiredNumber(Object? value, String field) {
    if (value is num && value > 0) {
      return value.toDouble();
    }
    throw ProjectApiException(
      'Layout field $field must be a positive number.',
      code: 'invalid_layout_payload',
    );
  }

  Map<String, Object?> _withoutNulls(Map<String, Object?> json) {
    return {
      for (final entry in json.entries)
        if (entry.value != null) entry.key: entry.value,
    };
  }

  ProjectApiException _projectAccessException(FirebaseException error) {
    if (_isPermissionError(error.code)) {
      return const ProjectApiException(
        'Permission blocked project access. Check that you still have access to this project, then retry.',
        code: 'permission_denied',
      );
    }
    return ProjectApiException(
      'Project access failed: ${error.message ?? error.code}',
      code: 'upload_failed',
    );
  }

  ProjectApiException _uploadException(FirebaseException error) {
    if (_isPermissionError(error.code)) {
      return const ProjectApiException(
        'Permission blocked the source image upload. Check that you still have access to this project, then retry.',
        code: 'permission_denied',
      );
    }
    return ProjectApiException(
      'Source image upload failed: ${error.message ?? error.code}',
      code: 'upload_failed',
    );
  }

  bool _isPermissionError(String code) {
    return code == 'permission-denied' || code == 'unauthorized';
  }
}
