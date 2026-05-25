import '../admin/admin_api.dart';
import '../auth/auth_repository.dart';
import '../firebase/firebase_repositories.dart';
import '../projects/firebase_project_api.dart';
import '../projects/firebase_source_image_upload.dart';
import '../projects/project_api.dart';
import 'backend_mode.dart';

class RoomForgeBackendBindings {
  const RoomForgeBackendBindings._();

  static ProjectApi projectApi({
    required BackendMode backendMode,
    required AuthRepository authRepository,
    required AuthSession session,
    required FirebaseFloorPlanRepository floorPlanRepository,
    required FirebaseGeometryRepository geometryRepository,
    required FirebaseLayoutRepository layoutRepository,
    required FirebaseProjectRepository projectRepository,
    required FirebaseReconstructionRepository reconstructionRepository,
    required FirebaseRoomDimensionsRepository roomDimensionsRepository,
    required FirebaseSourceImageRepository sourceImageRepository,
    required FirebaseSourceImageUploader sourceImageUploader,
  }) {
    if (backendMode == BackendMode.legacyApi) {
      return LegacyProjectApi(authRepository: authRepository);
    }

    return FirebaseProjectApi(
      authRepository: authRepository,
      session: session,
      floorPlanRepository: floorPlanRepository,
      geometryRepository: geometryRepository,
      layoutRepository: layoutRepository,
      projectRepository: projectRepository,
      reconstructionRepository: reconstructionRepository,
      roomDimensionsRepository: roomDimensionsRepository,
      sourceImageRepository: sourceImageRepository,
      sourceImageUploader: sourceImageUploader,
    );
  }

  static AdminApi? legacyAdminApi({
    required BackendMode backendMode,
    required AuthRepository authRepository,
  }) {
    return backendMode == BackendMode.legacyApi
        ? AdminApi(authRepository: authRepository)
        : null;
  }
}
