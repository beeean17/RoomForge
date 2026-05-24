import 'package:app/src/admin/firebase_admin_access_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Firebase admin role guard', () {
    test('allows only explicit admin role profile data', () {
      expect(
        FirebaseAdminRoleGuard.isAdminProfileData(const {'role': 'admin'}),
        true,
      );
      expect(
        FirebaseAdminRoleGuard.isAdminProfileData(const {'role': 'user'}),
        false,
      );
      expect(FirebaseAdminRoleGuard.isAdminProfileData(const {}), false);
      expect(FirebaseAdminRoleGuard.isAdminProfileData(null), false);
    });
  });
}
