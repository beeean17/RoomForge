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
  });

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

  @override
  String newSourceImageId({required String projectId}) => 'source-1';

  @override
  Future<FirebaseSourceImage> createMetadataAfterUpload(
    FirebaseSourceImage sourceImage,
  ) async {
    saved = sourceImage;
    return sourceImage;
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
  final floorPlans = <String, FirebaseFloorPlan>{};

  @override
  Future<FirebaseFloorPlan> saveFloorPlan(FirebaseFloorPlan floorPlan) async {
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

class _FakeSourceImageUploader implements FirebaseSourceImageUploader {
  _FakeSourceImageUploader({this.shouldFail = false});

  final bool shouldFail;
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
    onProgress?.call(1);
  }
}
