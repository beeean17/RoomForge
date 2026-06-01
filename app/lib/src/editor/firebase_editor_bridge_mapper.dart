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
        'providerType': result.providerType,
        'algorithmId': result.algorithmId,
        'modelId': result.modelId,
        'confidenceScore': result.confidenceScore,
        'qualityStatus': result.qualityStatus.wireValue,
        'failureReasonCode': result.failureReasonCode,
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

  double _numberValue(Object? value, double fallback) {
    return value is num ? value.toDouble() : fallback;
  }
}
