import 'package:app/src/admin/firebase_admin_diagnostics.dart';
import 'package:app/src/firebase/firebase_models.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Firebase admin artifact diagnostics', () {
    test('maps artifact read outcomes to permission-aware states', () {
      expect(
        FirebaseAdminArtifactDiagnostics.stateFor(artifactRef: null),
        FirebaseAdminArtifactReadState.notGenerated,
      );
      expect(
        FirebaseAdminArtifactDiagnostics.stateFor(
          artifactRef: _artifactRef(),
          readSucceeded: true,
        ),
        FirebaseAdminArtifactReadState.available,
      );
      expect(
        FirebaseAdminArtifactDiagnostics.stateFor(
          artifactRef: _artifactRef(),
          readError: FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        ),
        FirebaseAdminArtifactReadState.restricted,
      );
      expect(
        FirebaseAdminArtifactDiagnostics.stateFor(
          artifactRef: _artifactRef(),
          readError: FirebaseException(
            plugin: 'firebase_storage',
            code: 'object-not-found',
          ),
        ),
        FirebaseAdminArtifactReadState.missing,
      );
      expect(
        FirebaseAdminArtifactDiagnostics.stateFor(
          artifactRef: _artifactRef(),
          readError: StateError('network'),
        ),
        FirebaseAdminArtifactReadState.failedToLoad,
      );
    });

    test('uses safe copy for protected admin errors', () {
      expect(
        firebaseAdminSafeErrorMessage(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
            message: 'projects/secret-project/reconstruction_jobs/job-1',
          ),
        ),
        'Admin access required.',
      );
      expect(
        firebaseAdminSafeErrorMessage(StateError('private job details')),
        'Admin diagnostics unavailable.',
      );
    });
  });
}

FirebaseArtifactRef _artifactRef() {
  return const FirebaseArtifactRef(
    artifactId: 'artifact-1',
    storagePath:
        'users/user-1/projects/project-1/artifacts/job-1/artifact-1/overlay.png',
    artifactType: 'opencv_overlay',
    contentType: FirebaseArtifactContentType.png,
  );
}
