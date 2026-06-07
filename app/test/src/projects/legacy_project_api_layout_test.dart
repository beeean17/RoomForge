import 'dart:async';
import 'dart:convert';

import 'package:app/src/auth/auth_repository.dart';
import 'package:app/src/projects/project_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'LegacyProjectApi saveLayout posts and parses room and furniture state',
    () async {
      late http.Request capturedRequest;
      final api = LegacyProjectApi(
        authRepository: const _TokenAuthRepository('token-1'),
        baseUrl: 'https://api.example.test',
        client: MockClient((request) async {
          capturedRequest = request;
          final payload = jsonDecode(request.body) as Map<String, Object?>;
          final furniture =
              (payload['furniture_objects'] as List).single as Map;
          final size = furniture['size'] as Map;

          expect(request.method, 'POST');
          expect(
            request.url.toString(),
            'https://api.example.test/room-projects/project-1/layouts',
          );
          expect(request.headers['Authorization'], 'Bearer token-1');
          expect(payload['room_dimensions'], containsPair('unit', 'meters'));
          expect(
            payload['floor_plan'],
            containsPair('coordinate_space', 'meters'),
          );
          expect(
            payload['source_metadata'],
            containsPair('source_image_id', 7),
          );
          expect(furniture, containsPair('id', 'furniture-chair-1'));
          expect(furniture, containsPair('category', 'chair'));
          expect(furniture, containsPair('position', {'x': 1.2, 'y': 1.4}));
          expect(size, containsPair('width_meters', 0.55));
          expect(size, containsPair('depth_meters', 0.55));
          expect(size, containsPair('height_meters', 0.85));
          expect(furniture, containsPair('rotation_degrees', 15.0));
          expect(furniture, containsPair('color', '#64748b'));

          return http.Response(
            jsonEncode({
              'data': {
                'layout': {
                  'id': 11,
                  'project_id': 1,
                  'user_id': 42,
                  'room_dimensions': payload['room_dimensions'],
                  'floor_plan': payload['floor_plan'],
                  'source_metadata': payload['source_metadata'],
                  'furniture_objects': payload['furniture_objects'],
                  'editor_scene': payload['editor_scene'],
                  'created_at': '2026-05-29T00:00:00Z',
                  'updated_at': '2026-05-29T00:00:01Z',
                },
              },
              'error': null,
              'meta': {'request_id': 'req-1'},
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final saved = await api.saveLayout(
        projectId: 'project-1',
        roomDimensions: const {
          'unit': 'meters',
          'width_value': 4.2,
          'depth_value': 3.6,
          'height_value': 2.7,
        },
        floorPlan: const {
          'coordinate_space': 'meters',
          'points': [
            {'x': 0, 'y': 0},
            {'x': 4.2, 'y': 0},
            {'x': 4.2, 'y': 3.6},
            {'x': 0, 'y': 3.6},
          ],
        },
        sourceMetadata: const {
          'source_image_id': 7,
          'reconstruction_job_id': 9,
        },
        furnitureObjects: const [
          {
            'id': 'furniture-chair-1',
            'category': 'chair',
            'position': {'x': 1.2, 'y': 1.4},
            'size': {
              'width_meters': 0.55,
              'depth_meters': 0.55,
              'height_meters': 0.85,
            },
            'rotation_degrees': 15.0,
            'color': '#64748b',
          },
        ],
        editorScene: const {'scene_id': 'scene-1'},
      );

      final savedFurniture = Map<String, Object?>.from(
        saved.furnitureObjects.single as Map,
      );

      expect(capturedRequest.headers['Content-Type'], 'application/json');
      expect(saved.id, '11');
      expect(saved.projectId, '1');
      expect(saved.userId, '42');
      expect(saved.roomDimensions['height_value'], 2.7);
      expect(saved.floorPlan['coordinate_space'], 'meters');
      expect(saved.sourceMetadata['reconstruction_job_id'], 9);
      expect(savedFurniture['id'], 'furniture-chair-1');
      expect(savedFurniture['rotation_degrees'], 15.0);
      expect(savedFurniture['color'], '#64748b');
    },
  );

  test(
    'LegacyProjectApi loadLatestLayout fetches saved room and furniture state',
    () async {
      late http.Request capturedRequest;
      final api = LegacyProjectApi(
        authRepository: const _TokenAuthRepository('token-1'),
        baseUrl: 'https://api.example.test',
        client: MockClient((request) async {
          capturedRequest = request;
          expect(request.method, 'GET');
          expect(
            request.url.toString(),
            'https://api.example.test/room-projects/project-1/layouts/latest',
          );
          expect(request.headers['Authorization'], 'Bearer token-1');

          return http.Response(
            jsonEncode({
              'data': {
                'layout': {
                  'id': 11,
                  'project_id': 1,
                  'user_id': 42,
                  'room_dimensions': {
                    'unit': 'meters',
                    'width_value': 4.2,
                    'depth_value': 3.6,
                    'height_value': 2.7,
                  },
                  'floor_plan': {
                    'coordinate_space': 'meters',
                    'metric_geometry': {
                      'coordinate_space': 'meters',
                      'points': [
                        {'x': 0, 'y': 0},
                        {'x': 4.2, 'y': 0},
                        {'x': 4.2, 'y': 3.6},
                        {'x': 0, 'y': 3.6},
                      ],
                    },
                  },
                  'source_metadata': {
                    'source_image_id': 7,
                    'reconstruction_job_id': 9,
                  },
                  'furniture_objects': [
                    {
                      'id': 'furniture-chair-1',
                      'category': 'chair',
                      'position': {'x': 1.2, 'y': 1.4},
                      'size': {
                        'width_meters': 0.55,
                        'depth_meters': 0.55,
                        'height_meters': 0.85,
                      },
                      'rotation_degrees': 15.0,
                      'color': '#64748b',
                    },
                  ],
                  'editor_scene': {
                    'scene_id': 'scene-1',
                    'view_mode': '3d',
                    'selected': {
                      'object_id': 'furniture-chair-1',
                      'object_type': 'furniture',
                    },
                  },
                  'created_at': '2026-05-29T00:00:00Z',
                  'updated_at': '2026-05-29T00:00:01Z',
                },
              },
              'error': null,
              'meta': {'request_id': 'req-1'},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final loaded = await api.loadLatestLayout(projectId: 'project-1');
      final loadedFurniture = Map<String, Object?>.from(
        loaded.furnitureObjects.single as Map,
      );

      expect(capturedRequest.headers['Content-Type'], 'application/json');
      expect(loaded.id, '11');
      expect(loaded.roomDimensions['width_value'], 4.2);
      expect(loaded.floorPlan['coordinate_space'], 'meters');
      expect(loaded.sourceMetadata['source_image_id'], 7);
      expect(loaded.editorScene['view_mode'], '3d');
      expect(loadedFurniture['id'], 'furniture-chair-1');
      expect(loadedFurniture['rotation_degrees'], 15.0);
      expect(loadedFurniture['color'], '#64748b');
    },
  );

  test(
    'LegacyProjectApi exportLatestLayout returns layout JSON payload',
    () async {
      final api = LegacyProjectApi(
        authRepository: const _TokenAuthRepository('token-1'),
        baseUrl: 'https://api.example.test',
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(
            request.url.toString(),
            'https://api.example.test/room-projects/project-1/layouts/latest/export',
          );
          expect(request.headers['Authorization'], 'Bearer token-1');

          return http.Response(
            jsonEncode({
              'data': {
                'export': {
                  'format': 'roomforge_layout_json',
                  'version': 1,
                  'layout': {
                    'id': 11,
                    'project_id': 1,
                    'room_dimensions': {
                      'unit': 'meters',
                      'width_value': 4.2,
                      'depth_value': 3.6,
                      'height_value': 2.7,
                    },
                    'floor_plan': {'coordinate_space': 'meters'},
                    'source_metadata': {
                      'source_image_id': 7,
                      'reconstruction_job_id': 9,
                    },
                    'furniture_objects': [
                      {
                        'id': 'furniture-chair-1',
                        'category': 'chair',
                        'position': {'x': 1.2, 'y': 1.4},
                        'size': {
                          'width_meters': 0.55,
                          'depth_meters': 0.55,
                          'height_meters': 0.85,
                        },
                        'rotation_degrees': 15.0,
                        'color': '#64748b',
                      },
                    ],
                    'editor_scene': {'scene_id': 'scene-1'},
                    'created_at': '2026-05-29T00:00:00Z',
                    'updated_at': '2026-05-29T00:00:01Z',
                  },
                },
              },
              'error': null,
              'meta': {'request_id': 'req-1'},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final export = await api.exportLatestLayout(projectId: 'project-1');
      final layout = Map<String, Object?>.from(export['layout'] as Map);
      final furniture = Map<String, Object?>.from(
        (layout['furniture_objects'] as List).single as Map,
      );

      expect(export, containsPair('format', 'roomforge_layout_json'));
      expect(export, containsPair('version', 1));
      expect(layout['room_dimensions'], containsPair('height_value', 2.7));
      expect(layout['floor_plan'], containsPair('coordinate_space', 'meters'));
      expect(
        layout['source_metadata'],
        containsPair('reconstruction_job_id', 9),
      );
      expect(furniture, containsPair('id', 'furniture-chair-1'));
      expect(furniture, containsPair('rotation_degrees', 15.0));
      expect(furniture, containsPair('color', '#64748b'));
    },
  );

  test(
    'LegacyProjectApi preserves required fields across save load export',
    () async {
      Map<String, Object?>? persisted;
      final expected = _layoutPayload();
      final api = LegacyProjectApi(
        authRepository: const _TokenAuthRepository('token-1'),
        baseUrl: 'https://api.example.test',
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer token-1');

          if (request.method == 'POST' &&
              request.url.path == '/room-projects/project-1/layouts') {
            persisted = Map<String, Object?>.from(
              jsonDecode(request.body) as Map,
            );
            return http.Response(
              jsonEncode({
                'data': {'layout': _layoutResponse(persisted!)},
                'error': null,
                'meta': {'request_id': 'save-req'},
              }),
              201,
              headers: {'content-type': 'application/json'},
            );
          }

          if (request.method == 'GET' &&
              request.url.path == '/room-projects/project-1/layouts/latest') {
            expect(persisted, isNotNull);
            return http.Response(
              jsonEncode({
                'data': {'layout': _layoutResponse(persisted!)},
                'error': null,
                'meta': {'request_id': 'load-req'},
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }

          if (request.method == 'GET' &&
              request.url.path ==
                  '/room-projects/project-1/layouts/latest/export') {
            expect(persisted, isNotNull);
            return http.Response(
              jsonEncode({
                'data': {
                  'export': {
                    'format': 'roomforge_layout_json',
                    'version': 1,
                    'layout': _exportLayoutResponse(persisted!),
                  },
                },
                'error': null,
                'meta': {'request_id': 'export-req'},
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }

          return http.Response('{"error":{"code":"not_found"}}', 404);
        }),
      );

      final saved = await api.saveLayout(
        projectId: 'project-1',
        roomDimensions: Map<String, Object?>.from(
          expected['room_dimensions'] as Map,
        ),
        floorPlan: Map<String, Object?>.from(expected['floor_plan'] as Map),
        sourceMetadata: Map<String, Object?>.from(
          expected['source_metadata'] as Map,
        ),
        furnitureObjects: (expected['furniture_objects'] as List)
            .map((item) => Map<String, Object?>.from(item as Map))
            .toList(),
        editorScene: Map<String, Object?>.from(expected['editor_scene'] as Map),
      );
      final loaded = await api.loadLatestLayout(projectId: 'project-1');
      final exported = await api.exportLatestLayout(projectId: 'project-1');
      final exportedLayout = Map<String, Object?>.from(
        exported['layout'] as Map,
      );

      expect(_requiredFieldsFromSavedLayout(saved), expected);
      expect(_requiredFieldsFromSavedLayout(loaded), expected);
      expect(_requiredFieldsFromExport(exportedLayout), expected);
    },
  );
}

Map<String, Object?> _layoutPayload() {
  return {
    'room_dimensions': {
      'unit': 'meters',
      'width_value': 4.2,
      'depth_value': 3.6,
      'height_value': 2.7,
    },
    'floor_plan': {
      'coordinate_space': 'meters',
      'metric_geometry': {
        'coordinate_space': 'meters',
        'points': [
          {'x': 0.0, 'y': 0.0},
          {'x': 4.2, 'y': 0.0},
          {'x': 4.2, 'y': 3.6},
          {'x': 0.0, 'y': 3.6},
        ],
      },
    },
    'source_metadata': {'source_image_id': 7, 'reconstruction_job_id': 9},
    'furniture_objects': [
      {
        'id': 'furniture-chair-1',
        'category': 'chair',
        'position': {'x': 1.2, 'y': 1.4},
        'size': {
          'width_meters': 0.55,
          'depth_meters': 0.55,
          'height_meters': 0.85,
        },
        'rotation_degrees': 15.0,
        'color': '#64748b',
      },
    ],
    'editor_scene': {
      'scene_id': 'scene-1',
      'view_mode': '3d',
      'selected': {
        'object_id': 'furniture-chair-1',
        'object_type': 'furniture',
      },
    },
  };
}

Map<String, Object?> _layoutResponse(Map<String, Object?> layoutPayload) {
  return {
    'id': 11,
    'project_id': 1,
    'user_id': 42,
    ...layoutPayload,
    'created_at': '2026-05-29T00:00:00Z',
    'updated_at': '2026-05-29T00:00:01Z',
  };
}

Map<String, Object?> _exportLayoutResponse(Map<String, Object?> layoutPayload) {
  return {
    'id': 11,
    'project_id': 1,
    ...layoutPayload,
    'created_at': '2026-05-29T00:00:00Z',
    'updated_at': '2026-05-29T00:00:01Z',
  };
}

Map<String, Object?> _requiredFieldsFromSavedLayout(SavedLayout layout) {
  return {
    'room_dimensions': layout.roomDimensions,
    'floor_plan': layout.floorPlan,
    'source_metadata': layout.sourceMetadata,
    'furniture_objects': layout.furnitureObjects,
    'editor_scene': layout.editorScene,
  };
}

Map<String, Object?> _requiredFieldsFromExport(Map<String, Object?> layout) {
  return {
    'room_dimensions': layout['room_dimensions'],
    'floor_plan': layout['floor_plan'],
    'source_metadata': layout['source_metadata'],
    'furniture_objects': layout['furniture_objects'],
    'editor_scene': layout['editor_scene'],
  };
}

class _TokenAuthRepository implements AuthRepository {
  const _TokenAuthRepository(this.token);

  final String token;

  @override
  Stream<AuthSession?> authStateChanges() => const Stream.empty();

  @override
  Future<String?> idToken() async => token;

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signOut() async {}
}
