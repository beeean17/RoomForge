import 'package:app/src/auth/auth_repository.dart';
import 'package:app/src/firebase/firebase_models.dart';
import 'package:app/src/firebase/firebase_repositories.dart';
import 'package:firebase_core/firebase_core.dart';
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

    test('covers minimal admin diagnostics access smoke semantics', () {
      final adminProfile = const {'role': 'admin', 'uid': 'admin-1'};
      final nonAdminProfiles = [
        const {'role': 'user', 'uid': 'user-1'},
        const <String, Object?>{},
        null,
      ];

      expect(FirebaseAdminRoleGuard.isAdminProfileData(adminProfile), isTrue);
      for (final profile in nonAdminProfiles) {
        expect(FirebaseAdminRoleGuard.isAdminProfileData(profile), isFalse);
      }

      final querySpec = FirebaseAdminQuerySpecs.adminActionsForTarget(
        targetType: 'reconstruction_job',
        targetId: 'job-1',
      );
      final deniedError = FirebaseAdminRepositoryException.fromFirestoreError(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'Missing or insufficient permissions.',
        ),
        querySpec,
      );

      expect(deniedError.code, 'permission_denied');
      expect(deniedError.querySpec, same(querySpec));
      expect(deniedError.message, contains('denied by Firestore rules'));
    });
  });

  group('Firebase admin retry draft', () {
    test('builds linked retry job, transitions, and audit action', () {
      final createdAt = DateTime.utc(2026, 5, 24, 12);
      final now = DateTime.utc(2026, 5, 25, 9, 30);
      final job = FirebaseReconstructionJob(
        jobId: 'job-1',
        projectId: 'project-1',
        ownerUid: 'owner-1',
        sourceImageId: 'source-1',
        roomDimensionsId: 'current',
        status: FirebaseJobStatus.failed,
        statusUpdatedAt: createdAt,
        providerType: 'manual_assisted_opencv',
        createdByUid: 'owner-1',
        retryCount: 0,
        latestTransitionId: 'transition-failed',
        failureReasonCode: 'opencv_failed',
        failureReason: 'Synthetic failure.',
        createdAt: createdAt,
        updatedAt: createdAt,
        schemaVersion: 1,
      );

      final draft = buildFirebaseAdminRetryDraft(
        session: const AuthSession(uid: 'admin-1'),
        job: job,
        reasonMessage: 'Retry from diagnostics.',
        currentTransitionId: 'transition-retrying',
        retryJobId: 'retry-job-1',
        retryTransitionId: 'transition-created',
        actionId: 'action-1',
        now: now,
      );

      expect(draft.currentJob.status, FirebaseJobStatus.retrying);
      expect(draft.currentJob.rootJobId, 'job-1');
      expect(draft.currentJob.retryCount, 0);
      expect(draft.currentJob.createdAt, createdAt);
      expect(draft.currentJob.updatedAt, now);
      expect(draft.currentJob.latestTransitionId, 'transition-retrying');

      expect(draft.retryJob.jobId, 'retry-job-1');
      expect(draft.retryJob.status, FirebaseJobStatus.created);
      expect(draft.retryJob.createdByUid, 'admin-1');
      expect(draft.retryJob.retryOfJobId, 'job-1');
      expect(draft.retryJob.rootJobId, 'job-1');
      expect(draft.retryJob.retryCount, 1);
      expect(draft.retryJob.latestTransitionId, 'transition-created');

      expect(draft.currentTransition.fromStatus, FirebaseJobStatus.failed);
      expect(draft.currentTransition.toStatus, FirebaseJobStatus.retrying);
      expect(draft.currentTransition.retryJobId, 'retry-job-1');
      expect(draft.retryTransition.fromStatus, isNull);
      expect(draft.retryTransition.toStatus, FirebaseJobStatus.created);

      expect(draft.action.actionType, 'retry_reconstruction_job');
      expect(draft.action.targetId, 'job-1');
      expect(draft.action.retryJobId, 'retry-job-1');
      expect(draft.action.metadata['root_job_id'], 'job-1');
      expect(draft.action.metadata['previous_status'], 'failed');
      expect(draft.action.createdAt, now);
    });
  });

  group('Firebase admin query specs', () {
    test('builds collection group job query shapes', () {
      final statusSpec = const FirebaseAdminJobQuery(
        status: FirebaseJobStatus.failed,
      ).toSpec();
      expect(
        statusSpec.collectionGroup,
        FirebaseAdminCollectionGroup.reconstructionJobs,
      );
      expect(statusSpec.filters.single.field, 'status');
      expect(statusSpec.filters.single.isEqualTo, 'failed');
      expect(statusSpec.orderBy.single.field, 'updated_at');
      expect(statusSpec.orderBy.single.descending, isTrue);

      final ownerSpec = const FirebaseAdminJobQuery(
        ownerUid: 'user-1',
      ).toSpec();
      expect(ownerSpec.filters.single.field, 'owner_uid');
      expect(ownerSpec.filters.single.isEqualTo, 'user-1');
      expect(ownerSpec.orderBy.single.field, 'created_at');

      final projectSpec = const FirebaseAdminJobQuery(
        projectId: 'project-1',
      ).toSpec();
      expect(projectSpec.filters.single.field, 'project_id');
      expect(projectSpec.filters.single.isEqualTo, 'project-1');

      final jobSpec = const FirebaseAdminJobQuery(jobId: 'job-1').toSpec();
      expect(jobSpec.filters.single.field, 'job_id');
      expect(jobSpec.filters.single.isEqualTo, 'job-1');

      final retrySpec = const FirebaseAdminJobQuery(
        retryOfJobId: 'job-1',
      ).toSpec();
      expect(retrySpec.filters.single.field, 'retry_of_job_id');
      expect(retrySpec.filters.single.isEqualTo, 'job-1');
    });

    test('rejects broad or unindexed combined admin job queries', () {
      expect(
        () => const FirebaseAdminJobQuery().toSpec(),
        throwsA(isA<FirebaseContractException>()),
      );
      expect(
        () => const FirebaseAdminJobQuery(
          status: FirebaseJobStatus.failed,
          ownerUid: 'user-1',
        ).toSpec(),
        throwsA(isA<FirebaseContractException>()),
      );
    });

    test('builds related admin collection group query shapes', () {
      final transitionSpec = FirebaseAdminQuerySpecs.transitionsForJob(
        jobId: 'job-1',
      );
      expect(
        transitionSpec.collectionGroup,
        FirebaseAdminCollectionGroup.transitions,
      );
      expect(transitionSpec.filters.single.field, 'job_id');
      expect(transitionSpec.orderBy.single.field, 'occurred_at');
      expect(transitionSpec.orderBy.single.descending, isFalse);

      final resultSpec = FirebaseAdminQuerySpecs.resultsForJob(jobId: 'job-1');
      expect(
        resultSpec.collectionGroup,
        FirebaseAdminCollectionGroup.openCvResults,
      );
      expect(resultSpec.orderBy.single.field, 'created_at');

      final layoutSpec = FirebaseAdminQuerySpecs.layoutsByOwner(
        ownerUid: 'user-1',
      );
      expect(layoutSpec.collectionGroup, FirebaseAdminCollectionGroup.layouts);
      expect(layoutSpec.filters.single.field, 'owner_uid');
      expect(layoutSpec.orderBy.single.field, 'updated_at');

      final actionsSpec = FirebaseAdminQuerySpecs.adminActionsForTarget(
        targetType: 'reconstruction_job',
        targetId: 'job-1',
      );
      expect(
        actionsSpec.collectionGroup,
        FirebaseAdminCollectionGroup.adminActions,
      );
      expect(actionsSpec.filters.map((filter) => filter.field), [
        'target_type',
        'target_id',
      ]);
      expect(actionsSpec.orderBy.single.field, 'created_at');
    });
  });

  group('Firebase admin query diagnostics', () {
    test('maps missing Firestore index failures to an admin diagnostic', () {
      final spec = const FirebaseAdminJobQuery(
        status: FirebaseJobStatus.failed,
      ).toSpec();
      final error = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'failed-precondition',
        message: 'The query requires an index. You can create it here.',
      );

      final exception = FirebaseAdminRepositoryException.fromFirestoreError(
        error,
        spec,
      );

      expect(exception.code, 'missing_index');
      expect(exception.message, contains('Missing Firestore index'));
      expect(exception.message, contains('reconstruction_jobs'));
      expect(exception.querySpec, same(spec));
    });

    test('maps rules denials without returning empty admin states', () {
      final spec = const FirebaseAdminJobQuery(ownerUid: 'user-1').toSpec();
      final error = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Missing or insufficient permissions.',
      );

      final exception = FirebaseAdminRepositoryException.fromFirestoreError(
        error,
        spec,
      );

      expect(exception.code, 'permission_denied');
      expect(exception.message, contains('denied by Firestore rules'));
    });
  });
}
