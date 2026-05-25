import 'package:app/src/layouts/layout_furniture_bridge_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('layout furniture bridge mapper', () {
    test('maps saved furniture to camelCase bridge state', () {
      final bridgeFurniture = savedFurnitureToBridge(const [
        {
          'id': 'chair-1',
          'category': 'chair',
          'label': 'Desk chair',
          'position': {'x': 1.2, 'y': 2.4},
          'size': {
            'width_meters': 0.6,
            'depth_meters': 0.7,
            'height_meters': 0.9,
          },
          'rotation_degrees': 15.0,
          'color': '#64748b',
          'locked': false,
        },
      ]);

      expect(bridgeFurniture, hasLength(1));
      expect(bridgeFurniture.single, containsPair('objectId', 'chair-1'));
      expect(bridgeFurniture.single, containsPair('category', 'chair'));
      expect(bridgeFurniture.single, containsPair('label', 'Desk chair'));
      expect(bridgeFurniture.single, containsPair('color', '#64748b'));
      expect(bridgeFurniture.single, containsPair('locked', false));
      expect(bridgeFurniture.single, containsPair('rotationDegrees', 15.0));
      expect(bridgeFurniture.single, isNot(contains('furniture_id')));
      expect(bridgeFurniture.single, isNot(contains('position_m')));
    });

    test('maps bridge furniture to snake_case layout save payload', () {
      final layoutFurniture = bridgeFurnitureToLayoutPayload(const [
        {
          'objectId': 'chair-1',
          'category': 'chair',
          'label': 'Desk chair',
          'size': {'widthMeters': 0.6, 'depthMeters': 0.7, 'heightMeters': 0.9},
          'position': {'x': 1.2, 'y': 2.4},
          'rotationDegrees': 15.0,
          'color': '#64748b',
          'locked': false,
        },
      ]);

      expect(layoutFurniture, hasLength(1));
      expect(layoutFurniture.single, containsPair('id', 'chair-1'));
      expect(layoutFurniture.single, containsPair('category', 'chair'));
      expect(layoutFurniture.single, containsPair('label', 'Desk chair'));
      expect(layoutFurniture.single, containsPair('color', '#64748b'));
      expect(layoutFurniture.single, containsPair('locked', false));
      expect(layoutFurniture.single, containsPair('rotation_degrees', 15.0));
      expect(layoutFurniture.single, isNot(contains('objectId')));
      expect(layoutFurniture.single, isNot(contains('rotationDegrees')));
    });
  });
}
