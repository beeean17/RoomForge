import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';

import '../auth/auth_repository.dart';
import '../firebase/firebase_models.dart';
import '../firebase/firebase_repositories.dart';
import 'firebase_source_image_upload.dart';
import 'project_api.dart';

class FirebaseProjectApi extends ProjectApi {
  FirebaseProjectApi({
    required super.authRepository,
    required AuthSession session,
    required FirebaseProjectRepository projectRepository,
    required FirebaseReconstructionRepository reconstructionRepository,
    required FirebaseRoomDimensionsRepository roomDimensionsRepository,
    required FirebaseSourceImageRepository sourceImageRepository,
    required FirebaseSourceImageUploader sourceImageUploader,
  }) : _session = session,
       _projectRepository = projectRepository,
       _reconstructionRepository = reconstructionRepository,
       _roomDimensionsRepository = roomDimensionsRepository,
       _sourceImageRepository = sourceImageRepository,
       _sourceImageUploader = sourceImageUploader;

  final AuthSession _session;
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

  @override
  Future<SavedLayout> saveLayout({
    required String projectId,
    required Map<String, Object?> roomDimensions,
    required Map<String, Object?> floorPlan,
    required Map<String, Object?> sourceMetadata,
    required List<Map<String, Object?>> furnitureObjects,
    required Map<String, Object?> editorScene,
  }) {
    throw const ProjectApiException(
      'Firebase layout save is implemented in Epic 7.',
      code: 'not_implemented',
    );
  }

  @override
  Future<SavedLayout> loadLatestLayout({required String projectId}) {
    throw const ProjectApiException(
      'Firebase layout load is implemented in Epic 7.',
      code: 'not_implemented',
    );
  }

  @override
  Future<Map<String, Object?>> exportLatestLayout({required String projectId}) {
    throw const ProjectApiException(
      'Firebase layout export is implemented in Epic 7.',
      code: 'not_implemented',
    );
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
