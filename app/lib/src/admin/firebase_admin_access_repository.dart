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
    throw UnsupportedError('Firebase admin actions are implemented in Epic 8.');
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
