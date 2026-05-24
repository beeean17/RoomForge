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
      final api = FirebaseProjectApi(
        authRepository: DisabledAuthRepository(),
        session: _session(),
        projectRepository: projects,
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
      );

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
  }) async {
    if (shouldFail) {
      throw StateError('upload failed');
    }
    uploadedPath = storagePath;
    uploadedMetadata = metadata;
  }
}
