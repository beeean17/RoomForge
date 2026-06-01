import '../firebase/firebase_models.dart';
import '../firebase/firebase_serializers.dart';

class FirebaseEditorBridgeMapper {
  const FirebaseEditorBridgeMapper();

  FirebaseJson sceneToBridgePayload(FirebaseSavedLayout layout) {
    final editorScene = _recordValue(layout.editorScene);
    final floorPlanPayload = layout.floorPlan.toFirestoreJson();
    final metricGeometry = _metricGeometryFromFloorPlan(floorPlanPayload);
    final viewMode = editorScene['view_mode']?.toString() == '3d' ? '3d' : '2d';

    final payload = <String, Object?>{
      'scene': {
        'sceneId': _stringValue(
          editorScene['scene_id'],
          'layout-${layout.layoutId}-scene',
        ),
        'coordinateSpace': 'meters',
        'unit': layout.roomDimensions.unit,
        'viewMode': viewMode,
        'selected': _selectionToBridge(editorScene['selected']),
        'hasUnsavedChanges': false,
        'scale': {'metersPerSceneUnit': 1},
        'room': {
          'objectId': 'room-shell',
          'label': 'Room shell',
          'heightMeters': layout.roomDimensions.heightM,
          'floorPlan': {
            'floorPlanId': layout.floorPlanId,
            'metricGeometry': metricGeometry,
          },
        },
        'furniture': layout.furnitureObjects
            .map(furnitureObjectToBridgePayload)
            .toList(),
      },
    };
    FirebaseSerializerValidators.requireCamelCasePayload(
      payload,
      'editor_bridge',
    );
    return payload;
  }

  FirebaseJson openCvResultToBridgePayload(FirebaseOpenCvResult result) {
    result.validate();
    final payload = <String, Object?>{
      'candidateGeometry': {
        'resultId': result.resultId,
        'projectId': result.projectId,
        'jobId': result.jobId,
        'sourceImageId': result.sourceImageId,
        'coordinateSpace': result.coordinateSpace.wireValue,
        'candidateCorners': result.candidateCorners
            .map(point2dToBridgePayload)
            .toList(),
        'confidenceScore': result.confidenceScore,
        'qualityStatus': result.qualityStatus.wireValue,
      },
    };
    FirebaseSerializerValidators.requireCamelCasePayload(
      payload,
      'candidate_bridge',
    );
    return payload;
  }

  FirebaseJson confirmedGeometryToBridgePayload(
    FirebaseConfirmedGeometry geometry,
  ) {
    geometry.validate();
    final payload = <String, Object?>{
      'confirmedGeometry': {
        'geometryId': geometry.geometryId,
        'projectId': geometry.projectId,
        'jobId': geometry.jobId,
        'sourceImageId': geometry.sourceImageId,
        'opencvResultId': geometry.openCvResultId,
        'coordinateSpace': geometry.coordinateSpace.wireValue,
        'boundaryType': geometry.boundaryType.wireValue,
        'boundaryPoints': geometry.boundaryPoints
            .map(point2dToBridgePayload)
            .toList(),
        'correctionMethod': geometry.correctionMethod,
      },
    };
    FirebaseSerializerValidators.requireCamelCasePayload(
      payload,
      'confirmed_bridge',
    );
    return payload;
  }

  FirebaseJson floorPlanToBridgePayload(FirebaseFloorPlan floorPlan) {
    floorPlan.validate();
    final payload = <String, Object?>{
      'floorPlan': {
        'floorPlanId': floorPlan.floorPlanId,
        'coordinateSpace': floorPlan.coordinateSpace.wireValue,
        'metricGeometry': {
          'coordinateSpace': 'meters',
          'points': floorPlan.floorPolygon.map(point2dToBridgePayload).toList(),
        },
        'qualityStatus': floorPlan.qualityStatus.wireValue,
        'warnings': floorPlan.warnings,
      },
    };
    FirebaseSerializerValidators.requireCamelCasePayload(
      payload,
      'floor_plan_bridge',
    );
    return payload;
  }

  FirebaseJson sceneUnderstandingResultToBridgePayload(
    FirebaseSceneUnderstandingResult result,
  ) {
    result.validate();
    final payload = <String, Object?>{
      'sceneUnderstandingResult': {
        'resultId': result.resultId,
        'projectId': result.projectId,
        'captureSessionId': result.captureSessionId,
        'jobId': result.jobId,
        'providerType': result.providerType.wireValue,
        'algorithmId': result.algorithmId,
        'modelId': result.modelId,
        'confidenceScore': result.confidenceScore,
        'qualityStatus': result.qualityStatus.wireValue,
        'failureReasonCode': result.failureReasonCode?.wireValue,
        'failureReason': result.failureReason,
        'coverage': _camelCaseNested(result.coverage),
        'candidateObjects': result.candidateObjects
            .map(candidateSceneObjectToBridgePayload)
            .toList(),
        'placedObjects': result.placedObjects
            .map(placedSceneObjectToBridgePayload)
            .toList(),
        'confirmedObjects': result.confirmedObjects
            .map(confirmedSceneObjectToBridgePayload)
            .toList(),
        'structuralFixtures': result.structuralFixtures
            .map(structuralFixtureToBridgePayload)
            .toList(),
      },
    };
    FirebaseSerializerValidators.requireCamelCasePayload(
      payload,
      'scene_understanding_bridge',
    );
    return _withoutNulls(payload);
  }

  FirebaseSceneUnderstandingResult sceneUnderstandingResultFromBridgePayload({
    required FirebaseJson bridgePayload,
    required String projectId,
    required String ownerUid,
    required String resultId,
    required DateTime now,
  }) {
    FirebaseSerializerValidators.requireCamelCasePayload(
      bridgePayload,
      'scene_understanding_bridge',
    );
    final result = _recordValue(bridgePayload['sceneUnderstandingResult']);
    final candidateObjects = _listValue(result['candidateObjects'])
        .map(_recordValue)
        .where((object) => object.isNotEmpty)
        .map(_candidateSceneObjectFromBridgePayload)
        .toList();
    final placedObjects = _listValue(result['placedObjects'])
        .map(_recordValue)
        .where((object) => object.isNotEmpty)
        .map(_placedSceneObjectFromBridgePayload)
        .toList();
    final confirmedObjects = _listValue(result['confirmedObjects'])
        .map(_recordValue)
        .where((object) => object.isNotEmpty)
        .map(
          (object) => _confirmedSceneObjectFromBridgePayload(
            object,
            ownerUid: ownerUid,
            fallbackConfirmedAt: now,
          ),
        )
        .toList();
    final structuralFixtures = _listValue(result['structuralFixtures'])
        .map(_recordValue)
        .where((fixture) => fixture.isNotEmpty)
        .map(_structuralFixtureFromBridgePayload)
        .toList();
    final failureReasonCode = _sceneUnderstandingFailureReason(
      result['failureReasonCode'],
    );
    final confidenceScore = _optionalNumberValue(result['confidenceScore']);
    final coverage = _recordValue(_snakeCaseNested(result['coverage']));

    return FirebaseSceneUnderstandingResult(
      resultId: resultId,
      projectId: projectId,
      ownerUid: ownerUid,
      captureSessionId: _stringValue(
        result['captureSessionId'],
        'capture-session-unknown',
      ),
      jobId: _optionalStringValue(result['jobId']),
      providerType: _sceneUnderstandingProviderType(result['providerType']),
      algorithmId: _stringValue(
        result['algorithmId'],
        'browser-scene-understanding-v1',
      ),
      modelId: _optionalStringValue(result['modelId']),
      confidenceScore: confidenceScore,
      qualityStatus: _qualityStatusFromBridge(
        result['qualityStatus'],
        confidenceScore: confidenceScore,
        hasCandidateObjects: candidateObjects.isNotEmpty,
        failureReasonCode: failureReasonCode,
      ),
      failureReasonCode: failureReasonCode,
      failureReason: _optionalStringValue(result['failureReason']),
      coverage: coverage,
      candidateObjects: candidateObjects,
      placedObjects: placedObjects,
      confirmedObjects: confirmedObjects,
      structuralFixtures: structuralFixtures,
      processingStartedAt: _optionalDateValue(result['processingStartedAt']),
      processingCompletedAt: _optionalDateValue(
        result['processingCompletedAt'],
      ),
      createdAt: _optionalDateValue(result['createdAt']) ?? now,
      updatedAt: now,
      schemaVersion: 1,
    );
  }

  FirebaseJson captureSessionToBridgePayload(
    FirebaseCaptureSession session,
    List<FirebaseCaptureImage> images,
  ) {
    for (final image in images) {
      image.validate();
    }
    final sortedImages = [...images]
      ..sort(
        (a, b) => (a.captureOrder ?? _captureImageRoleOrder(a.role)).compareTo(
          b.captureOrder ?? _captureImageRoleOrder(b.role),
        ),
      );
    final payload = <String, Object?>{
      'captureSession': {
        'captureSessionId': session.captureSessionId,
        'projectId': session.projectId,
        'roomDimensionsId': session.roomDimensionsId,
        'captureMethod': session.captureMethod.wireValue,
        'depthEnabled': session.depthEnabled,
        'startedAt': session.startedAt?.toUtc().toIso8601String(),
        'completedAt': session.completedAt?.toUtc().toIso8601String(),
        'notes': session.notes,
        'availableRoles': sortedImages
            .map((image) => image.role.wireValue)
            .toSet()
            .toList(growable: false),
        'images': sortedImages.map(captureImageToBridgePayload).toList(),
      },
    };
    FirebaseSerializerValidators.requireCamelCasePayload(
      payload,
      'capture_session_bridge',
    );
    return _withoutNulls(payload);
  }

  FirebaseJson captureImageToBridgePayload(FirebaseCaptureImage image) {
    image.validate();
    final payload = <String, Object?>{
      'captureImageId': image.captureImageId,
      'captureSessionId': image.captureSessionId,
      'sourceImageId': image.sourceImageId,
      'role': image.role.wireValue,
      'storagePath': image.storagePath,
      'contentType': image.contentType.wireValue,
      'widthPx': image.widthPx,
      'heightPx': image.heightPx,
      'captureOrder': image.captureOrder,
      'guidanceState': image.guidanceState,
      'depthArtifactRefs': image.depthArtifactRefs
          .map(
            (ref) => {
              'artifactId': ref.artifactId,
              'artifactType': ref.artifactType,
              'storagePath': ref.storagePath,
              'contentType': ref.contentType.wireValue,
              'byteSize': ref.byteSize,
            },
          )
          .toList(),
      'cameraPose': _camelCaseNested(image.cameraPose),
    };
    FirebaseSerializerValidators.requireCamelCasePayload(
      payload,
      'capture_image_bridge',
    );
    return _withoutNulls(payload);
  }

  FirebaseJson bridgeSceneToEditorScene(FirebaseJson bridgeScene) {
    FirebaseSerializerValidators.requireCamelCasePayload(
      bridgeScene,
      'bridge_scene',
    );
    final selected = _recordValue(bridgeScene['selected']);
    return _snakeCasePayload({
      'scene_id': _stringValue(bridgeScene['sceneId'], 'scene'),
      'view_mode': _stringValue(bridgeScene['viewMode'], '2d'),
      'selected': selected.isEmpty
          ? null
          : {
              'object_id': _stringValue(selected['objectId'], ''),
              'object_type': _stringValue(selected['objectType'], 'room'),
            },
      'has_unsaved_changes': bridgeScene['hasUnsavedChanges'] == true,
    });
  }

  List<FirebaseJson> bridgeFurnitureToFirestore(FirebaseJson bridgeScene) {
    FirebaseSerializerValidators.requireCamelCasePayload(
      bridgeScene,
      'bridge_scene',
    );
    return _listValue(
      bridgeScene['furniture'],
    ).map(_recordValue).where((item) => item.isNotEmpty).map((item) {
      final size = _recordValue(item['size']);
      final position = _recordValue(item['position']);
      return _snakeCasePayload({
        'furniture_id': _stringValue(item['objectId'], ''),
        'category': _stringValue(item['category'], 'custom'),
        'position_m': {
          'x': _numberValue(position['x'], 0),
          'y': 0.0,
          'z': _numberValue(position['y'], 0),
        },
        'size_m': {
          'x': _numberValue(size['widthMeters'], 0),
          'y': _numberValue(size['heightMeters'], 0),
          'z': _numberValue(size['depthMeters'], 0),
        },
        'rotation_deg': _numberValue(item['rotationDegrees'], 0),
        'color': item['color']?.toString(),
        'label': item['label']?.toString(),
        'locked': item['locked'] is bool ? item['locked'] as bool : null,
      });
    }).toList();
  }

  FirebaseJson furnitureObjectToBridgePayload(FirebaseFurnitureObject object) {
    final payload = <String, Object?>{
      'objectId': object.furnitureId,
      'category': object.category.wireValue,
      'label': object.label ?? _categoryLabel(object.category),
      'size': {
        'widthMeters': object.sizeM.x,
        'depthMeters': object.sizeM.z,
        'heightMeters': object.sizeM.y,
      },
      'position': {'x': object.positionM.x, 'y': object.positionM.z},
      'rotationDegrees': object.rotationDeg,
      'color': object.color ?? '#64748b',
      'locked': object.locked,
    };
    FirebaseSerializerValidators.requireCamelCasePayload(
      payload,
      'furniture_bridge',
    );
    return _withoutNulls(payload);
  }

  FirebaseJson candidateSceneObjectToBridgePayload(
    FirebaseCandidateSceneObject object,
  ) {
    object.validate();
    final payload = <String, Object?>{
      'candidateId': object.candidateId,
      'objectType': object.objectType.wireValue,
      'category': object.category,
      'label': object.label,
      'sourceImageId': object.sourceImageId,
      'captureImageId': object.captureImageId,
      'sourceImageRole': object.sourceImageRole.wireValue,
      'coordinateSpace': object.coordinateSpace.wireValue,
      'boundingBox': {
        'x': object.boundingBox.x,
        'y': object.boundingBox.y,
        'width': object.boundingBox.width,
        'height': object.boundingBox.height,
      },
      'confidenceScore': object.confidenceScore,
      'reviewState': object.reviewState.wireValue,
      'reviewLabel': object.reviewState.displayLabel,
      'suggestedAssetId': object.suggestedAssetId,
      'suggestedPosition': _point3dToBridgePayload(object.suggestedPositionM),
      'suggestedSize': _point3dToBridgePayload(object.suggestedSizeM),
      'suggestedRotationDegrees': object.suggestedRotationDeg,
      'notes': object.notes,
    };
    FirebaseSerializerValidators.requireCamelCasePayload(
      payload,
      'candidate_scene_object_bridge',
    );
    return _withoutNulls(payload);
  }

  FirebaseJson placedSceneObjectToBridgePayload(
    FirebasePlacedSceneObject object,
  ) {
    object.validate();
    final payload = <String, Object?>{
      'objectId': object.objectId,
      'candidateId': object.candidateId,
      'objectType': object.objectType.wireValue,
      'category': object.category,
      'assetId': object.assetId,
      'label': object.label,
      'position': _point3dToBridgePayload(object.positionM),
      'size': _point3dToBridgePayload(object.sizeM),
      'rotationDegrees': object.rotationDeg,
      'confidenceScore': object.confidenceScore,
      'locked': object.locked,
    };
    FirebaseSerializerValidators.requireCamelCasePayload(
      payload,
      'placed_scene_object_bridge',
    );
    return _withoutNulls(payload);
  }

  FirebaseJson confirmedSceneObjectToBridgePayload(
    FirebaseConfirmedSceneObject object,
  ) {
    object.validate();
    final payload = <String, Object?>{
      'objectId': object.objectId,
      'candidateId': object.candidateId,
      'objectType': object.objectType.wireValue,
      'category': object.category,
      'assetId': object.assetId,
      'label': object.label,
      'position': _point3dToBridgePayload(object.positionM),
      'size': _point3dToBridgePayload(object.sizeM),
      'rotationDegrees': object.rotationDeg,
      'confirmedByUid': object.confirmedByUid,
      'confirmedAt': object.confirmedAt.toUtc().toIso8601String(),
      'locked': object.locked,
    };
    FirebaseSerializerValidators.requireCamelCasePayload(
      payload,
      'confirmed_scene_object_bridge',
    );
    return _withoutNulls(payload);
  }

  FirebaseJson structuralFixtureToBridgePayload(
    FirebaseStructuralFixture fixture,
  ) {
    fixture.validate();
    final payload = <String, Object?>{
      'fixtureId': fixture.fixtureId,
      'candidateId': fixture.candidateId,
      'category': fixture.category.wireValue,
      'wallId': fixture.wallId,
      'label': fixture.label,
      'position': _point3dToBridgePayload(fixture.positionM),
      'size': _point3dToBridgePayload(fixture.sizeM),
      'rotationDegrees': fixture.rotationDeg,
      'confidenceScore': fixture.confidenceScore,
      'locked': fixture.locked,
    };
    FirebaseSerializerValidators.requireCamelCasePayload(
      payload,
      'structural_fixture_bridge',
    );
    return _withoutNulls(payload);
  }

  FirebaseCandidateSceneObject _candidateSceneObjectFromBridgePayload(
    FirebaseJson object,
  ) {
    final boundingBox = _recordValue(object['boundingBox']);
    return FirebaseCandidateSceneObject(
      candidateId: _stringValue(object['candidateId'], 'candidate-unknown'),
      objectType: _sceneObjectType(object['objectType']),
      category: _stringValue(object['category'], 'custom'),
      label: _optionalStringValue(object['label']),
      sourceImageId: _stringValue(
        object['sourceImageId'],
        'source-image-unknown',
      ),
      captureImageId: _stringValue(
        object['captureImageId'],
        'capture-image-unknown',
      ),
      sourceImageRole: _captureImageRole(object['sourceImageRole']),
      coordinateSpace: _coordinateSpace(object['coordinateSpace']),
      boundingBox: FirebaseBoundingBox(
        x: _numberValue(boundingBox['x'], 0),
        y: _numberValue(boundingBox['y'], 0),
        width: _positiveNumberValue(boundingBox['width'], 1),
        height: _positiveNumberValue(boundingBox['height'], 1),
      ),
      confidenceScore: _clampedConfidence(object['confidenceScore']),
      reviewState: _candidateReviewState(object['reviewState']),
      suggestedAssetId: _optionalStringValue(object['suggestedAssetId']),
      suggestedPositionM: _optionalPoint3d(
        object['suggestedPosition'] ?? object['suggestedPositionM'],
      ),
      suggestedSizeM: _optionalPoint3d(
        object['suggestedSize'] ?? object['suggestedSizeM'],
      ),
      suggestedRotationDeg: _optionalNumberValue(
        object['suggestedRotationDegrees'] ?? object['suggestedRotationDeg'],
      ),
      notes: _optionalStringValue(object['notes']),
    );
  }

  FirebasePlacedSceneObject _placedSceneObjectFromBridgePayload(
    FirebaseJson object,
  ) {
    return FirebasePlacedSceneObject(
      objectId: _stringValue(object['objectId'], 'placed-object-unknown'),
      candidateId: _optionalStringValue(object['candidateId']),
      objectType: _sceneObjectType(object['objectType']),
      category: _stringValue(object['category'], 'custom'),
      assetId: _optionalStringValue(object['assetId']),
      label: _optionalStringValue(object['label']),
      positionM: _point3dWithFallback(object['position']),
      sizeM: _point3dWithFallback(object['size'], positiveFallback: 1),
      rotationDeg: _numberValue(object['rotationDegrees'], 0),
      confidenceScore: _optionalNumberValue(object['confidenceScore']),
      locked: object['locked'] is bool ? object['locked'] as bool : null,
    );
  }

  FirebaseConfirmedSceneObject _confirmedSceneObjectFromBridgePayload(
    FirebaseJson object, {
    required String ownerUid,
    required DateTime fallbackConfirmedAt,
  }) {
    return FirebaseConfirmedSceneObject(
      objectId: _stringValue(object['objectId'], 'confirmed-object-unknown'),
      candidateId: _optionalStringValue(object['candidateId']),
      objectType: _sceneObjectType(object['objectType']),
      category: _stringValue(object['category'], 'custom'),
      assetId: _optionalStringValue(object['assetId']),
      label: _optionalStringValue(object['label']),
      positionM: _point3dWithFallback(object['position']),
      sizeM: _point3dWithFallback(object['size'], positiveFallback: 1),
      rotationDeg: _numberValue(object['rotationDegrees'], 0),
      confirmedByUid: _stringValue(object['confirmedByUid'], ownerUid),
      confirmedAt:
          _optionalDateValue(object['confirmedAt']) ?? fallbackConfirmedAt,
      locked: object['locked'] is bool ? object['locked'] as bool : null,
    );
  }

  FirebaseStructuralFixture _structuralFixtureFromBridgePayload(
    FirebaseJson fixture,
  ) {
    return FirebaseStructuralFixture(
      fixtureId: _stringValue(fixture['fixtureId'], 'fixture-unknown'),
      candidateId: _optionalStringValue(fixture['candidateId']),
      category: _structuralFixtureCategory(fixture['category']),
      wallId: _stringValue(fixture['wallId'], 'room-shell'),
      label: _optionalStringValue(fixture['label']),
      positionM: _point3dWithFallback(fixture['position']),
      sizeM: _point3dWithFallback(fixture['size'], positiveFallback: 1),
      rotationDeg: _numberValue(fixture['rotationDegrees'], 0),
      confidenceScore: _optionalNumberValue(fixture['confidenceScore']),
      locked: fixture['locked'] is bool ? fixture['locked'] as bool : null,
    );
  }

  FirebaseJson point2dToBridgePayload(FirebasePoint2d point) {
    return {'x': point.x, 'y': point.y};
  }

  FirebaseJson _metricGeometryFromFloorPlan(FirebaseJson floorPlanPayload) {
    final points = _listValue(floorPlanPayload['floor_polygon'])
        .map(_recordValue)
        .map(
          (point) => {
            'x': _numberValue(point['x'], 0),
            'y': _numberValue(point['y'], 0),
          },
        )
        .toList();
    return {'coordinateSpace': 'meters', 'points': points};
  }

  FirebaseJson? _selectionToBridge(Object? value) {
    final selected = _recordValue(value);
    final objectId = selected['object_id'] ?? selected['objectId'];
    if (objectId == null) {
      return null;
    }
    return {
      'objectId': objectId.toString(),
      'objectType': selected['object_type']?.toString() == 'furniture'
          ? 'furniture'
          : 'room',
    };
  }

  String _categoryLabel(FirebaseFurnitureCategory category) {
    return switch (category) {
      FirebaseFurnitureCategory.bed => 'Bed',
      FirebaseFurnitureCategory.desk => 'Desk',
      FirebaseFurnitureCategory.chair => 'Chair',
      FirebaseFurnitureCategory.wardrobe => 'Wardrobe',
      FirebaseFurnitureCategory.sofa => 'Sofa',
      FirebaseFurnitureCategory.table => 'Table',
      FirebaseFurnitureCategory.shelf => 'Shelf',
      FirebaseFurnitureCategory.cabinet => 'Cabinet',
      FirebaseFurnitureCategory.custom => 'Custom',
    };
  }

  FirebaseJson? _point3dToBridgePayload(FirebasePoint3d? point) {
    if (point == null) {
      return null;
    }
    return {'x': point.x, 'y': point.y, 'z': point.z};
  }

  Object? _camelCaseNested(Object? value) {
    if (value is Map) {
      return {
        for (final entry in value.entries)
          _snakeToCamel(entry.key.toString()): _camelCaseNested(entry.value),
      };
    }
    if (value is Iterable) {
      return value.map(_camelCaseNested).toList();
    }
    return value;
  }

  Object? _snakeCaseNested(Object? value) {
    if (value is Map) {
      return {
        for (final entry in value.entries)
          _camelToSnake(entry.key.toString()): _snakeCaseNested(entry.value),
      };
    }
    if (value is Iterable) {
      return value.map(_snakeCaseNested).toList();
    }
    return value;
  }

  String _snakeToCamel(String value) {
    final parts = value.split('_');
    if (parts.isEmpty) {
      return value;
    }
    return [
      parts.first,
      ...parts
          .skip(1)
          .map(
            (part) => part.isEmpty
                ? part
                : '${part[0].toUpperCase()}${part.substring(1)}',
          ),
    ].join();
  }

  String _camelToSnake(String value) {
    return value.replaceAllMapped(
      RegExp(r'(?<=[a-z0-9])[A-Z]'),
      (match) => '_${match.group(0)!.toLowerCase()}',
    );
  }

  FirebaseJson _snakeCasePayload(FirebaseJson payload) {
    final compact = _withoutNulls(payload);
    FirebaseSerializerValidators.requireSnakeCasePayload(
      compact,
      'firestore_bridge',
    );
    return compact;
  }

  FirebaseJson _withoutNulls(FirebaseJson json) {
    return {
      for (final entry in json.entries)
        if (entry.value != null) entry.key: entry.value,
    };
  }

  FirebaseJson _recordValue(Object? value) {
    if (value is Map<String, Object?>) {
      return value;
    }
    return value is Map ? Map<String, Object?>.from(value) : {};
  }

  List<Object?> _listValue(Object? value) {
    return value is List ? value.cast<Object?>() : const [];
  }

  String _stringValue(Object? value, String fallback) {
    return value is String && value.isNotEmpty ? value : fallback;
  }

  String? _optionalStringValue(Object? value) {
    return value is String && value.isNotEmpty ? value : null;
  }

  double _numberValue(Object? value, double fallback) {
    return value is num ? value.toDouble() : fallback;
  }

  double? _optionalNumberValue(Object? value) {
    return value is num ? value.toDouble() : null;
  }

  double _positiveNumberValue(Object? value, double fallback) {
    final parsed = _numberValue(value, fallback);
    return parsed > 0 ? parsed : fallback;
  }

  double _clampedConfidence(Object? value) {
    final parsed = _numberValue(value, 0);
    if (parsed < 0) {
      return 0;
    }
    if (parsed > 1) {
      return 1;
    }
    return parsed;
  }

  DateTime? _optionalDateValue(Object? value) {
    if (value is DateTime) {
      return value.toUtc();
    }
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value)?.toUtc();
    }
    return null;
  }

  FirebasePoint3d? _optionalPoint3d(Object? value) {
    if (value is! Map) {
      return null;
    }
    final point = Map<String, Object?>.from(value);
    if (point['x'] is! num || point['y'] is! num || point['z'] is! num) {
      return null;
    }
    return FirebasePoint3d(
      x: (point['x'] as num).toDouble(),
      y: (point['y'] as num).toDouble(),
      z: (point['z'] as num).toDouble(),
    );
  }

  FirebasePoint3d _point3dWithFallback(
    Object? value, {
    double positiveFallback = 0,
  }) {
    return _optionalPoint3d(value) ??
        FirebasePoint3d(
          x: positiveFallback,
          y: positiveFallback,
          z: positiveFallback,
        );
  }

  FirebaseSceneUnderstandingProviderType _sceneUnderstandingProviderType(
    Object? value,
  ) {
    final provider = value?.toString() ?? '';
    if (provider.startsWith('browser_cv')) {
      return FirebaseSceneUnderstandingProviderType.browserCv;
    }
    try {
      return FirebaseSceneUnderstandingProviderType.fromWireValue(provider);
    } on FirebaseContractException {
      return FirebaseSceneUnderstandingProviderType.browserCv;
    }
  }

  FirebaseSceneUnderstandingFailureReason? _sceneUnderstandingFailureReason(
    Object? value,
  ) {
    final reason = value?.toString();
    if (reason == null || reason.isEmpty) {
      return null;
    }
    final normalized = reason == 'no_capture_images'
        ? 'no_source_images'
        : reason;
    try {
      return FirebaseSceneUnderstandingFailureReason.fromWireValue(normalized);
    } on FirebaseContractException {
      return FirebaseSceneUnderstandingFailureReason.detectorFailed;
    }
  }

  FirebaseQualityStatus _qualityStatusFromBridge(
    Object? value, {
    required double? confidenceScore,
    required bool hasCandidateObjects,
    required FirebaseSceneUnderstandingFailureReason? failureReasonCode,
  }) {
    if (value is String && value.isNotEmpty) {
      try {
        return FirebaseQualityStatus.fromWireValue(value);
      } on FirebaseContractException {
        // Fall back to signal-based resolution below.
      }
    }
    return FirebaseSceneUnderstandingQualityResolver.fromSignal(
      confidenceScore: confidenceScore,
      hasCandidateObjects: hasCandidateObjects,
      failureReasonCode: failureReasonCode,
    );
  }

  FirebaseSceneObjectType _sceneObjectType(Object? value) {
    final type = value?.toString();
    if (type == null || type.isEmpty) {
      return FirebaseSceneObjectType.furniture;
    }
    try {
      return FirebaseSceneObjectType.fromWireValue(type);
    } on FirebaseContractException {
      return FirebaseSceneObjectType.furniture;
    }
  }

  FirebaseCandidateReviewState _candidateReviewState(Object? value) {
    final state = value?.toString();
    if (state == null || state == 'new' || state.isEmpty) {
      return FirebaseCandidateReviewState.suggested;
    }
    try {
      return FirebaseCandidateReviewState.fromWireValue(state);
    } on FirebaseContractException {
      return FirebaseCandidateReviewState.reviewRequired;
    }
  }

  FirebaseCaptureImageRole _captureImageRole(Object? value) {
    final role = value?.toString();
    if (role == null || role.isEmpty) {
      return FirebaseCaptureImageRole.overview;
    }
    try {
      return FirebaseCaptureImageRole.fromWireValue(role);
    } on FirebaseContractException {
      return FirebaseCaptureImageRole.overview;
    }
  }

  FirebaseCoordinateSpace _coordinateSpace(Object? value) {
    final coordinateSpace = value?.toString();
    if (coordinateSpace == null || coordinateSpace.isEmpty) {
      return FirebaseCoordinateSpace.imagePixels;
    }
    try {
      return FirebaseCoordinateSpace.fromWireValue(coordinateSpace);
    } on FirebaseContractException {
      return FirebaseCoordinateSpace.imagePixels;
    }
  }

  FirebaseStructuralFixtureCategory _structuralFixtureCategory(Object? value) {
    final category = value?.toString();
    if (category == null || category.isEmpty) {
      return FirebaseStructuralFixtureCategory.custom;
    }
    try {
      return FirebaseStructuralFixtureCategory.fromWireValue(category);
    } on FirebaseContractException {
      return FirebaseStructuralFixtureCategory.custom;
    }
  }

  int _captureImageRoleOrder(FirebaseCaptureImageRole role) {
    return switch (role) {
      FirebaseCaptureImageRole.overview => 0,
      FirebaseCaptureImageRole.frontWall => 1,
      FirebaseCaptureImageRole.rightWall => 2,
      FirebaseCaptureImageRole.backWall => 3,
      FirebaseCaptureImageRole.leftWall => 4,
      FirebaseCaptureImageRole.extra => 5,
    };
  }
}
