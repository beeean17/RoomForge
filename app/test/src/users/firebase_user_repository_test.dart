import 'package:app/src/auth/auth_repository.dart';
import 'package:app/src/firebase/firebase_models.dart';
import 'package:app/src/users/firebase_user_repository.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Firebase user profile projection', () {
    test('create payload writes only non-privileged profile fields', () {
      final payload = FirebaseUserProfileProjection.createData(
        _session,
        createdAt: _now,
        updatedAt: _now,
        lastSeenAt: _now,
      );

      expect(payload, containsPair('uid', 'user-1'));
      expect(payload, containsPair('email', 'user@example.test'));
      expect(payload, containsPair('display_name', 'RoomForge User'));
      expect(payload, containsPair('photo_url', 'https://example.test/u.png'));
      expect(payload, containsPair('schema_version', 1));
      expect(
        FirebaseUserProfileProjection.containsPrivilegedRoleField(payload),
        false,
        reason: 'Normal profile create must not self-write role fields.',
      );
    });

    test(
      'update payload preserves existing privileged role fields by omission',
      () {
        final payload = FirebaseUserProfileProjection.updateData(
          _session,
          updatedAt: _now,
          lastSeenAt: _now,
        );

        expect(payload, containsPair('uid', 'user-1'));
        expect(payload, isNot(contains('created_at')));
        expect(payload, isNot(contains('role')));
        expect(payload, isNot(contains('role_updated_at')));
        expect(payload, isNot(contains('role_updated_by_uid')));
        expect(
          FirebaseUserProfileProjection.containsPrivilegedRoleField(payload),
          false,
          reason: 'repo-user-profile-update-preserves-role',
        );
      },
    );

    test('existing role fields round trip into the profile model', () {
      final profile = FirebaseUserProfileProjection.fromFirestoreData(
        {
          'uid': 'user-1',
          'email': 'user@example.test',
          'display_name': 'RoomForge User',
          'created_at': _now,
          'updated_at': _now,
          'schema_version': 1,
          'role': 'admin',
          'role_updated_at': _now,
          'role_updated_by_uid': 'bootstrap-admin',
        },
        uid: 'user-1',
        fallbackCreatedAt: _now,
        fallbackUpdatedAt: _now,
      );

      expect(profile.role, FirebaseAdminRole.admin);
      expect(profile.roleUpdatedByUid, 'bootstrap-admin');
      expect(profile.roleUpdatedAt, _now);
    });

    test('maps Firestore not-found to database setup guidance', () {
      final exception = firebaseUserProfileSyncExceptionFromError(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'not-found',
          message: 'Requested entity was not found.',
        ),
      );

      expect(exception.code, 'firestore_database_not_found');
      expect(exception.message, contains('Cloud Firestore database'));
      expect(exception.message, contains('ROOMFORGE_FIREBASE_PROJECT_ID'));
      expect(exception.toString(), exception.message);
    });

    test('hides Flutter web converted Future noise in profile sync errors', () {
      final exception = firebaseUserProfileSyncExceptionFromError(
        Exception(
          'Dart exception thrown from converted Future. Use the properties '
          "'error' to fetch the boxed error.",
        ),
      );

      expect(exception.code, 'firestore_web_error');
      expect(exception.message, contains('Firestore profile sync failed'));
      expect(exception.message, isNot(contains('converted Future')));
    });
  });
}

final _now = DateTime.utc(2026, 5, 25, 12);

const _session = AuthSession(
  uid: 'user-1',
  email: 'user@example.test',
  displayName: 'RoomForge User',
  photoUrl: 'https://example.test/u.png',
);
