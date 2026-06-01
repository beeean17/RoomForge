import 'package:app/src/firebase/firebase_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Firebase data contract models', () {
    test('cover every Firestore path from the contract', () {
      expect(
        FirebaseCollectionContract.values
            .map((contract) => contract.pathPattern)
            .toSet(),
        containsAll({
          'users/{uid}',
          'projects/{project_id}',
          'projects/{project_id}/source_images/{source_image_id}',
          'projects/{project_id}/room_dimensions/current',
          'projects/{project_id}/reconstruction_jobs/{job_id}',
          'projects/{project_id}/reconstruction_jobs/{job_id}/transitions/{transition_id}',
          'projects/{project_id}/opencv_results/{result_id}',
          'projects/{project_id}/confirmed_geometries/{geometry_id}',
          'projects/{project_id}/floor_plans/{floor_plan_id}',
          'projects/{project_id}/capture_sessions/{capture_session_id}',
          'projects/{project_id}/capture_sessions/{capture_session_id}/images/{capture_image_id}',
          'projects/{project_id}/scene_understanding_results/{result_id}',
          'projects/{project_id}/layouts/{layout_id}',
          'projects/{project_id}/admin_actions/{action_id}',
        }),
      );

      expect(
        FirebaseCollectionContract.values
            .map((contract) => contract.modelName)
            .where((modelName) => modelName.isEmpty),
        isEmpty,
      );
    });

    test('parse allowed job statuses and reject forbidden status aliases', () {
      for (final status in FirebaseJobStatus.values) {
        expect(FirebaseJobStatus.fromWireValue(status.wireValue), status);
      }

      for (final forbidden in ['needs_review', 'done', 'complete', 'error']) {
        expect(
          () => FirebaseJobStatus.fromWireValue(forbidden),
          throwsA(isA<FirebaseContractException>()),
          reason: 'model-job-forbidden-statuses-deny: $forbidden',
        );
      }
    });

    test('display review_required as Needs review', () {
      expect(FirebaseJobStatus.reviewRequired.wireValue, 'review_required');
      expect(FirebaseJobStatus.reviewRequired.displayLabel, 'Needs review');
      expect(
        FirebaseCandidateReviewState.reviewRequired.displayLabel,
        'Needs review',
      );
    });

    test('reject meters for OpenCV candidate results', () {
      final model = _openCvResult(
        coordinateSpace: FirebaseCoordinateSpace.meters,
      );

      expect(
        model.validate,
        throwsA(isA<FirebaseContractException>()),
        reason: 'opencv_results must remain in image_pixels.',
      );
    });

    test('reject meters for confirmed image geometry', () {
      final model = _confirmedGeometry(
        coordinateSpace: FirebaseCoordinateSpace.meters,
      );

      expect(
        model.validate,
        throwsA(isA<FirebaseContractException>()),
        reason: 'confirmed_geometries must remain in image_pixels.',
      );
    });

    test('reject absent or non-meters coordinate_space for floor plans', () {
      expect(
        () => FirebaseContractValidators.requireRawCoordinateSpace(
          const {},
          FirebaseCoordinateSpace.meters,
          'floor_plans',
        ),
        throwsA(isA<FirebaseContractException>()),
      );

      expect(
        () => _floorPlan(
          coordinateSpace: FirebaseCoordinateSpace.imagePixels,
        ).validate(),
        throwsA(isA<FirebaseContractException>()),
      );
    });

    test('reject absent or non-meters coordinate_space for layouts', () {
      expect(
        () => FirebaseContractValidators.requireRawCoordinateSpace(
          const {},
          FirebaseCoordinateSpace.meters,
          'layouts',
        ),
        throwsA(isA<FirebaseContractException>()),
      );

      expect(
        () => _layout(
          coordinateSpace: FirebaseCoordinateSpace.imagePixels,
        ).validate(),
        throwsA(isA<FirebaseContractException>()),
      );
    });

    test('reject layout review_required mismatch', () {
      expect(
        () => _layout(
          reconstructionStatus: FirebaseJobStatus.reviewRequired,
          reviewRequired: false,
        ).validate(),
        throwsA(isA<FirebaseContractException>()),
      );
    });

    test('validate capture image dimensions and candidate confidence', () {
      expect(
        () => _captureImage(widthPx: 0).validate(),
        throwsA(isA<FirebaseContractException>()),
      );

      expect(
        () => _candidate(confidenceScore: 1.2).validate(),
        throwsA(isA<FirebaseContractException>()),
      );
    });

    test('keep candidate scene objects in image pixels', () {
      expect(
        () => _candidate(
          coordinateSpace: FirebaseCoordinateSpace.meters,
        ).validate(),
        throwsA(isA<FirebaseContractException>()),
      );
    });

    test('validate scene understanding result object groups separately', () {
      final result = _sceneUnderstandingResult();

      expect(result.candidateObjects.single.candidateId, 'candidate-bed-1');
      expect(result.placedObjects.single.objectId, 'placed-bed-1');
      expect(result.confirmedObjects.single.objectId, 'confirmed-bed-1');
      expect(result.structuralFixtures.single.fixtureId, 'window-1');
      expect(result.validate, returnsNormally);
    });

    test('resolve scene understanding quality without new job statuses', () {
      expect(
        FirebaseSceneUnderstandingProviderType.fromWireValue('browser_cv'),
        FirebaseSceneUnderstandingProviderType.browserCv,
      );
      expect(
        FirebaseSceneUnderstandingProviderType.fromWireValue('cloud_gpu'),
        FirebaseSceneUnderstandingProviderType.cloudGpu,
      );
      expect(
        FirebaseSceneUnderstandingFailureReason.fromWireValue('low_confidence'),
        FirebaseSceneUnderstandingFailureReason.lowConfidence,
      );

      expect(
        FirebaseSceneUnderstandingQualityResolver.fromSignal(
          confidenceScore: 0.82,
          hasCandidateObjects: true,
          failureReasonCode: null,
        ),
        FirebaseQualityStatus.success,
      );
      expect(
        FirebaseSceneUnderstandingQualityResolver.fromSignal(
          confidenceScore: 0.42,
          hasCandidateObjects: true,
          failureReasonCode: null,
        ),
        FirebaseQualityStatus.reviewRequired,
      );
      expect(
        FirebaseSceneUnderstandingQualityResolver.fromSignal(
          confidenceScore: 0.82,
          hasCandidateObjects: false,
          failureReasonCode: null,
        ),
        FirebaseQualityStatus.failed,
      );
    });

    test('require failure reason for failed scene understanding results', () {
      expect(
        () => _sceneUnderstandingResult(
          qualityStatus: FirebaseQualityStatus.failed,
        ).validate(),
        throwsA(isA<FirebaseContractException>()),
      );

      expect(
        () => _sceneUnderstandingResult(
          qualityStatus: FirebaseQualityStatus.failed,
          failureReasonCode:
              FirebaseSceneUnderstandingFailureReason.detectorFailed,
        ).validate(),
        returnsNormally,
      );
    });
  });
}

DateTime get _now => DateTime.utc(2026, 5, 24, 12);

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

FirebaseOpenCvResult _openCvResult({
  FirebaseCoordinateSpace coordinateSpace = FirebaseCoordinateSpace.imagePixels,
}) {
  return FirebaseOpenCvResult(
    resultId: 'result-1',
    projectId: 'project-1',
    ownerUid: 'user-1',
    jobId: 'job-1',
    sourceImageId: 'source-image-1',
    coordinateSpace: coordinateSpace,
    algorithmId: 'opencv_lines_corners_v1',
    qualityStatus: FirebaseQualityStatus.success,
    createdAt: _now,
    updatedAt: _now,
    schemaVersion: 1,
  );
}

FirebaseConfirmedGeometry _confirmedGeometry({
  FirebaseCoordinateSpace coordinateSpace = FirebaseCoordinateSpace.imagePixels,
}) {
  return FirebaseConfirmedGeometry(
    geometryId: 'geometry-1',
    projectId: 'project-1',
    ownerUid: 'user-1',
    jobId: 'job-1',
    sourceImageId: 'source-image-1',
    coordinateSpace: coordinateSpace,
    boundaryType: FirebaseBoundaryType.rectangle,
    boundaryPoints: const [
      FirebasePoint2d(x: 0, y: 0),
      FirebasePoint2d(x: 100, y: 0),
      FirebasePoint2d(x: 100, y: 80),
      FirebasePoint2d(x: 0, y: 80),
    ],
    confirmedByUid: 'user-1',
    createdAt: _now,
    updatedAt: _now,
    schemaVersion: 1,
  );
}

FirebaseFloorPlan _floorPlan({
  FirebaseCoordinateSpace coordinateSpace = FirebaseCoordinateSpace.meters,
}) {
  return FirebaseFloorPlan(
    floorPlanId: 'floor-plan-1',
    projectId: 'project-1',
    ownerUid: 'user-1',
    jobId: 'job-1',
    sourceImageId: 'source-image-1',
    confirmedGeometryId: 'geometry-1',
    roomDimensionsId: 'current',
    coordinateSpace: coordinateSpace,
    roomDimensions: _roomDimensions(),
    floorPolygon: const [
      FirebasePoint2d(x: 0, y: 0),
      FirebasePoint2d(x: 4.2, y: 0),
      FirebasePoint2d(x: 4.2, y: 3.6),
      FirebasePoint2d(x: 0, y: 3.6),
    ],
    calibration: const {'scale': 1.0},
    qualityStatus: FirebaseQualityStatus.success,
    createdAt: _now,
    updatedAt: _now,
    schemaVersion: 1,
  );
}

FirebaseSavedLayout _layout({
  FirebaseCoordinateSpace coordinateSpace = FirebaseCoordinateSpace.meters,
  FirebaseJobStatus reconstructionStatus = FirebaseJobStatus.succeeded,
  bool reviewRequired = false,
}) {
  return FirebaseSavedLayout(
    layoutId: 'layout-1',
    projectId: 'project-1',
    ownerUid: 'user-1',
    sourceImageId: 'source-image-1',
    reconstructionJobId: 'job-1',
    reconstructionStatus: reconstructionStatus,
    reviewRequired: reviewRequired,
    floorPlanId: 'floor-plan-1',
    coordinateSpace: coordinateSpace,
    roomDimensions: _roomDimensions(),
    sourceMetadata: const {'source_image_id': 'source-image-1'},
    floorPlan: _floorPlan(),
    editorScene: const {'coordinate_space': 'meters'},
    furnitureObjects: const [
      FirebaseFurnitureObject(
        furnitureId: 'chair-1',
        category: FirebaseFurnitureCategory.chair,
        positionM: FirebasePoint3d(x: 1, y: 0, z: 1),
        sizeM: FirebasePoint3d(x: 0.6, y: 0.8, z: 0.6),
        rotationDeg: 0,
      ),
    ],
    savedAt: _now,
    createdAt: _now,
    updatedAt: _now,
    schemaVersion: 1,
    exportVersion: 1,
  );
}

FirebaseCaptureSession _captureSession() {
  return FirebaseCaptureSession(
    captureSessionId: 'capture-session-1',
    projectId: 'project-1',
    ownerUid: 'user-1',
    roomDimensionsId: 'current',
    captureMethod: FirebaseCaptureMethod.androidGuidedPhoto,
    depthEnabled: false,
    createdAt: _now,
    updatedAt: _now,
    schemaVersion: 1,
  );
}

FirebaseCaptureImage _captureImage({int widthPx = 1600}) {
  return FirebaseCaptureImage(
    captureImageId: 'capture-image-1',
    captureSessionId: _captureSession().captureSessionId,
    projectId: 'project-1',
    ownerUid: 'user-1',
    sourceImageId: 'source-image-1',
    role: FirebaseCaptureImageRole.frontWall,
    storagePath:
        'users/user-1/projects/project-1/source-images/source-image-1/front.jpg',
    contentType: FirebaseImageContentType.jpeg,
    widthPx: widthPx,
    heightPx: 1200,
    createdAt: _now,
    updatedAt: _now,
    schemaVersion: 1,
  );
}

FirebaseCandidateSceneObject _candidate({
  FirebaseCoordinateSpace coordinateSpace = FirebaseCoordinateSpace.imagePixels,
  double confidenceScore = 0.82,
}) {
  return FirebaseCandidateSceneObject(
    candidateId: 'candidate-bed-1',
    objectType: FirebaseSceneObjectType.furniture,
    category: 'bed',
    sourceImageId: 'source-image-1',
    captureImageId: 'capture-image-1',
    sourceImageRole: FirebaseCaptureImageRole.frontWall,
    coordinateSpace: coordinateSpace,
    boundingBox: const FirebaseBoundingBox(
      x: 120,
      y: 340,
      width: 520,
      height: 300,
    ),
    confidenceScore: confidenceScore,
    reviewState: FirebaseCandidateReviewState.suggested,
    suggestedAssetId: 'bed.double',
    suggestedPositionM: const FirebasePoint3d(x: 1.2, y: 0, z: 2.4),
    suggestedSizeM: const FirebasePoint3d(x: 1.5, y: 0.55, z: 2.0),
    suggestedRotationDeg: 90,
  );
}

FirebaseSceneUnderstandingResult _sceneUnderstandingResult({
  FirebaseQualityStatus qualityStatus = FirebaseQualityStatus.reviewRequired,
  FirebaseSceneUnderstandingFailureReason? failureReasonCode,
}) {
  return FirebaseSceneUnderstandingResult(
    resultId: 'scene-result-1',
    projectId: 'project-1',
    ownerUid: 'user-1',
    captureSessionId: 'capture-session-1',
    providerType: FirebaseSceneUnderstandingProviderType.browserCv,
    algorithmId: 'mock-scene-understanding-v1',
    confidenceScore: 0.74,
    qualityStatus: qualityStatus,
    failureReasonCode: failureReasonCode,
    coverage: const {'front_wall': 'complete'},
    candidateObjects: [_candidate()],
    placedObjects: const [
      FirebasePlacedSceneObject(
        objectId: 'placed-bed-1',
        candidateId: 'candidate-bed-1',
        objectType: FirebaseSceneObjectType.furniture,
        category: 'bed',
        positionM: FirebasePoint3d(x: 1.2, y: 0, z: 2.4),
        sizeM: FirebasePoint3d(x: 1.5, y: 0.55, z: 2.0),
        rotationDeg: 90,
      ),
    ],
    confirmedObjects: [
      FirebaseConfirmedSceneObject(
        objectId: 'confirmed-bed-1',
        candidateId: 'candidate-bed-1',
        objectType: FirebaseSceneObjectType.furniture,
        category: 'bed',
        positionM: const FirebasePoint3d(x: 1.2, y: 0, z: 2.4),
        sizeM: const FirebasePoint3d(x: 1.5, y: 0.55, z: 2.0),
        rotationDeg: 90,
        confirmedByUid: 'user-1',
        confirmedAt: _now,
      ),
    ],
    structuralFixtures: const [
      FirebaseStructuralFixture(
        fixtureId: 'window-1',
        category: FirebaseStructuralFixtureCategory.window,
        wallId: 'front-wall',
        positionM: FirebasePoint3d(x: 2.1, y: 1.1, z: 0),
        sizeM: FirebasePoint3d(x: 1.2, y: 1.0, z: 0.1),
        rotationDeg: 0,
      ),
    ],
    createdAt: _now,
    updatedAt: _now,
    schemaVersion: 1,
  );
}
