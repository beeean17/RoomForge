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
      expect(
        FirebaseAdminDiagnosticsUiText.artifactStateLabel(
          FirebaseAdminArtifactReadState.available,
        ),
        'available',
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
      expect(
        FirebaseAdminDiagnosticsUiText.noProtectedDataMessage,
        isNot(contains('private job details')),
      );
    });

    test(
      'exposes filter and lookup metadata for accessible admin controls',
      () {
        expect(
          FirebaseAdminDiagnosticsSearchField.values.map(
            (field) => field.wireValue,
          ),
          ['job_id', 'project_id', 'owner_uid'],
        );
        expect(
          FirebaseAdminDiagnosticsSearchField.fromWireValue('project_id'),
          FirebaseAdminDiagnosticsSearchField.projectId,
        );
        expect(
          FirebaseAdminDiagnosticsUiText.statusFilterSemanticsLabel,
          'Admin job status filter',
        );
        expect(
          FirebaseAdminDiagnosticsUiText.exactLookupSemanticsLabel,
          'Exact admin lookup',
        );
      },
    );

    test('summarizes protected job rows and required detail fields', () {
      final job = _job();

      expect(
        FirebaseAdminDiagnosticsUiText.jobRowAccessibilityLabel(job),
        'Job job-1. Owner user-1. Project project-1. Status failed',
      );
      expect(
        FirebaseAdminDiagnosticsUiText.jobDetailRequiredLabels(job),
        containsAll([
          'Status: failed',
          'Owner: user-1',
          'Project: project-1',
          'Job: job-1',
          'Source image: source-1',
          'Provider: manual_assisted_opencv',
          'Provider ID: provider-1',
          'Algorithm: opencv-js-canny-hough-v1',
          'OpenCV: 4.10.0',
          'Quality: failed',
          'Retry count: 1',
          'Latest transition: transition-1',
          'Latest result: result-1',
          'Latest geometry: geometry-1',
          'Latest floor plan: floor-plan-1',
          'Failure: weak_edges',
          'Failure detail: OpenCV could not find enough edges.',
          'Retry of: original-job',
          'Root job: root-job',
          'Started at: 2026-05-29T12:00:00.000Z',
          'Timeout at: 2026-05-29T12:05:00.000Z',
        ]),
      );
      expect(
        FirebaseAdminDiagnosticsUiText.jobDetailAccessibilitySummary(job),
        contains('Failure: weak_edges'),
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

FirebaseReconstructionJob _job() {
  final now = DateTime.utc(2026, 5, 29, 12);
  return FirebaseReconstructionJob(
    jobId: 'job-1',
    projectId: 'project-1',
    ownerUid: 'user-1',
    sourceImageId: 'source-1',
    roomDimensionsId: 'current',
    status: FirebaseJobStatus.failed,
    statusUpdatedAt: now,
    providerType: 'manual_assisted_opencv',
    providerId: 'provider-1',
    algorithmId: 'opencv-js-canny-hough-v1',
    openCvVersion: '4.10.0',
    createdByUid: 'user-1',
    retryOfJobId: 'original-job',
    rootJobId: 'root-job',
    retryCount: 1,
    latestTransitionId: 'transition-1',
    latestResultId: 'result-1',
    latestConfirmedGeometryId: 'geometry-1',
    latestFloorPlanId: 'floor-plan-1',
    failureReasonCode: 'weak_edges',
    failureReason: 'OpenCV could not find enough edges.',
    qualityStatus: FirebaseQualityStatus.failed,
    startedAt: now,
    timeoutAt: now.add(const Duration(minutes: 5)),
    createdAt: now,
    updatedAt: now,
    schemaVersion: 1,
  );
}
