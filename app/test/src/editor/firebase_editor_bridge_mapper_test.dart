import 'package:app/src/editor/firebase_editor_bridge_mapper.dart';
import 'package:app/src/firebase/firebase_models.dart';
import 'package:app/src/firebase/firebase_serializers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Firebase editor bridge mapper', () {
    const mapper = FirebaseEditorBridgeMapper();

    test('maps saved layout to camelCase editor bridge scene', () {
      final payload = mapper.sceneToBridgePayload(_layout());

      FirebaseSerializerValidators.requireCamelCasePayload(
        payload,
        'editor_bridge',
      );
      final scene = payload['scene'] as FirebaseJson;
      expect(scene, containsPair('sceneId', 'scene-1'));
      expect(scene, containsPair('coordinateSpace', 'meters'));
      expect(scene, contains('hasUnsavedChanges'));
      expect(scene, isNot(contains('scene_id')));
      expect(scene, isNot(contains('coordinate_space')));
      final furniture = scene['furniture'] as List<Object?>;
      final chair = Map<String, Object?>.from(furniture.single as Map);
      expect(chair, containsPair('objectId', 'chair-1'));
      expect(chair, containsPair('category', 'chair'));
      expect(chair, containsPair('label', 'Desk chair'));
      expect(chair, containsPair('color', '#64748b'));
      expect(chair, containsPair('locked', false));
      expect(chair, containsPair('rotationDegrees', 15.0));
      expect(chair, isNot(contains('furniture_id')));
      expect(chair, isNot(contains('position_m')));
    });

    test('restores saved layout scene for 2D and 3D editor views', () {
      for (final viewMode in ['2d', '3d']) {
        final payload = mapper.sceneToBridgePayload(
          _layout(viewMode: viewMode),
        );
        final scene = payload['scene'] as FirebaseJson;
        final selected = scene['selected'] as FirebaseJson;
        final room = scene['room'] as FirebaseJson;
        final floorPlan = room['floorPlan'] as FirebaseJson;
        final metricGeometry = floorPlan['metricGeometry'] as FirebaseJson;
        final points = metricGeometry['points'] as List<Object?>;
        final furniture = scene['furniture'] as List<Object?>;
        final chair = Map<String, Object?>.from(furniture.single as Map);
        final chairSize = Map<String, Object?>.from(chair['size'] as Map);
        final chairPosition = Map<String, Object?>.from(
          chair['position'] as Map,
        );

        expect(scene, containsPair('viewMode', viewMode));
        expect(scene, containsPair('hasUnsavedChanges', false));
        expect(selected, containsPair('objectId', 'chair-1'));
        expect(selected, containsPair('objectType', 'furniture'));
        expect(room, containsPair('heightMeters', 2.7));
        expect(floorPlan, containsPair('floorPlanId', 'floor-plan-1'));
        expect(metricGeometry, containsPair('coordinateSpace', 'meters'));
        expect(points, hasLength(4));
        expect(chair, containsPair('objectId', 'chair-1'));
        expect(chairSize, containsPair('widthMeters', 0.6));
        expect(chairSize, containsPair('depthMeters', 0.6));
        expect(chairSize, containsPair('heightMeters', 0.8));
        expect(chairPosition, containsPair('x', 1.0));
        expect(chairPosition, containsPair('y', 1.0));
        expect(chair, containsPair('rotationDegrees', 15.0));
        expect(chair, containsPair('color', '#64748b'));
      }
    });

    test('maps editor bridge scene back to snake_case persisted state', () {
      final persisted = mapper.bridgeSceneToEditorScene(const {
        'sceneId': 'scene-1',
        'viewMode': '3d',
        'hasUnsavedChanges': true,
        'selected': {'objectId': 'chair-1', 'objectType': 'furniture'},
      });

      FirebaseSerializerValidators.requireSnakeCasePayload(
        persisted,
        'editor_scene',
      );
      expect(persisted, containsPair('scene_id', 'scene-1'));
      expect(persisted, containsPair('view_mode', '3d'));
      expect(persisted, contains('has_unsaved_changes'));
      expect(persisted, isNot(contains('sceneId')));
    });

    test('maps bridge furniture to snake_case Firestore layout furniture', () {
      final furniture = mapper.bridgeFurnitureToFirestore(const {
        'furniture': [
          {
            'objectId': 'chair-1',
            'category': 'chair',
            'label': 'Desk chair',
            'size': {
              'widthMeters': 0.6,
              'depthMeters': 0.7,
              'heightMeters': 0.9,
            },
            'position': {'x': 1.2, 'y': 2.4},
            'rotationDegrees': 15,
            'color': '#64748b',
            'locked': false,
          },
        ],
      });

      expect(furniture, hasLength(1));
      FirebaseSerializerValidators.requireSnakeCasePayload(
        furniture,
        'furniture_objects',
      );
      expect(furniture.single, containsPair('furniture_id', 'chair-1'));
      expect(furniture.single, containsPair('rotation_deg', 15.0));
      expect(furniture.single, containsPair('label', 'Desk chair'));
      expect(furniture.single, containsPair('color', '#64748b'));
      expect(furniture.single, containsPair('locked', false));
      expect(furniture.single, contains('position_m'));
      expect(furniture.single, contains('size_m'));
      expect(furniture.single, isNot(contains('objectId')));
      expect(furniture.single, isNot(contains('rotationDegrees')));
    });

    test('keeps candidate and confirmed bridge payloads distinct', () {
      final candidate = mapper.openCvResultToBridgePayload(_openCvResult());
      final confirmed = mapper.confirmedGeometryToBridgePayload(
        _confirmedGeometry(),
      );

      FirebaseSerializerValidators.requireCamelCasePayload(
        candidate,
        'candidate_bridge',
      );
      FirebaseSerializerValidators.requireCamelCasePayload(
        confirmed,
        'confirmed_bridge',
      );
      expect(candidate, contains('candidateGeometry'));
      expect(candidate, isNot(contains('confirmedGeometry')));
      expect(confirmed, contains('confirmedGeometry'));
      expect(confirmed, isNot(contains('candidateGeometry')));
    });

    test('maps scene understanding result to camelCase candidate bridge', () {
      final payload = mapper.sceneUnderstandingResultToBridgePayload(
        _sceneUnderstandingResult(),
      );

      FirebaseSerializerValidators.requireCamelCasePayload(
        payload,
        'scene_understanding_bridge',
      );
      final result = payload['sceneUnderstandingResult'] as FirebaseJson;
      final coverage = result['coverage'] as FirebaseJson;
      final candidates = result['candidateObjects'] as List<Object?>;
      final placedObjects = result['placedObjects'] as List<Object?>;
      final confirmedObjects = result['confirmedObjects'] as List<Object?>;
      final fixtures = result['structuralFixtures'] as List<Object?>;
      final candidate = Map<String, Object?>.from(candidates.single as Map);
      final confirmed = Map<String, Object?>.from(
        confirmedObjects.single as Map,
      );
      final fixture = Map<String, Object?>.from(fixtures.single as Map);

      expect(result, containsPair('resultId', 'scene-result-1'));
      expect(result, containsPair('captureSessionId', 'session-1'));
      expect(result, containsPair('providerType', 'browser_cv'));
      expect(coverage, containsPair('frontWall', 'complete'));
      expect(candidate, containsPair('candidateId', 'candidate-bed-1'));
      expect(candidate, containsPair('coordinateSpace', 'image_pixels'));
      expect(candidate, containsPair('reviewLabel', 'Needs review'));
      expect(candidate, contains('boundingBox'));
      expect(candidate, isNot(contains('candidate_id')));
      expect(placedObjects, hasLength(1));
      expect(confirmed, containsPair('objectId', 'confirmed-bed-1'));
      expect(confirmed, containsPair('candidateId', 'candidate-bed-1'));
      expect(confirmed, contains('confirmedByUid'));
      expect(fixture, containsPair('fixtureId', 'window-1'));
      expect(fixture, containsPair('category', 'window'));
    });

    test('rejects snake_case bridge input before persistence mapping', () {
      expect(
        () => mapper.bridgeSceneToEditorScene(const {
          'scene_id': 'scene-1',
          'viewMode': '2d',
        }),
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

FirebaseSavedLayout _layout({String viewMode = '2d'}) {
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
    editorScene: {
      'scene_id': 'scene-1',
      'view_mode': viewMode,
      'selected': {'object_id': 'chair-1', 'object_type': 'furniture'},
    },
    furnitureObjects: const [
      FirebaseFurnitureObject(
        furnitureId: 'chair-1',
        category: FirebaseFurnitureCategory.chair,
        color: '#64748b',
        label: 'Desk chair',
        locked: false,
        positionM: FirebasePoint3d(x: 1, y: 0, z: 1),
        sizeM: FirebasePoint3d(x: 0.6, y: 0.8, z: 0.6),
        rotationDeg: 15.0,
      ),
    ],
    savedAt: _now,
    createdAt: _now,
    updatedAt: _now,
    schemaVersion: 1,
    exportVersion: 1,
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
