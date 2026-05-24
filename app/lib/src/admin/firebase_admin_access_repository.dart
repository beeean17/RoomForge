import 'package:cloud_firestore/cloud_firestore.dart';

import '../auth/auth_repository.dart';
import '../firebase/firebase_models.dart';
import '../firebase/firebase_repositories.dart';

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
  Stream<List<FirebaseReconstructionJob>> watchJobsByStatus(
    FirebaseJobStatus status,
  ) {
    return Stream.error(
      UnsupportedError('Firebase admin diagnostics are implemented in Epic 8.'),
    );
  }

  @override
  Future<FirebaseAdminAction> appendAdminAction(FirebaseAdminAction action) {
    throw UnsupportedError('Firebase admin actions are implemented in Epic 8.');
  }
}

class DisabledFirebaseAdminRepository implements FirebaseAdminRepository {
  const DisabledFirebaseAdminRepository();

  @override
  Future<bool> isCurrentUserAdmin(AuthSession session) async {
    return false;
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
  Future<FirebaseAdminAction> appendAdminAction(FirebaseAdminAction action) {
    throw UnsupportedError('Firebase admin access is unavailable.');
  }
}
