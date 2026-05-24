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
