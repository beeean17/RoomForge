import 'package:cloud_firestore/cloud_firestore.dart';

import '../firebase/firebase_models.dart';

enum FirebaseAdminArtifactReadState {
  available('available'),
  restricted('restricted'),
  missing('missing'),
  failedToLoad('failed_to_load'),
  notGenerated('not_generated');

  const FirebaseAdminArtifactReadState(this.wireValue);

  final String wireValue;
}

class FirebaseAdminArtifactDiagnostics {
  const FirebaseAdminArtifactDiagnostics._();

  static FirebaseAdminArtifactReadState stateFor({
    required FirebaseArtifactRef? artifactRef,
    Object? readError,
    bool readSucceeded = false,
  }) {
    if (artifactRef == null) {
      return FirebaseAdminArtifactReadState.notGenerated;
    }
    if (readSucceeded || readError == null) {
      return FirebaseAdminArtifactReadState.available;
    }
    if (readError is FirebaseException) {
      return switch (readError.code) {
        'permission-denied' ||
        'unauthorized' => FirebaseAdminArtifactReadState.restricted,
        'not-found' ||
        'object-not-found' => FirebaseAdminArtifactReadState.missing,
        _ => FirebaseAdminArtifactReadState.failedToLoad,
      };
    }
    return FirebaseAdminArtifactReadState.failedToLoad;
  }
}

String firebaseAdminSafeErrorMessage(Object error) {
  if (error is FirebaseException && error.code == 'permission-denied') {
    return 'Admin access required.';
  }
  if (error is FirebaseException && error.code == 'unauthorized') {
    return 'Admin access required.';
  }
  return 'Admin diagnostics unavailable.';
}
