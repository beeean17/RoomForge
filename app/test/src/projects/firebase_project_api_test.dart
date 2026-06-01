import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:app/src/auth/auth_repository.dart';
import 'package:app/src/firebase/firebase_models.dart';
import 'package:app/src/firebase/firebase_repositories.dart';
import 'package:app/src/firebase/firebase_serializers.dart';
import 'package:app/src/projects/firebase_project_api.dart';
import 'package:app/src/projects/firebase_source_image_upload.dart';
import 'package:app/src/projects/project_api.dart';

void main() {
  test(
    'FirebaseProjectApi creates projects with the signed-in owner uid',
    () async {
      final projects = _FakeProjectRepository();
      final api = FirebaseProjectApi(
        authRepository: DisabledAuthRepository(),
        session: _session(),
        floorPlanRepository: _FakeFloorPlanRepository(),
        geometryRepository: _FakeGeometryRepository(),
        layoutRepository: _FakeLayoutRepository(),
        projectRepository: projects,
        reconstructionRepository: _FakeReconstructionRepository(),
        roomDimensionsRepository: _FakeRoomDimensionsRepository(),
        sourceImageRepository: _FakeSourceImageRepository(),
        sourceImageUploader: _FakeSourceImageUploader(),
      );

      final project = await api.createProject(
        name: 'Studio',
        description: 'North wall',
      );
      final listed = await api.listProjects();

      expect(project.id, 'project-1');
      expect(project.userId, 'user-1');
      expect(project.name, 'Studio');
      expect(project.description, 'North wall');
      expect(listed.map((project) => project.id), contains('project-1'));
    },
  );

  test('FirebaseProjectApi saves and reloads metric room dimensions', () async {
    final dimensions = _FakeRoomDimensionsRepository();
    final api = FirebaseProjectApi(
      authRepository: DisabledAuthRepository(),
      session: _session(),
      floorPlanRepository: _FakeFloorPlanRepository(),
      geometryRepository: _FakeGeometryRepository(),
      layoutRepository: _FakeLayoutRepository(),
      projectRepository: _FakeProjectRepository(),
      reconstructionRepository: _FakeReconstructionRepository(),
      roomDimensionsRepository: dimensions,
      sourceImageRepository: _FakeSourceImageRepository(),
      sourceImageUploader: _FakeSourceImageUploader(),
    );

    final saved = await api.saveRoomDimensions(
      projectId: 'project-1',
      widthValue: 4.2,
      depthValue: 3.6,
    );
    final reloaded = await api.getRoomDimensions(projectId: 'project-1');

    expect(saved.unit, 'meters');
    expect(saved.heightValue, 2.4);
    expect(saved.usesDefaultHeight, isTrue);
    expect(reloaded?.widthValue, 4.2);
    expect(reloaded?.depthValue, 3.6);
  });

  test(
    'FirebaseProjectApi stores source metadata after upload succeeds',
    () async {
      final projects = _FakeProjectRepository();
      await projects.createProject(ownerUid: 'user-1', name: 'Studio');
      final sourceImages = _FakeSourceImageRepository();
      final uploader = _FakeSourceImageUploader();
      final progressUpdates = <double>[];
      final api = FirebaseProjectApi(
        authRepository: DisabledAuthRepository(),
        session: _session(),
        floorPlanRepository: _FakeFloorPlanRepository(),
        geometryRepository: _FakeGeometryRepository(),
        layoutRepository: _FakeLayoutRepository(),
        projectRepository: projects,
        reconstructionRepository: _FakeReconstructionRepository(),
        roomDimensionsRepository: _FakeRoomDimensionsRepository(),
        sourceImageRepository: sourceImages,
        sourceImageUploader: uploader,
      );

      final sourceImage = await api.uploadSourceImage(
        projectId: 'project-1',
        filename: '../Room Photo.png',
        contentType: 'image/png',
        bytes: Uint8List.fromList([1, 2, 3, 4]),
        widthPx: 1280,
        heightPx: 720,
        onProgress: progressUpdates.add,
      );

      expect(progressUpdates, containsAllInOrder([0, 0.5, 1]));
      expect(uploader.uploadedPath, sourceImages.saved?.storagePath);
      expect(
        sourceImages.saved?.storagePath,
        contains(
          'users/user-1/projects/project-1/source-images/source-1/Room_Photo.png',
        ),
      );
      expect(
        sourceImages.saved?.sha256Hex,
        FirebaseSourceImageUpload.sha256Hex(Uint8List.fromList([1, 2, 3, 4])),
      );
      expect(uploader.uploadedMetadata, containsPair('owner_uid', 'user-1'));
      expect(
        uploader.uploadedMetadata,
        containsPair('project_id', 'project-1'),
      );
      expect(
        uploader.uploadedMetadata,
        containsPair('source_image_id', 'source-1'),
      );
      expect(
        uploader.uploadedMetadata,
        containsPair('sha256_hex', sourceImages.saved?.sha256Hex),
      );
      expect(sourceImage.id, 'source-1');
      expect(sourceImage.contentType, 'image/png');
      expect(sourceImage.widthPx, 1280);
      expect(sourceImage.heightPx, 720);
    },
  );

  test(
    'FirebaseProjectApi creates guided capture sessions after dimensions exist',
    () async {
      final projects = _FakeProjectRepository();
      await projects.createProject(ownerUid: 'user-1', name: 'Studio');
      final dimensions = _FakeRoomDimensionsRepository();
      final sourceImages = _FakeSourceImageRepository();
      final api = FirebaseProjectApi(
        authRepository: DisabledAuthRepository(),
        session: _session(),
        floorPlanRepository: _FakeFloorPlanRepository(),
        geometryRepository: _FakeGeometryRepository(),
        layoutRepository: _FakeLayoutRepository(),
        projectRepository: projects,
        reconstructionRepository: _FakeReconstructionRepository(),
        roomDimensionsRepository: dimensions,
        sourceImageRepository: sourceImages,
        sourceImageUploader: _FakeSourceImageUploader(),
      );

      await api.saveRoomDimensions(
        projectId: 'project-1',
        widthValue: 4.2,
        depthValue: 3.6,
        heightValue: 2.7,
      );
      final session = await api.createCaptureSession(projectId: 'project-1');

      expect(session.id, 'capture-session-1');
      expect(session.captureMethod, 'android_guided_photo');
      expect(session.roomDimensionsId, 'current');
      expect(session.depthEnabled, isFalse);
      expect(sourceImages.captureSessions.single.captureSessionId, session.id);
    },
  );

  test(
    'FirebaseProjectApi creates depth-enabled capture sessions on request',
    () async {
      final projects = _FakeProjectRepository();
      await projects.createProject(ownerUid: 'user-1', name: 'Studio');
      final dimensions = _FakeRoomDimensionsRepository();
      final sourceImages = _FakeSourceImageRepository();
      final api = FirebaseProjectApi(
        authRepository: DisabledAuthRepository(),
        session: _session(),
        floorPlanRepository: _FakeFloorPlanRepository(),
        geometryRepository: _FakeGeometryRepository(),
        layoutRepository: _FakeLayoutRepository(),
        projectRepository: projects,
        reconstructionRepository: _FakeReconstructionRepository(),
        roomDimensionsRepository: dimensions,
        sourceImageRepository: sourceImages,
        sourceImageUploader: _FakeSourceImageUploader(),
      );

      await api.saveRoomDimensions(
        projectId: 'project-1',
        widthValue: 4.2,
        depthValue: 3.6,
        heightValue: 2.7,
      );
      final session = await api.createCaptureSession(
        projectId: 'project-1',
        depthEnabled: true,
      );

      expect(session.captureMethod, 'android_arcore_depth');
      expect(session.depthEnabled, isTrue);
      expect(sourceImages.captureSessions.single.depthEnabled, isTrue);
    },
  );

  test(
    'FirebaseProjectApi uploads guided capture images with role metadata',
    () async {
      final projects = _FakeProjectRepository();
      await projects.createProject(ownerUid: 'user-1', name: 'Studio');
      final dimensions = _FakeRoomDimensionsRepository();
      final sourceImages = _FakeSourceImageRepository();
      final uploader = _FakeSourceImageUploader();
      final api = FirebaseProjectApi(
        authRepository: DisabledAuthRepository(),
        session: _session(),
        floorPlanRepository: _FakeFloorPlanRepository(),
        geometryRepository: _FakeGeometryRepository(),
        layoutRepository: _FakeLayoutRepository(),
        projectRepository: projects,
        reconstructionRepository: _FakeReconstructionRepository(),
        roomDimensionsRepository: dimensions,
        sourceImageRepository: sourceImages,
        sourceImageUploader: uploader,
      );

      await api.saveRoomDimensions(
        projectId: 'project-1',
        widthValue: 4.2,
        depthValue: 3.6,
      );
      final session = await api.createCaptureSession(projectId: 'project-1');
      final image = await api.uploadCaptureImage(
        projectId: 'project-1',
        captureSessionId: session.id,
        role: 'overview',
        filename: 'overview photo.png',
        contentType: 'image/png',
        bytes: Uint8List.fromList([1, 2, 3, 4]),
        widthPx: 1600,
        heightPx: 900,
      );

      expect(image.id, 'capture-image-1');
      expect(image.role, 'overview');
      expect(image.captureSessionId, session.id);
      expect(image.sourceImageId, 'source-1');
      expect(
        uploader.uploadedPath,
        'users/user-1/projects/project-1/capture-sessions/${session.id}/images/capture-image-1/overview_photo.png',
      );
      expect(
        uploader.uploadedMetadata,
        containsPair('capture_session_id', session.id),
      );
      expect(
        uploader.uploadedMetadata,
        containsPair('capture_image_id', 'capture-image-1'),
      );
      expect(uploader.uploadedMetadata, containsPair('role', 'overview'));
      expect(sourceImages.saved?.captureSessionId, session.id);
      expect(sourceImages.saved?.captureImageId, 'capture-image-1');
      expect(sourceImages.saved?.captureImageRole?.wireValue, 'overview');
      expect(
        sourceImages.captureImages.single.role,
        FirebaseCaptureImageRole.overview,
      );
    },
  );

  test(
    'FirebaseProjectApi stores optional depth metadata for capture images',
    () async {
      final projects = _FakeProjectRepository();
      await projects.createProject(ownerUid: 'user-1', name: 'Studio');
      final dimensions = _FakeRoomDimensionsRepository();
      final sourceImages = _FakeSourceImageRepository();
      final uploader = _FakeSourceImageUploader();
      final api = FirebaseProjectApi(
        authRepository: DisabledAuthRepository(),
        session: _session(),
        floorPlanRepository: _FakeFloorPlanRepository(),
        geometryRepository: _FakeGeometryRepository(),
        layoutRepository: _FakeLayoutRepository(),
        projectRepository: projects,
        reconstructionRepository: _FakeReconstructionRepository(),
        roomDimensionsRepository: dimensions,
        sourceImageRepository: sourceImages,
        sourceImageUploader: uploader,
      );

      await api.saveRoomDimensions(
        projectId: 'project-1',
        widthValue: 4.2,
        depthValue: 3.6,
        heightValue: 2.7,
      );
      final session = await api.createCaptureSession(
        projectId: 'project-1',
        depthEnabled: true,
      );
      final depthRef = CaptureDepthArtifactRef(
        artifactId: 'depth-artifact-1',
        storagePath:
            'users/user-1/projects/project-1/capture-sessions/${session.id}/artifacts/depth-artifact-1/depth.json',
        artifactType: 'arcore_depth',
        contentType: 'application/json',
        byteSize: 128,
      );

      final image = await api.uploadCaptureImage(
        projectId: 'project-1',
        captureSessionId: session.id,
        role: 'front_wall',
        filename: 'front.png',
        contentType: 'image/png',
        bytes: Uint8List.fromList([1, 2, 3, 4]),
        widthPx: 1600,
        heightPx: 900,
        depthArtifactRefs: [depthRef],
        cameraPose: const {
          'translation_m': {'x': 1.0, 'y': 1.4, 'z': 0.8},
          'rotation_quat': {'x': 0, 'y': 0, 'z': 0, 'w': 1},
        },
      );

      expect(image.depthArtifactRefs.single.artifactId, 'depth-artifact-1');
      expect(image.cameraPose?['translation_m'], isA<Map>());
      expect(image.guidanceState, 'uploaded');
      expect(sourceImages.captureImages.single.depthArtifactRefs, hasLength(1));
      expect(sourceImages.captureImages.single.cameraPose, isNotNull);
    },
  );

  test(
    'FirebaseProjectApi keeps capture image valid when depth capture warns',
    () async {
      final projects = _FakeProjectRepository();
      await projects.createProject(ownerUid: 'user-1', name: 'Studio');
      final dimensions = _FakeRoomDimensionsRepository();
      final sourceImages = _FakeSourceImageRepository();
      final api = FirebaseProjectApi(
        authRepository: DisabledAuthRepository(),
        session: _session(),
        floorPlanRepository: _FakeFloorPlanRepository(),
        geometryRepository: _FakeGeometryRepository(),
        layoutRepository: _FakeLayoutRepository(),
        projectRepository: projects,
        reconstructionRepository: _FakeReconstructionRepository(),
        roomDimensionsRepository: dimensions,
        sourceImageRepository: sourceImages,
        sourceImageUploader: _FakeSourceImageUploader(),
      );

      await api.saveRoomDimensions(
        projectId: 'project-1',
        widthValue: 4.2,
        depthValue: 3.6,
        heightValue: 2.7,
      );
      final session = await api.createCaptureSession(
        projectId: 'project-1',
        depthEnabled: true,
      );

      final image = await api.uploadCaptureImage(
        projectId: 'project-1',
        captureSessionId: session.id,
        role: 'front_wall',
        filename: 'front.png',
        contentType: 'image/png',
        bytes: Uint8List.fromList([1, 2, 3, 4]),
        widthPx: 1600,
        heightPx: 900,
        depthWarning: 'Depth capture failed; photo saved without depth.',
      );

      expect(image.guidanceState, 'depth_warning');
      expect(image.depthArtifactRefs, isEmpty);
      expect(image.cameraPose, isNull);
      expect(sourceImages.captureImages.single.guidanceState, 'depth_warning');
    },
  );

  test(
    'FirebaseProjectApi loads latest capture session with uploaded role images',
    () async {
      final projects = _FakeProjectRepository();
      await projects.createProject(ownerUid: 'user-1', name: 'Studio');
      final dimensions = _FakeRoomDimensionsRepository();
      final sourceImages = _FakeSourceImageRepository();
      final api = FirebaseProjectApi(
        authRepository: DisabledAuthRepository(),
        session: _session(),
        floorPlanRepository: _FakeFloorPlanRepository(),
        geometryRepository: _FakeGeometryRepository(),
        layoutRepository: _FakeLayoutRepository(),
        projectRepository: projects,
        reconstructionRepository: _FakeReconstructionRepository(),
        roomDimensionsRepository: dimensions,
        sourceImageRepository: sourceImages,
        sourceImageUploader: _FakeSourceImageUploader(),
      );

      await api.saveRoomDimensions(
        projectId: 'project-1',
        widthValue: 4.2,
        depthValue: 3.6,
      );
      final session = await api.createCaptureSession(projectId: 'project-1');
      await api.uploadCaptureImage(
        projectId: 'project-1',
        captureSessionId: session.id,
        role: 'overview',
        filename: 'overview.png',
        contentType: 'image/png',
        bytes: Uint8List.fromList([1, 2, 3, 4]),
        widthPx: 1600,
        heightPx: 900,
      );
      await api.uploadCaptureImage(
        projectId: 'project-1',
        captureSessionId: session.id,
        role: 'front_wall',
        filename: 'front.png',
        contentType: 'image/png',
        bytes: Uint8List.fromList([5, 6, 7, 8]),
        widthPx: 1500,
        heightPx: 900,
      );

      final snapshot = await api.loadLatestCaptureSession(
        projectId: 'project-1',
      );

      expect(snapshot, isNotNull);
      expect(snapshot!.session.id, session.id);
      expect(snapshot.availableRoles, ['overview', 'front_wall']);
      expect(snapshot.images, hasLength(2));
      expect(snapshot.images.first.sourceImageId, 'source-1');
      expect(snapshot.images.last.sourceImageId, 'source-2');
    },
  );

  test(
    'FirebaseProjectApi keeps prior guided role metadata when another role upload fails',
    () async {
      final projects = _FakeProjectRepository();
      await projects.createProject(ownerUid: 'user-1', name: 'Studio');
      final sourceImages = _FakeSourceImageRepository();
      final uploader = _FakeSourceImageUploader();
      final api = FirebaseProjectApi(
        authRepository: DisabledAuthRepository(),
        session: _session(),
        floorPlanRepository: _FakeFloorPlanRepository(),
        geometryRepository: _FakeGeometryRepository(),
        layoutRepository: _FakeLayoutRepository(),
        projectRepository: projects,
        reconstructionRepository: _FakeReconstructionRepository(),
        roomDimensionsRepository: _FakeRoomDimensionsRepository()
          ..dimensions = _roomDimensions(),
        sourceImageRepository: sourceImages,
        sourceImageUploader: uploader,
      );

      final session = await api.createCaptureSession(projectId: 'project-1');
      await api.uploadCaptureImage(
        projectId: 'project-1',
        captureSessionId: session.id,
        role: 'overview',
        filename: 'overview.png',
        contentType: 'image/png',
        bytes: Uint8List.fromList([1, 2, 3, 4]),
        widthPx: 1600,
        heightPx: 900,
      );

      uploader.shouldFail = true;
      await expectLater(
        api.uploadCaptureImage(
          projectId: 'project-1',
          captureSessionId: session.id,
          role: 'front_wall',
          filename: 'front.png',
          contentType: 'image/png',
          bytes: Uint8List.fromList([5, 6, 7, 8]),
          widthPx: 1600,
          heightPx: 900,
        ),
        throwsA(
          isA<ProjectApiException>().having(
            (error) => error.code,
            'code',
            'upload_failed',
          ),
        ),
      );

      expect(sourceImages.captureImages, hasLength(1));
      expect(
        sourceImages.captureImages.single.role,
        FirebaseCaptureImageRole.overview,
      );
    },
  );

  test('FirebaseProjectApi rejects unsupported guided capture roles', () async {
    final projects = _FakeProjectRepository();
    await projects.createProject(ownerUid: 'user-1', name: 'Studio');
    final sourceImages = _FakeSourceImageRepository();
    final api = FirebaseProjectApi(
      authRepository: DisabledAuthRepository(),
      session: _session(),
      floorPlanRepository: _FakeFloorPlanRepository(),
      geometryRepository: _FakeGeometryRepository(),
      layoutRepository: _FakeLayoutRepository(),
      projectRepository: projects,
      reconstructionRepository: _FakeReconstructionRepository(),
      roomDimensionsRepository: _FakeRoomDimensionsRepository()
        ..dimensions = _roomDimensions(),
      sourceImageRepository: sourceImages,
      sourceImageUploader: _FakeSourceImageUploader(),
    );
    final session = await api.createCaptureSession(projectId: 'project-1');

    await expectLater(
      api.uploadCaptureImage(
        projectId: 'project-1',
        captureSessionId: session.id,
        role: 'side_wall',
        filename: 'side.png',
        contentType: 'image/png',
        bytes: Uint8List.fromList([1, 2, 3, 4]),
        widthPx: 1600,
        heightPx: 900,
      ),
      throwsA(
        isA<ProjectApiException>().having(
          (error) => error.code,
          'code',
          'invalid_capture_role',
        ),
      ),
    );
  });

  test(
    'FirebaseProjectApi does not store source metadata when upload fails',
    () async {
      final projects = _FakeProjectRepository();
      await projects.createProject(ownerUid: 'user-1', name: 'Studio');
      final sourceImages = _FakeSourceImageRepository();
      final api = FirebaseProjectApi(
        authRepository: DisabledAuthRepository(),
        session: _session(),
        floorPlanRepository: _FakeFloorPlanRepository(),
        geometryRepository: _FakeGeometryRepository(),
        layoutRepository: _FakeLayoutRepository(),
        projectRepository: projects,
        reconstructionRepository: _FakeReconstructionRepository(),
        roomDimensionsRepository: _FakeRoomDimensionsRepository(),
        sourceImageRepository: sourceImages,
        sourceImageUploader: _FakeSourceImageUploader(shouldFail: true),
      );

      await expectLater(
        api.uploadSourceImage(
          projectId: 'project-1',
          filename: 'room.png',
          contentType: 'image/png',
          bytes: Uint8List.fromList([1, 2, 3, 4]),
          widthPx: 1280,
          heightPx: 720,
        ),
        throwsA(
          isA<ProjectApiException>().having(
            (error) => error.code,
            'code',
            'upload_failed',
          ),
        ),
      );
      expect(sourceImages.saved, isNull);
    },
  );

  test(
    'FirebaseProjectApi creates reconstruction jobs and transitions',
    () async {
      final projects = _FakeProjectRepository();
      await projects.createProject(ownerUid: 'user-1', name: 'Studio');
      final reconstructions = _FakeReconstructionRepository();
      final api = FirebaseProjectApi(
        authRepository: DisabledAuthRepository(),
        session: _session(),
        floorPlanRepository: _FakeFloorPlanRepository(),
        geometryRepository: _FakeGeometryRepository(),
        layoutRepository: _FakeLayoutRepository(),
        projectRepository: projects,
        reconstructionRepository: reconstructions,
        roomDimensionsRepository: _FakeRoomDimensionsRepository(),
        sourceImageRepository: _FakeSourceImageRepository(),
        sourceImageUploader: _FakeSourceImageUploader(),
      );

      final job = await api.createReconstructionJob(
        projectId: 'project-1',
        sourceImageId: 'source-1',
      );
      final reloaded = await api.getReconstructionJob(
        projectId: 'project-1',
        jobId: job.id,
      );

      expect(job.status, 'created');
      expect(job.statusLabel, 'created');
      expect(job.terminal, isFalse);
      expect(reloaded.id, job.id);
      expect(
        reconstructions.transitions.single.toStatus,
        FirebaseJobStatus.created,
      );
      expect(
        reconstructions.jobs[job.id]?.latestTransitionId,
        reconstructions.transitions.single.transitionId,
      );
      expect(reconstructions.latestProject?.latestJobId, job.id);
      expect(
        reconstructions.latestProject?.currentReconstructionStatus,
        FirebaseJobStatus.created,
      );
    },
  );

  test(
    'FirebaseProjectApi updates reconstruction status with transition',
    () async {
      final projects = _FakeProjectRepository();
      await projects.createProject(ownerUid: 'user-1', name: 'Studio');
      final reconstructions = _FakeReconstructionRepository();
      final api = FirebaseProjectApi(
        authRepository: DisabledAuthRepository(),
        session: _session(),
        floorPlanRepository: _FakeFloorPlanRepository(),
        geometryRepository: _FakeGeometryRepository(),
        layoutRepository: _FakeLayoutRepository(),
        projectRepository: projects,
        reconstructionRepository: reconstructions,
        roomDimensionsRepository: _FakeRoomDimensionsRepository(),
        sourceImageRepository: _FakeSourceImageRepository(),
        sourceImageUploader: _FakeSourceImageUploader(),
      );
      final created = await api.createReconstructionJob(
        projectId: 'project-1',
        sourceImageId: 'source-1',
      );

      final updated = await api.updateReconstructionJobStatus(
        projectId: 'project-1',
        jobId: created.id,
        status: 'review_required',
        reasonCode: 'candidate_review_required',
        reasonMessage: 'Candidate extraction requires user review.',
      );

      expect(updated.status, 'review_required');
      expect(updated.statusLabel, 'Needs review');
      expect(
        reconstructions.jobs[created.id]?.latestTransitionId,
        'transition-2',
      );
      expect(
        reconstructions.transitions.last.fromStatus,
        FirebaseJobStatus.created,
      );
      expect(
        reconstructions.transitions.last.toStatus,
        FirebaseJobStatus.reviewRequired,
      );
      expect(reconstructions.transitions.last.actorUid, 'user-1');
      expect(
        reconstructions.transitions.last.reasonCode,
        'candidate_review_required',
      );
      expect(
        reconstructions.latestProject?.currentReconstructionStatus,
        FirebaseJobStatus.reviewRequired,
      );
    },
  );

  test('FirebaseProjectApi rejects generic retrying status updates', () async {
    final projects = _FakeProjectRepository();
    await projects.createProject(ownerUid: 'user-1', name: 'Studio');
    final api = FirebaseProjectApi(
      authRepository: DisabledAuthRepository(),
      session: _session(),
      floorPlanRepository: _FakeFloorPlanRepository(),
      geometryRepository: _FakeGeometryRepository(),
      layoutRepository: _FakeLayoutRepository(),
      projectRepository: projects,
      reconstructionRepository: _FakeReconstructionRepository(),
      roomDimensionsRepository: _FakeRoomDimensionsRepository(),
      sourceImageRepository: _FakeSourceImageRepository(),
      sourceImageUploader: _FakeSourceImageUploader(),
    );

    await expectLater(
      api.updateReconstructionJobStatus(
        projectId: 'project-1',
        jobId: 'job-1',
        status: 'retrying',
        reasonCode: 'manual_retry',
        reasonMessage: 'Retry requested.',
      ),
      throwsA(
        isA<ProjectApiException>().having(
          (error) => error.code,
          'code',
          'invalid_status_transition',
        ),
      ),
    );
  });

  test('FirebaseProjectApi creates linked retry reconstruction jobs', () async {
    final projects = _FakeProjectRepository();
    await projects.createProject(ownerUid: 'user-1', name: 'Studio');
    final reconstructions = _FakeReconstructionRepository();
    final api = FirebaseProjectApi(
      authRepository: DisabledAuthRepository(),
      session: _session(),
      floorPlanRepository: _FakeFloorPlanRepository(),
      geometryRepository: _FakeGeometryRepository(),
      layoutRepository: _FakeLayoutRepository(),
      projectRepository: projects,
      reconstructionRepository: reconstructions,
      roomDimensionsRepository: _FakeRoomDimensionsRepository(),
      sourceImageRepository: _FakeSourceImageRepository(),
      sourceImageUploader: _FakeSourceImageUploader(),
    );
    final original = await api.createReconstructionJob(
      projectId: 'project-1',
      sourceImageId: 'source-1',
    );

    final retry = await api.retryReconstructionJob(
      projectId: 'project-1',
      jobId: original.id,
    );

    expect(retry.id, isNot(original.id));
    expect(retry.retryOfJobId, original.id);
    expect(
      reconstructions.jobs[original.id]?.status,
      FirebaseJobStatus.retrying,
    );
    expect(
      reconstructions.jobs[original.id]?.latestTransitionId,
      reconstructions.transitions[1].transitionId,
    );
    expect(reconstructions.jobs[retry.id]?.retryCount, 1);
    expect(
      reconstructions.jobs[retry.id]?.latestTransitionId,
      reconstructions.transitions[2].transitionId,
    );
    expect(
      reconstructions.transitions.map((transition) => transition.toStatus),
      containsAllInOrder([
        FirebaseJobStatus.created,
        FirebaseJobStatus.retrying,
        FirebaseJobStatus.created,
      ]),
    );
  });

  test(
    'FirebaseProjectApi persists candidate and confirmed geometry separately',
    () async {
      final projects = _FakeProjectRepository();
      await projects.createProject(ownerUid: 'user-1', name: 'Studio');
      final geometry = _FakeGeometryRepository();
      final api = FirebaseProjectApi(
        authRepository: DisabledAuthRepository(),
        session: _session(),
        floorPlanRepository: _FakeFloorPlanRepository(),
        geometryRepository: geometry,
        layoutRepository: _FakeLayoutRepository(),
        projectRepository: projects,
        reconstructionRepository: _FakeReconstructionRepository(),
        roomDimensionsRepository: _FakeRoomDimensionsRepository(),
        sourceImageRepository: _FakeSourceImageRepository(),
        sourceImageUploader: _FakeSourceImageUploader(),
      );

      final candidate = await api.saveOpenCvResult(_openCvResult());
      final confirmed = await api.saveConfirmedGeometry(_confirmedGeometry());
      final reloadedCandidate = await api.getOpenCvResult(
        projectId: 'project-1',
        resultId: candidate.resultId,
      );
      final reloadedConfirmed = await api.getConfirmedGeometry(
        projectId: 'project-1',
        geometryId: confirmed.geometryId,
      );

      expect(candidate.coordinateSpace, FirebaseCoordinateSpace.imagePixels);
      expect(confirmed.coordinateSpace, FirebaseCoordinateSpace.imagePixels);
      expect(geometry.openCvResults, contains(candidate.resultId));
      expect(geometry.confirmedGeometries, contains(confirmed.geometryId));
      expect(
        geometry.openCvResults[candidate.resultId],
        isNot(isA<FirebaseConfirmedGeometry>()),
      );
      expect(
        geometry.confirmedGeometries[confirmed.geometryId],
        isNot(isA<FirebaseOpenCvResult>()),
      );
      expect(reloadedCandidate?.resultId, candidate.resultId);
      expect(reloadedConfirmed?.geometryId, confirmed.geometryId);
    },
  );

  test(
    'FirebaseProjectApi persists metric floor plans with artifact refs',
    () async {
      final projects = _FakeProjectRepository();
      await projects.createProject(ownerUid: 'user-1', name: 'Studio');
      final floorPlans = _FakeFloorPlanRepository();
      final api = FirebaseProjectApi(
        authRepository: DisabledAuthRepository(),
        session: _session(),
        floorPlanRepository: floorPlans,
        geometryRepository: _FakeGeometryRepository(),
        layoutRepository: _FakeLayoutRepository(),
        projectRepository: projects,
        reconstructionRepository: _FakeReconstructionRepository(),
        roomDimensionsRepository: _FakeRoomDimensionsRepository(),
        sourceImageRepository: _FakeSourceImageRepository(),
        sourceImageUploader: _FakeSourceImageUploader(),
      );

      final saved = await api.saveFloorPlan(_floorPlan());
      final reloaded = await api.getFloorPlan(
        projectId: 'project-1',
        floorPlanId: saved.floorPlanId,
      );

      expect(saved.coordinateSpace, FirebaseCoordinateSpace.meters);
      expect(saved.qualityStatus.displayLabel, 'Needs review');
      expect(saved.artifactRefs.single.storagePath, contains('/artifacts/'));
      expect(floorPlans.floorPlans, contains(saved.floorPlanId));
      expect(reloaded?.floorPlanId, saved.floorPlanId);
      expect(reloaded?.artifactRefs.single.contentType.wireValue, 'image/png');
    },
  );

  test(
    'FirebaseProjectApi uploads generated floor plan artifacts and persists refs',
    () async {
      final projects = _FakeProjectRepository();
      await projects.createProject(ownerUid: 'user-1', name: 'Studio');
      final floorPlans = _FakeFloorPlanRepository();
      final dimensions = _FakeRoomDimensionsRepository();
      final uploader = _FakeSourceImageUploader();
      final api = FirebaseProjectApi(
        authRepository: DisabledAuthRepository(),
        session: _session(),
        floorPlanRepository: floorPlans,
        geometryRepository: _FakeGeometryRepository(),
        layoutRepository: _FakeLayoutRepository(),
        projectRepository: projects,
        reconstructionRepository: _FakeReconstructionRepository(),
        roomDimensionsRepository: dimensions,
        sourceImageRepository: _FakeSourceImageRepository(),
        sourceImageUploader: uploader,
      );
      await api.saveRoomDimensions(
        projectId: 'project-1',
        widthValue: 4.2,
        depthValue: 3.6,
        heightValue: 2.7,
      );

      final ref = await api.persistFloorPlanResult(
        projectId: 'project-1',
        jobId: 'job-1',
        sourceImageId: 'source-1',
        confirmedGeometryId: 'geometry-1',
        referenceLine: const {'fromIndex': 0, 'toIndex': 1},
        referenceLengthValue: 4.2,
        imageGeometry: const {
          'coordinateSpace': 'image_pixels',
          'points': [
            {'x': 0, 'y': 0},
            {'x': 100, 'y': 0},
            {'x': 100, 'y': 80},
            {'x': 0, 'y': 80},
          ],
        },
        metricGeometry: const {
          'coordinateSpace': 'meters',
          'points': [
            {'x': 0, 'y': 0},
            {'x': 4.2, 'y': 0},
            {'x': 4.2, 'y': 3.6},
            {'x': 0, 'y': 3.6},
          ],
        },
        perspectiveAssumptions: const {'mode': 'orthographic_floor_projection'},
        qualityStatus: 'review_required',
      );

      final saved = floorPlans.floorPlans[ref.id]!;
      expect(saved.coordinateSpace, FirebaseCoordinateSpace.meters);
      expect(saved.qualityStatus.displayLabel, 'Needs review');
      expect(saved.artifactRefs, hasLength(2));
      expect(
        saved.artifactRefs.map((artifact) => artifact.artifactType),
        containsAll(['calibration_json', 'floor_plan_debug_json']),
      );
      expect(uploader.uploads, hasLength(2));
      for (final artifact in saved.artifactRefs) {
        final upload = uploader.uploads.singleWhere(
          (upload) => upload.metadata['artifact_id'] == artifact.artifactId,
        );
        expect(
          artifact.storagePath,
          startsWith(
            'users/user-1/projects/project-1/artifacts/job-1/${artifact.artifactId}/',
          ),
        );
        expect(upload.storagePath, artifact.storagePath);
        expect(upload.contentType, 'application/json');
        expect(upload.metadata, containsPair('owner_uid', 'user-1'));
        expect(upload.metadata, containsPair('project_id', 'project-1'));
        expect(upload.metadata, containsPair('job_id', 'job-1'));
        expect(upload.metadata, containsPair('uploaded_by_uid', 'user-1'));
        expect(artifact.byteSize, upload.bytes.length);
        expect(
          artifact.sha256Hex,
          FirebaseSourceImageUpload.sha256Hex(upload.bytes),
        );
        expect(artifact.createdAt, isNotNull);
      }
      expect(
        saved.calibration['reference_line'],
        containsPair('from_index', 0),
      );
      expect(
        saved.calibration['perspective_assumptions'],
        containsPair('mode', 'orthographic_floor_projection'),
      );
      final calibrationUpload = uploader.uploads.singleWhere(
        (upload) =>
            upload.metadata['artifact_id']?.endsWith('_calibration') ?? false,
      );
      final calibrationPayload =
          jsonDecode(utf8.decode(calibrationUpload.bytes))
              as Map<String, dynamic>;
      expect(calibrationPayload, containsPair('artifact_schema_version', 1));
      expect(
        calibrationPayload,
        containsPair('artifact_type', 'calibration_json'),
      );
      expect(calibrationPayload, containsPair('coordinate_space', 'meters'));
      expect(
        calibrationPayload,
        containsPair('quality_status', 'review_required'),
      );
      final calibration =
          calibrationPayload['calibration'] as Map<String, dynamic>;
      expect(calibration['reference_line'], containsPair('from_index', 0));
      expect(
        calibration['perspective_assumptions'],
        containsPair('mode', 'orthographic_floor_projection'),
      );
      final dimensionsPayload =
          calibrationPayload['room_dimensions'] as Map<String, dynamic>;
      expect(dimensionsPayload, containsPair('unit', 'meters'));

      final debugUpload = uploader.uploads.singleWhere(
        (upload) => upload.metadata['artifact_id']?.endsWith('_debug') ?? false,
      );
      final debugPayload =
          jsonDecode(utf8.decode(debugUpload.bytes)) as Map<String, dynamic>;
      expect(
        debugPayload,
        containsPair('artifact_type', 'floor_plan_debug_json'),
      );
      expect(debugPayload, containsPair('coordinate_space', 'meters'));
      expect(debugPayload, containsPair('point_count', 4));
    },
  );

  test(
    'FirebaseProjectApi does not save floor plan metadata when artifact upload fails',
    () async {
      final projects = _FakeProjectRepository();
      await projects.createProject(ownerUid: 'user-1', name: 'Studio');
      final floorPlans = _FakeFloorPlanRepository();
      final dimensions = _FakeRoomDimensionsRepository();
      final api = FirebaseProjectApi(
        authRepository: DisabledAuthRepository(),
        session: _session(),
        floorPlanRepository: floorPlans,
        geometryRepository: _FakeGeometryRepository(),
        layoutRepository: _FakeLayoutRepository(),
        projectRepository: projects,
        reconstructionRepository: _FakeReconstructionRepository(),
        roomDimensionsRepository: dimensions,
        sourceImageRepository: _FakeSourceImageRepository(),
        sourceImageUploader: _FakeSourceImageUploader(shouldFail: true),
      );
      await api.saveRoomDimensions(
        projectId: 'project-1',
        widthValue: 4.2,
        depthValue: 3.6,
        heightValue: 2.7,
      );

      await expectLater(
        api.persistFloorPlanResult(
          projectId: 'project-1',
          jobId: 'job-1',
          sourceImageId: 'source-1',
          confirmedGeometryId: 'geometry-1',
          referenceLine: const {'fromIndex': 0, 'toIndex': 1},
          referenceLengthValue: 4.2,
          imageGeometry: const {
            'coordinateSpace': 'image_pixels',
            'points': [
              {'x': 0, 'y': 0},
              {'x': 100, 'y': 0},
              {'x': 100, 'y': 80},
            ],
          },
          metricGeometry: const {
            'coordinateSpace': 'meters',
            'points': [
              {'x': 0, 'y': 0},
              {'x': 4.2, 'y': 0},
              {'x': 4.2, 'y': 3.6},
            ],
          },
          perspectiveAssumptions: const {},
        ),
        throwsA(
          isA<ProjectApiException>().having(
            (error) => error.code,
            'code',
            'artifact_upload_failed',
          ),
        ),
      );
      expect(floorPlans.floorPlans, isEmpty);
    },
  );

  test(
    'FirebaseProjectApi deletes uploaded artifacts when floor plan save fails',
    () async {
      final projects = _FakeProjectRepository();
      await projects.createProject(ownerUid: 'user-1', name: 'Studio');
      final floorPlans = _FakeFloorPlanRepository(shouldFailSave: true);
      final dimensions = _FakeRoomDimensionsRepository();
      final uploader = _FakeSourceImageUploader();
      final api = FirebaseProjectApi(
        authRepository: DisabledAuthRepository(),
        session: _session(),
        floorPlanRepository: floorPlans,
        geometryRepository: _FakeGeometryRepository(),
        layoutRepository: _FakeLayoutRepository(),
        projectRepository: projects,
        reconstructionRepository: _FakeReconstructionRepository(),
        roomDimensionsRepository: dimensions,
        sourceImageRepository: _FakeSourceImageRepository(),
        sourceImageUploader: uploader,
      );
      await api.saveRoomDimensions(
        projectId: 'project-1',
        widthValue: 4.2,
        depthValue: 3.6,
        heightValue: 2.7,
      );

      await expectLater(
        api.persistFloorPlanResult(
          projectId: 'project-1',
          jobId: 'job-1',
          sourceImageId: 'source-1',
          confirmedGeometryId: 'geometry-1',
          referenceLine: const {'fromIndex': 0, 'toIndex': 1},
          referenceLengthValue: 4.2,
          imageGeometry: const {
            'coordinateSpace': 'image_pixels',
            'points': [
              {'x': 0, 'y': 0},
              {'x': 100, 'y': 0},
              {'x': 100, 'y': 80},
            ],
          },
          metricGeometry: const {
            'coordinateSpace': 'meters',
            'points': [
              {'x': 0, 'y': 0},
              {'x': 4.2, 'y': 0},
              {'x': 4.2, 'y': 3.6},
            ],
          },
          perspectiveAssumptions: const {},
        ),
        throwsA(isA<FirebaseContractException>()),
      );
      expect(uploader.uploads, hasLength(2));
      expect(
        uploader.deletedPaths,
        unorderedEquals(uploader.uploads.map((upload) => upload.storagePath)),
      );
      expect(floorPlans.floorPlans, isEmpty);
    },
  );

  test(
    'FirebaseProjectApi saves and reloads scene understanding results',
    () async {
      final projects = _FakeProjectRepository();
      await projects.createProject(ownerUid: 'user-1', name: 'Studio');
      final sceneResults = _FakeSceneUnderstandingRepository();
      final api = FirebaseProjectApi(
        authRepository: DisabledAuthRepository(),
        session: _session(),
        floorPlanRepository: _FakeFloorPlanRepository(),
        geometryRepository: _FakeGeometryRepository(),
        layoutRepository: _FakeLayoutRepository(),
        projectRepository: projects,
        reconstructionRepository: _FakeReconstructionRepository(),
        roomDimensionsRepository: _FakeRoomDimensionsRepository(),
        sceneUnderstandingRepository: sceneResults,
        sourceImageRepository: _FakeSourceImageRepository(),
        sourceImageUploader: _FakeSourceImageUploader(),
      );

      final ref = await api.persistSceneUnderstandingResult(
        projectId: 'project-1',
        sceneUnderstandingResult: const {
          'resultId': 'scene-result-1',
          'captureSessionId': 'session-1',
          'providerType': 'browser_cv_mock',
          'algorithmId': 'mock-scene-understanding-v1',
          'confidenceScore': 0.72,
          'qualityStatus': 'review_required',
          'coverage': {'frontWall': 'complete'},
          'candidateObjects': [
            {
              'candidateId': 'candidate-chair-1',
              'objectType': 'furniture',
              'category': 'chair',
              'sourceImageId': 'source-image-1',
              'captureImageId': 'capture-image-1',
              'sourceImageRole': 'front_wall',
              'coordinateSpace': 'image_pixels',
              'boundingBox': {'x': 10, 'y': 20, 'width': 120, 'height': 160},
              'confidenceScore': 0.72,
              'reviewState': 'review_required',
            },
          ],
          'placedObjects': [],
          'confirmedObjects': [],
          'structuralFixtures': [],
        },
      );
      final reloaded = await api.loadLatestSceneUnderstandingResult(
        projectId: 'project-1',
      );

      expect(ref.id, 'scene-result-1');
      expect(sceneResults.saved?.ownerUid, 'user-1');
      expect(
        sceneResults.saved?.providerType,
        FirebaseSceneUnderstandingProviderType.browserCv,
      );
      expect(
        sceneResults.saved?.coverage,
        containsPair('front_wall', 'complete'),
      );
      final result = reloaded?['sceneUnderstandingResult'] as FirebaseJson;
      final candidates = result['candidateObjects'] as List<Object?>;
      expect(result, containsPair('resultId', 'scene-result-1'));
      expect(candidates, hasLength(1));
      expect(
        Map<String, Object?>.from(candidates.single as Map),
        containsPair('coordinateSpace', 'image_pixels'),
      );
    },
  );

  test(
    'FirebaseProjectApi exercises the signed-in default smoke flow in order',
    () async {
      final projects = _FakeProjectRepository();
      final roomDimensions = _FakeRoomDimensionsRepository();
      final sourceImages = _FakeSourceImageRepository();
      final reconstructions = _FakeReconstructionRepository();
      final geometry = _FakeGeometryRepository();
      final floorPlans = _FakeFloorPlanRepository();
      final layouts = _FakeLayoutRepository();
      final uploader = _FakeSourceImageUploader();
      final api = FirebaseProjectApi(
        authRepository: DisabledAuthRepository(),
        session: _session(),
        floorPlanRepository: floorPlans,
        geometryRepository: geometry,
        layoutRepository: layouts,
        projectRepository: projects,
        reconstructionRepository: reconstructions,
        roomDimensionsRepository: roomDimensions,
        sourceImageRepository: sourceImages,
        sourceImageUploader: uploader,
      );

      final project = await api.createProject(
        name: 'Firebase smoke room',
        description: 'Default path validation',
      );
      final openedProject = await api.getProject(project.id);
      final savedDimensions = await api.saveRoomDimensions(
        projectId: project.id,
        widthValue: 4.2,
        depthValue: 3.6,
        heightValue: 2.7,
      );
      final uploadedImage = await api.uploadSourceImage(
        projectId: project.id,
        filename: 'smoke-room.jpg',
        contentType: 'image/jpeg',
        bytes: Uint8List.fromList([1, 2, 3, 4]),
        widthPx: 1280,
        heightPx: 720,
      );
      final createdJob = await api.createReconstructionJob(
        projectId: project.id,
        sourceImageId: uploadedImage.id,
      );
      final reviewJob = await api.updateReconstructionJobStatus(
        projectId: project.id,
        jobId: createdJob.id,
        status: 'review_required',
        reasonCode: 'opencv_candidate_needs_review',
        reasonMessage: 'Smoke flow persisted a review-required result.',
      );
      final persistedJob = await api.getReconstructionJob(
        projectId: project.id,
        jobId: createdJob.id,
      );
      final candidate = await api.saveOpenCvResult(_openCvResult());
      final confirmed = await api.saveConfirmedGeometry(_confirmedGeometry());
      final floorPlan = await api.saveFloorPlan(_floorPlan());
      final savedLayout = await api.saveLayout(
        projectId: project.id,
        roomDimensions: const {
          'unit': 'meters',
          'width_value': 4.2,
          'depth_value': 3.6,
          'height_value': 2.7,
        },
        floorPlan: {'floor_plan_id': floorPlan.floorPlanId},
        sourceMetadata: {
          'source_image_id': uploadedImage.id,
          'reconstruction_job_id': createdJob.id,
        },
        furnitureObjects: const [
          {
            'id': 'table-1',
            'category': 'table',
            'position': {'x': 1.0, 'y': 1.2},
            'size': {
              'width_meters': 1.2,
              'depth_meters': 0.7,
              'height_meters': 0.75,
            },
            'rotation_degrees': 0.0,
          },
        ],
        editorScene: const {
          'scene_id': 'smoke-scene',
          'view_mode': '3d',
          'has_unsaved_changes': false,
        },
      );
      final loadedLayout = await api.loadLatestLayout(projectId: project.id);
      final exportPayload = await api.exportLatestLayout(projectId: project.id);

      expect(openedProject.id, project.id);
      expect(openedProject.userId, _session().uid);
      expect(savedDimensions.unit, 'meters');
      expect(uploadedImage.id, 'source-1');
      expect(uploader.uploadedMetadata, containsPair('owner_uid', 'user-1'));
      expect(createdJob.status, 'created');
      expect(reviewJob.status, 'review_required');
      expect(reviewJob.statusLabel, 'Needs review');
      expect(persistedJob.status, 'review_required');
      expect(reconstructions.transitions.map((item) => item.toStatus), [
        FirebaseJobStatus.created,
        FirebaseJobStatus.reviewRequired,
      ]);
      expect(candidate.coordinateSpace, FirebaseCoordinateSpace.imagePixels);
      expect(confirmed.coordinateSpace, FirebaseCoordinateSpace.imagePixels);
      expect(floorPlan.coordinateSpace, FirebaseCoordinateSpace.meters);
      expect(savedLayout.floorPlan['quality_status'], 'review_required');
      expect(loadedLayout.id, savedLayout.id);
      expect(exportPayload, containsPair('layout_id', savedLayout.id));
      expect(
        exportPayload,
        containsPair('reconstruction_status', 'review_required'),
      );
      expect(exportPayload, containsPair('review_required', true));
    },
  );

  test('FirebaseProjectApi saves and loads Firebase layouts', () async {
    final projects = _FakeProjectRepository();
    await projects.createProject(ownerUid: 'user-1', name: 'Studio');
    final reconstructions = _FakeReconstructionRepository();
    final floorPlans = _FakeFloorPlanRepository();
    final layouts = _FakeLayoutRepository();
    final sourceImages = _FakeSourceImageRepository();
    final api = FirebaseProjectApi(
      authRepository: DisabledAuthRepository(),
      session: _session(),
      floorPlanRepository: floorPlans,
      geometryRepository: _FakeGeometryRepository(),
      layoutRepository: layouts,
      projectRepository: projects,
      reconstructionRepository: reconstructions,
      roomDimensionsRepository: _FakeRoomDimensionsRepository(),
      sourceImageRepository: sourceImages,
      sourceImageUploader: _FakeSourceImageUploader(),
    );
    await sourceImages.createMetadataAfterUpload(_sourceImage());
    await api.createReconstructionJob(
      projectId: 'project-1',
      sourceImageId: 'source-1',
    );
    await api.saveFloorPlan(_floorPlan());

    final saved = await api.saveLayout(
      projectId: 'project-1',
      roomDimensions: const {
        'unit': 'meters',
        'width_value': 4.2,
        'depth_value': 3.6,
        'height_value': 2.7,
      },
      floorPlan: const {'floor_plan_id': 'floor-plan-1'},
      sourceMetadata: const {
        'source_image_id': 'source-1',
        'reconstruction_job_id': 'job-1',
      },
      furnitureObjects: const [
        {
          'id': 'chair-1',
          'category': 'chair',
          'position': {'x': 1.0, 'y': 1.2},
          'size': {
            'width_meters': 0.6,
            'depth_meters': 0.6,
            'height_meters': 0.8,
          },
          'rotation_degrees': 15.0,
          'color': '#64748b',
          'label': 'Desk chair',
          'locked': false,
        },
      ],
      editorScene: const {
        'scene_id': 'scene-1',
        'view_mode': '3d',
        'has_unsaved_changes': false,
      },
    );
    final reloaded = await api.loadLatestLayout(projectId: 'project-1');
    final exportPayload = await api.exportLatestLayout(projectId: 'project-1');

    expect(saved.projectId, 'project-1');
    expect(saved.roomDimensions['width_m'], 4.2);
    expect(saved.roomDimensions['width_value'], 4.2);
    expect(saved.roomDimensions['source'], 'user_entered');
    expect(saved.floorPlan['floor_plan_id'], 'floor-plan-1');
    expect(saved.floorPlan['job_id'], 'job-1');
    expect(saved.floorPlan['source_image_id'], 'source-1');
    expect(saved.floorPlan['room_dimensions'], isA<Map<String, Object?>>());
    expect(saved.floorPlan['calibration'], isA<Map<String, Object?>>());
    expect(saved.floorPlan['quality_status'], 'review_required');
    expect(saved.floorPlan['warnings'], contains('Needs review'));
    expect(saved.floorPlan['created_at'], isA<String>());
    expect(saved.floorPlan['updated_at'], isA<String>());
    expect(saved.sourceMetadata['content_type'], 'image/jpeg');
    expect(saved.sourceMetadata['byte_size'], 4);
    expect(saved.sourceMetadata['width_px'], 1280);
    expect(saved.sourceMetadata['height_px'], 720);
    expect(saved.sourceMetadata['sha256_hex'], startsWith('9f64a747'));
    expect(saved.sourceMetadata['uploaded_at'], isA<String>());
    expect(saved.schemaVersion, 1);
    expect(saved.exportVersion, 1);
    expect(saved.furnitureObjects.single, isA<Map<String, Object?>>());
    final savedFurniture = Map<String, Object?>.from(
      saved.furnitureObjects.single as Map,
    );
    expect(savedFurniture, containsPair('id', 'chair-1'));
    expect(savedFurniture, containsPair('category', 'chair'));
    expect(savedFurniture, containsPair('color', '#64748b'));
    expect(savedFurniture, containsPair('label', 'Desk chair'));
    expect(savedFurniture, containsPair('locked', false));
    expect(reloaded.id, saved.id);
    expect(reloaded.floorPlan['job_id'], 'job-1');
    expect(reloaded.floorPlan['calibration'], isA<Map<String, Object?>>());
    expect(reloaded.sourceMetadata['content_type'], 'image/jpeg');
    expect(reloaded.schemaVersion, 1);
    expect(reloaded.exportVersion, 1);
    expect(reloaded.editorScene['view_mode'], '3d');
    final reloadedFurniture = Map<String, Object?>.from(
      reloaded.furnitureObjects.single as Map,
    );
    expect(reloadedFurniture, containsPair('id', 'chair-1'));
    expect(reloadedFurniture, containsPair('color', '#64748b'));
    expect(reloadedFurniture, containsPair('label', 'Desk chair'));
    expect(reloadedFurniture, containsPair('locked', false));
    expect(layouts.saved?.coordinateSpace, FirebaseCoordinateSpace.meters);
    expect(layouts.saved?.roomDimensions.source, 'user_entered');
    expect(layouts.saved?.roomDimensions.createdAt, _now);
    expect(layouts.saved?.roomDimensions.updatedAt, _now);
    expect(layouts.saved?.floorPlan.floorPlanId, 'floor-plan-1');
    expect(
      layouts.saved?.roomDimensions.widthM,
      layouts.saved?.floorPlan.roomDimensions.widthM,
    );
    expect(layouts.saved?.sourceMetadata['reconstruction_status'], 'created');
    final persistedFurniture = layouts.saved!.furnitureObjects.single
        .toFirestoreJson();
    FirebaseSerializerValidators.requireSnakeCasePayload(
      persistedFurniture,
      'persisted_furniture',
    );
    expect(persistedFurniture, containsPair('furniture_id', 'chair-1'));
    expect(persistedFurniture, containsPair('category', 'chair'));
    expect(persistedFurniture, containsPair('rotation_deg', 15.0));
    expect(persistedFurniture, containsPair('color', '#64748b'));
    expect(persistedFurniture, containsPair('label', 'Desk chair'));
    expect(persistedFurniture, containsPair('locked', false));
    expect(persistedFurniture, contains('position_m'));
    expect(persistedFurniture, contains('size_m'));
    expect(persistedFurniture, isNot(contains('objectId')));
    expect(persistedFurniture, isNot(contains('rotationDegrees')));
    FirebaseSerializerValidators.requireSnakeCasePayload(
      exportPayload,
      'layout_export',
    );
    expect(exportPayload, containsPair('layout_id', saved.id));
    expect(exportPayload, containsPair('reconstruction_status', 'created'));
    expect(exportPayload, containsPair('review_required', true));
    expect(exportPayload, contains('furniture_objects'));
    expect(exportPayload, isNot(contains('layoutId')));
    final exportedFurniture = Map<String, Object?>.from(
      (exportPayload['furniture_objects'] as List<Object?>).single as Map,
    );
    expect(exportedFurniture, containsPair('furniture_id', 'chair-1'));
    expect(exportedFurniture, containsPair('category', 'chair'));
    expect(exportedFurniture, containsPair('rotation_deg', 15.0));
    expect(exportedFurniture, containsPair('color', '#64748b'));
    expect(exportedFurniture, containsPair('label', 'Desk chair'));
    expect(exportedFurniture, containsPair('locked', false));
    expect(exportedFurniture, contains('position_m'));
    expect(exportedFurniture, contains('size_m'));
    expect(exportedFurniture, isNot(contains('objectId')));
  });

  test(
    'FirebaseProjectApi rejects export without saved cloud layout',
    () async {
      final api = FirebaseProjectApi(
        authRepository: DisabledAuthRepository(),
        session: _session(),
        floorPlanRepository: _FakeFloorPlanRepository(),
        geometryRepository: _FakeGeometryRepository(),
        layoutRepository: _FakeLayoutRepository(),
        projectRepository: _FakeProjectRepository(),
        reconstructionRepository: _FakeReconstructionRepository(),
        roomDimensionsRepository: _FakeRoomDimensionsRepository(),
        sourceImageRepository: _FakeSourceImageRepository(),
        sourceImageUploader: _FakeSourceImageUploader(),
      );

      await expectLater(
        api.exportLatestLayout(projectId: 'project-1'),
        throwsA(
          isA<ProjectApiException>().having(
            (error) => error.code,
            'code',
            'not_found',
          ),
        ),
      );
    },
  );

  test(
    'FirebaseProjectApi rejects layout dimensions that differ from floor plan',
    () async {
      final projects = _FakeProjectRepository();
      await projects.createProject(ownerUid: 'user-1', name: 'Studio');
      final reconstructions = _FakeReconstructionRepository();
      final floorPlans = _FakeFloorPlanRepository();
      final layouts = _FakeLayoutRepository();
      final sourceImages = _FakeSourceImageRepository();
      final api = FirebaseProjectApi(
        authRepository: DisabledAuthRepository(),
        session: _session(),
        floorPlanRepository: floorPlans,
        geometryRepository: _FakeGeometryRepository(),
        layoutRepository: layouts,
        projectRepository: projects,
        reconstructionRepository: reconstructions,
        roomDimensionsRepository: _FakeRoomDimensionsRepository(),
        sourceImageRepository: sourceImages,
        sourceImageUploader: _FakeSourceImageUploader(),
      );
      await sourceImages.createMetadataAfterUpload(_sourceImage());
      await api.createReconstructionJob(
        projectId: 'project-1',
        sourceImageId: 'source-1',
      );
      await api.saveFloorPlan(_floorPlan());

      await expectLater(
        api.saveLayout(
          projectId: 'project-1',
          roomDimensions: const {
            'unit': 'meters',
            'width_value': 5.0,
            'depth_value': 3.6,
            'height_value': 2.7,
          },
          floorPlan: const {'floor_plan_id': 'floor-plan-1'},
          sourceMetadata: const {
            'source_image_id': 'source-1',
            'reconstruction_job_id': 'job-1',
          },
          furnitureObjects: const [],
          editorScene: const {'scene_id': 'scene-1'},
        ),
        throwsA(
          isA<ProjectApiException>().having(
            (error) => error.code,
            'code',
            'invalid_layout_payload',
          ),
        ),
      );
      expect(layouts.saved, isNull);
    },
  );

  test(
    'FirebaseProjectApi rejects incomplete furniture layout payloads',
    () async {
      final projects = _FakeProjectRepository();
      await projects.createProject(ownerUid: 'user-1', name: 'Studio');
      final reconstructions = _FakeReconstructionRepository();
      final floorPlans = _FakeFloorPlanRepository();
      final layouts = _FakeLayoutRepository();
      final sourceImages = _FakeSourceImageRepository();
      final api = FirebaseProjectApi(
        authRepository: DisabledAuthRepository(),
        session: _session(),
        floorPlanRepository: floorPlans,
        geometryRepository: _FakeGeometryRepository(),
        layoutRepository: layouts,
        projectRepository: projects,
        reconstructionRepository: reconstructions,
        roomDimensionsRepository: _FakeRoomDimensionsRepository(),
        sourceImageRepository: sourceImages,
        sourceImageUploader: _FakeSourceImageUploader(),
      );
      await sourceImages.createMetadataAfterUpload(_sourceImage());
      await api.createReconstructionJob(
        projectId: 'project-1',
        sourceImageId: 'source-1',
      );
      await api.saveFloorPlan(_floorPlan());

      await expectLater(
        api.saveLayout(
          projectId: 'project-1',
          roomDimensions: const {
            'unit': 'meters',
            'width_value': 4.2,
            'depth_value': 3.6,
            'height_value': 2.7,
          },
          floorPlan: const {'floor_plan_id': 'floor-plan-1'},
          sourceMetadata: const {
            'source_image_id': 'source-1',
            'reconstruction_job_id': 'job-1',
          },
          furnitureObjects: const [
            {
              'id': 'chair-1',
              'category': 'chair',
              'position': {'x': 1.0, 'y': 1.2},
              'rotation_degrees': 15.0,
            },
          ],
          editorScene: const {'scene_id': 'scene-1'},
        ),
        throwsA(
          isA<ProjectApiException>().having(
            (error) => error.code,
            'code',
            'invalid_layout_payload',
          ),
        ),
      );
      expect(layouts.saved, isNull);
    },
  );
}

AuthSession _session() {
  return const AuthSession(uid: 'user-1', email: 'user@example.test');
}

DateTime get _now => DateTime.utc(2026, 5, 24, 12);

FirebaseSourceImage _sourceImage() {
  return FirebaseSourceImage(
    sourceImageId: 'source-1',
    projectId: 'project-1',
    ownerUid: 'user-1',
    storagePath:
        'users/user-1/projects/project-1/source-images/source-1/room.jpg',
    originalFilename: 'room.jpg',
    storedFilename: 'room.jpg',
    contentType: FirebaseImageContentType.jpeg,
    byteSize: 4,
    sha256Hex:
        '9f64a747e1b97f131fabb6b447296c9b6f0201e79fb3c5356e6c77e89b6a806a',
    widthPx: 1280,
    heightPx: 720,
    captureSource: 'file_upload',
    retentionStatus: FirebaseRetentionStatus.active,
    uploadedAt: _now,
    createdAt: _now,
    updatedAt: _now,
    schemaVersion: 1,
  );
}

FirebaseRoomDimensions _roomDimensions() {
  return FirebaseRoomDimensions(
    projectId: 'project-1',
    ownerUid: 'user-1',
    widthM: 4.2,
    depthM: 3.6,
    heightM: 2.7,
    unit: 'meters',
    source: 'user_entered',
    createdAt: _now,
    updatedAt: _now,
    schemaVersion: 1,
  );
}

FirebaseOpenCvResult _openCvResult() {
  return FirebaseOpenCvResult(
    resultId: 'result-1',
    projectId: 'project-1',
    ownerUid: 'user-1',
    jobId: 'job-1',
    sourceImageId: 'source-1',
    coordinateSpace: FirebaseCoordinateSpace.imagePixels,
    algorithmId: 'opencv_lines_corners_v1',
    candidateCorners: const [
      FirebasePoint2d(x: 0, y: 0),
      FirebasePoint2d(x: 100, y: 0),
      FirebasePoint2d(x: 100, y: 80),
      FirebasePoint2d(x: 0, y: 80),
    ],
    qualityStatus: FirebaseQualityStatus.reviewRequired,
    createdAt: _now,
    updatedAt: _now,
    schemaVersion: 1,
  );
}

FirebaseConfirmedGeometry _confirmedGeometry() {
  return FirebaseConfirmedGeometry(
    geometryId: 'geometry-1',
    projectId: 'project-1',
    ownerUid: 'user-1',
    jobId: 'job-1',
    sourceImageId: 'source-1',
    openCvResultId: 'result-1',
    coordinateSpace: FirebaseCoordinateSpace.imagePixels,
    boundaryType: FirebaseBoundaryType.rectangle,
    boundaryPoints: const [
      FirebasePoint2d(x: 0, y: 0),
      FirebasePoint2d(x: 100, y: 0),
      FirebasePoint2d(x: 100, y: 80),
      FirebasePoint2d(x: 0, y: 80),
    ],
    correctionMethod: 'candidate_adjusted',
    confirmedByUid: 'user-1',
    createdAt: _now,
    updatedAt: _now,
    schemaVersion: 1,
  );
}

FirebaseFloorPlan _floorPlan() {
  return FirebaseFloorPlan(
    floorPlanId: 'floor-plan-1',
    projectId: 'project-1',
    ownerUid: 'user-1',
    jobId: 'job-1',
    sourceImageId: 'source-1',
    confirmedGeometryId: 'geometry-1',
    roomDimensionsId: 'current',
    coordinateSpace: FirebaseCoordinateSpace.meters,
    roomDimensions: FirebaseRoomDimensions(
      projectId: 'project-1',
      ownerUid: 'user-1',
      widthM: 4.2,
      depthM: 3.6,
      heightM: 2.7,
      unit: 'meters',
      source: 'user_entered',
      createdAt: _now,
      updatedAt: _now,
      schemaVersion: 1,
    ),
    floorPolygon: const [
      FirebasePoint2d(x: 0, y: 0),
      FirebasePoint2d(x: 4.2, y: 0),
      FirebasePoint2d(x: 4.2, y: 3.6),
      FirebasePoint2d(x: 0, y: 3.6),
    ],
    calibration: const {
      'scale_px_per_meter': 100,
      'method': 'room_dimensions_rect',
    },
    qualityStatus: FirebaseQualityStatus.reviewRequired,
    warnings: const ['Needs review'],
    artifactRefs: [
      FirebaseArtifactRef(
        artifactId: 'artifact-1',
        storagePath:
            'users/user-1/projects/project-1/artifacts/job-1/artifact-1/overlay.png',
        artifactType: 'opencv_overlay',
        contentType: FirebaseArtifactContentType.png,
        byteSize: 4,
        createdAt: _now,
      ),
    ],
    createdAt: _now,
    updatedAt: _now,
    schemaVersion: 1,
  );
}

class _FakeProjectRepository implements FirebaseProjectRepository {
  FirebaseRoomProject? project;

  @override
  Stream<List<FirebaseRoomProject>> watchOwnedProjects(String ownerUid) {
    return Stream.value([
      if (project != null && project!.ownerUid == ownerUid) project!,
    ]);
  }

  @override
  Future<FirebaseRoomProject> createProject({
    required String ownerUid,
    required String name,
    String? description,
  }) async {
    final now = DateTime.utc(2026);
    project = FirebaseRoomProject(
      projectId: 'project-1',
      ownerUid: ownerUid,
      name: name,
      description: description,
      schemaVersion: 1,
      createdAt: now,
      updatedAt: now,
    );
    return project!;
  }

  @override
  Future<FirebaseRoomProject> getProject({
    required String ownerUid,
    required String projectId,
  }) async {
    return project!;
  }

  @override
  Future<FirebaseRoomProject> updateProject(FirebaseRoomProject project) async {
    this.project = project;
    return project;
  }

  @override
  Future<void> softDeleteProject({
    required String ownerUid,
    required String projectId,
  }) async {}
}

class _FakeRoomDimensionsRepository
    implements FirebaseRoomDimensionsRepository {
  FirebaseRoomDimensions? dimensions;

  @override
  Future<FirebaseRoomDimensions> saveCurrent(
    FirebaseRoomDimensions dimensions,
  ) async {
    this.dimensions = dimensions;
    return dimensions;
  }

  @override
  Future<FirebaseRoomDimensions?> getCurrent({
    required String ownerUid,
    required String projectId,
  }) async {
    return dimensions;
  }
}

class _FakeSourceImageRepository implements FirebaseSourceImageRepository {
  FirebaseSourceImage? saved;
  final captureSessions = <FirebaseCaptureSession>[];
  final captureImages = <FirebaseCaptureImage>[];
  var _sourceImageCount = 0;
  var _captureSessionCount = 0;
  var _captureImageCount = 0;

  @override
  String newSourceImageId({required String projectId}) {
    _sourceImageCount += 1;
    return 'source-$_sourceImageCount';
  }

  @override
  String newCaptureSessionId({required String projectId}) {
    _captureSessionCount += 1;
    return 'capture-session-$_captureSessionCount';
  }

  @override
  String newCaptureImageId({
    required String projectId,
    required String captureSessionId,
  }) {
    _captureImageCount += 1;
    return 'capture-image-$_captureImageCount';
  }

  @override
  Future<FirebaseSourceImage> createMetadataAfterUpload(
    FirebaseSourceImage sourceImage,
  ) async {
    saved = sourceImage;
    return sourceImage;
  }

  @override
  Future<FirebaseCaptureSession> createCaptureSession(
    FirebaseCaptureSession session,
  ) async {
    captureSessions.add(session);
    return session;
  }

  @override
  Future<FirebaseCaptureSession?> getLatestCaptureSession({
    required String ownerUid,
    required String projectId,
  }) async {
    final matches = [
      for (final session in captureSessions)
        if (session.ownerUid == ownerUid && session.projectId == projectId)
          session,
    ];
    if (matches.isEmpty) {
      return null;
    }
    matches.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return matches.first;
  }

  @override
  Future<FirebaseCaptureImage> createCaptureImageMetadataAfterUpload(
    FirebaseCaptureImage captureImage,
  ) async {
    captureImages.add(captureImage);
    return captureImage;
  }

  @override
  Future<FirebaseSourceImage?> getSourceImage({
    required String ownerUid,
    required String projectId,
    required String sourceImageId,
  }) async {
    final sourceImage = saved;
    if (sourceImage == null ||
        sourceImage.ownerUid != ownerUid ||
        sourceImage.projectId != projectId ||
        sourceImage.sourceImageId != sourceImageId) {
      return null;
    }
    return sourceImage;
  }

  @override
  Stream<List<FirebaseSourceImage>> watchProjectSourceImages({
    required String ownerUid,
    required String projectId,
  }) {
    return Stream.value([
      if (saved != null &&
          saved!.ownerUid == ownerUid &&
          saved!.projectId == projectId)
        saved!,
    ]);
  }

  @override
  Stream<List<FirebaseCaptureImage>> watchCaptureImages({
    required String ownerUid,
    required String projectId,
    required String captureSessionId,
  }) {
    return Stream.value([
      for (final image in captureImages)
        if (image.ownerUid == ownerUid &&
            image.projectId == projectId &&
            image.captureSessionId == captureSessionId)
          image,
    ]);
  }
}

class _FakeReconstructionRepository
    implements FirebaseReconstructionRepository {
  final jobs = <String, FirebaseReconstructionJob>{};
  final transitions = <FirebaseJobStatusTransition>[];
  FirebaseRoomProject? latestProject;
  var _jobCount = 0;
  var _transitionCount = 0;

  @override
  String newJobId({required String projectId}) {
    _jobCount += 1;
    return 'job-$_jobCount';
  }

  @override
  String newTransitionId({required String projectId, required String jobId}) {
    _transitionCount += 1;
    return 'transition-$_transitionCount';
  }

  @override
  Future<FirebaseReconstructionJob> createJobWithTransition({
    required FirebaseReconstructionJob job,
    required FirebaseJobStatusTransition transition,
    required FirebaseRoomProject project,
  }) async {
    jobs[job.jobId] = job;
    transitions.add(transition);
    latestProject = project;
    return job;
  }

  @override
  Future<FirebaseReconstructionJob> updateJobWithTransition({
    required FirebaseReconstructionJob job,
    required FirebaseJobStatusTransition transition,
    required FirebaseRoomProject project,
  }) async {
    jobs[job.jobId] = job;
    transitions.add(transition);
    latestProject = project;
    return job;
  }

  @override
  Future<FirebaseReconstructionJob> retryJobWithTransitions({
    required FirebaseReconstructionJob currentJob,
    required FirebaseJobStatusTransition currentTransition,
    required FirebaseReconstructionJob retryJob,
    required FirebaseJobStatusTransition retryTransition,
    required FirebaseRoomProject project,
  }) async {
    jobs[currentJob.jobId] = currentJob;
    transitions.add(currentTransition);
    jobs[retryJob.jobId] = retryJob;
    transitions.add(retryTransition);
    latestProject = project;
    return retryJob;
  }

  @override
  Future<FirebaseReconstructionJob?> getJob({
    required String ownerUid,
    required String projectId,
    required String jobId,
  }) async {
    final job = jobs[jobId];
    if (job == null || job.ownerUid != ownerUid || job.projectId != projectId) {
      return null;
    }
    return job;
  }

  @override
  Stream<FirebaseReconstructionJob?> watchJob({
    required String ownerUid,
    required String projectId,
    required String jobId,
  }) {
    return Stream.fromFuture(
      getJob(ownerUid: ownerUid, projectId: projectId, jobId: jobId),
    );
  }
}

class _FakeGeometryRepository implements FirebaseGeometryRepository {
  final openCvResults = <String, FirebaseOpenCvResult>{};
  final confirmedGeometries = <String, FirebaseConfirmedGeometry>{};

  @override
  Future<FirebaseOpenCvResult> saveOpenCvResult(
    FirebaseOpenCvResult result,
  ) async {
    result.validate();
    openCvResults[result.resultId] = result;
    return result;
  }

  @override
  Future<FirebaseConfirmedGeometry> saveConfirmedGeometry(
    FirebaseConfirmedGeometry geometry,
  ) async {
    geometry.validate();
    confirmedGeometries[geometry.geometryId] = geometry;
    return geometry;
  }

  @override
  Future<FirebaseOpenCvResult?> getOpenCvResult({
    required String ownerUid,
    required String projectId,
    required String resultId,
  }) async {
    final result = openCvResults[resultId];
    if (result == null ||
        result.ownerUid != ownerUid ||
        result.projectId != projectId) {
      return null;
    }
    return result;
  }

  @override
  Future<FirebaseConfirmedGeometry?> getConfirmedGeometry({
    required String ownerUid,
    required String projectId,
    required String geometryId,
  }) async {
    final geometry = confirmedGeometries[geometryId];
    if (geometry == null ||
        geometry.ownerUid != ownerUid ||
        geometry.projectId != projectId) {
      return null;
    }
    return geometry;
  }
}

class _FakeFloorPlanRepository implements FirebaseFloorPlanRepository {
  _FakeFloorPlanRepository({this.shouldFailSave = false});

  final bool shouldFailSave;
  final floorPlans = <String, FirebaseFloorPlan>{};

  @override
  Future<FirebaseFloorPlan> saveFloorPlan(FirebaseFloorPlan floorPlan) async {
    if (shouldFailSave) {
      throw const FirebaseContractException('floor plan save failed');
    }
    floorPlan.validate();
    floorPlans[floorPlan.floorPlanId] = floorPlan;
    return floorPlan;
  }

  @override
  Future<FirebaseFloorPlan?> getFloorPlan({
    required String ownerUid,
    required String projectId,
    required String floorPlanId,
  }) async {
    final floorPlan = floorPlans[floorPlanId];
    if (floorPlan == null ||
        floorPlan.ownerUid != ownerUid ||
        floorPlan.projectId != projectId) {
      return null;
    }
    return floorPlan;
  }
}

class _FakeLayoutRepository implements FirebaseLayoutRepository {
  FirebaseSavedLayout? saved;

  @override
  Future<FirebaseSavedLayout> saveLayout(FirebaseSavedLayout layout) async {
    layout.validate();
    saved = layout;
    return layout;
  }

  @override
  Future<FirebaseSavedLayout?> loadLatestLayout({
    required String ownerUid,
    required String projectId,
  }) async {
    final layout = saved;
    if (layout == null ||
        layout.ownerUid != ownerUid ||
        layout.projectId != projectId) {
      return null;
    }
    return layout;
  }

  @override
  Future<FirebaseJson> exportLatestLayout({
    required String ownerUid,
    required String projectId,
  }) async {
    final layout = await loadLatestLayout(
      ownerUid: ownerUid,
      projectId: projectId,
    );
    if (layout == null) {
      throw const FirebaseContractException('Layout is not available.');
    }
    return layout.toExportJson();
  }
}

class _FakeSceneUnderstandingRepository
    implements FirebaseSceneUnderstandingRepository {
  FirebaseSceneUnderstandingResult? saved;
  var _resultCount = 0;

  @override
  String newResultId({required String projectId}) {
    _resultCount += 1;
    return 'scene-result-$_resultCount';
  }

  @override
  Future<FirebaseSceneUnderstandingResult> saveSceneUnderstandingResult(
    FirebaseSceneUnderstandingResult result,
  ) async {
    result.validate();
    saved = result;
    return result;
  }

  @override
  Future<FirebaseSceneUnderstandingResult?> loadLatestSceneUnderstandingResult({
    required String ownerUid,
    required String projectId,
  }) async {
    final result = saved;
    if (result == null ||
        result.ownerUid != ownerUid ||
        result.projectId != projectId) {
      return null;
    }
    return result;
  }
}

class _FakeSourceImageUploader implements FirebaseSourceImageUploader {
  _FakeSourceImageUploader({this.shouldFail = false});

  bool shouldFail;
  final uploads = <_FakeUpload>[];
  final deletedPaths = <String>[];
  String? uploadedPath;
  Map<String, String>? uploadedMetadata;

  @override
  Future<void> uploadBytes({
    required String storagePath,
    required Uint8List bytes,
    required String contentType,
    required Map<String, String> metadata,
    void Function(double progress)? onProgress,
  }) async {
    if (shouldFail) {
      throw StateError('upload failed');
    }
    onProgress?.call(0.5);
    uploadedPath = storagePath;
    uploadedMetadata = metadata;
    uploads.add(
      _FakeUpload(
        storagePath: storagePath,
        bytes: bytes,
        contentType: contentType,
        metadata: metadata,
      ),
    );
    onProgress?.call(1);
  }

  @override
  Future<void> deleteObject(String storagePath) async {
    deletedPaths.add(storagePath);
  }
}

class _FakeUpload {
  const _FakeUpload({
    required this.storagePath,
    required this.bytes,
    required this.contentType,
    required this.metadata,
  });

  final String storagePath;
  final Uint8List bytes;
  final String contentType;
  final Map<String, String> metadata;
}
