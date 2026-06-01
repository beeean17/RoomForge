import 'package:app/src/firebase/firebase_models.dart';
import 'package:app/src/firebase/firebase_serializers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Firebase serializers', () {
    test('serialize layout Firestore payloads with snake_case keys', () {
      final payload = _layout().toFirestoreJson();

      FirebaseSerializerValidators.requireSnakeCasePayload(payload, 'layout');
      expect(payload, containsPair('layout_id', 'layout-1'));
      expect(payload, containsPair('reconstruction_job_id', 'job-1'));
      expect(payload, containsPair('coordinate_space', 'meters'));
      expect(payload, isNot(contains('layoutId')));
      expect(payload, isNot(contains('reconstructionJobId')));
    });

    test(
      'serialize layout export JSON with snake_case keys and JSON dates',
      () {
        final payload = _layout().toExportJson();

        FirebaseSerializerValidators.requireSnakeCasePayload(
          payload,
          'layout_export',
        );
        expect(payload['saved_at'], isA<String>());
        expect(payload['saved_at'], '2026-05-24T12:00:00.000Z');
        expect(payload, containsPair('export_version', 1));
      },
    );

    test('preserve Dart model API as camelCase', () {
      final layout = _layout();

      expect(layout.layoutId, 'layout-1');
      expect(layout.reconstructionJobId, 'job-1');
      expect(layout.reviewRequired, false);
      expect(
        FirebaseSerializerValidators.isCamelCaseKey('reconstructionJobId'),
        true,
      );
      expect(
        FirebaseSerializerValidators.isCamelCaseKey('reconstruction_job_id'),
        false,
      );
    });

    test('keep candidate and confirmed geometry serializers distinct', () {
      final candidatePayload = _openCvResult().toFirestoreJson();
      final confirmedPayload = _confirmedGeometry().toFirestoreJson();

      FirebaseSerializerValidators.requireSnakeCasePayload(
        candidatePayload,
        'opencv_results',
      );
      FirebaseSerializerValidators.requireSnakeCasePayload(
        confirmedPayload,
        'confirmed_geometries',
      );

      expect(candidatePayload, contains('result_id'));
      expect(candidatePayload, contains('candidate_corners'));
      expect(candidatePayload, isNot(contains('geometry_id')));
      expect(candidatePayload, isNot(contains('boundary_points')));
      expect(candidatePayload, isNot(contains('confirmed_by_uid')));

      expect(confirmedPayload, contains('geometry_id'));
      expect(confirmedPayload, contains('boundary_points'));
      expect(confirmedPayload, contains('confirmed_by_uid'));
      expect(confirmedPayload, isNot(contains('result_id')));
      expect(confirmedPayload, isNot(contains('candidate_corners')));

      expect(
        candidatePayload.keys.toSet(),
        isNot(confirmedPayload.keys.toSet()),
      );
    });

    test('parse valid floor plan and layout Firestore payloads', () {
      final floorPlan = FirebaseModelSerializers.floorPlanFromFirestore(
        _floorPlan().toFirestoreJson(),
      );
      final layout = FirebaseModelSerializers.savedLayoutFromFirestore(
        _layout().toFirestoreJson(),
      );

      expect(floorPlan.coordinateSpace, FirebaseCoordinateSpace.meters);
      expect(layout.coordinateSpace, FirebaseCoordinateSpace.meters);
      expect(layout.floorPlan.floorPlanId, 'floor-plan-1');
      expect(layout.furnitureObjects.single.furnitureId, 'chair-1');
    });

    test('reject missing or non-meters floor plan coordinate_space', () {
      final missing = _floorPlan().toFirestoreJson()
        ..remove('coordinate_space');
      final wrong = _floorPlan().toFirestoreJson()
        ..['coordinate_space'] = 'image_pixels';

      expect(
        () => FirebaseModelSerializers.floorPlanFromFirestore(missing),
        throwsA(isA<FirebaseContractException>()),
      );
      expect(
        () => FirebaseModelSerializers.floorPlanFromFirestore(wrong),
        throwsA(isA<FirebaseContractException>()),
      );
    });

    test('reject missing or non-meters layout coordinate_space', () {
      final missing = _layout().toFirestoreJson()..remove('coordinate_space');
      final wrong = _layout().toFirestoreJson()
        ..['coordinate_space'] = 'image_pixels';

      expect(
        () => FirebaseModelSerializers.savedLayoutFromFirestore(missing),
        throwsA(isA<FirebaseContractException>()),
      );
      expect(
        () => FirebaseModelSerializers.savedLayoutFromFirestore(wrong),
        throwsA(isA<FirebaseContractException>()),
      );
    });

    test('reject camelCase keys inside persisted raw maps', () {
      final layout = _layout(editorScene: const {'coordinateSpace': 'meters'});

      expect(layout.toFirestoreJson, throwsA(isA<FirebaseContractException>()));
    });

    test('serialize capture session and image contracts as snake_case', () {
      final sessionPayload = _captureSession().toFirestoreJson();
      final imagePayload = _captureImage().toFirestoreJson();

      FirebaseSerializerValidators.requireSnakeCasePayload(
        sessionPayload,
        'capture_session',
      );
      FirebaseSerializerValidators.requireSnakeCasePayload(
        imagePayload,
        'capture_image',
      );
      expect(sessionPayload, containsPair('capture_session_id', 'session-1'));
      expect(
        sessionPayload,
        containsPair('capture_method', 'android_guided_photo'),
      );
      expect(imagePayload, containsPair('role', 'front_wall'));
      expect(imagePayload, containsPair('source_image_id', 'source-image-1'));
      expect(imagePayload, isNot(contains('sourceImageId')));
    });

    test('serialize and parse scene understanding results distinctly', () {
      final payload = _sceneUnderstandingResult().toFirestoreJson();

      FirebaseSerializerValidators.requireSnakeCasePayload(
        payload,
        'scene_understanding_results',
      );
      expect(payload, containsPair('result_id', 'scene-result-1'));
      expect(payload, contains('candidate_objects'));
      expect(payload, contains('placed_objects'));
      expect(payload, contains('confirmed_objects'));
      expect(payload, contains('structural_fixtures'));

      final candidateObjects = payload['candidate_objects'] as List<Object?>;
      final confirmedObjects = payload['confirmed_objects'] as List<Object?>;
      final candidate = Map<String, Object?>.from(
        candidateObjects.single as Map,
      );
      final confirmed = Map<String, Object?>.from(
        confirmedObjects.single as Map,
      );

      expect(candidate, containsPair('candidate_id', 'candidate-bed-1'));
      expect(candidate, contains('bounding_box'));
      expect(candidate, contains('review_state'));
      expect(candidate, isNot(contains('confirmed_by_uid')));
      expect(confirmed, containsPair('object_id', 'confirmed-bed-1'));
      expect(confirmed, contains('confirmed_by_uid'));
      expect(confirmed, isNot(contains('bounding_box')));

      final parsed =
          FirebaseModelSerializers.sceneUnderstandingResultFromFirestore(
            payload,
          );
      expect(
        parsed.providerType,
        FirebaseSceneUnderstandingProviderType.browserCv,
      );
      expect(parsed.candidateObjects.single.candidateId, 'candidate-bed-1');
      expect(parsed.confirmedObjects.single.objectId, 'confirmed-bed-1');
      expect(
        parsed.structuralFixtures.single.category,
        FirebaseStructuralFixtureCategory.window,
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

FirebaseOpenCvResult _openCvResult() {
  return FirebaseOpenCvResult(
    resultId: 'result-1',
    projectId: 'project-1',
    ownerUid: 'user-1',
    jobId: 'job-1',
    sourceImageId: 'source-image-1',
    coordinateSpace: FirebaseCoordinateSpace.imagePixels,
    algorithmId: 'opencv_lines_corners_v1',
    candidateCorners: const [
      FirebasePoint2d(x: 0, y: 0),
      FirebasePoint2d(x: 100, y: 0),
    ],
    qualityStatus: FirebaseQualityStatus.success,
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
    sourceImageId: 'source-image-1',
    openCvResultId: 'result-1',
    coordinateSpace: FirebaseCoordinateSpace.imagePixels,
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

FirebaseFloorPlan _floorPlan() {
  return FirebaseFloorPlan(
    floorPlanId: 'floor-plan-1',
    projectId: 'project-1',
    ownerUid: 'user-1',
    jobId: 'job-1',
    sourceImageId: 'source-image-1',
    confirmedGeometryId: 'geometry-1',
    roomDimensionsId: 'current',
    coordinateSpace: FirebaseCoordinateSpace.meters,
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

FirebaseSavedLayout _layout({FirebaseJson? editorScene}) {
  return FirebaseSavedLayout(
    layoutId: 'layout-1',
    projectId: 'project-1',
    ownerUid: 'user-1',
    sourceImageId: 'source-image-1',
    reconstructionJobId: 'job-1',
    reconstructionStatus: FirebaseJobStatus.succeeded,
    reviewRequired: false,
    floorPlanId: 'floor-plan-1',
    coordinateSpace: FirebaseCoordinateSpace.meters,
    roomDimensions: _roomDimensions(),
    sourceMetadata: const {'source_image_id': 'source-image-1'},
    floorPlan: _floorPlan(),
    editorScene: editorScene ?? const {'coordinate_space': 'meters'},
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
    captureSessionId: 'session-1',
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

FirebaseCaptureImage _captureImage() {
  return FirebaseCaptureImage(
    captureImageId: 'capture-image-1',
    captureSessionId: 'session-1',
    projectId: 'project-1',
    ownerUid: 'user-1',
    sourceImageId: 'source-image-1',
    role: FirebaseCaptureImageRole.frontWall,
    storagePath:
        'users/user-1/projects/project-1/source-images/source-image-1/front.jpg',
    contentType: FirebaseImageContentType.jpeg,
    widthPx: 1600,
    heightPx: 1200,
    captureOrder: 1,
    createdAt: _now,
    updatedAt: _now,
    schemaVersion: 1,
  );
}

FirebaseCandidateSceneObject _candidate() {
  return const FirebaseCandidateSceneObject(
    candidateId: 'candidate-bed-1',
    objectType: FirebaseSceneObjectType.furniture,
    category: 'bed',
    sourceImageId: 'source-image-1',
    captureImageId: 'capture-image-1',
    sourceImageRole: FirebaseCaptureImageRole.frontWall,
    coordinateSpace: FirebaseCoordinateSpace.imagePixels,
    boundingBox: FirebaseBoundingBox(x: 120, y: 340, width: 520, height: 300),
    confidenceScore: 0.82,
    reviewState: FirebaseCandidateReviewState.reviewRequired,
    suggestedAssetId: 'bed.double',
    suggestedPositionM: FirebasePoint3d(x: 1.2, y: 0, z: 2.4),
    suggestedSizeM: FirebasePoint3d(x: 1.5, y: 0.55, z: 2.0),
    suggestedRotationDeg: 90,
  );
}

FirebaseSceneUnderstandingResult _sceneUnderstandingResult() {
  return FirebaseSceneUnderstandingResult(
    resultId: 'scene-result-1',
    projectId: 'project-1',
    ownerUid: 'user-1',
    captureSessionId: 'session-1',
    providerType: FirebaseSceneUnderstandingProviderType.browserCv,
    algorithmId: 'mock-scene-understanding-v1',
    confidenceScore: 0.74,
    qualityStatus: FirebaseQualityStatus.reviewRequired,
    coverage: const {'front_wall': 'complete'},
    candidateObjects: [_candidate()],
    placedObjects: const [
      FirebasePlacedSceneObject(
        objectId: 'placed-bed-1',
        candidateId: 'candidate-bed-1',
        objectType: FirebaseSceneObjectType.furniture,
        category: 'bed',
        assetId: 'bed.double',
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
        assetId: 'bed.double',
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
