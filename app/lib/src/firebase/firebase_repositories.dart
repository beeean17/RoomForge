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

enum FirebaseAdminCollectionGroup {
  reconstructionJobs('reconstruction_jobs'),
  transitions('transitions'),
  openCvResults('opencv_results'),
  layouts('layouts'),
  adminActions('admin_actions');

  const FirebaseAdminCollectionGroup(this.wireValue);

  final String wireValue;
}

class FirebaseAdminQueryFilter {
  const FirebaseAdminQueryFilter({
    required this.field,
    required this.isEqualTo,
  });

  final String field;
  final Object isEqualTo;
}

class FirebaseAdminQueryOrder {
  const FirebaseAdminQueryOrder({
    required this.field,
    required this.descending,
  });

  final String field;
  final bool descending;
}

class FirebaseAdminQuerySpec {
  const FirebaseAdminQuerySpec({
    required this.collectionGroup,
    required this.filters,
    required this.orderBy,
    this.limit = 50,
  });

  final FirebaseAdminCollectionGroup collectionGroup;
  final List<FirebaseAdminQueryFilter> filters;
  final List<FirebaseAdminQueryOrder> orderBy;
  final int? limit;

  String get diagnosticName {
    final filterText = filters
        .map((filter) => '${filter.field} == ${filter.isEqualTo}')
        .join(', ');
    final orderText = orderBy
        .map((order) => '${order.field} ${order.descending ? 'desc' : 'asc'}')
        .join(', ');
    return '${collectionGroup.wireValue} filters=[$filterText] order=[$orderText] limit=$limit';
  }
}

class FirebaseAdminJobQuery {
  const FirebaseAdminJobQuery({
    this.status,
    this.ownerUid,
    this.projectId,
    this.jobId,
    this.retryOfJobId,
    this.limit = 50,
  });

  final FirebaseJobStatus? status;
  final String? ownerUid;
  final String? projectId;
  final String? jobId;
  final String? retryOfJobId;
  final int? limit;

  FirebaseAdminQuerySpec toSpec() {
    final filters = <FirebaseAdminQueryFilter>[
      if (status != null)
        FirebaseAdminQueryFilter(field: 'status', isEqualTo: status!.wireValue),
      if (ownerUid != null)
        FirebaseAdminQueryFilter(field: 'owner_uid', isEqualTo: ownerUid!),
      if (projectId != null)
        FirebaseAdminQueryFilter(field: 'project_id', isEqualTo: projectId!),
      if (jobId != null)
        FirebaseAdminQueryFilter(field: 'job_id', isEqualTo: jobId!),
      if (retryOfJobId != null)
        FirebaseAdminQueryFilter(
          field: 'retry_of_job_id',
          isEqualTo: retryOfJobId!,
        ),
    ];
    if (filters.isEmpty) {
      throw const FirebaseContractException(
        'Admin job queries require at least one explicit filter.',
      );
    }
    if (filters.length > 1) {
      throw const FirebaseContractException(
        'Admin job queries support one indexed lookup filter at a time.',
      );
    }
    return FirebaseAdminQuerySpec(
      collectionGroup: FirebaseAdminCollectionGroup.reconstructionJobs,
      filters: filters,
      orderBy: [
        FirebaseAdminQueryOrder(
          field: status != null ? 'updated_at' : 'created_at',
          descending: true,
        ),
      ],
      limit: limit,
    );
  }
}

class FirebaseAdminQuerySpecs {
  const FirebaseAdminQuerySpecs._();

  static FirebaseAdminQuerySpec transitionsForJob({
    required String jobId,
    int? limit = 100,
  }) {
    return FirebaseAdminQuerySpec(
      collectionGroup: FirebaseAdminCollectionGroup.transitions,
      filters: [FirebaseAdminQueryFilter(field: 'job_id', isEqualTo: jobId)],
      orderBy: const [
        FirebaseAdminQueryOrder(field: 'occurred_at', descending: false),
      ],
      limit: limit,
    );
  }

  static FirebaseAdminQuerySpec resultsForJob({
    required String jobId,
    int? limit = 50,
  }) {
    return FirebaseAdminQuerySpec(
      collectionGroup: FirebaseAdminCollectionGroup.openCvResults,
      filters: [FirebaseAdminQueryFilter(field: 'job_id', isEqualTo: jobId)],
      orderBy: const [
        FirebaseAdminQueryOrder(field: 'created_at', descending: true),
      ],
      limit: limit,
    );
  }

  static FirebaseAdminQuerySpec layoutsByOwner({
    required String ownerUid,
    int? limit = 50,
  }) {
    return FirebaseAdminQuerySpec(
      collectionGroup: FirebaseAdminCollectionGroup.layouts,
      filters: [
        FirebaseAdminQueryFilter(field: 'owner_uid', isEqualTo: ownerUid),
      ],
      orderBy: const [
        FirebaseAdminQueryOrder(field: 'updated_at', descending: true),
      ],
      limit: limit,
    );
  }

  static FirebaseAdminQuerySpec adminActionsForTarget({
    required String targetType,
    required String targetId,
    int? limit = 50,
  }) {
    return FirebaseAdminQuerySpec(
      collectionGroup: FirebaseAdminCollectionGroup.adminActions,
      filters: [
        FirebaseAdminQueryFilter(field: 'target_type', isEqualTo: targetType),
        FirebaseAdminQueryFilter(field: 'target_id', isEqualTo: targetId),
      ],
      orderBy: const [
        FirebaseAdminQueryOrder(field: 'created_at', descending: true),
      ],
      limit: limit,
    );
  }
}

abstract class FirebaseAdminRepository {
  Future<bool> isCurrentUserAdmin(AuthSession session);

  Stream<List<FirebaseReconstructionJob>> watchJobs(
    FirebaseAdminJobQuery query,
  );

  Stream<List<FirebaseReconstructionJob>> watchJobsByStatus(
    FirebaseJobStatus status,
  );

  Stream<List<FirebaseJobStatusTransition>> watchTransitionsForJob({
    required String jobId,
  });

  Stream<List<FirebaseOpenCvResult>> watchResultsForJob({
    required String jobId,
  });

  Stream<List<FirebaseSavedLayout>> watchLayoutsByOwner({
    required String ownerUid,
  });

  Stream<List<FirebaseAdminAction>> watchAdminActionsForTarget({
    required String targetType,
    required String targetId,
  });

  Future<FirebaseAdminAction> appendAdminAction(FirebaseAdminAction action);

  Future<FirebaseReconstructionJob> retryJobWithAdminAction({
    required AuthSession session,
    required FirebaseReconstructionJob job,
    required String reasonMessage,
  });
}
