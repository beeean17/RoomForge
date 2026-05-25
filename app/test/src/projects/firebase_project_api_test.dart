import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:app/src/auth/auth_repository.dart';
import 'package:app/src/firebase/firebase_models.dart';
import 'package:app/src/firebase/firebase_repositories.dart';
import 'package:app/src/projects/firebase_project_api.dart';
import 'package:app/src/projects/firebase_source_image_upload.dart';
import 'package:app/src/projects/project_api.dart';

void main() {
  test(
    'FirebaseProjectApi creates projects with the signed-in owner uid',
    () async {
      final projects = _FakeProjectRepository();
      final api = FirebaseProjectApi(
        authRepository: DisabledAuthRepository(),
        session: _session(),
        projectRepository: projects,
        reconstructionRepository: _FakeReconstructionRepository(),
        roomDimensionsRepository: _FakeRoomDimensionsRepository(),
        sourceImageRepository: _FakeSourceImageRepository(),
        sourceImageUploader: _FakeSourceImageUploader(),
      );

      final project = await api.createProject(
        name: 'Studio',
        description: 'North wall',
      );
      final listed = await api.listProjects();

      expect(project.id, 'project-1');
      expect(project.userId, 'user-1');
      expect(project.name, 'Studio');
      expect(project.description, 'North wall');
      expect(listed.map((project) => project.id), contains('project-1'));
    },
  );

  test('FirebaseProjectApi saves and reloads metric room dimensions', () async {
    final dimensions = _FakeRoomDimensionsRepository();
    final api = FirebaseProjectApi(
      authRepository: DisabledAuthRepository(),
      session: _session(),
      projectRepository: _FakeProjectRepository(),
      reconstructionRepository: _FakeReconstructionRepository(),
      roomDimensionsRepository: dimensions,
      sourceImageRepository: _FakeSourceImageRepository(),
      sourceImageUploader: _FakeSourceImageUploader(),
    );

    final saved = await api.saveRoomDimensions(
      projectId: 'project-1',
      widthValue: 4.2,
      depthValue: 3.6,
    );
    final reloaded = await api.getRoomDimensions(projectId: 'project-1');

    expect(saved.unit, 'meters');
    expect(saved.heightValue, 2.4);
    expect(saved.usesDefaultHeight, isTrue);
    expect(reloaded?.widthValue, 4.2);
    expect(reloaded?.depthValue, 3.6);
  });

  test(
    'FirebaseProjectApi stores source metadata after upload succeeds',
    () async {
      final projects = _FakeProjectRepository();
      await projects.createProject(ownerUid: 'user-1', name: 'Studio');
      final sourceImages = _FakeSourceImageRepository();
      final uploader = _FakeSourceImageUploader();
      final progressUpdates = <double>[];
      final api = FirebaseProjectApi(
        authRepository: DisabledAuthRepository(),
        session: _session(),
        projectRepository: projects,
        reconstructionRepository: _FakeReconstructionRepository(),
        roomDimensionsRepository: _FakeRoomDimensionsRepository(),
        sourceImageRepository: sourceImages,
        sourceImageUploader: uploader,
      );

      final sourceImage = await api.uploadSourceImage(
        projectId: 'project-1',
        filename: '../Room Photo.png',
        contentType: 'image/png',
        bytes: Uint8List.fromList([1, 2, 3, 4]),
        widthPx: 1280,
        heightPx: 720,
        onProgress: progressUpdates.add,
      );

      expect(progressUpdates, containsAllInOrder([0, 0.5, 1]));
      expect(uploader.uploadedPath, sourceImages.saved?.storagePath);
      expect(
        sourceImages.saved?.storagePath,
        contains(
          'users/user-1/projects/project-1/source-images/source-1/Room_Photo.png',
        ),
      );
      expect(
        sourceImages.saved?.sha256Hex,
        FirebaseSourceImageUpload.sha256Hex(Uint8List.fromList([1, 2, 3, 4])),
      );
      expect(uploader.uploadedMetadata, containsPair('owner_uid', 'user-1'));
      expect(
        uploader.uploadedMetadata,
        containsPair('project_id', 'project-1'),
      );
      expect(
        uploader.uploadedMetadata,
        containsPair('source_image_id', 'source-1'),
      );
      expect(
        uploader.uploadedMetadata,
        containsPair('sha256_hex', sourceImages.saved?.sha256Hex),
      );
      expect(sourceImage.id, 'source-1');
      expect(sourceImage.contentType, 'image/png');
      expect(sourceImage.widthPx, 1280);
      expect(sourceImage.heightPx, 720);
    },
  );

  test(
    'FirebaseProjectApi does not store source metadata when upload fails',
    () async {
      final projects = _FakeProjectRepository();
      await projects.createProject(ownerUid: 'user-1', name: 'Studio');
      final sourceImages = _FakeSourceImageRepository();
      final api = FirebaseProjectApi(
        authRepository: DisabledAuthRepository(),
        session: _session(),
        projectRepository: projects,
        reconstructionRepository: _FakeReconstructionRepository(),
        roomDimensionsRepository: _FakeRoomDimensionsRepository(),
        sourceImageRepository: sourceImages,
        sourceImageUploader: _FakeSourceImageUploader(shouldFail: true),
      );

      await expectLater(
        api.uploadSourceImage(
          projectId: 'project-1',
          filename: 'room.png',
          contentType: 'image/png',
          bytes: Uint8List.fromList([1, 2, 3, 4]),
          widthPx: 1280,
          heightPx: 720,
        ),
        throwsA(
          isA<ProjectApiException>().having(
            (error) => error.code,
            'code',
            'upload_failed',
          ),
        ),
      );
      expect(sourceImages.saved, isNull);
    },
  );

  test(
    'FirebaseProjectApi creates reconstruction jobs and transitions',
    () async {
      final projects = _FakeProjectRepository();
      await projects.createProject(ownerUid: 'user-1', name: 'Studio');
      final reconstructions = _FakeReconstructionRepository();
      final api = FirebaseProjectApi(
        authRepository: DisabledAuthRepository(),
        session: _session(),
        projectRepository: projects,
        reconstructionRepository: reconstructions,
        roomDimensionsRepository: _FakeRoomDimensionsRepository(),
        sourceImageRepository: _FakeSourceImageRepository(),
        sourceImageUploader: _FakeSourceImageUploader(),
      );

      final job = await api.createReconstructionJob(
        projectId: 'project-1',
        sourceImageId: 'source-1',
      );
      final reloaded = await api.getReconstructionJob(
        projectId: 'project-1',
        jobId: job.id,
      );

      expect(job.status, 'created');
      expect(job.statusLabel, 'created');
      expect(job.terminal, isFalse);
      expect(reloaded.id, job.id);
      expect(
        reconstructions.transitions.single.toStatus,
        FirebaseJobStatus.created,
      );
      expect(
        reconstructions.jobs[job.id]?.latestTransitionId,
        reconstructions.transitions.single.transitionId,
      );
      expect(reconstructions.latestProject?.latestJobId, job.id);
      expect(
        reconstructions.latestProject?.currentReconstructionStatus,
        FirebaseJobStatus.created,
      );
    },
  );

  test(
    'FirebaseProjectApi updates reconstruction status with transition',
    () async {
      final projects = _FakeProjectRepository();
      await projects.createProject(ownerUid: 'user-1', name: 'Studio');
      final reconstructions = _FakeReconstructionRepository();
      final api = FirebaseProjectApi(
        authRepository: DisabledAuthRepository(),
        session: _session(),
        projectRepository: projects,
        reconstructionRepository: reconstructions,
        roomDimensionsRepository: _FakeRoomDimensionsRepository(),
        sourceImageRepository: _FakeSourceImageRepository(),
        sourceImageUploader: _FakeSourceImageUploader(),
      );
      final created = await api.createReconstructionJob(
        projectId: 'project-1',
        sourceImageId: 'source-1',
      );

      final updated = await api.updateReconstructionJobStatus(
        projectId: 'project-1',
        jobId: created.id,
        status: 'review_required',
        reasonCode: 'candidate_review_required',
        reasonMessage: 'Candidate extraction requires user review.',
      );

      expect(updated.status, 'review_required');
      expect(updated.statusLabel, 'Needs review');
      expect(
        reconstructions.jobs[created.id]?.latestTransitionId,
        'transition-2',
      );
      expect(
        reconstructions.transitions.last.fromStatus,
        FirebaseJobStatus.created,
      );
      expect(
        reconstructions.transitions.last.toStatus,
        FirebaseJobStatus.reviewRequired,
      );
      expect(reconstructions.transitions.last.actorUid, 'user-1');
      expect(
        reconstructions.transitions.last.reasonCode,
        'candidate_review_required',
      );
      expect(
        reconstructions.latestProject?.currentReconstructionStatus,
        FirebaseJobStatus.reviewRequired,
      );
    },
  );

  test('FirebaseProjectApi rejects generic retrying status updates', () async {
    final projects = _FakeProjectRepository();
    await projects.createProject(ownerUid: 'user-1', name: 'Studio');
    final api = FirebaseProjectApi(
      authRepository: DisabledAuthRepository(),
      session: _session(),
      projectRepository: projects,
      reconstructionRepository: _FakeReconstructionRepository(),
      roomDimensionsRepository: _FakeRoomDimensionsRepository(),
      sourceImageRepository: _FakeSourceImageRepository(),
      sourceImageUploader: _FakeSourceImageUploader(),
    );

    await expectLater(
      api.updateReconstructionJobStatus(
        projectId: 'project-1',
        jobId: 'job-1',
        status: 'retrying',
        reasonCode: 'manual_retry',
        reasonMessage: 'Retry requested.',
      ),
      throwsA(
        isA<ProjectApiException>().having(
          (error) => error.code,
          'code',
          'invalid_status_transition',
        ),
      ),
    );
  });

  test('FirebaseProjectApi creates linked retry reconstruction jobs', () async {
    final projects = _FakeProjectRepository();
    await projects.createProject(ownerUid: 'user-1', name: 'Studio');
    final reconstructions = _FakeReconstructionRepository();
    final api = FirebaseProjectApi(
      authRepository: DisabledAuthRepository(),
      session: _session(),
      projectRepository: projects,
      reconstructionRepository: reconstructions,
      roomDimensionsRepository: _FakeRoomDimensionsRepository(),
      sourceImageRepository: _FakeSourceImageRepository(),
      sourceImageUploader: _FakeSourceImageUploader(),
    );
    final original = await api.createReconstructionJob(
      projectId: 'project-1',
      sourceImageId: 'source-1',
    );

    final retry = await api.retryReconstructionJob(
      projectId: 'project-1',
      jobId: original.id,
    );

    expect(retry.id, isNot(original.id));
    expect(retry.retryOfJobId, original.id);
    expect(
      reconstructions.jobs[original.id]?.status,
      FirebaseJobStatus.retrying,
    );
    expect(
      reconstructions.jobs[original.id]?.latestTransitionId,
      reconstructions.transitions[1].transitionId,
    );
    expect(reconstructions.jobs[retry.id]?.retryCount, 1);
    expect(
      reconstructions.jobs[retry.id]?.latestTransitionId,
      reconstructions.transitions[2].transitionId,
    );
    expect(
      reconstructions.transitions.map((transition) => transition.toStatus),
      containsAllInOrder([
        FirebaseJobStatus.created,
        FirebaseJobStatus.retrying,
        FirebaseJobStatus.created,
      ]),
    );
  });
}

AuthSession _session() {
  return const AuthSession(uid: 'user-1', email: 'user@example.test');
}

class _FakeProjectRepository implements FirebaseProjectRepository {
  FirebaseRoomProject? project;

  @override
  Stream<List<FirebaseRoomProject>> watchOwnedProjects(String ownerUid) {
    return Stream.value([
      if (project != null && project!.ownerUid == ownerUid) project!,
    ]);
  }

  @override
  Future<FirebaseRoomProject> createProject({
    required String ownerUid,
    required String name,
    String? description,
  }) async {
    final now = DateTime.utc(2026);
    project = FirebaseRoomProject(
      projectId: 'project-1',
      ownerUid: ownerUid,
      name: name,
      description: description,
      schemaVersion: 1,
      createdAt: now,
      updatedAt: now,
    );
    return project!;
  }

  @override
  Future<FirebaseRoomProject> getProject({
    required String ownerUid,
    required String projectId,
  }) async {
    return project!;
  }

  @override
  Future<FirebaseRoomProject> updateProject(FirebaseRoomProject project) async {
    this.project = project;
    return project;
  }

  @override
  Future<void> softDeleteProject({
    required String ownerUid,
    required String projectId,
  }) async {}
}

class _FakeRoomDimensionsRepository
    implements FirebaseRoomDimensionsRepository {
  FirebaseRoomDimensions? dimensions;

  @override
  Future<FirebaseRoomDimensions> saveCurrent(
    FirebaseRoomDimensions dimensions,
  ) async {
    this.dimensions = dimensions;
    return dimensions;
  }

  @override
  Future<FirebaseRoomDimensions?> getCurrent({
    required String ownerUid,
    required String projectId,
  }) async {
    return dimensions;
  }
}

class _FakeSourceImageRepository implements FirebaseSourceImageRepository {
  FirebaseSourceImage? saved;

  @override
  String newSourceImageId({required String projectId}) => 'source-1';

  @override
  Future<FirebaseSourceImage> createMetadataAfterUpload(
    FirebaseSourceImage sourceImage,
  ) async {
    saved = sourceImage;
    return sourceImage;
  }

  @override
  Stream<List<FirebaseSourceImage>> watchProjectSourceImages({
    required String ownerUid,
    required String projectId,
  }) {
    return Stream.value([
      if (saved != null &&
          saved!.ownerUid == ownerUid &&
          saved!.projectId == projectId)
        saved!,
    ]);
  }
}

class _FakeReconstructionRepository
    implements FirebaseReconstructionRepository {
  final jobs = <String, FirebaseReconstructionJob>{};
  final transitions = <FirebaseJobStatusTransition>[];
  FirebaseRoomProject? latestProject;
  var _jobCount = 0;
  var _transitionCount = 0;

  @override
  String newJobId({required String projectId}) {
    _jobCount += 1;
    return 'job-$_jobCount';
  }

  @override
  String newTransitionId({required String projectId, required String jobId}) {
    _transitionCount += 1;
    return 'transition-$_transitionCount';
  }

  @override
  Future<FirebaseReconstructionJob> createJobWithTransition({
    required FirebaseReconstructionJob job,
    required FirebaseJobStatusTransition transition,
    required FirebaseRoomProject project,
  }) async {
    jobs[job.jobId] = job;
    transitions.add(transition);
    latestProject = project;
    return job;
  }

  @override
  Future<FirebaseReconstructionJob> updateJobWithTransition({
    required FirebaseReconstructionJob job,
    required FirebaseJobStatusTransition transition,
    required FirebaseRoomProject project,
  }) async {
    jobs[job.jobId] = job;
    transitions.add(transition);
    latestProject = project;
    return job;
  }

  @override
  Future<FirebaseReconstructionJob> retryJobWithTransitions({
    required FirebaseReconstructionJob currentJob,
    required FirebaseJobStatusTransition currentTransition,
    required FirebaseReconstructionJob retryJob,
    required FirebaseJobStatusTransition retryTransition,
    required FirebaseRoomProject project,
  }) async {
    jobs[currentJob.jobId] = currentJob;
    transitions.add(currentTransition);
    jobs[retryJob.jobId] = retryJob;
    transitions.add(retryTransition);
    latestProject = project;
    return retryJob;
  }

  @override
  Future<FirebaseReconstructionJob?> getJob({
    required String ownerUid,
    required String projectId,
    required String jobId,
  }) async {
    final job = jobs[jobId];
    if (job == null || job.ownerUid != ownerUid || job.projectId != projectId) {
      return null;
    }
    return job;
  }

  @override
  Stream<FirebaseReconstructionJob?> watchJob({
    required String ownerUid,
    required String projectId,
    required String jobId,
  }) {
    return Stream.fromFuture(
      getJob(ownerUid: ownerUid, projectId: projectId, jobId: jobId),
    );
  }
}

class _FakeSourceImageUploader implements FirebaseSourceImageUploader {
  _FakeSourceImageUploader({this.shouldFail = false});

  final bool shouldFail;
  String? uploadedPath;
  Map<String, String>? uploadedMetadata;

  @override
  Future<void> uploadBytes({
    required String storagePath,
    required Uint8List bytes,
    required String contentType,
    required Map<String, String> metadata,
    void Function(double progress)? onProgress,
  }) async {
    if (shouldFail) {
      throw StateError('upload failed');
    }
    onProgress?.call(0.5);
    uploadedPath = storagePath;
    uploadedMetadata = metadata;
    onProgress?.call(1);
  }
}
