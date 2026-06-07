import 'package:app/src/api/backend_bindings.dart';
import 'package:app/src/api/backend_mode.dart';
import 'package:app/src/auth/auth_repository.dart';
import 'package:app/src/firebase/firebase_project_repository.dart';
import 'package:app/src/projects/firebase_project_api.dart';
import 'package:app/src/projects/firebase_source_image_upload.dart';
import 'package:app/src/projects/project_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Backend mode configuration', () {
    test('defaults to Firebase when no dart define overrides it', () {
      expect(BackendModeConfig.current, BackendMode.firebase);
      expect(BackendModeConfig.isFirebaseDefault, isTrue);
      expect(BackendModeConfig.isLegacyApi, isFalse);
    });

    test('parses explicit legacy_api mode only by value', () {
      expect(
        BackendMode.fromEnvironmentValue('legacy_api'),
        BackendMode.legacyApi,
      );
      expect(
        () => BackendMode.fromEnvironmentValue('legacy'),
        throwsArgumentError,
      );
    });
  });

  group('RoomForge backend bindings', () {
    test('selects Firebase project API and no legacy admin API by default', () {
      final authRepository = DisabledAuthRepository();
      final projectApi = RoomForgeBackendBindings.projectApi(
        backendMode: BackendMode.firebase,
        authRepository: authRepository,
        session: const AuthSession(uid: 'user-1'),
        floorPlanRepository: const DisabledFirebaseFloorPlanRepository(),
        geometryRepository: const DisabledFirebaseGeometryRepository(),
        layoutRepository: const DisabledFirebaseLayoutRepository(),
        projectRepository: const DisabledFirebaseProjectRepository(),
        reconstructionRepository:
            const DisabledFirebaseReconstructionRepository(),
        roomDimensionsRepository:
            const DisabledFirebaseRoomDimensionsRepository(),
        sceneUnderstandingRepository:
            const DisabledFirebaseSceneUnderstandingRepository(),
        sourceImageRepository: const DisabledFirebaseSourceImageRepository(),
        sourceImageUploader: const DisabledFirebaseSourceImageUploader(),
      );
      final legacyAdminApi = RoomForgeBackendBindings.legacyAdminApi(
        backendMode: BackendMode.firebase,
        authRepository: authRepository,
      );

      expect(projectApi, isA<FirebaseProjectApi>());
      expect(legacyAdminApi, isNull);
    });

    test('selects legacy adapters only for explicit legacy_api mode', () {
      final authRepository = DisabledAuthRepository();
      final projectApi = RoomForgeBackendBindings.projectApi(
        backendMode: BackendMode.legacyApi,
        authRepository: authRepository,
        session: const AuthSession(uid: 'user-1'),
        floorPlanRepository: const DisabledFirebaseFloorPlanRepository(),
        geometryRepository: const DisabledFirebaseGeometryRepository(),
        layoutRepository: const DisabledFirebaseLayoutRepository(),
        projectRepository: const DisabledFirebaseProjectRepository(),
        reconstructionRepository:
            const DisabledFirebaseReconstructionRepository(),
        roomDimensionsRepository:
            const DisabledFirebaseRoomDimensionsRepository(),
        sceneUnderstandingRepository:
            const DisabledFirebaseSceneUnderstandingRepository(),
        sourceImageRepository: const DisabledFirebaseSourceImageRepository(),
        sourceImageUploader: const DisabledFirebaseSourceImageUploader(),
      );
      final legacyAdminApi = RoomForgeBackendBindings.legacyAdminApi(
        backendMode: BackendMode.legacyApi,
        authRepository: authRepository,
      );

      expect(projectApi, isA<LegacyProjectApi>());
      expect(projectApi, isA<ProjectApi>());
      expect(legacyAdminApi, isNotNull);
    });
  });
}
