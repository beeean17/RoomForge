import 'package:cloud_firestore/cloud_firestore.dart';

import '../firebase/firebase_models.dart';

enum FirebaseAdminDiagnosticsSearchField {
  jobId('job_id', 'Job ID'),
  projectId('project_id', 'Project ID'),
  ownerUid('owner_uid', 'User ID');

  const FirebaseAdminDiagnosticsSearchField(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static FirebaseAdminDiagnosticsSearchField fromWireValue(String value) {
    return FirebaseAdminDiagnosticsSearchField.values.firstWhere(
      (field) => field.wireValue == value,
      orElse: () => FirebaseAdminDiagnosticsSearchField.jobId,
    );
  }
}

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

class FirebaseAdminDiagnosticsUiText {
  const FirebaseAdminDiagnosticsUiText._();

  static const statusFilterSemanticsLabel = 'Admin job status filter';
  static const exactLookupSemanticsLabel = 'Exact admin lookup';
  static const jobListSemanticsLabel = 'Protected Firebase job results';
  static const jobDetailSemanticsLabel = 'Protected Firebase job detail';
  static const artifactAccessSemanticsLabel = 'Artifact access diagnostics';
  static const transitionHistorySemanticsLabel = 'Transition history';
  static const opencvResultsSemanticsLabel = 'OpenCV result references';
  static const layoutReferencesSemanticsLabel = 'Layout references';
  static const protectedLoadingMessage = 'Loading protected job diagnostics...';
  static const noProtectedDataMessage = 'Protected admin data is unavailable.';

  static String artifactStateLabel(FirebaseAdminArtifactReadState state) {
    return state.wireValue;
  }

  static String jobRowAccessibilityLabel(FirebaseReconstructionJob job) {
    return [
      'Job ${job.jobId}',
      'Owner ${job.ownerUid}',
      'Project ${job.projectId}',
      'Status ${job.status.wireValue}',
    ].join('. ');
  }

  static List<String> jobDetailRequiredLabels(FirebaseReconstructionJob job) {
    return [
      'Status: ${job.status.wireValue}',
      'Owner: ${job.ownerUid}',
      'Project: ${job.projectId}',
      'Job: ${job.jobId}',
      'Source image: ${job.sourceImageId}',
      'Provider: ${job.providerType}',
      if (job.providerId != null) 'Provider ID: ${job.providerId}',
      if (job.algorithmId != null) 'Algorithm: ${job.algorithmId}',
      if (job.openCvVersion != null) 'OpenCV: ${job.openCvVersion}',
      if (job.qualityStatus != null)
        'Quality: ${job.qualityStatus!.displayLabel}',
      'Retry count: ${job.retryCount}',
      if (job.latestTransitionId != null)
        'Latest transition: ${job.latestTransitionId}',
      'Latest result: ${job.latestResultId ?? 'not_generated'}',
      'Latest geometry: ${job.latestConfirmedGeometryId ?? 'not_generated'}',
      'Latest floor plan: ${job.latestFloorPlanId ?? 'not_generated'}',
      if (job.failureReasonCode != null) 'Failure: ${job.failureReasonCode}',
      if (job.failureReason != null) 'Failure detail: ${job.failureReason}',
      if (job.retryOfJobId != null) 'Retry of: ${job.retryOfJobId}',
      if (job.rootJobId != null) 'Root job: ${job.rootJobId}',
      if (job.startedAt != null)
        'Started at: ${job.startedAt!.toUtc().toIso8601String()}',
      if (job.completedAt != null)
        'Completed at: ${job.completedAt!.toUtc().toIso8601String()}',
      if (job.timeoutAt != null)
        'Timeout at: ${job.timeoutAt!.toUtc().toIso8601String()}',
    ];
  }

  static String jobDetailAccessibilitySummary(FirebaseReconstructionJob job) {
    return jobDetailRequiredLabels(job).join('. ');
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
