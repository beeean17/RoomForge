import 'dart:async';
import 'dart:typed_data';

import 'package:app/main.dart';
import 'package:app/src/admin/firebase_admin_access_repository.dart';
import 'package:app/src/api/backend_mode.dart';
import 'package:app/src/auth/auth_repository.dart';
import 'package:app/src/firebase/firebase_app_bootstrap.dart';
import 'package:app/src/firebase/firebase_project_repository.dart';
import 'package:app/src/projects/firebase_source_image_upload.dart';
import 'package:app/src/projects/project_api.dart';
import 'package:app/src/users/firebase_user_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('redirects protected mobile routes to login while signed out', (
    tester,
  ) async {
    final authRepository = _FakeAuthRepository();
    await tester.pumpWidget(
      RoomForgeMobileApp(
        bootstrap: _bootstrap(authRepository),
        projectApiFactory: (_, session) =>
            _FakeProjectApi(authRepository: authRepository),
        availableCameras: _emptyCameras,
        initialLocation: '/projects/project-1/capture',
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('사진으로'), findsOneWidget);
    expect(find.text('Google로 계속하기'), findsOneWidget);
  });

  testWidgets('opens the authenticated native project list route', (
    tester,
  ) async {
    final authRepository = _FakeAuthRepository(session: _session);
    final api = _FakeProjectApi(authRepository: authRepository);

    await tester.pumpWidget(
      RoomForgeMobileApp(
        bootstrap: _bootstrap(authRepository),
        projectApiFactory: (_, session) => api,
        availableCameras: _emptyCameras,
        initialLocation: '/projects',
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('내 프로젝트'), findsOneWidget);
    expect(find.text('거실 리노베이션'), findsOneWidget);
    expect(find.text('새 방 촬영'), findsOneWidget);
  });

  testWidgets('system back on the project list asks before exiting', (
    tester,
  ) async {
    final authRepository = _FakeAuthRepository(session: _session);
    final api = _FakeProjectApi(authRepository: authRepository);

    await tester.pumpWidget(
      RoomForgeMobileApp(
        bootstrap: _bootstrap(authRepository),
        projectApiFactory: (_, session) => api,
        availableCameras: _emptyCameras,
        initialLocation: '/projects',
      ),
    );

    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('내 프로젝트'), findsOneWidget);
    expect(find.text('한 번 더 누르면 앱을 종료합니다.'), findsOneWidget);
  });

  testWidgets('locks the native model preview until source images complete', (
    tester,
  ) async {
    final authRepository = _FakeAuthRepository(session: _session);
    final api = _FakeProjectApi(authRepository: authRepository);

    await tester.pumpWidget(
      RoomForgeMobileApp(
        bootstrap: _bootstrap(authRepository),
        projectApiFactory: (_, session) => api,
        availableCameras: _emptyCameras,
        initialLocation: '/projects/project-1/preview',
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('거실 리노베이션'), findsOneWidget);
    expect(find.text('소스 2/8'), findsNothing);
    expect(find.text('소스 단계 필요'), findsOneWidget);
    expect(find.text('소스 촬영'), findsWidgets);
    expect(find.text('데스크탑에서 편집'), findsNothing);
  });

  testWidgets('opens the native model preview after reconstruction succeeds', (
    tester,
  ) async {
    final authRepository = _FakeAuthRepository(session: _session);
    final api = _FakeProjectApi(
      authRepository: authRepository,
      capturedRoleIds: _allRequiredRoleIds,
      currentReconstructionStatus: 'succeeded',
      latestFloorPlanId: 'floor-plan-1',
    );

    await tester.pumpWidget(
      RoomForgeMobileApp(
        bootstrap: _bootstrap(authRepository),
        projectApiFactory: (_, session) => api,
        availableCameras: _emptyCameras,
        initialLocation: '/projects/project-1/preview',
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('거실 리노베이션'), findsOneWidget);
    expect(find.text('3D 미리보기'), findsOneWidget);
    expect(find.text('편집 준비됨'), findsNothing);
    expect(find.text('데스크탑에서 편집'), findsOneWidget);
  });

  testWidgets('opens the reconstruction route as the middle workflow step', (
    tester,
  ) async {
    final authRepository = _FakeAuthRepository(session: _session);
    final api = _FakeProjectApi(
      authRepository: authRepository,
      capturedRoleIds: _allRequiredRoleIds,
    );

    await tester.pumpWidget(
      RoomForgeMobileApp(
        bootstrap: _bootstrap(authRepository),
        projectApiFactory: (_, session) => api,
        availableCameras: _emptyCameras,
        initialLocation: '/projects/project-1/reconstruction',
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('재구성'), findsWidgets);
    expect(find.text('재구성 대기'), findsWidgets);
    expect(find.text('상태 새로고침'), findsWidgets);
  });

  testWidgets('opens upload status as an eight-angle board', (tester) async {
    final authRepository = _FakeAuthRepository(session: _session);
    final api = _FakeProjectApi(authRepository: authRepository);

    await tester.pumpWidget(
      RoomForgeMobileApp(
        bootstrap: _bootstrap(authRepository),
        projectApiFactory: (_, session) => api,
        availableCameras: _emptyCameras,
        initialLocation: '/projects/project-1/upload',
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('업로드 상태'), findsWidgets);
    expect(find.text('소스 2/8'), findsNothing);
    expect(find.text('2 / 8'), findsOneWidget);
    expect(find.text('정면'), findsOneWidget);
    expect(find.text('정면 우측'), findsOneWidget);
    expect(find.text('후면 좌측'), findsOneWidget);
  });

  testWidgets('system back from a project deep link falls back to projects', (
    tester,
  ) async {
    final authRepository = _FakeAuthRepository(session: _session);
    final api = _FakeProjectApi(authRepository: authRepository);

    await tester.pumpWidget(
      RoomForgeMobileApp(
        bootstrap: _bootstrap(authRepository),
        projectApiFactory: (_, session) => api,
        availableCameras: _emptyCameras,
        initialLocation: '/projects/project-1',
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('2 / 8'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('내 프로젝트'), findsOneWidget);
    expect(find.text('새 방 촬영'), findsOneWidget);
  });

  testWidgets('system back from capture falls back to the project overview', (
    tester,
  ) async {
    final authRepository = _FakeAuthRepository(session: _session);
    final api = _FakeProjectApi(authRepository: authRepository);

    await tester.pumpWidget(
      RoomForgeMobileApp(
        bootstrap: _bootstrap(authRepository),
        projectApiFactory: (_, session) => api,
        availableCameras: _emptyCameras,
        initialLocation: '/projects/project-1/capture',
      ),
    );

    await tester.pumpAndSettle();
    expect(find.textContaining('16:9 가로 프레임'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('2 / 8'), findsOneWidget);
    expect(find.text('거실 리노베이션'), findsWidgets);
  });

  testWidgets('source image angle slots open the selected capture role', (
    tester,
  ) async {
    final authRepository = _FakeAuthRepository(session: _session);
    final api = _FakeProjectApi(authRepository: authRepository);

    await tester.pumpWidget(
      RoomForgeMobileApp(
        bootstrap: _bootstrap(authRepository),
        projectApiFactory: (_, session) => api,
        availableCameras: _emptyCameras,
        initialLocation: '/projects/project-1',
      ),
    );

    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -620));
    await tester.pumpAndSettle();

    expect(find.text('소스 이미지'), findsOneWidget);
    expect(find.text('2 / 8'), findsOneWidget);
    expect(find.text('정면 우측'), findsOneWidget);

    await tester.ensureVisible(find.text('정면 우측'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('정면 우측'));
    await tester.pumpAndSettle();

    expect(find.textContaining('정면 우측 각도'), findsOneWidget);
  });

  testWidgets('uploaded source slots open edit actions instead of capture', (
    tester,
  ) async {
    final authRepository = _FakeAuthRepository(session: _session);
    final api = _FakeProjectApi(authRepository: authRepository);

    await tester.pumpWidget(
      RoomForgeMobileApp(
        bootstrap: _bootstrap(authRepository),
        projectApiFactory: (_, session) => api,
        availableCameras: _emptyCameras,
        initialLocation: '/projects/project-1',
      ),
    );

    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -620));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('우측'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('우측'));
    await tester.pumpAndSettle();

    expect(find.text('Firebase 업로드 완료'), findsOneWidget);
    expect(find.text('수정 촬영'), findsOneWidget);
    expect(find.textContaining('우측 각도'), findsNothing);
  });
}

Future<List<Never>> _emptyCameras() async => const [];

const _session = AuthSession(
  uid: 'user-1',
  email: 'sample@example.com',
  displayName: 'Sample Yoon',
);

const _allRequiredRoleIds = [
  'front_wall',
  'front_right_corner',
  'right_wall',
  'back_right_corner',
  'back_wall',
  'back_left_corner',
  'left_wall',
  'front_left_corner',
];

FirebaseAppBootstrapResult _bootstrap(AuthRepository authRepository) {
  return FirebaseAppBootstrapResult(
    authRepository: authRepository,
    adminRepository: const DisabledFirebaseAdminRepository(),
    floorPlanRepository: const DisabledFirebaseFloorPlanRepository(),
    geometryRepository: const DisabledFirebaseGeometryRepository(),
    layoutRepository: const DisabledFirebaseLayoutRepository(),
    projectRepository: const DisabledFirebaseProjectRepository(),
    reconstructionRepository: const DisabledFirebaseReconstructionRepository(),
    roomDimensionsRepository: const DisabledFirebaseRoomDimensionsRepository(),
    sceneUnderstandingRepository:
        const DisabledFirebaseSceneUnderstandingRepository(),
    sourceImageRepository: const DisabledFirebaseSourceImageRepository(),
    sourceImageUploader: const DisabledFirebaseSourceImageUploader(),
    userRepository: DisabledFirebaseUserRepository(),
    backendMode: BackendMode.firebase,
  );
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.session});

  final AuthSession? session;

  @override
  Stream<AuthSession?> authStateChanges() => Stream.value(session);

  @override
  Future<String?> idToken() async => 'token';

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signOut() async {}
}

class _FakeProjectApi extends ProjectApi {
  _FakeProjectApi({
    required super.authRepository,
    this.capturedRoleIds = const ['front_wall', 'right_wall'],
    this.currentReconstructionStatus,
    this.latestFloorPlanId,
  });

  final now = DateTime.utc(2026, 6, 5, 12);
  final List<String> capturedRoleIds;
  final String? currentReconstructionStatus;
  final String? latestFloorPlanId;

  @override
  Future<List<RoomProject>> listProjects() async => [_project];

  @override
  Future<RoomProject> getProject(String projectId) async => _project;

  @override
  Future<RoomProject> createProject({
    required String name,
    String? description,
  }) async {
    return RoomProject(
      id: 'project-created',
      userId: _session.uid,
      name: name,
      description: description,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<RoomDimensions?> getRoomDimensions({required String projectId}) async {
    return _dimensions;
  }

  @override
  Future<CaptureSessionSnapshot?> loadLatestCaptureSession({
    required String projectId,
  }) async {
    return _captureSnapshot;
  }

  @override
  Future<RoomDimensions> saveRoomDimensions({
    required String projectId,
    required double widthValue,
    required double depthValue,
    double? heightValue,
  }) async {
    return _dimensions;
  }

  @override
  Future<CaptureSession> createCaptureSession({
    required String projectId,
    bool depthEnabled = false,
    String? notes,
  }) async {
    return _captureSnapshot.session;
  }

  @override
  Future<CaptureImage> uploadCaptureImage({
    required String projectId,
    required String captureSessionId,
    required String role,
    required String filename,
    required String contentType,
    required Uint8List bytes,
    int? widthPx,
    int? heightPx,
    int? captureOrder,
    List<CaptureDepthArtifactRef> depthArtifactRefs = const [],
    Map<String, Object?>? cameraPose,
    String? depthWarning,
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(1);
    return _captureImage(role);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  RoomProject get _project => RoomProject(
    id: 'project-1',
    userId: _session.uid,
    name: '거실 리노베이션',
    description: '이미지 ${capturedRoleIds.length} · 5.2 x 6.0 m',
    latestFloorPlanId: latestFloorPlanId,
    currentReconstructionStatus: currentReconstructionStatus,
    createdAt: now,
    updatedAt: now,
  );

  RoomDimensions get _dimensions => RoomDimensions(
    projectId: 'project-1',
    userId: _session.uid,
    widthValue: 5.2,
    depthValue: 6.0,
    heightValue: 2.8,
    unit: 'meters',
    heightSource: 'user',
    createdAt: now,
    updatedAt: now,
  );

  CaptureSessionSnapshot get _captureSnapshot => CaptureSessionSnapshot(
    session: CaptureSession(
      id: 'capture-1',
      projectId: 'project-1',
      userId: _session.uid,
      roomDimensionsId: 'dimensions-1',
      captureMethod: 'guided_mobile',
      depthEnabled: false,
      createdAt: now,
      updatedAt: now,
    ),
    images: [for (final role in capturedRoleIds) _captureImage(role)],
  );

  CaptureImage _captureImage(String role) => CaptureImage(
    id: 'image-$role',
    captureSessionId: 'capture-1',
    projectId: 'project-1',
    userId: _session.uid,
    sourceImageId: 'source-$role',
    role: role,
    storagePath: 'users/user-1/projects/project-1/$role.jpg',
    contentType: 'image/jpeg',
    widthPx: 1600,
    heightPx: 900,
    captureOrder: 0,
    createdAt: now,
    updatedAt: now,
  );
}
