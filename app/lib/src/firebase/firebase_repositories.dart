import '../auth/auth_repository.dart';
import 'firebase_models.dart';

abstract class FirebaseUserRepository {
  Stream<FirebaseUserProfile?> watchCurrentUserProfile(AuthSession session);

  Future<FirebaseUserProfile> syncProfile(AuthSession session);
}

abstract class FirebaseProjectRepository {
  Stream<List<FirebaseRoomProject>> watchOwnedProjects(String ownerUid);

  Future<FirebaseRoomProject> createProject({
    required String ownerUid,
    required String name,
    String? description,
  });

  Future<FirebaseRoomProject> getProject({
    required String ownerUid,
    required String projectId,
  });

  Future<FirebaseRoomProject> updateProject(FirebaseRoomProject project);

  Future<void> softDeleteProject({
    required String ownerUid,
    required String projectId,
  });
}

abstract class FirebaseSourceImageRepository {
  String newSourceImageId({required String projectId});

  Future<FirebaseSourceImage> createMetadataAfterUpload(
    FirebaseSourceImage sourceImage,
  );

  Future<FirebaseSourceImage?> getSourceImage({
    required String ownerUid,
    required String projectId,
    required String sourceImageId,
  });

  Stream<List<FirebaseSourceImage>> watchProjectSourceImages({
    required String ownerUid,
    required String projectId,
  });
}

abstract class FirebaseRoomDimensionsRepository {
  Future<FirebaseRoomDimensions> saveCurrent(FirebaseRoomDimensions dimensions);

  Future<FirebaseRoomDimensions?> getCurrent({
    required String ownerUid,
    required String projectId,
  });
}

abstract class FirebaseReconstructionRepository {
  String newJobId({required String projectId});

  String newTransitionId({required String projectId, required String jobId});

  Future<FirebaseReconstructionJob> createJobWithTransition({
    required FirebaseReconstructionJob job,
    required FirebaseJobStatusTransition transition,
    required FirebaseRoomProject project,
  });

  Future<FirebaseReconstructionJob> updateJobWithTransition({
    required FirebaseReconstructionJob job,
    required FirebaseJobStatusTransition transition,
    required FirebaseRoomProject project,
  });

  Future<FirebaseReconstructionJob> retryJobWithTransitions({
    required FirebaseReconstructionJob currentJob,
    required FirebaseJobStatusTransition currentTransition,
    required FirebaseReconstructionJob retryJob,
    required FirebaseJobStatusTransition retryTransition,
    required FirebaseRoomProject project,
  });

  Future<FirebaseReconstructionJob?> getJob({
    required String ownerUid,
    required String projectId,
    required String jobId,
  });

  Stream<FirebaseReconstructionJob?> watchJob({
    required String ownerUid,
    required String projectId,
    required String jobId,
  });
}

abstract class FirebaseGeometryRepository {
  Future<FirebaseOpenCvResult> saveOpenCvResult(FirebaseOpenCvResult result);

  Future<FirebaseConfirmedGeometry> saveConfirmedGeometry(
    FirebaseConfirmedGeometry geometry,
  );

  Future<FirebaseOpenCvResult?> getOpenCvResult({
    required String ownerUid,
    required String projectId,
    required String resultId,
  });

  Future<FirebaseConfirmedGeometry?> getConfirmedGeometry({
    required String ownerUid,
    required String projectId,
    required String geometryId,
  });
}

abstract class FirebaseFloorPlanRepository {
  Future<FirebaseFloorPlan> saveFloorPlan(FirebaseFloorPlan floorPlan);

  Future<FirebaseFloorPlan?> getFloorPlan({
    required String ownerUid,
    required String projectId,
    required String floorPlanId,
  });
}

abstract class FirebaseLayoutRepository {
  Future<FirebaseSavedLayout> saveLayout(FirebaseSavedLayout layout);

  Future<FirebaseSavedLayout?> loadLatestLayout({
    required String ownerUid,
    required String projectId,
  });

  Future<FirebaseJson> exportLatestLayout({
    required String ownerUid,
    required String projectId,
  });
}

abstract class FirebaseDraftRepository {
  Future<void> saveLocalDraft({
    required String ownerUid,
    required String projectId,
    required FirebaseJson bridgePayload,
  });

  Future<FirebaseJson?> loadLocalDraft({
    required String ownerUid,
    required String projectId,
  });

  Future<void> clearLocalDraft({
    required String ownerUid,
    required String projectId,
  });
}

abstract class FirebaseAdminRepository {
  Future<bool> isCurrentUserAdmin(AuthSession session);

  Stream<List<FirebaseReconstructionJob>> watchJobsByStatus(
    FirebaseJobStatus status,
  );

  Future<FirebaseAdminAction> appendAdminAction(FirebaseAdminAction action);
}
