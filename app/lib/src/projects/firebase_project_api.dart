import 'dart:typed_data';

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
    required FirebaseRoomDimensionsRepository roomDimensionsRepository,
    required FirebaseSourceImageRepository sourceImageRepository,
    required FirebaseSourceImageUploader sourceImageUploader,
  }) : _session = session,
       _projectRepository = projectRepository,
       _roomDimensionsRepository = roomDimensionsRepository,
       _sourceImageRepository = sourceImageRepository,
       _sourceImageUploader = sourceImageUploader;

  final AuthSession _session;
  final FirebaseProjectRepository _projectRepository;
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

    final project = await _projectRepository.getProject(
      ownerUid: _session.uid,
      projectId: projectId,
    );
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
      );
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
  }) {
    throw const ProjectApiException(
      'Firebase reconstruction jobs are implemented in Epic 5.',
      code: 'not_implemented',
    );
  }

  @override
  Future<ReconstructionJob> getReconstructionJob({
    required String projectId,
    required String jobId,
  }) {
    throw const ProjectApiException(
      'Firebase reconstruction jobs are implemented in Epic 5.',
      code: 'not_implemented',
    );
  }

  @override
  Future<ReconstructionJob> retryReconstructionJob({
    required String projectId,
    required String jobId,
  }) {
    throw const ProjectApiException(
      'Firebase reconstruction retry is implemented in Epic 5.',
      code: 'not_implemented',
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
}
