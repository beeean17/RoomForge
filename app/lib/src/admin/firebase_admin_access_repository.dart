import 'package:cloud_firestore/cloud_firestore.dart';

import '../auth/auth_repository.dart';
import '../firebase/firebase_models.dart';
import '../firebase/firebase_repositories.dart';
import '../firebase/firebase_serializers.dart';

class FirebaseAdminRoleGuard {
  const FirebaseAdminRoleGuard._();

  static bool isAdminProfileData(Map<String, Object?>? data) {
    return data?['role'] == FirebaseAdminRole.admin.wireValue;
  }
}

String firebaseAdminRetryActionId(String retryJobId) {
  return 'retry_$retryJobId';
}

class FirebaseAdminRetryDraft {
  const FirebaseAdminRetryDraft({
    required this.currentJob,
    required this.retryJob,
    required this.currentTransition,
    required this.retryTransition,
    required this.action,
  });

  final FirebaseReconstructionJob currentJob;
  final FirebaseReconstructionJob retryJob;
  final FirebaseJobStatusTransition currentTransition;
  final FirebaseJobStatusTransition retryTransition;
  final FirebaseAdminAction action;
}

FirebaseAdminRetryDraft buildFirebaseAdminRetryDraft({
  required AuthSession session,
  required FirebaseReconstructionJob job,
  required String reasonMessage,
  required String currentTransitionId,
  required String retryJobId,
  required String retryTransitionId,
  required String actionId,
  required DateTime now,
}) {
  final rootJobId = job.rootJobId ?? job.jobId;
  final currentJob = FirebaseReconstructionJob(
    jobId: job.jobId,
    projectId: job.projectId,
    ownerUid: job.ownerUid,
    sourceImageId: job.sourceImageId,
    roomDimensionsId: job.roomDimensionsId,
    status: FirebaseJobStatus.retrying,
    statusUpdatedAt: now,
    providerType: job.providerType,
    providerId: job.providerId,
    algorithmId: job.algorithmId,
    openCvVersion: job.openCvVersion,
    createdByUid: job.createdByUid,
    retryOfJobId: job.retryOfJobId,
    rootJobId: rootJobId,
    retryCount: job.retryCount,
    latestTransitionId: currentTransitionId,
    latestResultId: job.latestResultId,
    latestConfirmedGeometryId: job.latestConfirmedGeometryId,
    latestFloorPlanId: job.latestFloorPlanId,
    failureReasonCode: job.failureReasonCode,
    failureReason: job.failureReason,
    qualityStatus: job.qualityStatus,
    artifactRefs: job.artifactRefs,
    startedAt: job.startedAt,
    completedAt: job.completedAt,
    timeoutAt: job.timeoutAt,
    createdAt: job.createdAt,
    updatedAt: now,
    schemaVersion: job.schemaVersion,
  );
  final retryJob = FirebaseReconstructionJob(
    jobId: retryJobId,
    projectId: job.projectId,
    ownerUid: job.ownerUid,
    sourceImageId: job.sourceImageId,
    roomDimensionsId: job.roomDimensionsId,
    status: FirebaseJobStatus.created,
    statusUpdatedAt: now,
    providerType: job.providerType,
    providerId: job.providerId,
    algorithmId: job.algorithmId,
    openCvVersion: job.openCvVersion,
    createdByUid: session.uid,
    retryOfJobId: job.jobId,
    rootJobId: rootJobId,
    retryCount: job.retryCount + 1,
    latestTransitionId: retryTransitionId,
    artifactRefs: const [],
    createdAt: now,
    updatedAt: now,
    schemaVersion: job.schemaVersion,
  );
  final currentTransition = FirebaseJobStatusTransition(
    transitionId: currentTransitionId,
    projectId: job.projectId,
    ownerUid: job.ownerUid,
    jobId: job.jobId,
    fromStatus: job.status,
    toStatus: FirebaseJobStatus.retrying,
    occurredAt: now,
    actorType: FirebaseActorType.admin,
    actorUid: session.uid,
    reasonCode: 'admin_retry',
    reasonMessage: reasonMessage,
    retryJobId: retryJobId,
    schemaVersion: 1,
  );
  final retryTransition = FirebaseJobStatusTransition(
    transitionId: retryTransitionId,
    projectId: job.projectId,
    ownerUid: job.ownerUid,
    jobId: retryJobId,
    toStatus: FirebaseJobStatus.created,
    occurredAt: now,
    actorType: FirebaseActorType.admin,
    actorUid: session.uid,
    reasonCode: 'admin_retry_created',
    reasonMessage: reasonMessage,
    schemaVersion: 1,
  );
  final action = FirebaseAdminAction(
    actionId: actionId,
    projectId: job.projectId,
    ownerUid: job.ownerUid,
    createdByUid: session.uid,
    createdByRole: FirebaseAdminRole.admin,
    actionType: 'retry_reconstruction_job',
    targetType: 'reconstruction_job',
    targetId: job.jobId,
    reasonCode: 'admin_retry',
    reasonMessage: reasonMessage,
    retryJobId: retryJobId,
    metadata: {
      'root_job_id': rootJobId,
      'previous_status': job.status.wireValue,
    },
    createdAt: now,
    schemaVersion: 1,
  );

  return FirebaseAdminRetryDraft(
    currentJob: currentJob,
    retryJob: retryJob,
    currentTransition: currentTransition,
    retryTransition: retryTransition,
    action: action,
  );
}

class FirebaseAdminAccessRepository implements FirebaseAdminRepository {
  const FirebaseAdminAccessRepository({required FirebaseFirestore firestore})
    : _firestore = firestore;

  final FirebaseFirestore _firestore;

  @override
  Future<bool> isCurrentUserAdmin(AuthSession session) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(session.uid)
        .get(const GetOptions(source: Source.server));
    return FirebaseAdminRoleGuard.isAdminProfileData(snapshot.data());
  }

  @override
  Stream<List<FirebaseReconstructionJob>> watchJobs(
    FirebaseAdminJobQuery query,
  ) {
    return _watchQuery(
      query.toSpec(),
      FirebaseModelSerializers.reconstructionJobFromFirestore,
    );
  }

  @override
  Stream<List<FirebaseReconstructionJob>> watchJobsByStatus(
    FirebaseJobStatus status,
  ) {
    return watchJobs(FirebaseAdminJobQuery(status: status));
  }

  @override
  Stream<List<FirebaseJobStatusTransition>> watchTransitionsForJob({
    required String jobId,
  }) {
    return _watchQuery(
      FirebaseAdminQuerySpecs.transitionsForJob(jobId: jobId),
      FirebaseModelSerializers.jobStatusTransitionFromFirestore,
    );
  }

  @override
  Stream<List<FirebaseOpenCvResult>> watchResultsForJob({
    required String jobId,
  }) {
    return _watchQuery(
      FirebaseAdminQuerySpecs.resultsForJob(jobId: jobId),
      FirebaseModelSerializers.openCvResultFromFirestore,
    );
  }

  @override
  Stream<List<FirebaseSavedLayout>> watchLayoutsByOwner({
    required String ownerUid,
  }) {
    return _watchQuery(
      FirebaseAdminQuerySpecs.layoutsByOwner(ownerUid: ownerUid),
      FirebaseModelSerializers.savedLayoutFromFirestore,
    );
  }

  @override
  Stream<List<FirebaseAdminAction>> watchAdminActionsForTarget({
    required String targetType,
    required String targetId,
  }) {
    return _watchQuery(
      FirebaseAdminQuerySpecs.adminActionsForTarget(
        targetType: targetType,
        targetId: targetId,
      ),
      FirebaseModelSerializers.adminActionFromFirestore,
    );
  }

  @override
  Future<FirebaseAdminAction> appendAdminAction(FirebaseAdminAction action) {
    return _adminActionsCollection(
      action.projectId,
    ).doc(action.actionId).set(action.toFirestoreJson()).then((_) => action);
  }

  @override
  Future<FirebaseReconstructionJob> retryJobWithAdminAction({
    required AuthSession session,
    required FirebaseReconstructionJob job,
    required String reasonMessage,
  }) async {
    final isAdmin = await isCurrentUserAdmin(session);
    if (!isAdmin) {
      throw const FirebaseContractException('Admin role required.');
    }

    if (job.status != FirebaseJobStatus.failed &&
        job.status != FirebaseJobStatus.timeout) {
      throw const FirebaseContractException(
        'Only failed or timeout jobs can be retried by admin.',
      );
    }

    final jobs = _jobsCollection(job.projectId);
    final currentTransitionId = jobs
        .doc(job.jobId)
        .collection('transitions')
        .doc()
        .id;
    final retryJobId = jobs.doc().id;
    final retryTransitionId = jobs
        .doc(retryJobId)
        .collection('transitions')
        .doc()
        .id;
    final actionDoc = _adminActionsCollection(
      job.projectId,
    ).doc(firebaseAdminRetryActionId(retryJobId));
    final now = DateTime.now().toUtc();
    final draft = buildFirebaseAdminRetryDraft(
      session: session,
      job: job,
      reasonMessage: reasonMessage,
      currentTransitionId: currentTransitionId,
      retryJobId: retryJobId,
      retryTransitionId: retryTransitionId,
      actionId: actionDoc.id,
      now: now,
    );

    final batch = _firestore.batch();
    batch.update(jobs.doc(job.jobId), draft.currentJob.toFirestoreJson());
    batch.set(
      jobs.doc(job.jobId).collection('transitions').doc(currentTransitionId),
      draft.currentTransition.toFirestoreJson(),
    );
    batch.set(jobs.doc(retryJobId), draft.retryJob.toFirestoreJson());
    batch.set(
      jobs.doc(retryJobId).collection('transitions').doc(retryTransitionId),
      draft.retryTransition.toFirestoreJson(),
    );
    batch.set(actionDoc, draft.action.toFirestoreJson());
    await batch.commit();
    return draft.retryJob;
  }

  Stream<List<T>> _watchQuery<T>(
    FirebaseAdminQuerySpec spec,
    T Function(FirebaseJson json) mapper,
  ) {
    return _queryFor(spec)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => mapper(_firestoreJson(doc.data())))
              .toList();
        })
        .handleError((Object error) {
          throw FirebaseAdminRepositoryException.fromFirestoreError(
            error,
            spec,
          );
        });
  }

  Query<Map<String, dynamic>> _queryFor(FirebaseAdminQuerySpec spec) {
    Query<Map<String, dynamic>> query = _firestore.collectionGroup(
      spec.collectionGroup.wireValue,
    );
    for (final filter in spec.filters) {
      query = query.where(filter.field, isEqualTo: filter.isEqualTo);
    }
    for (final order in spec.orderBy) {
      query = query.orderBy(order.field, descending: order.descending);
    }
    final limit = spec.limit;
    return limit == null ? query : query.limit(limit);
  }

  CollectionReference<Map<String, dynamic>> _jobsCollection(String projectId) {
    return _firestore
        .collection('projects')
        .doc(projectId)
        .collection('reconstruction_jobs');
  }

  CollectionReference<Map<String, dynamic>> _adminActionsCollection(
    String projectId,
  ) {
    return _firestore
        .collection('projects')
        .doc(projectId)
        .collection('admin_actions');
  }
}

class DisabledFirebaseAdminRepository implements FirebaseAdminRepository {
  const DisabledFirebaseAdminRepository();

  @override
  Future<bool> isCurrentUserAdmin(AuthSession session) async {
    return false;
  }

  @override
  Stream<List<FirebaseReconstructionJob>> watchJobs(
    FirebaseAdminJobQuery query,
  ) {
    return Stream.error(
      UnsupportedError('Firebase admin access is unavailable.'),
    );
  }

  @override
  Stream<List<FirebaseReconstructionJob>> watchJobsByStatus(
    FirebaseJobStatus status,
  ) {
    return Stream.error(
      UnsupportedError('Firebase admin access is unavailable.'),
    );
  }

  @override
  Stream<List<FirebaseJobStatusTransition>> watchTransitionsForJob({
    required String jobId,
  }) {
    return Stream.error(
      UnsupportedError('Firebase admin access is unavailable.'),
    );
  }

  @override
  Stream<List<FirebaseOpenCvResult>> watchResultsForJob({
    required String jobId,
  }) {
    return Stream.error(
      UnsupportedError('Firebase admin access is unavailable.'),
    );
  }

  @override
  Stream<List<FirebaseSavedLayout>> watchLayoutsByOwner({
    required String ownerUid,
  }) {
    return Stream.error(
      UnsupportedError('Firebase admin access is unavailable.'),
    );
  }

  @override
  Stream<List<FirebaseAdminAction>> watchAdminActionsForTarget({
    required String targetType,
    required String targetId,
  }) {
    return Stream.error(
      UnsupportedError('Firebase admin access is unavailable.'),
    );
  }

  @override
  Future<FirebaseAdminAction> appendAdminAction(FirebaseAdminAction action) {
    throw UnsupportedError('Firebase admin access is unavailable.');
  }

  @override
  Future<FirebaseReconstructionJob> retryJobWithAdminAction({
    required AuthSession session,
    required FirebaseReconstructionJob job,
    required String reasonMessage,
  }) {
    throw UnsupportedError('Firebase admin access is unavailable.');
  }
}

class FirebaseAdminRepositoryException implements Exception {
  const FirebaseAdminRepositoryException({
    required this.code,
    required this.message,
    required this.querySpec,
    this.cause,
  });

  final String code;
  final String message;
  final FirebaseAdminQuerySpec querySpec;
  final Object? cause;

  static FirebaseAdminRepositoryException fromFirestoreError(
    Object error,
    FirebaseAdminQuerySpec querySpec,
  ) {
    if (error is FirebaseException) {
      final lowerMessage = (error.message ?? '').toLowerCase();
      if (error.code == 'failed-precondition' &&
          lowerMessage.contains('index')) {
        return FirebaseAdminRepositoryException(
          code: 'missing_index',
          message:
              'Missing Firestore index for admin query: ${querySpec.diagnosticName}. ${error.message ?? ''}',
          querySpec: querySpec,
          cause: error,
        );
      }
      if (error.code == 'permission-denied') {
        return FirebaseAdminRepositoryException(
          code: 'permission_denied',
          message:
              'Admin query was denied by Firestore rules: ${querySpec.diagnosticName}.',
          querySpec: querySpec,
          cause: error,
        );
      }
      return FirebaseAdminRepositoryException(
        code: error.code,
        message:
            'Admin query failed for ${querySpec.diagnosticName}: ${error.message ?? error.code}.',
        querySpec: querySpec,
        cause: error,
      );
    }
    return FirebaseAdminRepositoryException(
      code: 'admin_query_failed',
      message: 'Admin query failed for ${querySpec.diagnosticName}: $error.',
      querySpec: querySpec,
      cause: error,
    );
  }

  @override
  String toString() => message;
}

FirebaseJson _firestoreJson(Map<String, dynamic> data) {
  return data.map((key, value) => MapEntry(key, _firestoreValue(value)));
}

Object? _firestoreValue(Object? value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is Map) {
    return value.map(
      (key, nestedValue) =>
          MapEntry(key.toString(), _firestoreValue(nestedValue)),
    );
  }
  if (value is Iterable) {
    return value.map(_firestoreValue).toList();
  }
  return value;
}
