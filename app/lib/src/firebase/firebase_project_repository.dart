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
  Future<List<FirebaseRoomProject>> listOwnedProjectsFromServer(
    String ownerUid,
  ) async {
    final snapshot = await _projects
        .where('owner_uid', isEqualTo: ownerUid)
        .get(const GetOptions(source: Source.server));
    return _sortedVisibleProjects(snapshot.docs);
  }

  @override
  Stream<List<FirebaseRoomProject>> watchOwnedProjects(String ownerUid) {
    return _projects.where('owner_uid', isEqualTo: ownerUid).snapshots().map((
      snapshot,
    ) {
      return _sortedVisibleProjects(snapshot.docs);
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

  List<FirebaseRoomProject> _sortedVisibleProjects(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final projects = docs
        .map(
          (doc) => FirebaseModelSerializers.roomProjectFromFirestore(
            _firestoreJson(doc.data()),
          ),
        )
        .where((project) => project.deletedAt == null)
        .toList();
    projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return projects;
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

class FirebaseFirestoreSourceImageRepository
    implements FirebaseSourceImageRepository {
  const FirebaseFirestoreSourceImageRepository({
    required FirebaseFirestore firestore,
  }) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _sourceImagesCollection(
    String projectId,
  ) {
    return _firestore
        .collection('projects')
        .doc(projectId)
        .collection('source_images');
  }

  CollectionReference<Map<String, dynamic>> _captureSessionsCollection(
    String projectId,
  ) {
    return _firestore
        .collection('projects')
        .doc(projectId)
        .collection('capture_sessions');
  }

  CollectionReference<Map<String, dynamic>> _captureImagesCollection(
    String projectId,
    String captureSessionId,
  ) {
    return _captureSessionsCollection(
      projectId,
    ).doc(captureSessionId).collection('images');
  }

  @override
  String newSourceImageId({required String projectId}) {
    return _sourceImagesCollection(projectId).doc().id;
  }

  @override
  String newCaptureSessionId({required String projectId}) {
    return _captureSessionsCollection(projectId).doc().id;
  }

  @override
  String newCaptureImageId({
    required String projectId,
    required String captureSessionId,
  }) {
    return _captureImagesCollection(projectId, captureSessionId).doc().id;
  }

  @override
  Future<FirebaseSourceImage> createMetadataAfterUpload(
    FirebaseSourceImage sourceImage,
  ) async {
    final doc = _sourceImagesCollection(
      sourceImage.projectId,
    ).doc(sourceImage.sourceImageId);
    final projectDoc = _firestore
        .collection('projects')
        .doc(sourceImage.projectId);
    final batch = _firestore.batch()
      ..set(doc, sourceImage.toFirestoreJson())
      ..update(projectDoc, {
        'latest_source_image_id': sourceImage.sourceImageId,
        'updated_at': Timestamp.fromDate(sourceImage.updatedAt),
      });
    await batch.commit();
    return sourceImage;
  }

  @override
  Future<FirebaseCaptureSession> createCaptureSession(
    FirebaseCaptureSession session,
  ) async {
    final doc = _captureSessionsCollection(
      session.projectId,
    ).doc(session.captureSessionId);
    await doc.set(session.toFirestoreJson());
    return session;
  }

  @override
  Future<FirebaseCaptureSession?> getLatestCaptureSession({
    required String ownerUid,
    required String projectId,
  }) async {
    final snapshot = await _captureSessionsCollection(projectId)
        .where('owner_uid', isEqualTo: ownerUid)
        .orderBy('updated_at', descending: true)
        .limit(1)
        .get(const GetOptions(source: Source.server));
    if (snapshot.docs.isEmpty) {
      return null;
    }
    final session = FirebaseModelSerializers.captureSessionFromFirestore(
      _firestoreJson(snapshot.docs.first.data()),
    );
    if (session.ownerUid != ownerUid) {
      throw const FirebaseContractException(
        'Capture session is not available.',
      );
    }
    return session;
  }

  @override
  Future<FirebaseCaptureImage> createCaptureImageMetadataAfterUpload(
    FirebaseCaptureImage captureImage,
  ) async {
    final doc = _captureImagesCollection(
      captureImage.projectId,
      captureImage.captureSessionId,
    ).doc(captureImage.captureImageId);
    await doc.set(captureImage.toFirestoreJson());
    return captureImage;
  }

  @override
  Future<FirebaseSourceImage?> getSourceImage({
    required String ownerUid,
    required String projectId,
    required String sourceImageId,
  }) async {
    final snapshot = await _sourceImagesCollection(
      projectId,
    ).doc(sourceImageId).get(const GetOptions(source: Source.server));
    final data = snapshot.data();
    if (data == null) {
      return null;
    }
    final sourceImage = FirebaseModelSerializers.sourceImageFromFirestore(
      _firestoreJson(data),
    );
    if (sourceImage.ownerUid != ownerUid) {
      throw const FirebaseContractException('Source image is not available.');
    }
    return sourceImage;
  }

  @override
  Stream<List<FirebaseSourceImage>> watchProjectSourceImages({
    required String ownerUid,
    required String projectId,
  }) {
    return _sourceImagesCollection(
      projectId,
    ).where('owner_uid', isEqualTo: ownerUid).snapshots().map((snapshot) {
      final images = snapshot.docs
          .map(
            (doc) => FirebaseModelSerializers.sourceImageFromFirestore(
              _firestoreJson(doc.data()),
            ),
          )
          .toList();
      images.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
      return images;
    });
  }

  @override
  Stream<List<FirebaseCaptureImage>> watchCaptureImages({
    required String ownerUid,
    required String projectId,
    required String captureSessionId,
  }) {
    return _captureImagesCollection(
      projectId,
      captureSessionId,
    ).where('owner_uid', isEqualTo: ownerUid).snapshots().map((snapshot) {
      final images = snapshot.docs
          .map(
            (doc) => FirebaseModelSerializers.captureImageFromFirestore(
              _firestoreJson(doc.data()),
            ),
          )
          .toList();
      images.sort(
        (a, b) => (a.captureOrder ?? 0).compareTo(b.captureOrder ?? 0),
      );
      return images;
    });
  }
}

class FirebaseFirestoreReconstructionRepository
    implements FirebaseReconstructionRepository {
  const FirebaseFirestoreReconstructionRepository({
    required FirebaseFirestore firestore,
  }) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _jobsCollection(String projectId) {
    return _firestore
        .collection('projects')
        .doc(projectId)
        .collection('reconstruction_jobs');
  }

  DocumentReference<Map<String, dynamic>> _projectDoc(String projectId) {
    return _firestore.collection('projects').doc(projectId);
  }

  DocumentReference<Map<String, dynamic>> _jobDoc({
    required String projectId,
    required String jobId,
  }) {
    return _jobsCollection(projectId).doc(jobId);
  }

  CollectionReference<Map<String, dynamic>> _transitionsCollection({
    required String projectId,
    required String jobId,
  }) {
    return _jobsCollection(projectId).doc(jobId).collection('transitions');
  }

  @override
  String newJobId({required String projectId}) {
    return _jobsCollection(projectId).doc().id;
  }

  @override
  String newTransitionId({required String projectId, required String jobId}) {
    return _transitionsCollection(projectId: projectId, jobId: jobId).doc().id;
  }

  @override
  Future<FirebaseReconstructionJob> createJobWithTransition({
    required FirebaseReconstructionJob job,
    required FirebaseJobStatusTransition transition,
    required FirebaseRoomProject project,
  }) async {
    final batch = _firestore.batch();
    batch.set(
      _jobDoc(projectId: job.projectId, jobId: job.jobId),
      job.toFirestoreJson(),
    );
    batch.set(
      _transitionsCollection(
        projectId: transition.projectId,
        jobId: transition.jobId,
      ).doc(transition.transitionId),
      transition.toFirestoreJson(),
    );
    batch.set(_projectDoc(project.projectId), project.toFirestoreJson());
    await batch.commit();
    return job;
  }

  @override
  Future<FirebaseReconstructionJob> updateJobWithTransition({
    required FirebaseReconstructionJob job,
    required FirebaseJobStatusTransition transition,
    required FirebaseRoomProject project,
  }) async {
    final batch = _firestore.batch();
    batch.set(
      _jobDoc(projectId: job.projectId, jobId: job.jobId),
      job.toFirestoreJson(),
    );
    batch.set(
      _transitionsCollection(
        projectId: transition.projectId,
        jobId: transition.jobId,
      ).doc(transition.transitionId),
      transition.toFirestoreJson(),
    );
    batch.set(_projectDoc(project.projectId), project.toFirestoreJson());
    await batch.commit();
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
    final batch = _firestore.batch();
    batch.set(
      _jobDoc(projectId: currentJob.projectId, jobId: currentJob.jobId),
      currentJob.toFirestoreJson(),
    );
    batch.set(
      _transitionsCollection(
        projectId: currentTransition.projectId,
        jobId: currentTransition.jobId,
      ).doc(currentTransition.transitionId),
      currentTransition.toFirestoreJson(),
    );
    batch.set(
      _jobDoc(projectId: retryJob.projectId, jobId: retryJob.jobId),
      retryJob.toFirestoreJson(),
    );
    batch.set(
      _transitionsCollection(
        projectId: retryTransition.projectId,
        jobId: retryTransition.jobId,
      ).doc(retryTransition.transitionId),
      retryTransition.toFirestoreJson(),
    );
    batch.set(_projectDoc(project.projectId), project.toFirestoreJson());
    await batch.commit();
    return retryJob;
  }

  @override
  Future<FirebaseReconstructionJob?> getJob({
    required String ownerUid,
    required String projectId,
    required String jobId,
  }) async {
    final snapshot = await _jobsCollection(
      projectId,
    ).doc(jobId).get(const GetOptions(source: Source.server));
    return _jobFromSnapshot(snapshot, ownerUid: ownerUid);
  }

  @override
  Stream<FirebaseReconstructionJob?> watchJob({
    required String ownerUid,
    required String projectId,
    required String jobId,
  }) {
    return _jobsCollection(projectId).doc(jobId).snapshots().map((snapshot) {
      return _jobFromSnapshot(snapshot, ownerUid: ownerUid);
    });
  }

  FirebaseReconstructionJob? _jobFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot, {
    required String ownerUid,
  }) {
    final data = snapshot.data();
    if (data == null) {
      return null;
    }
    final job = FirebaseModelSerializers.reconstructionJobFromFirestore(
      _firestoreJson(data),
    );
    if (job.ownerUid != ownerUid) {
      throw const FirebaseContractException(
        'Reconstruction job is not available.',
      );
    }
    return job;
  }
}

class FirebaseFirestoreGeometryRepository
    implements FirebaseGeometryRepository {
  const FirebaseFirestoreGeometryRepository({
    required FirebaseFirestore firestore,
  }) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _openCvResultsCollection(
    String projectId,
  ) {
    return _firestore
        .collection('projects')
        .doc(projectId)
        .collection('opencv_results');
  }

  CollectionReference<Map<String, dynamic>> _confirmedGeometriesCollection(
    String projectId,
  ) {
    return _firestore
        .collection('projects')
        .doc(projectId)
        .collection('confirmed_geometries');
  }

  @override
  Future<FirebaseOpenCvResult> saveOpenCvResult(
    FirebaseOpenCvResult result,
  ) async {
    result.validate();
    await _openCvResultsCollection(
      result.projectId,
    ).doc(result.resultId).set(result.toFirestoreJson());
    return result;
  }

  @override
  Future<FirebaseConfirmedGeometry> saveConfirmedGeometry(
    FirebaseConfirmedGeometry geometry,
  ) async {
    geometry.validate();
    await _confirmedGeometriesCollection(
      geometry.projectId,
    ).doc(geometry.geometryId).set(geometry.toFirestoreJson());
    return geometry;
  }

  @override
  Future<FirebaseOpenCvResult?> getOpenCvResult({
    required String ownerUid,
    required String projectId,
    required String resultId,
  }) async {
    final snapshot = await _openCvResultsCollection(
      projectId,
    ).doc(resultId).get(const GetOptions(source: Source.server));
    final data = snapshot.data();
    if (data == null) {
      return null;
    }
    final result = FirebaseModelSerializers.openCvResultFromFirestore(
      _firestoreJson(data),
    );
    if (result.ownerUid != ownerUid) {
      throw const FirebaseContractException('OpenCV result is not available.');
    }
    return result;
  }

  @override
  Future<FirebaseConfirmedGeometry?> getConfirmedGeometry({
    required String ownerUid,
    required String projectId,
    required String geometryId,
  }) async {
    final snapshot = await _confirmedGeometriesCollection(
      projectId,
    ).doc(geometryId).get(const GetOptions(source: Source.server));
    final data = snapshot.data();
    if (data == null) {
      return null;
    }
    final geometry = FirebaseModelSerializers.confirmedGeometryFromFirestore(
      _firestoreJson(data),
    );
    if (geometry.ownerUid != ownerUid) {
      throw const FirebaseContractException(
        'Confirmed geometry is not available.',
      );
    }
    return geometry;
  }
}

class FirebaseFirestoreFloorPlanRepository
    implements FirebaseFloorPlanRepository {
  const FirebaseFirestoreFloorPlanRepository({
    required FirebaseFirestore firestore,
  }) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _floorPlansCollection(
    String projectId,
  ) {
    return _firestore
        .collection('projects')
        .doc(projectId)
        .collection('floor_plans');
  }

  @override
  Future<FirebaseFloorPlan> saveFloorPlan(FirebaseFloorPlan floorPlan) async {
    floorPlan.validate();
    await _floorPlansCollection(
      floorPlan.projectId,
    ).doc(floorPlan.floorPlanId).set(floorPlan.toFirestoreJson());
    return floorPlan;
  }

  @override
  Future<FirebaseFloorPlan?> getFloorPlan({
    required String ownerUid,
    required String projectId,
    required String floorPlanId,
  }) async {
    final snapshot = await _floorPlansCollection(
      projectId,
    ).doc(floorPlanId).get(const GetOptions(source: Source.server));
    final data = snapshot.data();
    if (data == null) {
      return null;
    }
    final floorPlan = FirebaseModelSerializers.floorPlanFromFirestore(
      _firestoreJson(data),
    );
    if (floorPlan.ownerUid != ownerUid) {
      throw const FirebaseContractException('Floor plan is not available.');
    }
    return floorPlan;
  }
}

class FirebaseFirestoreLayoutRepository implements FirebaseLayoutRepository {
  const FirebaseFirestoreLayoutRepository({
    required FirebaseFirestore firestore,
  }) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _layoutsCollection(
    String projectId,
  ) {
    return _firestore
        .collection('projects')
        .doc(projectId)
        .collection('layouts');
  }

  @override
  Future<FirebaseSavedLayout> saveLayout(FirebaseSavedLayout layout) async {
    layout.validate();
    final batch = _firestore.batch();
    batch.set(
      _layoutsCollection(layout.projectId).doc(layout.layoutId),
      layout.toFirestoreJson(),
    );
    batch.update(_firestore.collection('projects').doc(layout.projectId), {
      'latest_layout_id': layout.layoutId,
      'updated_at': layout.updatedAt,
    });
    await batch.commit();
    return layout;
  }

  @override
  Future<FirebaseSavedLayout?> loadLatestLayout({
    required String ownerUid,
    required String projectId,
  }) async {
    final snapshot = await _layoutsCollection(projectId)
        .orderBy('updated_at', descending: true)
        .limit(1)
        .get(const GetOptions(source: Source.server));
    if (snapshot.docs.isEmpty) {
      return null;
    }
    final layout = FirebaseModelSerializers.savedLayoutFromFirestore(
      _firestoreJson(snapshot.docs.first.data()),
    );
    if (layout.ownerUid != ownerUid) {
      throw const FirebaseContractException('Layout is not available.');
    }
    return layout;
  }

  @override
  Future<FirebaseJson> exportLatestLayout({
    required String ownerUid,
    required String projectId,
  }) async {
    final layout = await loadLatestLayout(
      ownerUid: ownerUid,
      projectId: projectId,
    );
    if (layout == null) {
      throw const FirebaseContractException('Layout is not available.');
    }
    return layout.toExportJson();
  }
}

class FirebaseFirestoreSceneUnderstandingRepository
    implements FirebaseSceneUnderstandingRepository {
  const FirebaseFirestoreSceneUnderstandingRepository({
    required FirebaseFirestore firestore,
  }) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _resultsCollection(
    String projectId,
  ) {
    return _firestore
        .collection('projects')
        .doc(projectId)
        .collection('scene_understanding_results');
  }

  @override
  String newResultId({required String projectId}) {
    return _resultsCollection(projectId).doc().id;
  }

  @override
  Future<FirebaseSceneUnderstandingResult> saveSceneUnderstandingResult(
    FirebaseSceneUnderstandingResult result,
  ) async {
    result.validate();
    await _resultsCollection(
      result.projectId,
    ).doc(result.resultId).set(result.toFirestoreJson());
    return result;
  }

  @override
  Future<FirebaseSceneUnderstandingResult?> loadLatestSceneUnderstandingResult({
    required String ownerUid,
    required String projectId,
  }) async {
    final snapshot = await _resultsCollection(projectId)
        .orderBy('updated_at', descending: true)
        .limit(1)
        .get(const GetOptions(source: Source.server));
    if (snapshot.docs.isEmpty) {
      return null;
    }
    final result =
        FirebaseModelSerializers.sceneUnderstandingResultFromFirestore(
          _firestoreJson(snapshot.docs.first.data()),
        );
    if (result.ownerUid != ownerUid) {
      throw const FirebaseContractException(
        'Scene understanding result is not available.',
      );
    }
    return result;
  }
}

class DisabledFirebaseProjectRepository implements FirebaseProjectRepository {
  const DisabledFirebaseProjectRepository();

  @override
  Future<List<FirebaseRoomProject>> listOwnedProjectsFromServer(
    String ownerUid,
  ) {
    throw UnsupportedError('Firebase project access is unavailable.');
  }

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

class DisabledFirebaseSourceImageRepository
    implements FirebaseSourceImageRepository {
  const DisabledFirebaseSourceImageRepository();

  @override
  String newSourceImageId({required String projectId}) {
    throw UnsupportedError('Firebase source image access is unavailable.');
  }

  @override
  String newCaptureSessionId({required String projectId}) {
    throw UnsupportedError('Firebase capture session access is unavailable.');
  }

  @override
  String newCaptureImageId({
    required String projectId,
    required String captureSessionId,
  }) {
    throw UnsupportedError('Firebase capture image access is unavailable.');
  }

  @override
  Future<FirebaseSourceImage> createMetadataAfterUpload(
    FirebaseSourceImage sourceImage,
  ) {
    throw UnsupportedError('Firebase source image access is unavailable.');
  }

  @override
  Future<FirebaseCaptureSession> createCaptureSession(
    FirebaseCaptureSession session,
  ) {
    throw UnsupportedError('Firebase capture session access is unavailable.');
  }

  @override
  Future<FirebaseCaptureSession?> getLatestCaptureSession({
    required String ownerUid,
    required String projectId,
  }) {
    throw UnsupportedError('Firebase capture session access is unavailable.');
  }

  @override
  Future<FirebaseCaptureImage> createCaptureImageMetadataAfterUpload(
    FirebaseCaptureImage captureImage,
  ) {
    throw UnsupportedError('Firebase capture image access is unavailable.');
  }

  @override
  Future<FirebaseSourceImage?> getSourceImage({
    required String ownerUid,
    required String projectId,
    required String sourceImageId,
  }) {
    throw UnsupportedError('Firebase source image access is unavailable.');
  }

  @override
  Stream<List<FirebaseSourceImage>> watchProjectSourceImages({
    required String ownerUid,
    required String projectId,
  }) {
    return Stream.error(
      UnsupportedError('Firebase source image access is unavailable.'),
    );
  }

  @override
  Stream<List<FirebaseCaptureImage>> watchCaptureImages({
    required String ownerUid,
    required String projectId,
    required String captureSessionId,
  }) {
    return Stream.error(
      UnsupportedError('Firebase capture image access is unavailable.'),
    );
  }
}

class DisabledFirebaseReconstructionRepository
    implements FirebaseReconstructionRepository {
  const DisabledFirebaseReconstructionRepository();

  @override
  String newJobId({required String projectId}) {
    throw UnsupportedError('Firebase reconstruction access is unavailable.');
  }

  @override
  String newTransitionId({required String projectId, required String jobId}) {
    throw UnsupportedError('Firebase reconstruction access is unavailable.');
  }

  @override
  Future<FirebaseReconstructionJob> createJobWithTransition({
    required FirebaseReconstructionJob job,
    required FirebaseJobStatusTransition transition,
    required FirebaseRoomProject project,
  }) {
    throw UnsupportedError('Firebase reconstruction access is unavailable.');
  }

  @override
  Future<FirebaseReconstructionJob> updateJobWithTransition({
    required FirebaseReconstructionJob job,
    required FirebaseJobStatusTransition transition,
    required FirebaseRoomProject project,
  }) {
    throw UnsupportedError('Firebase reconstruction access is unavailable.');
  }

  @override
  Future<FirebaseReconstructionJob?> getJob({
    required String ownerUid,
    required String projectId,
    required String jobId,
  }) {
    throw UnsupportedError('Firebase reconstruction access is unavailable.');
  }

  @override
  Future<FirebaseReconstructionJob> retryJobWithTransitions({
    required FirebaseReconstructionJob currentJob,
    required FirebaseJobStatusTransition currentTransition,
    required FirebaseReconstructionJob retryJob,
    required FirebaseJobStatusTransition retryTransition,
    required FirebaseRoomProject project,
  }) {
    throw UnsupportedError('Firebase reconstruction access is unavailable.');
  }

  @override
  Stream<FirebaseReconstructionJob?> watchJob({
    required String ownerUid,
    required String projectId,
    required String jobId,
  }) {
    return Stream.error(
      UnsupportedError('Firebase reconstruction access is unavailable.'),
    );
  }
}

class DisabledFirebaseGeometryRepository implements FirebaseGeometryRepository {
  const DisabledFirebaseGeometryRepository();

  @override
  Future<FirebaseOpenCvResult> saveOpenCvResult(FirebaseOpenCvResult result) {
    throw UnsupportedError('Firebase geometry access is unavailable.');
  }

  @override
  Future<FirebaseConfirmedGeometry> saveConfirmedGeometry(
    FirebaseConfirmedGeometry geometry,
  ) {
    throw UnsupportedError('Firebase geometry access is unavailable.');
  }

  @override
  Future<FirebaseOpenCvResult?> getOpenCvResult({
    required String ownerUid,
    required String projectId,
    required String resultId,
  }) {
    throw UnsupportedError('Firebase geometry access is unavailable.');
  }

  @override
  Future<FirebaseConfirmedGeometry?> getConfirmedGeometry({
    required String ownerUid,
    required String projectId,
    required String geometryId,
  }) {
    throw UnsupportedError('Firebase geometry access is unavailable.');
  }
}

class DisabledFirebaseFloorPlanRepository
    implements FirebaseFloorPlanRepository {
  const DisabledFirebaseFloorPlanRepository();

  @override
  Future<FirebaseFloorPlan> saveFloorPlan(FirebaseFloorPlan floorPlan) {
    throw UnsupportedError('Firebase floor plan access is unavailable.');
  }

  @override
  Future<FirebaseFloorPlan?> getFloorPlan({
    required String ownerUid,
    required String projectId,
    required String floorPlanId,
  }) {
    throw UnsupportedError('Firebase floor plan access is unavailable.');
  }
}

class DisabledFirebaseLayoutRepository implements FirebaseLayoutRepository {
  const DisabledFirebaseLayoutRepository();

  @override
  Future<FirebaseSavedLayout> saveLayout(FirebaseSavedLayout layout) {
    throw UnsupportedError('Firebase layout access is unavailable.');
  }

  @override
  Future<FirebaseSavedLayout?> loadLatestLayout({
    required String ownerUid,
    required String projectId,
  }) {
    throw UnsupportedError('Firebase layout access is unavailable.');
  }

  @override
  Future<FirebaseJson> exportLatestLayout({
    required String ownerUid,
    required String projectId,
  }) {
    throw UnsupportedError('Firebase layout access is unavailable.');
  }
}

class DisabledFirebaseSceneUnderstandingRepository
    implements FirebaseSceneUnderstandingRepository {
  const DisabledFirebaseSceneUnderstandingRepository();

  @override
  String newResultId({required String projectId}) {
    throw UnsupportedError(
      'Firebase scene understanding access is unavailable.',
    );
  }

  @override
  Future<FirebaseSceneUnderstandingResult> saveSceneUnderstandingResult(
    FirebaseSceneUnderstandingResult result,
  ) {
    throw UnsupportedError(
      'Firebase scene understanding access is unavailable.',
    );
  }

  @override
  Future<FirebaseSceneUnderstandingResult?> loadLatestSceneUnderstandingResult({
    required String ownerUid,
    required String projectId,
  }) {
    throw UnsupportedError(
      'Firebase scene understanding access is unavailable.',
    );
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
