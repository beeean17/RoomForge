import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_models.dart';
import 'firebase_repositories.dart';
import 'firebase_serializers.dart';

class FirebaseFirestoreProjectRepository implements FirebaseProjectRepository {
  const FirebaseFirestoreProjectRepository({
    required FirebaseFirestore firestore,
  }) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _projects =>
      _firestore.collection('projects');

  @override
  Stream<List<FirebaseRoomProject>> watchOwnedProjects(String ownerUid) {
    return _projects.where('owner_uid', isEqualTo: ownerUid).snapshots().map((
      snapshot,
    ) {
      final projects = snapshot.docs
          .map(
            (doc) => FirebaseModelSerializers.roomProjectFromFirestore(
              _firestoreJson(doc.data()),
            ),
          )
          .where((project) => project.deletedAt == null)
          .toList();
      projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return projects;
    });
  }

  @override
  Future<FirebaseRoomProject> createProject({
    required String ownerUid,
    required String name,
    String? description,
  }) async {
    final doc = _projects.doc();
    final now = DateTime.now().toUtc();
    final project = FirebaseRoomProject(
      projectId: doc.id,
      ownerUid: ownerUid,
      name: name,
      description: description,
      schemaVersion: 1,
      createdAt: now,
      updatedAt: now,
    );
    await doc.set(project.toFirestoreJson());
    return project;
  }

  @override
  Future<FirebaseRoomProject> getProject({
    required String ownerUid,
    required String projectId,
  }) async {
    final snapshot = await _projects
        .doc(projectId)
        .get(const GetOptions(source: Source.server));
    final project = _projectFromSnapshot(snapshot);
    if (project.ownerUid != ownerUid || project.deletedAt != null) {
      throw const FirebaseContractException('Project is not available.');
    }
    return project;
  }

  @override
  Future<FirebaseRoomProject> updateProject(FirebaseRoomProject project) async {
    final doc = _projects.doc(project.projectId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(doc);
      final current = _projectFromSnapshot(snapshot);
      if (current.ownerUid != project.ownerUid || current.deletedAt != null) {
        throw const FirebaseContractException('Project is not available.');
      }
      transaction.set(doc, project.toFirestoreJson());
    });
    return project;
  }

  @override
  Future<void> softDeleteProject({
    required String ownerUid,
    required String projectId,
  }) async {
    final doc = _projects.doc(projectId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(doc);
      final current = _projectFromSnapshot(snapshot);
      if (current.ownerUid != ownerUid || current.deletedAt != null) {
        throw const FirebaseContractException('Project is not available.');
      }
      final now = DateTime.now().toUtc();
      final deleted = FirebaseRoomProject(
        projectId: current.projectId,
        ownerUid: current.ownerUid,
        name: current.name,
        description: current.description,
        schemaVersion: current.schemaVersion,
        createdAt: current.createdAt,
        updatedAt: now,
        deletedAt: now,
        latestSourceImageId: current.latestSourceImageId,
        latestJobId: current.latestJobId,
        latestFloorPlanId: current.latestFloorPlanId,
        latestLayoutId: current.latestLayoutId,
        currentReconstructionStatus: current.currentReconstructionStatus,
        lastOpenedAt: current.lastOpenedAt,
      );
      transaction.set(doc, deleted.toFirestoreJson());
    });
  }

  FirebaseRoomProject _projectFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) {
      throw const FirebaseContractException('Project was not found.');
    }
    return FirebaseModelSerializers.roomProjectFromFirestore(
      _firestoreJson(data),
    );
  }
}

class FirebaseFirestoreRoomDimensionsRepository
    implements FirebaseRoomDimensionsRepository {
  const FirebaseFirestoreRoomDimensionsRepository({
    required FirebaseFirestore firestore,
  }) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _dimensionsDoc(String projectId) {
    return _firestore
        .collection('projects')
        .doc(projectId)
        .collection('room_dimensions')
        .doc('current');
  }

  @override
  Future<FirebaseRoomDimensions> saveCurrent(
    FirebaseRoomDimensions dimensions,
  ) async {
    dimensions.validate();
    final doc = _dimensionsDoc(dimensions.projectId);
    await doc.set(dimensions.toFirestoreJson());
    return dimensions;
  }

  @override
  Future<FirebaseRoomDimensions?> getCurrent({
    required String ownerUid,
    required String projectId,
  }) async {
    final snapshot = await _dimensionsDoc(
      projectId,
    ).get(const GetOptions(source: Source.server));
    final data = snapshot.data();
    if (data == null) {
      return null;
    }
    final dimensions = FirebaseModelSerializers.roomDimensionsFromFirestore(
      _firestoreJson(data),
    );
    if (dimensions.ownerUid != ownerUid) {
      throw const FirebaseContractException(
        'Room dimensions are not available.',
      );
    }
    return dimensions;
  }
}

class DisabledFirebaseProjectRepository implements FirebaseProjectRepository {
  const DisabledFirebaseProjectRepository();

  @override
  Stream<List<FirebaseRoomProject>> watchOwnedProjects(String ownerUid) {
    return Stream.error(
      UnsupportedError('Firebase project access is unavailable.'),
    );
  }

  @override
  Future<FirebaseRoomProject> createProject({
    required String ownerUid,
    required String name,
    String? description,
  }) {
    throw UnsupportedError('Firebase project access is unavailable.');
  }

  @override
  Future<FirebaseRoomProject> getProject({
    required String ownerUid,
    required String projectId,
  }) {
    throw UnsupportedError('Firebase project access is unavailable.');
  }

  @override
  Future<FirebaseRoomProject> updateProject(FirebaseRoomProject project) {
    throw UnsupportedError('Firebase project access is unavailable.');
  }

  @override
  Future<void> softDeleteProject({
    required String ownerUid,
    required String projectId,
  }) {
    throw UnsupportedError('Firebase project access is unavailable.');
  }
}

class DisabledFirebaseRoomDimensionsRepository
    implements FirebaseRoomDimensionsRepository {
  const DisabledFirebaseRoomDimensionsRepository();

  @override
  Future<FirebaseRoomDimensions> saveCurrent(
    FirebaseRoomDimensions dimensions,
  ) {
    throw UnsupportedError('Firebase room dimensions are unavailable.');
  }

  @override
  Future<FirebaseRoomDimensions?> getCurrent({
    required String ownerUid,
    required String projectId,
  }) {
    throw UnsupportedError('Firebase room dimensions are unavailable.');
  }
}

FirebaseJson _firestoreJson(Map<String, dynamic> data) {
  return data.map((key, value) => MapEntry(key, _firestoreValue(value)));
}

Object? _firestoreValue(Object? value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is Map) {
    return value.map(
      (key, nestedValue) =>
          MapEntry(key.toString(), _firestoreValue(nestedValue)),
    );
  }
  if (value is Iterable) {
    return value.map(_firestoreValue).toList();
  }
  return value;
}
