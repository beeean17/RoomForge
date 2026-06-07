import 'dart:async';
import 'dart:collection';
import 'dart:io';
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
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

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
    expect(find.text('활동'), findsNothing);
    expect(find.text('설정'), findsNothing);
  });

  testWidgets('project cards expose rename and delete actions', (tester) async {
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
    await tester.ensureVisible(find.byTooltip('거실 리노베이션 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('거실 리노베이션 메뉴'));
    await tester.pumpAndSettle();

    expect(find.text('이름 변경'), findsOneWidget);
    expect(find.text('삭제'), findsOneWidget);

    await tester.tap(find.text('이름 변경'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '침실 레이아웃');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(api.projectName, '침실 레이아웃');
    expect(find.text('침실 레이아웃'), findsOneWidget);
  });

  testWidgets('project delete failure keeps the project visible', (
    tester,
  ) async {
    final authRepository = _FakeAuthRepository(session: _session);
    final api = _FakeProjectApi(
      authRepository: authRepository,
      deleteError: const ProjectApiException(
        '이 프로젝트를 삭제할 권한이 없습니다.',
        code: 'permission-denied',
      ),
    );

    await tester.pumpWidget(
      RoomForgeMobileApp(
        bootstrap: _bootstrap(authRepository),
        projectApiFactory: (_, session) => api,
        availableCameras: _emptyCameras,
        initialLocation: '/projects',
      ),
    );

    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('거실 리노베이션 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('거실 리노베이션 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '삭제'));
    await tester.pumpAndSettle();

    expect(api.deleted, isFalse);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 420));
    await tester.pumpAndSettle();
    expect(find.text('거실 리노베이션'), findsOneWidget);
    expect(find.textContaining('삭제할 권한이 없습니다'), findsOneWidget);
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
    expect(find.text('2D 레이아웃'), findsOneWidget);
    expect(find.text('편집 준비됨'), findsNothing);
    expect(find.text('좌회전'), findsNothing);
    expect(find.text('우회전'), findsNothing);
    expect(find.text('작게'), findsNothing);
    expect(find.text('크게'), findsNothing);
    expect(find.text('2D 변경 저장'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('평면도 요약'),
      180,
      maxScrolls: 6,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('mobile-2d-layout-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('문 1'), findsOneWidget);
    expect(find.text('창 1'), findsOneWidget);
    expect(find.text('품질 확인됨'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.textContaining('모바일에서는 보기만 가능합니다'),
      220,
      maxScrolls: 8,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('mobile-2d-layout-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('의자'), findsWidgets);
    expect(find.text('가구 목록 1'), findsOneWidget);
    expect(find.textContaining('모바일에서는 보기만 가능합니다'), findsOneWidget);
    expect(find.text('데스크탑에서 편집'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('컴퓨터에서 이어서 편집'),
      220,
      maxScrolls: 8,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('mobile-2d-layout-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('/projects/project-1/editor'), findsWidgets);
    expect(api.saveLayoutCount, 0);
  });

  testWidgets(
    'opens preview when a floor plan exists without source snapshot',
    (tester) async {
      final authRepository = _FakeAuthRepository(session: _session);
      final api = _FakeProjectApi(
        authRepository: authRepository,
        capturedRoleIds: const [],
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

      expect(find.text('소스 단계 필요'), findsNothing);
      expect(find.text('2D 레이아웃'), findsOneWidget);
    },
  );

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
    expect(find.text('재구성은 데스크탑 웹에서'), findsOneWidget);
    expect(find.text('웹 링크 복사'), findsOneWidget);
    expect(find.text('상태 새로고침'), findsWidgets);
  });

  testWidgets(
    'status refresh opens 2D preview when reconstruction is created',
    (tester) async {
      final authRepository = _FakeAuthRepository(session: _session);
      final api = _FakeProjectApi(
        authRepository: authRepository,
        capturedRoleIds: _allRequiredRoleIds,
        currentReconstructionStatus: 'processing',
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

      expect(find.text('재구성 중'), findsWidgets);
      expect(find.text('2D 레이아웃'), findsNothing);

      api.currentReconstructionStatus = 'created';

      await tester.tap(find.widgetWithText(OutlinedButton, '상태 새로고침'));
      await tester.pumpAndSettle();

      expect(find.text('2D 레이아웃'), findsOneWidget);
    },
  );

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

  testWidgets('project overview more menu exposes project management actions', (
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
    await tester.tap(find.byTooltip('더보기'));
    await tester.pumpAndSettle();

    expect(find.text('이름 변경'), findsOneWidget);
    expect(find.text('데스크탑 링크 복사'), findsOneWidget);
    expect(find.text('삭제'), findsOneWidget);
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

  testWidgets('source image angle slots ask for image source first', (
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

    expect(find.text('이미지 선택'), findsOneWidget);
    expect(find.text('이미지 촬영'), findsOneWidget);
    expect(find.textContaining('정면 우측 각도'), findsNothing);

    await tester.tap(find.text('이미지 촬영'));
    await tester.pumpAndSettle();

    expect(find.textContaining('정면 우측 각도'), findsOneWidget);
  });

  testWidgets('uploads all pending source images concurrently', (tester) async {
    final authRepository = _FakeAuthRepository(session: _session);
    final uploadGate = Completer<void>();
    final api = _FakeProjectApi(
      authRepository: authRepository,
      capturedRoleIds: const ['front_wall', 'right_wall'],
      uploadGate: uploadGate,
    );
    final roomImageBytes = File('assets/design/room.png').readAsBytesSync();
    final originalImagePickerPlatform = ImagePickerPlatform.instance;
    final imagePickerPlatform = _QueuedImagePickerPlatform([
      XFile.fromData(
        roomImageBytes,
        name: 'front-right.png',
        mimeType: 'image/png',
      ),
      XFile.fromData(
        roomImageBytes,
        name: 'back-wall.png',
        mimeType: 'image/png',
      ),
    ]);
    ImagePickerPlatform.instance = imagePickerPlatform;
    addTearDown(() {
      ImagePickerPlatform.instance = originalImagePickerPlatform;
    });

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

    await _selectSourceImageFromGallery(tester, '정면 우측');
    await _selectSourceImageFromGallery(tester, '후면');

    expect(imagePickerPlatform.pickCount, 2);
    expect(find.textContaining('이미지 선택 실패'), findsNothing);
    await tester.ensureVisible(find.text('소스 이미지'));
    await tester.pumpAndSettle();
    expect(find.text('모두 업로드'), findsOneWidget);
    expect(find.textContaining('2개 업로드 대기'), findsOneWidget);

    await tester.tap(find.text('모두 업로드'));
    await tester.pump();

    expect(api.maxConcurrentUploads, 2);
    expect(api.uploadedRoleIds, isEmpty);

    uploadGate.complete();
    await tester.pumpAndSettle();

    expect(
      api.uploadedRoleIds,
      containsAll(['front_right_corner', 'back_wall']),
    );
    expect(find.text('4 / 8'), findsOneWidget);
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
    expect(find.text('이미지 선택'), findsOneWidget);
    expect(find.text('이미지 촬영'), findsOneWidget);
    expect(find.textContaining('우측 각도'), findsNothing);
  });
}

Future<void> _selectSourceImageFromGallery(
  WidgetTester tester,
  String roleLabel,
) async {
  await tester.ensureVisible(find.text(roleLabel));
  await tester.pumpAndSettle();
  await tester.tap(find.text(roleLabel));
  await tester.pumpAndSettle();
  await tester.tap(find.text('이미지 선택'));
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pumpAndSettle();
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

class _QueuedImagePickerPlatform extends ImagePickerPlatform {
  _QueuedImagePickerPlatform(List<XFile> images)
    : _images = Queue<XFile>.from(images);

  final Queue<XFile> _images;
  int pickCount = 0;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    pickCount += 1;
    if (_images.isEmpty) return null;
    return _images.removeFirst();
  }
}

class _FakeProjectApi extends ProjectApi {
  _FakeProjectApi({
    required super.authRepository,
    List<String> capturedRoleIds = const ['front_wall', 'right_wall'],
    this.currentReconstructionStatus,
    this.latestFloorPlanId,
    this.deleteError,
    this.uploadGate,
  }) : capturedRoleIds = List<String>.from(capturedRoleIds);

  final now = DateTime.utc(2026, 6, 5, 12);
  final List<String> capturedRoleIds;
  String? currentReconstructionStatus;
  String? latestFloorPlanId;
  final ProjectApiException? deleteError;
  final Completer<void>? uploadGate;
  final List<String> uploadedRoleIds = [];
  String projectName = '거실 리노베이션';
  String? projectDescription;
  SavedLayout? savedLayout;
  bool deleted = false;
  int activeUploads = 0;
  int maxConcurrentUploads = 0;
  int saveLayoutCount = 0;

  @override
  Future<List<RoomProject>> listProjects() async => deleted ? [] : [_project];

  @override
  Future<RoomProject> getProject(String projectId) async {
    if (deleted) {
      throw const ProjectApiException('Project not found.', code: 'not_found');
    }
    return _project;
  }

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
  Future<RoomProject> updateProject({
    required String projectId,
    required String name,
    String? description,
  }) async {
    projectName = name;
    projectDescription = description;
    return _project;
  }

  @override
  Future<void> deleteProject(String projectId) async {
    final error = deleteError;
    if (error != null) throw error;
    deleted = true;
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
    activeUploads += 1;
    if (activeUploads > maxConcurrentUploads) {
      maxConcurrentUploads = activeUploads;
    }
    onProgress?.call(0.2);
    try {
      final gate = uploadGate;
      if (gate != null) await gate.future;
      onProgress?.call(1);
      uploadedRoleIds.add(role);
      if (!capturedRoleIds.contains(role)) {
        capturedRoleIds.add(role);
      }
    } finally {
      activeUploads -= 1;
    }
    return _captureImage(role);
  }

  @override
  Future<SavedLayout> loadLatestLayout({required String projectId}) async {
    return savedLayout ?? _savedLayout;
  }

  @override
  Future<SavedLayout> saveLayout({
    required String projectId,
    required Map<String, Object?> roomDimensions,
    required Map<String, Object?> floorPlan,
    required Map<String, Object?> sourceMetadata,
    required List<Map<String, Object?>> furnitureObjects,
    required Map<String, Object?> editorScene,
  }) async {
    saveLayoutCount += 1;
    savedLayout = SavedLayout(
      id: 'layout-$saveLayoutCount',
      projectId: projectId,
      userId: _session.uid,
      roomDimensions: roomDimensions,
      floorPlan: floorPlan,
      sourceMetadata: sourceMetadata,
      furnitureObjects: furnitureObjects,
      editorScene: editorScene,
      createdAt: now,
      updatedAt: now,
    );
    return savedLayout!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  RoomProject get _project => RoomProject(
    id: 'project-1',
    userId: _session.uid,
    name: projectName,
    description:
        projectDescription ?? '이미지 ${capturedRoleIds.length} · 5.2 x 6.0 m',
    latestFloorPlanId: latestFloorPlanId,
    currentReconstructionStatus: currentReconstructionStatus,
    createdAt: now,
    updatedAt: now,
  );

  SavedLayout get _savedLayout => SavedLayout(
    id: 'layout-1',
    projectId: 'project-1',
    userId: _session.uid,
    roomDimensions: const {
      'width_value': 5.2,
      'depth_value': 6.0,
      'height_value': 2.8,
      'unit': 'meters',
    },
    floorPlan: const {
      'floor_plan_id': 'floor-plan-1',
      'coordinate_space': 'meters',
      'quality_status': 'success',
      'floor_polygon': [
        {'x': 0.0, 'y': 0.0},
        {'x': 5.2, 'y': 0.0},
        {'x': 5.2, 'y': 6.0},
        {'x': 0.0, 'y': 6.0},
      ],
      'structural_fixtures': [
        {
          'fixture_id': 'door-1',
          'category': 'door',
          'position_m': {'x': 2.2, 'z': 0.0},
          'size_m': {'x': 0.9, 'z': 0.1},
          'rotation_deg': 0.0,
        },
        {
          'fixture_id': 'window-1',
          'category': 'window',
          'position_m': {'x': 5.2, 'z': 3.1},
          'size_m': {'x': 1.2, 'z': 0.1},
          'rotation_deg': 90.0,
        },
      ],
    },
    sourceMetadata: const {
      'source_image_id': 'source-front_wall',
      'reconstruction_job_id': 'job-1',
      'reconstruction_status': 'succeeded',
    },
    furnitureObjects: const [
      {
        'id': 'furniture-chair-1',
        'category': 'chair',
        'position': {'x': 1.4, 'y': 1.6},
        'size': {
          'width_meters': 0.8,
          'depth_meters': 0.7,
          'height_meters': 0.9,
        },
        'rotation_degrees': 0.0,
        'color': '#64748b',
        'label': '의자',
        'locked': false,
      },
    ],
    editorScene: const {'scene_id': 'scene-1', 'view_mode': '2d'},
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
