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
