import 'package:cloud_firestore/cloud_firestore.dart';

import '../auth/auth_repository.dart';
import '../firebase/firebase_models.dart';
import '../firebase/firebase_repositories.dart';

class FirebaseUserProfileProjection {
  FirebaseUserProfileProjection._();

  static const privilegedRoleFields = {
    'role',
    'role_updated_at',
    'role_updated_by_uid',
  };

  static Map<String, Object?> createData(
    AuthSession session, {
    required Object createdAt,
    required Object updatedAt,
    Object? lastSeenAt,
  }) {
    return _withoutNulls({
      'uid': session.uid,
      'email': session.email,
      'display_name': session.displayName,
      'photo_url': session.photoUrl,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'last_seen_at': lastSeenAt,
      'schema_version': 1,
    });
  }

  static Map<String, Object?> updateData(
    AuthSession session, {
    required Object updatedAt,
    Object? lastSeenAt,
  }) {
    return _withoutNulls({
      'uid': session.uid,
      'email': session.email,
      'display_name': session.displayName,
      'photo_url': session.photoUrl,
      'updated_at': updatedAt,
      'last_seen_at': lastSeenAt,
      'schema_version': 1,
    });
  }

  static bool containsPrivilegedRoleField(Map<String, Object?> data) {
    return data.keys.any(privilegedRoleFields.contains);
  }

  static FirebaseUserProfile fromFirestoreData(
    Map<String, Object?> data, {
    required String uid,
    required DateTime fallbackCreatedAt,
    required DateTime fallbackUpdatedAt,
  }) {
    return FirebaseUserProfile(
      uid: data['uid']?.toString() ?? uid,
      email: data['email']?.toString(),
      displayName: data['display_name']?.toString(),
      photoUrl: data['photo_url']?.toString(),
      createdAt: _dateValue(data['created_at']) ?? fallbackCreatedAt,
      updatedAt: _dateValue(data['updated_at']) ?? fallbackUpdatedAt,
      lastSeenAt: _dateValue(data['last_seen_at']),
      schemaVersion: _intValue(data['schema_version']) ?? 1,
      role: data['role'] == null
          ? null
          : FirebaseAdminRole.fromWireValue(data['role']),
      roleUpdatedAt: _dateValue(data['role_updated_at']),
      roleUpdatedByUid: data['role_updated_by_uid']?.toString(),
    );
  }

  static Map<String, Object?> _withoutNulls(Map<String, Object?> data) {
    return {
      for (final entry in data.entries)
        if (entry.value != null) entry.key: entry.value,
    };
  }

  static DateTime? _dateValue(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is Timestamp) {
      return value.toDate().toUtc();
    }
    if (value is DateTime) {
      return value.toUtc();
    }
    if (value is String) {
      return DateTime.parse(value).toUtc();
    }
    return null;
  }

  static int? _intValue(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num && value % 1 == 0) {
      return value.toInt();
    }
    return null;
  }
}

class FirebaseUserProfileRepository implements FirebaseUserRepository {
  FirebaseUserProfileRepository({
    required FirebaseFirestore firestore,
    DateTime Function()? clock,
  }) : _firestore = firestore,
       _clock = clock ?? DateTime.now;

  final FirebaseFirestore _firestore;
  final DateTime Function() _clock;

  CollectionReference<Map<String, dynamic>> get _users {
    return _firestore.collection('users');
  }

  @override
  Stream<FirebaseUserProfile?> watchCurrentUserProfile(AuthSession session) {
    return _users.doc(session.uid).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) {
        return null;
      }
      final now = _clock().toUtc();
      return FirebaseUserProfileProjection.fromFirestoreData(
        Map<String, Object?>.from(data),
        uid: session.uid,
        fallbackCreatedAt: now,
        fallbackUpdatedAt: now,
      );
    });
  }

  @override
  Future<FirebaseUserProfile> syncProfile(AuthSession session) async {
    final docRef = _users.doc(session.uid);
    final now = _clock().toUtc();
    final serverNow = FieldValue.serverTimestamp();

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final data = snapshot.data();

      if (snapshot.exists) {
        final payload = FirebaseUserProfileProjection.updateData(
          session,
          updatedAt: serverNow,
          lastSeenAt: serverNow,
        );
        transaction.update(docRef, payload);
      } else {
        final payload = FirebaseUserProfileProjection.createData(
          session,
          createdAt: serverNow,
          updatedAt: serverNow,
          lastSeenAt: serverNow,
        );
        transaction.set(docRef, payload);
      }

      final profileData = data == null
          ? FirebaseUserProfileProjection.createData(
              session,
              createdAt: now,
              updatedAt: now,
              lastSeenAt: now,
            )
          : {
              ...Map<String, Object?>.from(data),
              ...FirebaseUserProfileProjection.updateData(
                session,
                updatedAt: now,
                lastSeenAt: now,
              ),
            };

      return FirebaseUserProfileProjection.fromFirestoreData(
        profileData,
        uid: session.uid,
        fallbackCreatedAt: now,
        fallbackUpdatedAt: now,
      );
    });
  }
}

class DisabledFirebaseUserRepository implements FirebaseUserRepository {
  @override
  Stream<FirebaseUserProfile?> watchCurrentUserProfile(AuthSession session) {
    return const Stream<FirebaseUserProfile?>.empty();
  }

  @override
  Future<FirebaseUserProfile> syncProfile(AuthSession session) {
    throw const AuthUnavailableException(
      'Firebase profile sync is unavailable until Firebase configuration is provided.',
    );
  }
}
