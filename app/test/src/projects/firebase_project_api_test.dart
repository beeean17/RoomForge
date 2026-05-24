import 'package:flutter_test/flutter_test.dart';
import 'package:app/src/auth/auth_repository.dart';
import 'package:app/src/firebase/firebase_models.dart';
import 'package:app/src/firebase/firebase_repositories.dart';
import 'package:app/src/projects/firebase_project_api.dart';

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
