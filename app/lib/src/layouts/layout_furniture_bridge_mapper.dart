typedef LayoutJson = Map<String, Object?>;

List<LayoutJson> savedFurnitureToBridge(List<Object?> furnitureObjects) {
  final objects = <LayoutJson>[];
  for (final item in furnitureObjects) {
    final furniture = _recordValue(item);
    if (furniture.isEmpty) {
      continue;
    }
    final size = _recordValue(furniture['size']);
    final position = _recordValue(furniture['position']);
    final category = furniture['category']?.toString();
    objects.add(
      _withoutNulls({
        'objectId': furniture['id']?.toString() ?? '',
        'category': category ?? 'chair',
        'label': furniture['label']?.toString() ?? _furnitureLabel(category),
        'size': {
          'widthMeters': _numberValue(size['width_meters'], 0.6),
          'depthMeters': _numberValue(size['depth_meters'], 0.6),
          'heightMeters': _numberValue(size['height_meters'], 0.8),
        },
        'position': {
          'x': _numberValue(position['x'], 1),
          'y': _numberValue(position['y'], 1),
        },
        'rotationDegrees': _numberValue(furniture['rotation_degrees'], 0),
        'color': furniture['color']?.toString() ?? '#64748b',
        'locked': furniture['locked'] is bool
            ? furniture['locked'] as bool
            : null,
      }),
    );
  }
  return objects;
}

List<LayoutJson> bridgeFurnitureToLayoutPayload(Object? furnitureObjects) {
  final objects = <LayoutJson>[];
  for (final item in _listValue(furnitureObjects)) {
    final furniture = _recordValue(item);
    if (furniture.isEmpty) {
      continue;
    }
    final size = _recordValue(furniture['size']);
    final position = _recordValue(furniture['position']);
    objects.add(
      _withoutNulls({
        'id': furniture['objectId']?.toString() ?? '',
        'category': furniture['category']?.toString() ?? 'unknown',
        'position': {
          'x': _numberValue(position['x'], 0),
          'y': _numberValue(position['y'], 0),
        },
        'size': {
          'width_meters': _numberValue(size['widthMeters'], 0),
          'depth_meters': _numberValue(size['depthMeters'], 0),
          'height_meters': _numberValue(size['heightMeters'], 0),
        },
        'rotation_degrees': _numberValue(furniture['rotationDegrees'], 0),
        'color': furniture['color']?.toString() ?? '#64748b',
        'label': furniture['label']?.toString(),
        'locked': furniture['locked'] is bool
            ? furniture['locked'] as bool
            : null,
      }),
    );
  }
  return objects;
}

String _furnitureLabel(String? category) {
  return switch (category) {
    'table' => 'Table',
    'sofa' => 'Sofa',
    _ => 'Chair',
  };
}

LayoutJson _recordValue(Object? value) {
  return value is Map ? Map<String, Object?>.from(value) : {};
}

List<Object?> _listValue(Object? value) {
  return value is List ? value.cast<Object?>() : const [];
}

double _numberValue(Object? value, double fallback) {
  return value is num ? value.toDouble() : fallback;
}

LayoutJson _withoutNulls(LayoutJson json) {
  return {
    for (final entry in json.entries)
      if (entry.value != null) entry.key: entry.value,
  };
}
