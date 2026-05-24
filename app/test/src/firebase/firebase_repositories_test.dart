import 'package:app/src/firebase/firebase_repositories.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Firebase repository boundaries', () {
    test('define Flutter-side repository contracts for Firebase domains', () {
      expect(FirebaseUserRepository, isNotNull);
      expect(FirebaseProjectRepository, isNotNull);
      expect(FirebaseSourceImageRepository, isNotNull);
      expect(FirebaseRoomDimensionsRepository, isNotNull);
      expect(FirebaseReconstructionRepository, isNotNull);
      expect(FirebaseGeometryRepository, isNotNull);
      expect(FirebaseFloorPlanRepository, isNotNull);
      expect(FirebaseLayoutRepository, isNotNull);
      expect(FirebaseDraftRepository, isNotNull);
      expect(FirebaseAdminRepository, isNotNull);
    });
  });
}
