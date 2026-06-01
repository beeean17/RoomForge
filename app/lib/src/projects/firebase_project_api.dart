import 'dart:convert';
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
  Future<CaptureSession> createCaptureSession({
    required String projectId,
    bool depthEnabled = false,
    String? notes,
  }) async {
    final project = await _projectRepository.getProject(
      ownerUid: _session.uid,
      projectId: projectId,
    );
    final dimensions = await _roomDimensionsRepository.getCurrent(
      ownerUid: _session.uid,
      projectId: project.projectId,
    );
    if (dimensions == null) {
      throw const ProjectApiException(
        'Room dimensions are required before starting guided capture.',
        code: 'missing_room_dimensions',
      );
    }

    final now = DateTime.now().toUtc();
    final session = FirebaseCaptureSession(
      captureSessionId: _sourceImageRepository.newCaptureSessionId(
        projectId: project.projectId,
      ),
      projectId: project.projectId,
      ownerUid: _session.uid,
      roomDimensionsId: 'current',
      captureMethod: depthEnabled
          ? FirebaseCaptureMethod.androidArcoreDepth
          : FirebaseCaptureMethod.androidGuidedPhoto,
      depthEnabled: depthEnabled,
      startedAt: now,
      notes: notes,
      createdAt: now,
      updatedAt: now,
      schemaVersion: 1,
    );
    final created = await _sourceImageRepository.createCaptureSession(session);
    return _captureSessionFromFirebase(created);
  }

  @override
  Future<CaptureImage> uploadCaptureImage({
    required String projectId,
    required String captureSessionId,
    required String role,
    required String filename,
    required String contentType,
    required Uint8List bytes,
    int? widthPx,
    int? heightPx,
    int? captureOrder,
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
        'Image dimensions are required before capture image metadata can be saved.',
        code: 'missing_image_dimensions',
      );
    }

    late final FirebaseCaptureImageRole roleValue;
    try {
      roleValue = FirebaseCaptureImageRole.fromWireValue(role);
    } on FirebaseContractException {
      throw const ProjectApiException(
        'Unsupported capture image role.',
        code: 'invalid_capture_role',
      );
    }

    final project = await _projectRepository.getProject(
      ownerUid: _session.uid,
      projectId: projectId,
    );
    final sourceImageId = _sourceImageRepository.newSourceImageId(
      projectId: project.projectId,
    );
    final captureImageId = _sourceImageRepository.newCaptureImageId(
      projectId: project.projectId,
      captureSessionId: captureSessionId,
    );
    final storedFilename = FirebaseSourceImageUpload.sanitizeFilename(filename);
    final storagePath = FirebaseSourceImageUpload.captureImageStoragePath(
      ownerUid: _session.uid,
      projectId: project.projectId,
      captureSessionId: captureSessionId,
      captureImageId: captureImageId,
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
          'capture_session_id': captureSessionId,
          'capture_image_id': captureImageId,
          'source_image_id': sourceImageId,
          'role': roleValue.wireValue,
          'sha256_hex': sha256Hex,
          'uploaded_by_uid': _session.uid,
        },
        onProgress: onProgress,
      );
    } on FirebaseException catch (error) {
      throw _uploadException(error);
    } catch (error) {
      throw ProjectApiException(
        'Capture image upload failed: $error',
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
      captureSource: 'guided_capture',
      captureSessionId: captureSessionId,
      captureImageId: captureImageId,
      captureImageRole: roleValue,
      retentionStatus: FirebaseRetentionStatus.active,
      uploadedAt: now,
      createdAt: now,
      updatedAt: now,
      schemaVersion: 1,
    );
    final captureImage = FirebaseCaptureImage(
      captureImageId: captureImageId,
      captureSessionId: captureSessionId,
      projectId: project.projectId,
      ownerUid: _session.uid,
      sourceImageId: sourceImageId,
      role: roleValue,
      storagePath: storagePath,
      contentType: FirebaseImageContentType.fromWireValue(contentType),
      widthPx: widthPx,
      heightPx: heightPx,
      captureOrder: captureOrder ?? _captureOrderForRole(roleValue),
      guidanceState: 'uploaded',
      createdAt: now,
      updatedAt: now,
      schemaVersion: 1,
    );

    try {
      await _sourceImageRepository.createMetadataAfterUpload(sourceImage);
      final savedCaptureImage = await _sourceImageRepository
          .createCaptureImageMetadataAfterUpload(captureImage);
      return _captureImageFromFirebase(savedCaptureImage);
    } catch (error) {
      throw ProjectApiException(
        'Upload succeeded, but guided capture image metadata could not be saved. Retry this role or replace the photo.',
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

  @override
  Future<OpenCvResultRef> persistOpenCvResult({
    required String projectId,
    required String jobId,
    required String sourceImageId,
    required Map<String, Object?> candidateGeometry,
    required double? confidence,
    required String algorithm,
    String coordinateSpace = 'image_pixels',
    String? qualityStatus,
    String? failureReasonCode,
    String? failureReason,
    String? openCvVersion,
  }) async {
    final now = DateTime.now().toUtc();
    final resultId = 'opencv-$jobId-${now.microsecondsSinceEpoch}';
    final candidateGeometryPayload = _snakeCaseJsonMap(candidateGeometry);
    final result = FirebaseOpenCvResult(
      resultId: resultId,
      projectId: projectId,
      ownerUid: _session.uid,
      jobId: jobId,
      sourceImageId: sourceImageId,
      coordinateSpace: FirebaseCoordinateSpace.fromWireValue(coordinateSpace),
      algorithmId: algorithm,
      openCvVersion: openCvVersion,
      candidateEdges: _jsonList(candidateGeometryPayload['candidate_edges']),
      candidateLines: _jsonList(candidateGeometryPayload['candidate_lines']),
      candidateCorners: _pointList(
        candidateGeometryPayload['candidate_corners'],
      ),
      boundaryHints: _jsonList(
        candidateGeometryPayload['boundary_hints'] ??
            candidateGeometryPayload['candidate_sets'],
      ),
      confidenceScore: confidence,
      qualityStatus: _qualityStatusFromWireValue(qualityStatus, confidence),
      failureReasonCode: failureReasonCode,
      failureReason: failureReason,
      processingStartedAt: now,
      processingCompletedAt: now,
      createdAt: now,
      updatedAt: now,
      schemaVersion: 1,
    );
    final saved = await saveOpenCvResult(result);
    return OpenCvResultRef(id: saved.resultId);
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

  @override
  Future<ConfirmedGeometryRef> persistConfirmedGeometry({
    required String projectId,
    required String jobId,
    required String sourceImageId,
    required String? openCvResultId,
    required List<Map<String, Object?>> points,
    String coordinateSpace = 'image_pixels',
    String geometryKind = 'room_boundary',
    String? correctionMethod,
  }) async {
    final now = DateTime.now().toUtc();
    final geometryId = 'geometry-$jobId-${now.microsecondsSinceEpoch}';
    final geometry = FirebaseConfirmedGeometry(
      geometryId: geometryId,
      projectId: projectId,
      ownerUid: _session.uid,
      jobId: jobId,
      sourceImageId: sourceImageId,
      openCvResultId: openCvResultId,
      coordinateSpace: FirebaseCoordinateSpace.fromWireValue(coordinateSpace),
      boundaryType: points.length == 4
          ? FirebaseBoundaryType.rectangle
          : FirebaseBoundaryType.simplePolygon,
      boundaryPoints: _pointList(points),
      correctionMethod: correctionMethod,
      confirmedByUid: _session.uid,
      createdAt: now,
      updatedAt: now,
      schemaVersion: 1,
    );
    final saved = await saveConfirmedGeometry(geometry);
    return ConfirmedGeometryRef(id: saved.geometryId);
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

  @override
  Future<FloorPlanRef> persistFloorPlanResult({
    required String projectId,
    required String jobId,
    required String sourceImageId,
    required String confirmedGeometryId,
    required Map<String, Object?> referenceLine,
    required double referenceLengthValue,
    required Map<String, Object?> imageGeometry,
    required Map<String, Object?> metricGeometry,
    required Map<String, Object?> perspectiveAssumptions,
    String unit = 'meters',
    String? qualityStatus,
  }) async {
    final dimensions = await _roomDimensionsRepository.getCurrent(
      ownerUid: _session.uid,
      projectId: projectId,
    );
    if (dimensions == null) {
      throw const ProjectApiException(
        'Room dimensions are required before saving a floor plan.',
        code: 'validation_error',
      );
    }
    final now = DateTime.now().toUtc();
    final floorPlanId = 'floor-plan-$jobId-${now.microsecondsSinceEpoch}';
    final referenceLinePayload = _snakeCaseJsonMap(referenceLine);
    final imageGeometryPayload = _snakeCaseJsonMap(imageGeometry);
    final metricGeometryPayload = _snakeCaseJsonMap(metricGeometry);
    final perspectivePayload = _snakeCaseJsonMap(perspectiveAssumptions);
    final quality = _qualityStatusFromWireValue(qualityStatus, null);
    final calibration = {
      'reference_line': referenceLinePayload,
      'reference_length_value': referenceLengthValue,
      'unit': unit,
      'image_geometry': imageGeometryPayload,
      'metric_geometry': metricGeometryPayload,
      'perspective_assumptions': perspectivePayload,
    };
    final artifactRefs = await _uploadFloorPlanArtifacts(
      projectId: projectId,
      jobId: jobId,
      floorPlanId: floorPlanId,
      sourceImageId: sourceImageId,
      confirmedGeometryId: confirmedGeometryId,
      roomDimensions: dimensions,
      calibration: calibration,
      metricGeometry: metricGeometryPayload,
      qualityStatus: quality,
      generatedAt: now,
    );
    final floorPlan = FirebaseFloorPlan(
      floorPlanId: floorPlanId,
      projectId: projectId,
      ownerUid: _session.uid,
      jobId: jobId,
      sourceImageId: sourceImageId,
      confirmedGeometryId: confirmedGeometryId,
      roomDimensionsId: 'current',
      coordinateSpace: FirebaseCoordinateSpace.meters,
      roomDimensions: dimensions,
      floorPolygon: _pointList(metricGeometry['points']),
      calibration: calibration,
      qualityStatus: quality,
      artifactRefs: artifactRefs,
      createdAt: now,
      updatedAt: now,
      schemaVersion: 1,
    );
    try {
      final saved = await saveFloorPlan(floorPlan);
      return FloorPlanRef(id: saved.floorPlanId);
    } catch (_) {
      await _deleteUploadedArtifacts(artifactRefs);
      rethrow;
    }
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

  Future<List<FirebaseArtifactRef>> _uploadFloorPlanArtifacts({
    required String projectId,
    required String jobId,
    required String floorPlanId,
    required String sourceImageId,
    required String confirmedGeometryId,
    required FirebaseRoomDimensions roomDimensions,
    required FirebaseJson calibration,
    required FirebaseJson metricGeometry,
    required FirebaseQualityStatus qualityStatus,
    required DateTime generatedAt,
  }) async {
    final generatedAtIso = generatedAt.toUtc().toIso8601String();
    final specs = [
      _FloorPlanArtifactSpec(
        artifactId: '${floorPlanId}_calibration',
        filename: 'calibration.json',
        artifactType: 'calibration_json',
        description: 'Metric calibration output for the generated floor plan.',
        payload: {
          'artifact_schema_version': 1,
          'artifact_type': 'calibration_json',
          'project_id': projectId,
          'owner_uid': _session.uid,
          'job_id': jobId,
          'source_image_id': sourceImageId,
          'confirmed_geometry_id': confirmedGeometryId,
          'floor_plan_id': floorPlanId,
          'coordinate_space': FirebaseCoordinateSpace.meters.wireValue,
          'quality_status': qualityStatus.wireValue,
          'room_dimensions': roomDimensions.toFirestoreJson(
            options: FirebaseSerializationOptions.exportJson,
          ),
          'calibration': calibration,
          'generated_at': generatedAtIso,
        },
      ),
      _FloorPlanArtifactSpec(
        artifactId: '${floorPlanId}_debug',
        filename: 'debug.json',
        artifactType: 'floor_plan_debug_json',
        description:
            'Debug summary for floor plan generation and traceability.',
        payload: {
          'artifact_schema_version': 1,
          'artifact_type': 'floor_plan_debug_json',
          'project_id': projectId,
          'owner_uid': _session.uid,
          'job_id': jobId,
          'source_image_id': sourceImageId,
          'confirmed_geometry_id': confirmedGeometryId,
          'floor_plan_id': floorPlanId,
          'coordinate_space': FirebaseCoordinateSpace.meters.wireValue,
          'quality_status': qualityStatus.wireValue,
          'metric_geometry': metricGeometry,
          'point_count': _pointList(metricGeometry['points']).length,
          'generated_by': 'flutter_firebase_project_api',
          'generated_at': generatedAtIso,
        },
      ),
    ];

    final refs = <FirebaseArtifactRef>[];
    for (final spec in specs) {
      final bytes = _jsonArtifactBytes(spec.payload);
      final storagePath = _artifactStoragePath(
        ownerUid: _session.uid,
        projectId: projectId,
        jobId: jobId,
        artifactId: spec.artifactId,
        filename: spec.filename,
      );
      final sha256Hex = FirebaseSourceImageUpload.sha256Hex(bytes);
      try {
        await _sourceImageUploader.uploadBytes(
          storagePath: storagePath,
          bytes: bytes,
          contentType: FirebaseArtifactContentType.json.wireValue,
          metadata: {
            'owner_uid': _session.uid,
            'project_id': projectId,
            'job_id': jobId,
            'artifact_id': spec.artifactId,
            'uploaded_by_uid': _session.uid,
            'sha256_hex': sha256Hex,
          },
        );
      } on FirebaseException catch (error) {
        throw _artifactUploadException(error);
      } catch (error) {
        throw ProjectApiException(
          'Floor plan artifact upload failed: $error',
          code: 'artifact_upload_failed',
        );
      }

      refs.add(
        FirebaseArtifactRef(
          artifactId: spec.artifactId,
          storagePath: storagePath,
          artifactType: spec.artifactType,
          contentType: FirebaseArtifactContentType.json,
          byteSize: bytes.length,
          sha256Hex: sha256Hex,
          createdAt: generatedAt,
          description: spec.description,
        ),
      );
    }

    return refs;
  }

  Future<void> _deleteUploadedArtifacts(
    List<FirebaseArtifactRef> artifactRefs,
  ) async {
    for (final artifactRef in artifactRefs) {
      try {
        await _sourceImageUploader.deleteObject(artifactRef.storagePath);
      } catch (_) {
        // Preserve the floor-plan save failure; cleanup is best-effort.
      }
    }
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
      captureSessionId: sourceImage.captureSessionId,
      captureImageId: sourceImage.captureImageId,
      captureImageRole: sourceImage.captureImageRole?.wireValue,
      sha256Hex: sourceImage.sha256Hex,
      retentionStatus: sourceImage.retentionStatus.wireValue,
      uploadedAt: sourceImage.uploadedAt,
    );
  }

  CaptureSession _captureSessionFromFirebase(FirebaseCaptureSession session) {
    return CaptureSession(
      id: session.captureSessionId,
      projectId: session.projectId,
      userId: session.ownerUid,
      roomDimensionsId: session.roomDimensionsId,
      captureMethod: session.captureMethod.wireValue,
      depthEnabled: session.depthEnabled,
      startedAt: session.startedAt,
      completedAt: session.completedAt,
      notes: session.notes,
      createdAt: session.createdAt,
      updatedAt: session.updatedAt,
    );
  }

  CaptureImage _captureImageFromFirebase(FirebaseCaptureImage captureImage) {
    return CaptureImage(
      id: captureImage.captureImageId,
      captureSessionId: captureImage.captureSessionId,
      projectId: captureImage.projectId,
      userId: captureImage.ownerUid,
      sourceImageId: captureImage.sourceImageId,
      role: captureImage.role.wireValue,
      storagePath: captureImage.storagePath,
      contentType: captureImage.contentType.wireValue,
      widthPx: captureImage.widthPx,
      heightPx: captureImage.heightPx,
      captureOrder: captureImage.captureOrder,
      guidanceState: captureImage.guidanceState,
      createdAt: captureImage.createdAt,
      updatedAt: captureImage.updatedAt,
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

  int _captureOrderForRole(FirebaseCaptureImageRole role) {
    return switch (role) {
      FirebaseCaptureImageRole.overview => 0,
      FirebaseCaptureImageRole.frontWall => 1,
      FirebaseCaptureImageRole.rightWall => 2,
      FirebaseCaptureImageRole.backWall => 3,
      FirebaseCaptureImageRole.leftWall => 4,
      FirebaseCaptureImageRole.extra => 5,
    };
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

  List<FirebaseJson> _jsonList(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map>()
        .map((entry) => Map<String, Object?>.from(entry))
        .toList();
  }

  List<FirebasePoint2d> _pointList(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map>()
        .map((entry) => Map<String, Object?>.from(entry))
        .where((entry) => entry['x'] is num && entry['y'] is num)
        .map(
          (entry) => FirebasePoint2d(
            x: (entry['x'] as num).toDouble(),
            y: (entry['y'] as num).toDouble(),
          ),
        )
        .toList();
  }

  Map<String, Object?> _snakeCaseJsonMap(Map<String, Object?> value) {
    return {
      for (final entry in value.entries)
        _snakeCaseKey(entry.key): _snakeCaseJsonValue(entry.value),
    };
  }

  Object? _snakeCaseJsonValue(Object? value) {
    if (value is Map) {
      return {
        for (final entry in value.entries)
          _snakeCaseKey(entry.key.toString()): _snakeCaseJsonValue(entry.value),
      };
    }
    if (value is Iterable) {
      return value.map(_snakeCaseJsonValue).toList();
    }
    return value;
  }

  String _snakeCaseKey(String value) {
    return value.replaceAllMapped(
      RegExp(r'(?<=[a-z0-9])[A-Z]'),
      (match) => '_${match.group(0)!.toLowerCase()}',
    );
  }

  FirebaseQualityStatus _qualityStatusFromWireValue(
    String? value,
    double? confidence,
  ) {
    if (value != null) {
      try {
        return FirebaseQualityStatus.fromWireValue(value);
      } on FirebaseContractException {
        return FirebaseQualityStatus.reviewRequired;
      }
    }
    if (confidence == null) {
      return FirebaseQualityStatus.reviewRequired;
    }
    return confidence >= 0.68
        ? FirebaseQualityStatus.success
        : FirebaseQualityStatus.reviewRequired;
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

  ProjectApiException _artifactUploadException(FirebaseException error) {
    if (_isPermissionError(error.code)) {
      return const ProjectApiException(
        'Permission blocked floor plan artifact upload. Check project access, then retry.',
        code: 'permission_denied',
      );
    }
    return ProjectApiException(
      'Floor plan artifact upload failed: ${error.message ?? error.code}',
      code: 'artifact_upload_failed',
    );
  }

  bool _isPermissionError(String code) {
    return code == 'permission-denied' || code == 'unauthorized';
  }
}

class _FloorPlanArtifactSpec {
  const _FloorPlanArtifactSpec({
    required this.artifactId,
    required this.filename,
    required this.artifactType,
    required this.description,
    required this.payload,
  });

  final String artifactId;
  final String filename;
  final String artifactType;
  final String description;
  final FirebaseJson payload;
}

Uint8List _jsonArtifactBytes(FirebaseJson payload) {
  return Uint8List.fromList(utf8.encode(jsonEncode(payload)));
}

String _artifactStoragePath({
  required String ownerUid,
  required String projectId,
  required String jobId,
  required String artifactId,
  required String filename,
}) {
  return 'users/$ownerUid/projects/$projectId/artifacts/$jobId/$artifactId/$filename';
}
