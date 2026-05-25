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
