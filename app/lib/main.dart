import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart' as camera;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'src/api/backend_bindings.dart';
import 'src/auth/auth_repository.dart';
import 'src/firebase/firebase_app_bootstrap.dart';
import 'src/projects/guided_capture_session_section.dart';
import 'src/projects/project_api.dart';

const _ink = Color(0xFFF8F8F5);
const _muted = Color(0xFFA7ADB0);
const _dim = Color(0xFF6E7378);
const _paper = Color(0xFF050505);
const _panel = Color(0xFF0B0D0F);
const _border = Color(0x244B6277);
const _borderStrong = Color(0x3A8292A0);
const _primary = Color(0xFF8FB4FF);
const _success = Color(0xFF80C7C2);
const _warning = Color(0xFFD49A5C);
const _danger = Color(0xFFE08B82);
const _captureAspectRatio = 16 / 9;
const _captureResolutionPreset = camera.ResolutionPreset.ultraHigh;
const _captureResolutionLabel = '2160p';
const _captureScreenOrientation = DeviceOrientation.landscapeLeft;
const _captureScreenOrientations = <DeviceOrientation>[
  _captureScreenOrientation,
];
const _systemManagedScreenOrientations = <DeviceOrientation>[];

typedef RoomForgeProjectApiFactory =
    ProjectApi Function(
      FirebaseAppBootstrapResult bootstrap,
      AuthSession session,
    );
typedef RoomForgeAvailableCameras =
    Future<List<camera.CameraDescription>> Function();

final _requiredGuidedCaptureRoles = defaultGuidedCaptureRoles
    .where((role) => role.required)
    .toList(growable: false);
final _requiredGuidedCaptureRoleIds = _requiredGuidedCaptureRoles
    .map((role) => role.id)
    .toSet();
final _pendingCaptureDraftsByProject =
    <String, Map<String, _PendingCaptureDraft>>{};

final _bootstrapProvider = Provider<FirebaseAppBootstrapResult>((ref) {
  throw UnimplementedError(
    'FirebaseAppBootstrapResult is provided at app boot.',
  );
});

final _projectApiFactoryProvider = Provider<RoomForgeProjectApiFactory>((ref) {
  return _defaultProjectApiFactory;
});

final _availableCamerasProvider = Provider<RoomForgeAvailableCameras>((ref) {
  return camera.availableCameras;
});

final _initialLocationProvider = Provider<String>((ref) => '/projects');

final _authSessionProvider = StreamProvider<AuthSession?>((ref) {
  return ref.watch(_bootstrapProvider).authRepository.authStateChanges();
});

class _PendingCaptureDraft {
  const _PendingCaptureDraft({
    required this.roleId,
    required this.filename,
    required this.contentType,
    required this.bytes,
    required this.widthPx,
    required this.heightPx,
    required this.createdAt,
  });

  final String roleId;
  final String filename;
  final String contentType;
  final Uint8List bytes;
  final int widthPx;
  final int heightPx;
  final DateTime createdAt;
}

Map<String, _PendingCaptureDraft> _pendingDraftsForProject(String projectId) {
  return _pendingCaptureDraftsByProject[projectId] ??
      const <String, _PendingCaptureDraft>{};
}

_PendingCaptureDraft? _pendingDraftForRole(String projectId, String roleId) {
  return _pendingCaptureDraftsByProject[projectId]?[roleId];
}

void _savePendingDraft(String projectId, _PendingCaptureDraft draft) {
  final drafts = _pendingCaptureDraftsByProject.putIfAbsent(
    projectId,
    () => <String, _PendingCaptureDraft>{},
  );
  drafts[draft.roleId] = draft;
}

void _removePendingDraft(String projectId, String roleId) {
  final drafts = _pendingCaptureDraftsByProject[projectId];
  if (drafts == null) return;
  drafts.remove(roleId);
  if (drafts.isEmpty) {
    _pendingCaptureDraftsByProject.remove(projectId);
  }
}

Set<String> _pendingRequiredRoleIds(String projectId) {
  return {
    for (final roleId in _pendingDraftsForProject(projectId).keys)
      if (_requiredGuidedCaptureRoleIds.contains(roleId)) roleId,
  };
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: _paper,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final bootstrap = await FirebaseAppBootstrap.initialize();
  runApp(RoomForgeMobileApp(bootstrap: bootstrap));
}

ProjectApi _defaultProjectApiFactory(
  FirebaseAppBootstrapResult bootstrap,
  AuthSession session,
) {
  return RoomForgeBackendBindings.projectApi(
    backendMode: bootstrap.backendMode,
    authRepository: bootstrap.authRepository,
    session: session,
    floorPlanRepository: bootstrap.floorPlanRepository,
    geometryRepository: bootstrap.geometryRepository,
    layoutRepository: bootstrap.layoutRepository,
    projectRepository: bootstrap.projectRepository,
    reconstructionRepository: bootstrap.reconstructionRepository,
    roomDimensionsRepository: bootstrap.roomDimensionsRepository,
    sceneUnderstandingRepository: bootstrap.sceneUnderstandingRepository,
    sourceImageRepository: bootstrap.sourceImageRepository,
    sourceImageUploader: bootstrap.sourceImageUploader,
  );
}

class RoomForgeMobileApp extends StatelessWidget {
  const RoomForgeMobileApp({
    required this.bootstrap,
    this.projectApiFactory,
    this.availableCameras,
    this.initialLocation = '/projects',
    super.key,
  });

  final FirebaseAppBootstrapResult bootstrap;
  final RoomForgeProjectApiFactory? projectApiFactory;
  final RoomForgeAvailableCameras? availableCameras;
  final String initialLocation;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        _bootstrapProvider.overrideWithValue(bootstrap),
        _projectApiFactoryProvider.overrideWithValue(
          projectApiFactory ?? _defaultProjectApiFactory,
        ),
        _availableCamerasProvider.overrideWithValue(
          availableCameras ?? camera.availableCameras,
        ),
        _initialLocationProvider.overrideWithValue(initialLocation),
      ],
      child: const _RoomForgeRouterApp(),
    );
  }
}

class _RoomForgeRouterApp extends ConsumerWidget {
  const _RoomForgeRouterApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(_bootstrapProvider);
    final authState = ref.watch(_authSessionProvider);
    final session = authState.value;
    final projectApi = session == null
        ? null
        : ref.watch(_projectApiFactoryProvider)(bootstrap, session);
    final router = _mobileRouter(
      bootstrap: bootstrap,
      session: session,
      projectApi: projectApi,
      availableCameras: ref.watch(_availableCamerasProvider),
      initialLocation: ref.watch(_initialLocationProvider),
    );

    return MaterialApp.router(
      title: 'RoomForge',
      debugShowCheckedModeBanner: false,
      theme: _roomForgeTheme(),
      routerConfig: router,
    );
  }
}

ThemeData _roomForgeTheme() {
  return ThemeData(
    colorScheme: const ColorScheme.dark(
      primary: _primary,
      onPrimary: _paper,
      secondary: _success,
      surface: _panel,
      onSurface: _ink,
      error: _danger,
      onError: _paper,
    ),
    scaffoldBackgroundColor: _paper,
    useMaterial3: true,
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xDD08090B),
      foregroundColor: _ink,
      elevation: 0,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _ink,
        side: const BorderSide(color: _borderStrong),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
  );
}

GoRouter _mobileRouter({
  required FirebaseAppBootstrapResult bootstrap,
  required AuthSession? session,
  required ProjectApi? projectApi,
  required RoomForgeAvailableCameras availableCameras,
  required String initialLocation,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    redirect: (context, state) {
      final path = state.uri.path;
      final signedIn = session != null;
      if (!signedIn && path != '/login') return '/login';
      if (signedIn && (path == '/' || path == '/login')) return '/projects';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const _MobileSplash()),
      GoRoute(
        path: '/login',
        builder: (context, state) => _MobileSignInScreen(
          authRepository: bootstrap.authRepository,
          setupMessage: bootstrap.authSetupMessage,
        ),
      ),
      GoRoute(
        path: '/projects',
        builder: (context, state) => _ProjectsScreen(
          session: session!,
          projectApi: projectApi!,
          authRepository: bootstrap.authRepository,
        ),
      ),
      GoRoute(
        path: '/projects/:projectId',
        builder: (context, state) => _ProjectOverviewScreen(
          projectId: state.pathParameters['projectId']!,
          projectApi: projectApi!,
        ),
      ),
      GoRoute(
        path: '/projects/:projectId/capture',
        builder: (context, state) => _GuidedCaptureCameraScreen(
          projectId: state.pathParameters['projectId']!,
          projectApi: projectApi!,
          availableCameras: availableCameras,
          initialRoleId: state.uri.queryParameters['role'],
        ),
      ),
      GoRoute(
        path: '/projects/:projectId/upload',
        builder: (context, state) => _UploadProgressScreen(
          projectId: state.pathParameters['projectId']!,
          projectApi: projectApi!,
        ),
      ),
      GoRoute(
        path: '/projects/:projectId/reconstruction',
        builder: (context, state) => _ReconstructionStatusScreen(
          projectId: state.pathParameters['projectId']!,
          projectApi: projectApi!,
        ),
      ),
      GoRoute(
        path: '/projects/:projectId/preview',
        builder: (context, state) => _ModelPreviewScreen(
          projectId: state.pathParameters['projectId']!,
          projectApi: projectApi!,
        ),
      ),
    ],
    errorBuilder: (context, state) => _RouteErrorScreen(error: state.error),
  );
}

String _projectPath(String projectId) {
  return '/projects/${Uri.encodeComponent(projectId)}';
}

String _capturePath(String projectId, {String? roleId}) {
  final base = '${_projectPath(projectId)}/capture';
  final queryParameters = <String, String>{
    if (roleId != null && roleId.isNotEmpty) 'role': roleId,
  };
  if (queryParameters.isEmpty) return base;
  return Uri(path: base, queryParameters: queryParameters).toString();
}

String _uploadPath(String projectId) {
  return '${_projectPath(projectId)}/upload';
}

String _reconstructionPath(String projectId) {
  return '${_projectPath(projectId)}/reconstruction';
}

String _previewPath(String projectId) {
  return '${_projectPath(projectId)}/preview';
}

void _pushMobileRoute(BuildContext context, String location) {
  unawaited(context.push(location));
}

void _popOrGo(BuildContext context, String fallbackLocation) {
  if (context.canPop()) {
    context.pop();
    return;
  }

  context.go(fallbackLocation);
}

class _BackFallbackScope extends StatelessWidget {
  const _BackFallbackScope({
    required this.fallbackLocation,
    required this.child,
  });

  final String fallbackLocation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _popOrGo(context, fallbackLocation);
      },
      child: child,
    );
  }
}

class _MobileSplash extends StatelessWidget {
  const _MobileSplash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: _MobileBackdrop(
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
    );
  }
}

class _MobileSignInScreen extends StatefulWidget {
  const _MobileSignInScreen({
    required this.authRepository,
    required this.setupMessage,
  });

  final AuthRepository authRepository;
  final String? setupMessage;

  @override
  State<_MobileSignInScreen> createState() => _MobileSignInScreenState();
}

class _MobileSignInScreenState extends State<_MobileSignInScreen> {
  String? _error;
  bool _busy = false;

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.authRepository.signInWithGoogle();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _MobileBackdrop(
        blur: true,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _MobileBrand(),
                const Spacer(),
                const _Eyebrow('PHOTO TO METRIC ROOM'),
                const SizedBox(height: 12),
                Text(
                  '사진으로\n방을 3D로.',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: _ink,
                    fontWeight: FontWeight.w900,
                    height: 1.02,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  '앱의 가이드 촬영으로 방을 스캔하면, 치수 기반 3D 공간이 자동으로 만들어집니다.',
                  style: TextStyle(color: _muted, fontSize: 15, height: 1.45),
                ),
                const SizedBox(height: 26),
                _HandoffNote(
                  icon: Icons.phone_android_outlined,
                  text: '촬영은 이 앱에서, 정밀 편집은 데스크탑에서',
                ),
                if (widget.setupMessage != null) ...[
                  const SizedBox(height: 12),
                  _NoticeCard(
                    tone: _warning,
                    title: 'Firebase 설정 필요',
                    body: widget.setupMessage!,
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _NoticeCard(tone: _danger, title: '로그인 실패', body: _error!),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _signIn,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login_outlined),
                    label: Text(_busy ? '로그인 준비 중' : 'Google로 계속하기'),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '계속하면 이용약관 및 개인정보처리방침에 동의합니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _dim, fontSize: 12.5, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectsScreen extends StatefulWidget {
  const _ProjectsScreen({
    required this.session,
    required this.projectApi,
    required this.authRepository,
  });

  final AuthSession session;
  final ProjectApi projectApi;
  final AuthRepository authRepository;

  @override
  State<_ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<_ProjectsScreen> {
  late Future<List<RoomProject>> _projectsFuture;
  String? _status;
  bool _creating = false;
  DateTime? _lastBackPressedAt;

  @override
  void initState() {
    super.initState();
    _projectsFuture = _loadProjects();
  }

  Future<List<RoomProject>> _loadProjects() async {
    try {
      return await widget.projectApi.listProjects();
    } catch (error) {
      if (mounted) setState(() => _status = '프로젝트를 불러오지 못했습니다: $error');
      return const [];
    }
  }

  Future<void> _refresh() async {
    setState(() => _projectsFuture = _loadProjects());
    await _projectsFuture;
  }

  Future<void> _createProject({bool openCapture = false}) async {
    setState(() {
      _creating = true;
      _status = '새 방 프로젝트를 만드는 중입니다.';
    });
    try {
      final project = await widget.projectApi.createProject(
        name: '새 방 촬영 ${DateTime.now().millisecondsSinceEpoch}',
        description: '모바일 가이드 촬영으로 시작한 방입니다.',
      );
      if (!mounted) return;
      setState(() => _projectsFuture = _loadProjects());
      _pushMobileRoute(
        context,
        openCapture ? _capturePath(project.id) : _projectPath(project.id),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = '프로젝트 생성 실패: $error');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _openCaptureFor(List<RoomProject> projects) async {
    if (projects.isEmpty) {
      await _createProject(openCapture: true);
      return;
    }
    _pushMobileRoute(context, _capturePath(projects.first.id));
  }

  void _handleRootBack() {
    final now = DateTime.now();
    final previous = _lastBackPressedAt;
    _lastBackPressedAt = now;
    if (previous != null &&
        now.difference(previous) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('한 번 더 누르면 앱을 종료합니다.')));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleRootBack();
      },
      child: Scaffold(
        appBar: _MobileTopBar(
          title: const _MobileBrand(),
          leading: const SizedBox.shrink(),
          actions: [
            IconButton(
              tooltip: '검색',
              onPressed: () =>
                  setState(() => _status = '검색은 모바일 후속 단계에서 연결됩니다.'),
              icon: const Icon(Icons.search_outlined),
            ),
            _Avatar(session: widget.session),
            IconButton(
              tooltip: '로그아웃',
              onPressed: widget.authRepository.signOut,
              icon: const Icon(Icons.logout_outlined),
            ),
          ],
        ),
        body: _MobileBackdrop(
          opacity: 0.07,
          child: SafeArea(
            top: false,
            child: FutureBuilder<List<RoomProject>>(
              future: _projectsFuture,
              builder: (context, snapshot) {
                final projects = snapshot.data ?? const <RoomProject>[];
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 124),
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              '내 프로젝트',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: _ink,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0,
                                  ),
                            ),
                          ),
                          Text(
                            '${projects.length}',
                            style: const TextStyle(
                              color: _dim,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const _ProjectFilterChips(),
                      if (_status != null) ...[
                        const SizedBox(height: 14),
                        _NoticeCard(
                          tone: _primary,
                          title: '상태',
                          body: _status!,
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const _LoadingPanel(label: '프로젝트를 불러오는 중')
                      else if (projects.isEmpty)
                        _EmptyProjectCard(
                          onCreateProject: () => _createProject(),
                        )
                      else
                        ...projects.map(
                          (project) => _ProjectPreviewCard(
                            project: project,
                            onOpen: () => _pushMobileRoute(
                              context,
                              _projectPath(project.id),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: FutureBuilder<List<RoomProject>>(
          future: _projectsFuture,
          builder: (context, snapshot) {
            return FloatingActionButton.extended(
              onPressed: _creating
                  ? null
                  : () => unawaited(_openCaptureFor(snapshot.data ?? const [])),
              backgroundColor: _primary,
              foregroundColor: _paper,
              icon: _creating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.photo_camera_outlined),
              label: Text(_creating ? '생성 중' : '새 방 촬영'),
            );
          },
        ),
        bottomNavigationBar: const _MobileTabBar(active: _MobileTab.projects),
      ),
    );
  }
}

class _ProjectOverviewScreen extends StatefulWidget {
  const _ProjectOverviewScreen({
    required this.projectId,
    required this.projectApi,
  });

  final String projectId;
  final ProjectApi projectApi;

  @override
  State<_ProjectOverviewScreen> createState() => _ProjectOverviewScreenState();
}

class _ProjectOverviewScreenState extends State<_ProjectOverviewScreen> {
  late Future<_ProjectDetails> _detailsFuture;
  String? _status;
  String? _uploadingDraftRoleId;

  @override
  void initState() {
    super.initState();
    _detailsFuture = _loadDetails();
  }

  Future<_ProjectDetails> _loadDetails() async {
    final project = await widget.projectApi.getProject(widget.projectId);
    RoomDimensions? dimensions;
    CaptureSessionSnapshot? captureSnapshot;
    try {
      dimensions = await widget.projectApi.getRoomDimensions(
        projectId: widget.projectId,
      );
    } catch (_) {
      dimensions = null;
    }
    try {
      captureSnapshot = await widget.projectApi.loadLatestCaptureSession(
        projectId: widget.projectId,
      );
    } catch (_) {
      captureSnapshot = null;
    }
    return _ProjectDetails(
      project: project,
      dimensions: dimensions,
      captureSnapshot: captureSnapshot,
    );
  }

  Future<void> _saveSampleDimensions() async {
    setState(() => _status = '샘플 치수를 저장하는 중입니다.');
    try {
      await widget.projectApi.saveRoomDimensions(
        projectId: widget.projectId,
        widthValue: 5.2,
        depthValue: 6.0,
        heightValue: 2.8,
      );
      if (!mounted) return;
      setState(() {
        _status = '5.2 x 6.0 x 2.8 m 치수를 저장했습니다.';
        _detailsFuture = _loadDetails();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = '치수 저장 실패: $error');
    }
  }

  Future<void> _openCaptureRole(String? roleId) async {
    await context.push(_capturePath(widget.projectId, roleId: roleId));
    if (!mounted) return;
    setState(() => _detailsFuture = _loadDetails());
  }

  Future<_ProjectDetails> _ensureCaptureSession(_ProjectDetails details) async {
    var dimensions = details.dimensions;
    var snapshot = details.captureSnapshot;

    if (dimensions == null) {
      setState(() => _status = '방 치수를 먼저 저장합니다.');
      dimensions = await widget.projectApi.saveRoomDimensions(
        projectId: widget.projectId,
        widthValue: 5.2,
        depthValue: 6.0,
        heightValue: 2.8,
      );
    }

    if (snapshot == null) {
      setState(() => _status = '가이드 촬영 세션을 시작합니다.');
      await widget.projectApi.createCaptureSession(
        projectId: widget.projectId,
        depthEnabled: false,
      );
      snapshot = await widget.projectApi.loadLatestCaptureSession(
        projectId: widget.projectId,
      );
    }

    return _ProjectDetails(
      project: details.project,
      dimensions: dimensions,
      captureSnapshot: snapshot,
    );
  }

  Future<void> _uploadPendingRole(String roleId) async {
    final draft = _pendingDraftForRole(widget.projectId, roleId);
    if (draft == null || _uploadingDraftRoleId != null) return;

    final roleLabel = _roleShortLabel(roleId);
    setState(() {
      _uploadingDraftRoleId = roleId;
      _status = '$roleLabel 업로드를 준비합니다.';
    });

    try {
      final details = await _loadDetails();
      final ready = await _ensureCaptureSession(details);
      final session = ready.captureSnapshot?.session;
      if (session == null) {
        throw const ProjectApiException(
          '가이드 촬영 세션을 만들 수 없습니다.',
          code: 'capture_session_unavailable',
        );
      }

      await widget.projectApi.uploadCaptureImage(
        projectId: widget.projectId,
        captureSessionId: session.id,
        role: draft.roleId,
        filename: _captureFilename(draft.roleId, draft.filename),
        contentType: draft.contentType,
        bytes: draft.bytes,
        widthPx: draft.widthPx,
        heightPx: draft.heightPx,
        captureOrder: _captureOrderForRole(draft.roleId),
        onProgress: (progress) {
          if (!mounted) return;
          setState(
            () => _status = '$roleLabel 업로드 ${(progress * 100).round()}%',
          );
        },
      );

      _removePendingDraft(widget.projectId, roleId);
      if (!mounted) return;
      setState(() {
        _status = '$roleLabel 업로드가 완료되었습니다.';
        _detailsFuture = _loadDetails();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = '$roleLabel 업로드 실패: $error');
    } finally {
      if (mounted) setState(() => _uploadingDraftRoleId = null);
    }
  }

  void _discardPendingRole(String roleId) {
    _removePendingDraft(widget.projectId, roleId);
    setState(() => _status = '${_roleShortLabel(roleId)} 촬영본을 삭제했습니다.');
  }

  @override
  Widget build(BuildContext context) {
    return _BackFallbackScope(
      fallbackLocation: '/projects',
      child: FutureBuilder<_ProjectDetails>(
        future: _detailsFuture,
        builder: (context, snapshot) {
          final details = snapshot.data;
          final title = details?.project.name ?? '프로젝트';
          final workflow = details == null
              ? null
              : _MobileWorkflowState.fromDetails(details);
          return Scaffold(
            appBar: _MobileTopBar(
              title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
              workflow: workflow,
              leading: _RoundIconButton(
                tooltip: '뒤로',
                icon: Icons.chevron_left,
                onPressed: () => _popOrGo(context, '/projects'),
              ),
              actions: [
                IconButton(
                  tooltip: '더보기',
                  onPressed: () =>
                      _showDesktopHandoff(context, widget.projectId),
                  icon: const Icon(Icons.more_horiz),
                ),
              ],
            ),
            body: _MobileBackdrop(
              opacity: 0.07,
              child: SafeArea(
                top: false,
                child: _AsyncDetailsView(
                  snapshot: snapshot,
                  builder: (context, loaded) => ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
                    children: [
                      if (_status != null) ...[
                        _NoticeCard(
                          tone: _primary,
                          title: '상태',
                          body: _status!,
                        ),
                        const SizedBox(height: 16),
                      ],
                      _SourceImagesCard(
                        details: loaded,
                        pendingDrafts: _pendingDraftsForProject(
                          widget.projectId,
                        ),
                        uploadingRoleId: _uploadingDraftRoleId,
                        onCaptureRole: (roleId) =>
                            unawaited(_openCaptureRole(roleId)),
                        onUploadRole: (roleId) =>
                            unawaited(_uploadPendingRole(roleId)),
                        onDiscardDraft: _discardPendingRole,
                      ),
                      const SizedBox(height: 16),
                      if (loaded.dimensions == null)
                        _NoticeCard(
                          tone: _warning,
                          title: '방 치수 필요',
                          body: '가이드 촬영 세션을 시작하려면 미터 단위의 방 치수가 필요합니다.',
                          action: OutlinedButton.icon(
                            onPressed: _saveSampleDimensions,
                            icon: const Icon(Icons.straighten_outlined),
                            label: const Text('샘플 치수 사용'),
                          ),
                        )
                      else
                        _DesktopHandoffCard(projectId: loaded.project.id),
                    ],
                  ),
                ),
              ),
            ),
            bottomNavigationBar: _ProjectActionBar(
              projectId: widget.projectId,
              primaryLabel: workflow == null || !workflow.sourceComplete
                  ? '소스 촬영'
                  : workflow.editReady
                  ? '편집 열기'
                  : '재구성 보기',
              primaryIcon: workflow == null || !workflow.sourceComplete
                  ? Icons.photo_camera_outlined
                  : workflow.editReady
                  ? Icons.view_in_ar_outlined
                  : Icons.sync_outlined,
              onPrimary: () {
                if (workflow == null || !workflow.sourceComplete) {
                  unawaited(_openCaptureRole(workflow?.nextRequiredRole?.id));
                  return;
                }
                _pushMobileRoute(
                  context,
                  workflow.editReady
                      ? _previewPath(widget.projectId)
                      : _reconstructionPath(widget.projectId),
                );
              },
              secondaryLabel: '소스 상태',
              secondaryIcon: Icons.cloud_upload_outlined,
              onSecondary: () =>
                  _pushMobileRoute(context, _uploadPath(widget.projectId)),
            ),
          );
        },
      ),
    );
  }
}

class _GuidedCaptureCameraScreen extends StatefulWidget {
  const _GuidedCaptureCameraScreen({
    required this.projectId,
    required this.projectApi,
    required this.availableCameras,
    this.initialRoleId,
  });

  final String projectId;
  final ProjectApi projectApi;
  final RoomForgeAvailableCameras availableCameras;
  final String? initialRoleId;

  @override
  State<_GuidedCaptureCameraScreen> createState() =>
      _GuidedCaptureCameraScreenState();
}

class _GuidedCaptureCameraScreenState
    extends State<_GuidedCaptureCameraScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  late Future<_ProjectDetails> _detailsFuture;
  Future<void>? _cameraInitialization;
  camera.CameraController? _cameraController;
  String? _cameraStatus;
  String? _status;
  String? _selectedRoleId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_enterCaptureOrientation());
    _selectedRoleId = _normalizedCaptureRoleId(widget.initialRoleId);
    _cameraStatus = '카메라를 준비 중입니다.';
    _detailsFuture = _loadDetails();
    _cameraInitialization = _initializeCamera();
  }

  @override
  void didUpdateWidget(covariant _GuidedCaptureCameraScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialRoleId != oldWidget.initialRoleId) {
      _selectedRoleId = _normalizedCaptureRoleId(widget.initialRoleId);
    }
  }

  @override
  void dispose() {
    unawaited(_cameraController?.dispose());
    unawaited(_restoreMobileOrientation());
    super.dispose();
  }

  Future<void> _enterCaptureOrientation() async {
    await SystemChrome.setPreferredOrientations(_captureScreenOrientations);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _restoreMobileOrientation() async {
    await SystemChrome.setPreferredOrientations(
      _systemManagedScreenOrientations,
    );
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await widget.availableCameras().timeout(
        const Duration(seconds: 6),
      );
      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() => _cameraStatus = '사용 가능한 카메라가 없습니다.');
        return;
      }

      final selectedCamera = cameras.firstWhere(
        (description) =>
            description.lensDirection == camera.CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = camera.CameraController(
        selectedCamera,
        _captureResolutionPreset,
        enableAudio: false,
      );
      await controller.initialize();
      await controller.lockCaptureOrientation(_captureScreenOrientation);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _cameraController = controller;
        _cameraStatus = null;
      });
    } on camera.CameraException catch (error) {
      if (!mounted) return;
      setState(() => _cameraStatus = _cameraErrorMessage(error));
    } catch (error) {
      if (!mounted) return;
      setState(() => _cameraStatus = '카메라를 시작할 수 없습니다: $error');
    }
  }

  Future<_ProjectDetails> _loadDetails() async {
    final project = await widget.projectApi.getProject(widget.projectId);
    RoomDimensions? dimensions;
    CaptureSessionSnapshot? captureSnapshot;
    try {
      dimensions = await widget.projectApi.getRoomDimensions(
        projectId: widget.projectId,
      );
    } catch (_) {
      dimensions = null;
    }
    try {
      captureSnapshot = await widget.projectApi.loadLatestCaptureSession(
        projectId: widget.projectId,
      );
    } catch (_) {
      captureSnapshot = null;
    }
    return _ProjectDetails(
      project: project,
      dimensions: dimensions,
      captureSnapshot: captureSnapshot,
    );
  }

  GuidedCaptureRoleInstruction? _activeRole(CaptureSessionSnapshot? snapshot) {
    final selected = _guidedCaptureRoleById(_selectedRoleId);
    if (selected != null) return selected;
    return _nextRequiredRoleByIds({
      ..._uploadedRoleIds(snapshot),
      ..._pendingRequiredRoleIds(widget.projectId),
    });
  }

  Future<void> _selectAndStageRoleImage(
    _ProjectDetails details,
    Future<XFile?> Function() selectImage, {
    required String sourceLabel,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = null;
    });

    try {
      final role = _activeRole(details.captureSnapshot);
      if (role == null) {
        setState(() => _status = '필수 촬영이 모두 완료되었습니다.');
        return;
      }

      final roleLabel = _roleShortLabel(role.id);
      setState(() => _status = '$roleLabel 각도 사진을 $sourceLabel합니다.');
      final photo = await selectImage();
      if (photo == null) {
        if (!mounted) return;
        setState(() => _status = '사진 $sourceLabel이 취소되었습니다.');
        return;
      }

      final bytes = await photo.readAsBytes();
      final imageSize = await _decodeImageSize(bytes);

      _savePendingDraft(
        widget.projectId,
        _PendingCaptureDraft(
          roleId: role.id,
          filename: photo.name,
          contentType: _imageContentType(photo),
          bytes: bytes,
          widthPx: imageSize.width,
          heightPx: imageSize.height,
          createdAt: DateTime.now().toUtc(),
        ),
      );

      if (!mounted) return;
      final capturedOrUploaded = {
        ..._uploadedRequiredRoleIds(details.captureSnapshot),
        ..._pendingRequiredRoleIds(widget.projectId),
      };
      final nextRequired = _nextRequiredRoleByIds(capturedOrUploaded);
      setState(() {
        _status = '$roleLabel 사진이 촬영되었습니다. 소스 화면에서 수정하거나 업로드하세요.';
        _selectedRoleId = nextRequired?.id ?? role.id;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = '촬영 저장 실패: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickGalleryImage(_ProjectDetails details) {
    return _selectAndStageRoleImage(
      details,
      () => _imagePicker.pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      ),
      sourceLabel: '선택',
    );
  }

  Future<void> _captureCameraImage(_ProjectDetails details) async {
    var controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      setState(() => _status = _cameraStatus ?? '카메라를 준비 중입니다.');
      await _cameraInitialization;
      controller = _cameraController;
    }

    if (controller == null || !controller.value.isInitialized) {
      if (!mounted) return;
      setState(() => _status = _cameraStatus ?? '카메라 프리뷰를 사용할 수 없습니다.');
      return;
    }

    if (controller.value.isTakingPicture) return;
    await _selectAndStageRoleImage(details, () async {
      await controller!.lockCaptureOrientation(_captureScreenOrientation);
      return controller.takePicture();
    }, sourceLabel: '촬영');
  }

  @override
  Widget build(BuildContext context) {
    return _BackFallbackScope(
      fallbackLocation: _projectPath(widget.projectId),
      child: FutureBuilder<_ProjectDetails>(
        future: _detailsFuture,
        builder: (context, snapshot) {
          final details = snapshot.data;
          final uploadedRequired = _uploadedRequiredRoleIds(
            details?.captureSnapshot,
          );
          final capturedOrUploadedRequired = {
            ...uploadedRequired,
            ..._pendingRequiredRoleIds(widget.projectId),
          };
          final activeRole = _activeRole(details?.captureSnapshot);
          final progress =
              capturedOrUploadedRequired.length /
              _requiredGuidedCaptureRoles.length;
          final projectName = details?.project.name ?? '가이드 촬영';
          final captureInstruction =
              _status ??
              (activeRole == null
                  ? '필수 촬영 완료 · 소스 화면에서 각 사진을 업로드하세요'
                  : '16:9 가로 프레임에 방 전체를 맞추고 ${_roleShortLabel(activeRole.id)} 각도를 촬영하세요');
          final captureBusy =
              _busy || snapshot.connectionState == ConnectionState.waiting;

          return Scaffold(
            backgroundColor: const Color(0xFF151719),
            body: _NativeCaptureLayout(
              leftRail: _CaptureLeftRail(
                hasUpload: capturedOrUploadedRequired.isNotEmpty,
                onClose: () =>
                    _popOrGo(context, _projectPath(widget.projectId)),
                onGallery: details == null
                    ? null
                    : () => unawaited(_pickGalleryImage(details)),
              ),
              preview: _CapturePreviewPane(
                controller: _cameraController,
                initialization: _cameraInitialization,
                cameraStatus: _cameraStatus,
                projectName: projectName,
                instruction: captureInstruction,
                busy: _busy,
                onRetry: () {
                  final previousController = _cameraController;
                  unawaited(previousController?.dispose());
                  setState(() {
                    _cameraController = null;
                    _cameraStatus = '카메라를 준비 중입니다.';
                    _cameraInitialization = _initializeCamera();
                  });
                },
              ),
              rightRail: _CaptureRightRail(
                progress: progress,
                busy: captureBusy,
                uploadedRoleIds: capturedOrUploadedRequired,
                currentRoleId: activeRole?.id,
                onShutter: details == null
                    ? null
                    : () => unawaited(_captureCameraImage(details)),
                onDone: () => context.go(_projectPath(widget.projectId)),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _UploadProgressScreen extends StatefulWidget {
  const _UploadProgressScreen({
    required this.projectId,
    required this.projectApi,
  });

  final String projectId;
  final ProjectApi projectApi;

  @override
  State<_UploadProgressScreen> createState() => _UploadProgressScreenState();
}

class _UploadProgressScreenState extends State<_UploadProgressScreen> {
  late Future<_ProjectDetails> _detailsFuture;

  @override
  void initState() {
    super.initState();
    _detailsFuture = _loadDetails();
  }

  Future<_ProjectDetails> _loadDetails() async {
    final project = await widget.projectApi.getProject(widget.projectId);
    RoomDimensions? dimensions;
    CaptureSessionSnapshot? captureSnapshot;
    try {
      dimensions = await widget.projectApi.getRoomDimensions(
        projectId: widget.projectId,
      );
      captureSnapshot = await widget.projectApi.loadLatestCaptureSession(
        projectId: widget.projectId,
      );
    } catch (_) {
      captureSnapshot = null;
    }
    return _ProjectDetails(
      project: project,
      dimensions: dimensions,
      captureSnapshot: captureSnapshot,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _BackFallbackScope(
      fallbackLocation: _projectPath(widget.projectId),
      child: FutureBuilder<_ProjectDetails>(
        future: _detailsFuture,
        builder: (context, snapshot) {
          final workflow = snapshot.data == null
              ? null
              : _MobileWorkflowState.fromDetails(snapshot.data!);
          return Scaffold(
            appBar: _MobileTopBar(
              title: const Text('업로드'),
              workflow: workflow,
              leading: _RoundIconButton(
                tooltip: '닫기',
                icon: Icons.close,
                onPressed: () =>
                    _popOrGo(context, _projectPath(widget.projectId)),
              ),
              actions: const [SizedBox(width: 42)],
            ),
            body: _MobileBackdrop(
              opacity: 0.06,
              child: SafeArea(
                top: false,
                child: _AsyncDetailsView(
                  snapshot: snapshot,
                  builder: (context, details) {
                    final uploaded = _uploadedRequiredRoleIds(
                      details.captureSnapshot,
                    );
                    final total = _requiredGuidedCaptureRoles.length;
                    final value = total == 0 ? 0.0 : uploaded.length / total;
                    final complete = uploaded.length >= total;
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(18, 24, 18, 104),
                      children: [
                        _UploadStatusBoard(
                          uploadedRoleIds: uploaded,
                          value: value.clamp(0.0, 1.0),
                          completed: uploaded.length,
                          total: total,
                        ),
                        const SizedBox(height: 20),
                        _HandoffNote(
                          icon: Icons.sync_outlined,
                          text: complete
                              ? '필수 소스가 모두 준비됐습니다. 다음 단계에서 재구성 상태를 확인하세요.'
                              : '남은 각도를 촬영하면 재구성 입력 품질이 더 안정적입니다.',
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            bottomNavigationBar: _ProjectActionBar(
              projectId: widget.projectId,
              primaryLabel: workflow?.sourceComplete == true ? '재구성으로' : '완료',
              primaryIcon: workflow?.sourceComplete == true
                  ? Icons.sync_outlined
                  : Icons.check,
              onPrimary: () {
                if (workflow?.sourceComplete == true) {
                  context.go(_reconstructionPath(widget.projectId));
                  return;
                }
                _popOrGo(context, _projectPath(widget.projectId));
              },
              secondaryLabel: '계속 촬영',
              secondaryIcon: Icons.photo_camera_outlined,
              onSecondary: () => _pushMobileRoute(
                context,
                _capturePath(
                  widget.projectId,
                  roleId: workflow?.nextRequiredRole?.id,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ReconstructionStatusScreen extends StatefulWidget {
  const _ReconstructionStatusScreen({
    required this.projectId,
    required this.projectApi,
  });

  final String projectId;
  final ProjectApi projectApi;

  @override
  State<_ReconstructionStatusScreen> createState() =>
      _ReconstructionStatusScreenState();
}

class _ReconstructionStatusScreenState
    extends State<_ReconstructionStatusScreen> {
  late Future<_ProjectDetails> _detailsFuture;

  @override
  void initState() {
    super.initState();
    _detailsFuture = _loadDetails();
  }

  Future<_ProjectDetails> _loadDetails() async {
    final project = await widget.projectApi.getProject(widget.projectId);
    RoomDimensions? dimensions;
    CaptureSessionSnapshot? captureSnapshot;
    try {
      dimensions = await widget.projectApi.getRoomDimensions(
        projectId: widget.projectId,
      );
    } catch (_) {
      dimensions = null;
    }
    try {
      captureSnapshot = await widget.projectApi.loadLatestCaptureSession(
        projectId: widget.projectId,
      );
    } catch (_) {
      captureSnapshot = null;
    }
    return _ProjectDetails(
      project: project,
      dimensions: dimensions,
      captureSnapshot: captureSnapshot,
    );
  }

  void _refresh() {
    setState(() => _detailsFuture = _loadDetails());
  }

  @override
  Widget build(BuildContext context) {
    return _BackFallbackScope(
      fallbackLocation: _projectPath(widget.projectId),
      child: FutureBuilder<_ProjectDetails>(
        future: _detailsFuture,
        builder: (context, snapshot) {
          final workflow = snapshot.data == null
              ? null
              : _MobileWorkflowState.fromDetails(snapshot.data!);
          return Scaffold(
            appBar: _MobileTopBar(
              title: const Text('재구성'),
              workflow: workflow,
              leading: _RoundIconButton(
                tooltip: '뒤로',
                icon: Icons.chevron_left,
                onPressed: () =>
                    _popOrGo(context, _projectPath(widget.projectId)),
              ),
              actions: [
                IconButton(
                  tooltip: '새로고침',
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            body: _MobileBackdrop(
              opacity: 0.06,
              child: SafeArea(
                top: false,
                child: _AsyncDetailsView(
                  snapshot: snapshot,
                  builder: (context, details) {
                    final workflow = _MobileWorkflowState.fromDetails(details);
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(18, 24, 18, 104),
                      children: [
                        _ReconstructionStageCard(
                          state: workflow,
                          onCapture: () => _pushMobileRoute(
                            context,
                            _capturePath(
                              widget.projectId,
                              roleId: workflow.nextRequiredRole?.id,
                            ),
                          ),
                          onRefresh: _refresh,
                          onPreview: () =>
                              context.go(_previewPath(widget.projectId)),
                        ),
                        const SizedBox(height: 16),
                        _HandoffNote(
                          icon: Icons.fact_check_outlined,
                          text:
                              '편집 단계는 재구성 상태가 성공으로 확인되거나 플로어 플랜이 저장된 뒤에만 열립니다.',
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            bottomNavigationBar: _ProjectActionBar(
              projectId: widget.projectId,
              primaryLabel: workflow == null || !workflow.sourceComplete
                  ? '소스 촬영'
                  : workflow.editReady
                  ? '편집 열기'
                  : '상태 새로고침',
              primaryIcon: workflow == null || !workflow.sourceComplete
                  ? Icons.photo_camera_outlined
                  : workflow.editReady
                  ? Icons.view_in_ar_outlined
                  : Icons.refresh,
              onPrimary: () {
                if (workflow == null || !workflow.sourceComplete) {
                  _pushMobileRoute(
                    context,
                    _capturePath(
                      widget.projectId,
                      roleId: workflow?.nextRequiredRole?.id,
                    ),
                  );
                  return;
                }
                if (workflow.editReady) {
                  context.go(_previewPath(widget.projectId));
                  return;
                }
                _refresh();
              },
              secondaryLabel: '소스 상태',
              secondaryIcon: Icons.cloud_upload_outlined,
              onSecondary: () => context.go(_uploadPath(widget.projectId)),
            ),
          );
        },
      ),
    );
  }
}

class _ReconstructionStageCard extends StatelessWidget {
  const _ReconstructionStageCard({
    required this.state,
    required this.onCapture,
    required this.onRefresh,
    required this.onPreview,
  });

  final _MobileWorkflowState state;
  final VoidCallback onCapture;
  final VoidCallback onRefresh;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final (:tone, :title, :body, :action) = _content();
    return _NoticeCard(tone: tone, title: title, body: body, action: action);
  }

  ({Color tone, String title, String body, Widget action}) _content() {
    if (!state.sourceComplete) {
      return (
        tone: _warning,
        title: '소스 단계 필요',
        body:
            '필수 소스 ${state.requiredTotal}개 중 ${state.uploadedRequiredCount}개만 준비됐습니다. '
            '나머지 ${state.missingRequiredCount}개 각도를 먼저 촬영해야 재구성을 시작할 수 있습니다.',
        action: OutlinedButton.icon(
          onPressed: onCapture,
          icon: const Icon(Icons.photo_camera_outlined),
          label: const Text('남은 각도 촬영'),
        ),
      );
    }

    if (state.editReady) {
      return (
        tone: _success,
        title: '재구성 완료',
        body: '재구성 결과가 준비되었습니다. 이제 편집 단계에서 3D 미리보기와 데스크탑 편집 링크를 사용할 수 있습니다.',
        action: FilledButton.icon(
          onPressed: onPreview,
          icon: const Icon(Icons.view_in_ar_outlined),
          label: const Text('편집 열기'),
        ),
      );
    }

    if (state.reconstructionNeedsReview) {
      return (
        tone: _warning,
        title: '재구성 검토 필요',
        body: '서버가 재구성 후보를 만들었지만 검토가 필요합니다. 검토가 끝나기 전에는 편집/3D 미리보기를 열지 않습니다.',
        action: OutlinedButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
          label: const Text('상태 새로고침'),
        ),
      );
    }

    if (state.reconstructionFailed) {
      return (
        tone: _danger,
        title: state.reconstructionStatusLabel,
        body: '재구성 작업이 완료되지 않았습니다. 소스 입력을 확인하거나 재시도 작업이 생성된 뒤 상태를 다시 확인하세요.',
        action: OutlinedButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
          label: const Text('상태 새로고침'),
        ),
      );
    }

    if (state.reconstructionInProgress) {
      return (
        tone: _primary,
        title: state.reconstructionStatusLabel,
        body: '필수 소스 8개가 서버 재구성 단계에 들어갔습니다. 성공 상태가 확인될 때까지 편집 단계는 잠겨 있습니다.',
        action: OutlinedButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
          label: const Text('상태 새로고침'),
        ),
      );
    }

    return (
      tone: _warning,
      title: '재구성 대기',
      body: '필수 소스 8개가 준비됐습니다. 서버 재구성 작업 상태가 생성되면 이 화면에서 진행 상태를 공유합니다.',
      action: OutlinedButton.icon(
        onPressed: onRefresh,
        icon: const Icon(Icons.refresh),
        label: const Text('상태 새로고침'),
      ),
    );
  }
}

class _ModelPreviewScreen extends StatefulWidget {
  const _ModelPreviewScreen({
    required this.projectId,
    required this.projectApi,
  });

  final String projectId;
  final ProjectApi projectApi;

  @override
  State<_ModelPreviewScreen> createState() => _ModelPreviewScreenState();
}

class _ModelPreviewScreenState extends State<_ModelPreviewScreen> {
  late Future<_ProjectDetails> _detailsFuture;

  @override
  void initState() {
    super.initState();
    _detailsFuture = _loadDetails();
  }

  Future<_ProjectDetails> _loadDetails() async {
    final project = await widget.projectApi.getProject(widget.projectId);
    RoomDimensions? dimensions;
    CaptureSessionSnapshot? captureSnapshot;
    try {
      dimensions = await widget.projectApi.getRoomDimensions(
        projectId: widget.projectId,
      );
      captureSnapshot = await widget.projectApi.loadLatestCaptureSession(
        projectId: widget.projectId,
      );
    } catch (_) {
      captureSnapshot = null;
    }
    return _ProjectDetails(
      project: project,
      dimensions: dimensions,
      captureSnapshot: captureSnapshot,
    );
  }

  Future<void> _copyDesktopLink(BuildContext context) async {
    final path = '/projects/${Uri.encodeComponent(widget.projectId)}/editor';
    await Clipboard.setData(ClipboardData(text: path));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('데스크탑 편집 링크를 복사했습니다.')));
  }

  Widget _buildLockedPreviewScaffold(
    BuildContext context,
    AsyncSnapshot<_ProjectDetails> snapshot,
    _MobileWorkflowState? workflow,
  ) {
    return Scaffold(
      appBar: _MobileTopBar(
        title: const Text('편집'),
        workflow: workflow,
        leading: _RoundIconButton(
          tooltip: '뒤로',
          icon: Icons.chevron_left,
          onPressed: () => _popOrGo(context, _projectPath(widget.projectId)),
        ),
        actions: const [SizedBox(width: 42)],
      ),
      body: _MobileBackdrop(
        opacity: 0.06,
        child: SafeArea(
          top: false,
          child: _AsyncDetailsView(
            snapshot: snapshot,
            builder: (context, details) {
              final workflow = _MobileWorkflowState.fromDetails(details);
              final sourceLocked = !workflow.sourceComplete;
              return ListView(
                padding: const EdgeInsets.fromLTRB(18, 24, 18, 104),
                children: [
                  Text(
                    details.project.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: _ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _NoticeCard(
                    tone: sourceLocked ? _warning : workflow.reconstructionTone,
                    title: sourceLocked ? '소스 단계 필요' : '재구성 단계 필요',
                    body: sourceLocked
                        ? '필수 소스 ${workflow.requiredTotal}개 중 ${workflow.uploadedRequiredCount}개만 준비됐습니다. 편집/3D 미리보기는 모든 소스가 채워진 뒤 재구성이 끝나야 열립니다.'
                        : '${workflow.reconstructionStatusLabel} 상태입니다. 재구성 성공 또는 플로어 플랜 저장이 확인되기 전에는 3D 미리보기를 표시하지 않습니다.',
                    action: OutlinedButton.icon(
                      onPressed: () => context.go(
                        sourceLocked
                            ? _capturePath(
                                widget.projectId,
                                roleId: workflow.nextRequiredRole?.id,
                              )
                            : _reconstructionPath(widget.projectId),
                      ),
                      icon: Icon(
                        sourceLocked
                            ? Icons.photo_camera_outlined
                            : Icons.sync_outlined,
                      ),
                      label: Text(sourceLocked ? '소스 촬영' : '재구성 보기'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _HandoffNote(
                    icon: Icons.lock_outline,
                    text:
                        '이 화면은 편집 단계입니다. 이전 단계가 완료되지 않으면 3D 미리보기는 렌더링하지 않습니다.',
                  ),
                ],
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: _ProjectActionBar(
        projectId: widget.projectId,
        primaryLabel: workflow == null || !workflow.sourceComplete
            ? '소스 촬영'
            : '재구성 보기',
        primaryIcon: workflow == null || !workflow.sourceComplete
            ? Icons.photo_camera_outlined
            : Icons.sync_outlined,
        onPrimary: () {
          if (workflow == null || !workflow.sourceComplete) {
            context.go(
              _capturePath(
                widget.projectId,
                roleId: workflow?.nextRequiredRole?.id,
              ),
            );
            return;
          }
          context.go(_reconstructionPath(widget.projectId));
        },
        secondaryLabel: '소스 상태',
        secondaryIcon: Icons.cloud_upload_outlined,
        onSecondary: () => context.go(_uploadPath(widget.projectId)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _BackFallbackScope(
      fallbackLocation: _projectPath(widget.projectId),
      child: FutureBuilder<_ProjectDetails>(
        future: _detailsFuture,
        builder: (context, snapshot) {
          final details = snapshot.data;
          final workflow = details == null
              ? null
              : _MobileWorkflowState.fromDetails(details);
          if (workflow?.editReady != true) {
            return _buildLockedPreviewScaffold(context, snapshot, workflow);
          }
          return Scaffold(
            backgroundColor: const Color(0xFF0A0B0D),
            body: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _RoomPreviewPainter(
                      roomDimensions: details?.dimensions,
                      uploadedCount: _uploadedRoleIds(
                        details?.captureSnapshot,
                      ).length,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.58),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.74),
                        ],
                        stops: const [0, 0.36, 1],
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                        child: Row(
                          children: [
                            _GlassIconButton(
                              tooltip: '뒤로',
                              icon: Icons.chevron_left,
                              onPressed: () => _popOrGo(
                                context,
                                _projectPath(widget.projectId),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    details?.project.name ?? '3D 미리보기',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    '3D 미리보기',
                                    style: TextStyle(
                                      color: _muted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _GlassIconButton(
                              tooltip: '공유',
                              icon: Icons.ios_share_outlined,
                              onPressed: () =>
                                  unawaited(_copyDesktopLink(context)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _WorkflowTitleProgress(state: workflow!),
                      const SizedBox(height: 20),
                      const _GlassPill(
                        icon: Icons.swipe_outlined,
                        label: '드래그하여 둘러보기',
                      ),
                      const Spacer(),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _GlassPill(
                            icon: Icons.grid_4x4_outlined,
                            label: '평면도',
                          ),
                          SizedBox(width: 8),
                          _GlassPill(
                            icon: Icons.restart_alt_outlined,
                            label: '시점 초기화',
                          ),
                        ],
                      ),
                      const SizedBox(height: 88),
                    ],
                  ),
                ),
              ],
            ),
            bottomNavigationBar: _ProjectActionBar(
              projectId: widget.projectId,
              secondaryLabel: '데스크탑 링크',
              secondaryIcon: Icons.send_outlined,
              onSecondary: () => unawaited(_copyDesktopLink(context)),
              primaryLabel: '데스크탑에서 편집',
              primaryIcon: Icons.desktop_windows_outlined,
              onPrimary: () => unawaited(_copyDesktopLink(context)),
            ),
          );
        },
      ),
    );
  }
}

class _ProjectDetails {
  const _ProjectDetails({
    required this.project,
    required this.dimensions,
    required this.captureSnapshot,
  });

  final RoomProject project;
  final RoomDimensions? dimensions;
  final CaptureSessionSnapshot? captureSnapshot;
}

enum _MobileWorkflowStep { source, reconstruction, edit }

class _MobileWorkflowState {
  const _MobileWorkflowState({
    required this.uploadedRequiredRoleIds,
    required this.filledRequiredRoleIds,
    required this.requiredTotal,
    required this.reconstructionStatus,
    required this.hasFloorPlan,
  });

  factory _MobileWorkflowState.fromDetails(_ProjectDetails details) {
    final uploadedRequiredRoleIds = _uploadedRequiredRoleIds(
      details.captureSnapshot,
    );
    return _MobileWorkflowState(
      uploadedRequiredRoleIds: uploadedRequiredRoleIds,
      filledRequiredRoleIds: {
        ...uploadedRequiredRoleIds,
        ..._pendingRequiredRoleIds(details.project.id),
      },
      requiredTotal: _requiredGuidedCaptureRoles.length,
      reconstructionStatus: details.project.currentReconstructionStatus,
      hasFloorPlan: details.project.latestFloorPlanId != null,
    );
  }

  final Set<String> uploadedRequiredRoleIds;
  final Set<String> filledRequiredRoleIds;
  final int requiredTotal;
  final String? reconstructionStatus;
  final bool hasFloorPlan;

  int get uploadedRequiredCount => uploadedRequiredRoleIds.length;
  int get filledRequiredCount => filledRequiredRoleIds.length;
  int get missingRequiredCount =>
      math.max(0, requiredTotal - uploadedRequiredCount);

  bool get sourceComplete =>
      requiredTotal > 0 && uploadedRequiredCount >= requiredTotal;

  bool get reconstructionComplete =>
      sourceComplete && (hasFloorPlan || reconstructionStatus == 'succeeded');

  bool get editReady => reconstructionComplete;

  bool get reconstructionStarted => reconstructionStatus != null;

  bool get reconstructionNeedsReview =>
      reconstructionStatus == 'review_required';

  bool get reconstructionFailed {
    return const {
      'failed',
      'timeout',
      'cancelled',
    }.contains(reconstructionStatus);
  }

  bool get reconstructionInProgress {
    return const {
      'created',
      'uploading',
      'processing',
      'retrying',
    }.contains(reconstructionStatus);
  }

  _MobileWorkflowStep get activeStep {
    if (!sourceComplete) return _MobileWorkflowStep.source;
    if (!reconstructionComplete) return _MobileWorkflowStep.reconstruction;
    return _MobileWorkflowStep.edit;
  }

  GuidedCaptureRoleInstruction? get nextRequiredRole {
    return _nextRequiredRoleByIds(uploadedRequiredRoleIds);
  }

  double get progressValue {
    const sourceSegmentEnd = 1 / 3;
    const reconstructionSegmentEnd = 2 / 3;

    if (!sourceComplete) {
      if (requiredTotal == 0) return 0;
      return (filledRequiredCount / requiredTotal * sourceSegmentEnd).clamp(
        0.0,
        sourceSegmentEnd,
      );
    }
    if (reconstructionComplete) return 1;
    if (reconstructionNeedsReview) return reconstructionSegmentEnd;
    if (reconstructionInProgress) {
      return sourceSegmentEnd +
          (reconstructionSegmentEnd - sourceSegmentEnd) * 0.68;
    }
    return sourceSegmentEnd;
  }

  String get progressCaption {
    if (!sourceComplete) return '소스 $filledRequiredCount/$requiredTotal';
    if (reconstructionComplete) return '편집 준비됨';
    return reconstructionStatusLabel;
  }

  Color get reconstructionTone {
    if (!sourceComplete) return _dim;
    if (reconstructionComplete) return _success;
    if (reconstructionFailed || reconstructionNeedsReview) return _warning;
    if (reconstructionInProgress) return _primary;
    return _warning;
  }

  String get reconstructionStatusLabel {
    if (!sourceComplete) return '소스 대기';
    if (reconstructionComplete) return '재구성 완료';
    return switch (reconstructionStatus) {
      'created' => '재구성 생성됨',
      'uploading' => '업로드 중',
      'processing' => '재구성 중',
      'review_required' => '검토 필요',
      'failed' => '재구성 실패',
      'timeout' => '시간 초과',
      'cancelled' => '취소됨',
      'retrying' => '다시 실행 중',
      _ => '재구성 대기',
    };
  }
}

class _WorkflowTitleProgress extends StatelessWidget {
  const _WorkflowTitleProgress({required this.state});

  final _MobileWorkflowState state;

  @override
  Widget build(BuildContext context) {
    final steps = [
      (
        label: '소스',
        complete: state.sourceComplete,
        active: state.activeStep == _MobileWorkflowStep.source,
      ),
      (
        label: '재구성',
        complete: state.reconstructionComplete,
        active: state.activeStep == _MobileWorkflowStep.reconstruction,
      ),
      (
        label: '편집',
        complete: state.editReady,
        active: state.activeStep == _MobileWorkflowStep.edit,
      ),
    ];

    return Semantics(
      label: '진행 상태 ${state.progressCaption}',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      value: state.progressValue,
                      backgroundColor: _borderStrong,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        state.editReady
                            ? _success
                            : state.sourceComplete
                            ? state.reconstructionTone
                            : _primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                for (final step in steps) ...[
                  _WorkflowStepDot(
                    label: step.label,
                    complete: step.complete,
                    active: step.active,
                  ),
                  if (step != steps.last) const SizedBox(width: 8),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkflowStepDot extends StatelessWidget {
  const _WorkflowStepDot({
    required this.label,
    required this.complete,
    required this.active,
  });

  final String label;
  final bool complete;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = complete
        ? _success
        : active
        ? _primary
        : _dim;
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: SizedBox(width: active ? 7 : 5, height: active ? 7 : 5),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: active || complete
                    ? FontWeight.w900
                    : FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AsyncDetailsView extends StatelessWidget {
  const _AsyncDetailsView({required this.snapshot, required this.builder});

  final AsyncSnapshot<_ProjectDetails> snapshot;
  final Widget Function(BuildContext context, _ProjectDetails details) builder;

  @override
  Widget build(BuildContext context) {
    if (snapshot.connectionState == ConnectionState.waiting &&
        snapshot.data == null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(18, 28, 18, 120),
        children: const [_LoadingPanel(label: '프로젝트 정보를 불러오는 중')],
      );
    }

    if (snapshot.hasError || snapshot.data == null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(18, 28, 18, 120),
        children: [
          _NoticeCard(
            tone: _danger,
            title: '프로젝트를 열 수 없습니다',
            body: '${snapshot.error ?? '알 수 없는 오류'}',
          ),
          OutlinedButton.icon(
            onPressed: () => context.go('/projects'),
            icon: const Icon(Icons.arrow_back),
            label: const Text('프로젝트 목록으로'),
          ),
        ],
      );
    }

    return builder(context, snapshot.data!);
  }
}

class _SourceImagesCard extends StatelessWidget {
  const _SourceImagesCard({
    required this.details,
    required this.pendingDrafts,
    required this.uploadingRoleId,
    required this.onCaptureRole,
    required this.onUploadRole,
    required this.onDiscardDraft,
  });

  final _ProjectDetails details;
  final Map<String, _PendingCaptureDraft> pendingDrafts;
  final String? uploadingRoleId;
  final ValueChanged<String> onCaptureRole;
  final ValueChanged<String> onUploadRole;
  final ValueChanged<String> onDiscardDraft;

  @override
  Widget build(BuildContext context) {
    final images = details.captureSnapshot?.images ?? const <CaptureImage>[];
    final imagesByRole = <String, CaptureImage>{};
    for (final image in images) {
      imagesByRole[image.role] = image;
    }
    final uploadedRequired = _requiredGuidedCaptureRoles
        .where((role) => imagesByRole.containsKey(role.id))
        .length;
    final pendingRequired = pendingDrafts.keys
        .where(_requiredGuidedCaptureRoleIds.contains)
        .length;
    final capturedOrUploadedRoleIds = {
      ...imagesByRole.keys,
      ...pendingDrafts.keys,
    };
    final emptyRequired =
        _requiredGuidedCaptureRoles.length -
        _requiredGuidedCaptureRoleIds
            .intersection(capturedOrUploadedRoleIds)
            .length;
    final extraImages = images.where((image) => image.role == 'extra').toList();

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '소스 이미지',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: _ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$uploadedRequired / ${_requiredGuidedCaptureRoles.length}',
                style: const TextStyle(color: _dim, fontSize: 12.5),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$uploadedRequired개 업로드됨 · $pendingRequired개 촬영 후 업로드 대기 · '
            '$emptyRequired개가 비어 있어요',
            style: const TextStyle(color: _muted, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: 9,
            itemBuilder: (context, index) {
              final roleId = _sourceImageBoardRoleAt(index);
              if (roleId == null) {
                return const _RoomPositionTile();
              }
              final role = _guidedCaptureRoleById(roleId)!;
              return _SourceImageRoleSlot(
                role: role,
                status: _sourceImageSlotStatus(
                  pendingDraft: pendingDrafts[role.id],
                  uploadedImage: imagesByRole[role.id],
                ),
                uploading: uploadingRoleId == role.id,
                onPressed: () => _handleRolePressed(
                  context,
                  role: role,
                  pendingDraft: pendingDrafts[role.id],
                  uploadedImage: imagesByRole[role.id],
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Text(
                '추가 사진',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: _ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '+${extraImages.length}',
                style: const TextStyle(color: _dim, fontSize: 12.5),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 112,
            height: 112,
            child: _SourceImageRoleSlot(
              role: _guidedCaptureRoleById('extra')!,
              status: _sourceImageSlotStatus(
                pendingDraft: pendingDrafts['extra'],
                uploadedImage: extraImages.isEmpty ? null : extraImages.last,
              ),
              uploading: uploadingRoleId == 'extra',
              compact: true,
              onPressed: () => _handleRolePressed(
                context,
                role: _guidedCaptureRoleById('extra')!,
                pendingDraft: pendingDrafts['extra'],
                uploadedImage: extraImages.isEmpty ? null : extraImages.last,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _SourceImageSlotStatus _sourceImageSlotStatus({
    required _PendingCaptureDraft? pendingDraft,
    required CaptureImage? uploadedImage,
  }) {
    if (pendingDraft != null) return _SourceImageSlotStatus.captured;
    if (uploadedImage != null) return _SourceImageSlotStatus.uploaded;
    return _SourceImageSlotStatus.empty;
  }

  void _handleRolePressed(
    BuildContext context, {
    required GuidedCaptureRoleInstruction role,
    required _PendingCaptureDraft? pendingDraft,
    required CaptureImage? uploadedImage,
  }) {
    if (pendingDraft == null && uploadedImage == null) {
      onCaptureRole(role.id);
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _panel,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _roleShortLabel(role.id),
                style: const TextStyle(
                  color: _ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                pendingDraft != null
                    ? '촬영됨 · 아직 Firebase에 업로드되지 않았습니다.'
                    : 'Firebase 업로드 완료',
                style: const TextStyle(color: _muted),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  onCaptureRole(role.id);
                },
                icon: const Icon(Icons.edit_outlined),
                label: Text(pendingDraft == null ? '수정 촬영' : '수정'),
              ),
              if (pendingDraft != null) ...[
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: uploadingRoleId == role.id
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          onUploadRole(role.id);
                        },
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: const Text('업로드'),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onDiscardDraft(role.id);
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('촬영본 삭제'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomPositionTile extends StatelessWidget {
  const _RoomPositionTile();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(color: _borderStrong),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: CustomPaint(
          painter: _RoomPlanIconPainter(),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

enum _SourceImageSlotStatus { empty, captured, uploaded }

class _SourceImageRoleSlot extends StatelessWidget {
  const _SourceImageRoleSlot({
    required this.role,
    required this.status,
    required this.uploading,
    required this.onPressed,
    this.compact = false,
  });

  final GuidedCaptureRoleInstruction role;
  final _SourceImageSlotStatus status;
  final bool uploading;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = _roleShortLabel(role.id);
    final done = status != _SourceImageSlotStatus.empty;
    final color = switch (status) {
      _SourceImageSlotStatus.uploaded => _success,
      _SourceImageSlotStatus.captured => _primary,
      _SourceImageSlotStatus.empty => _muted,
    };
    final icon = switch (status) {
      _SourceImageSlotStatus.uploaded => Icons.cloud_done_outlined,
      _SourceImageSlotStatus.captured => Icons.photo_camera_outlined,
      _SourceImageSlotStatus.empty => Icons.add_a_photo_outlined,
    };
    final stateLabel = switch (status) {
      _SourceImageSlotStatus.uploaded => '업로드됨',
      _SourceImageSlotStatus.captured => '촬영됨',
      _SourceImageSlotStatus.empty => '촬영 필요',
    };
    return Semantics(
      button: true,
      label: '$label 소스 이미지 $stateLabel',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: done
                      ? color.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.025),
                  border: Border.all(
                    color: done ? color.withValues(alpha: 0.62) : _borderStrong,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (uploading)
                      SizedBox(
                        width: compact ? 22 : 26,
                        height: compact ? 22 : 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: color,
                        ),
                      )
                    else
                      Icon(
                        icon,
                        color: color,
                        size: done ? (compact ? 28 : 32) : (compact ? 22 : 24),
                      ),
                    if (status != _SourceImageSlotStatus.uploaded) ...[
                      const SizedBox(height: 6),
                      Text(
                        compact && status == _SourceImageSlotStatus.empty
                            ? '추가'
                            : stateLabel,
                        style: TextStyle(
                          color: color,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Positioned(
                left: 6,
                right: 6,
                bottom: 5,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomPlanIconPainter extends CustomPainter {
  const _RoomPlanIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final width = math.min(size.width, size.height) * 0.72;
    final origin = Offset((size.width - width) / 2, (size.height - width) / 2);
    final room = Rect.fromLTWH(origin.dx, origin.dy, width, width * 0.82);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.74);
    canvas.drawRRect(
      RRect.fromRectAndRadius(room, const Radius.circular(3)),
      paint,
    );
    final inset = width * 0.18;
    canvas.drawRect(
      Rect.fromLTWH(
        room.left + inset,
        room.top + inset,
        width * 0.36,
        width * 0.36,
      ),
      paint,
    );
    final accent = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = _primary;
    canvas.drawLine(
      Offset(room.center.dx - width * 0.16, room.top - 1),
      Offset(room.center.dx + width * 0.16, room.top - 1),
      accent,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DesktopHandoffCard extends StatelessWidget {
  const _DesktopHandoffCard({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _IconTile(icon: Icons.desktop_windows_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '정밀 편집은 데스크탑에서',
                  style: TextStyle(color: _ink, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  '벽, 가구 보정과 평면도 편집은 /projects/$projectId/editor 에서 이어서 작업하세요.',
                  style: const TextStyle(color: _muted, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectActionBar extends StatelessWidget {
  const _ProjectActionBar({
    required this.projectId,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.onPrimary,
    this.secondaryLabel = '데스크탑 링크',
    this.secondaryIcon = Icons.send_outlined,
    this.onSecondary,
  });

  final String projectId;
  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback onPrimary;
  final String secondaryLabel;
  final IconData secondaryIcon;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Color(0xEE08090B),
          border: Border(top: BorderSide(color: _border)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      onSecondary ??
                      () => _copyProjectLink(
                        context,
                        '/projects/$projectId/editor',
                      ),
                  icon: Icon(secondaryIcon),
                  label: Text(secondaryLabel),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onPrimary,
                  icon: Icon(primaryIcon),
                  label: Text(primaryLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectPreviewCard extends StatelessWidget {
  const _ProjectPreviewCard({required this.project, required this.onOpen});

  final RoomProject project;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final status = project.currentReconstructionStatus;
    final editReady =
        project.latestFloorPlanId != null || status == 'succeeded';
    final processing = const {
      'created',
      'uploading',
      'processing',
      'retrying',
    }.contains(status);
    final badgeColor = editReady
        ? _success
        : processing
        ? _primary
        : _warning;
    final badgeLabel = editReady
        ? '편집 가능'
        : processing
        ? '재구성 중'
        : '소스 입력';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _panel,
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (!editReady && !processing)
                        const DecoratedBox(
                          decoration: BoxDecoration(color: Color(0xFF0C0D10)),
                          child: Icon(
                            Icons.add_a_photo_outlined,
                            color: _dim,
                            size: 34,
                          ),
                        )
                      else
                        Image.asset(
                          'assets/design/room.png',
                          fit: BoxFit.cover,
                          color: Colors.black.withValues(
                            alpha: processing ? 0.42 : 0.12,
                          ),
                          colorBlendMode: BlendMode.darken,
                        ),
                      Positioned(
                        left: 10,
                        top: 10,
                        child: _GlassPill(
                          icon: Icons.circle,
                          label: badgeLabel,
                          compact: true,
                          color: badgeColor,
                        ),
                      ),
                      if (processing)
                        const Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: LinearProgressIndicator(value: 0.62),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      project.description ?? '프로젝트 ${project.id}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _dim, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectFilterChips extends StatelessWidget {
  const _ProjectFilterChips();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(label: '전체', selected: true),
          _FilterChip(label: '진행 중'),
          _FilterChip(label: '완료'),
          _FilterChip(label: '촬영 필요'),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? Colors.white.withValues(alpha: 0.1) : _panel,
          border: Border.all(color: selected ? _borderStrong : _border),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? _ink : _muted,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyProjectCard extends StatelessWidget {
  const _EmptyProjectCard({required this.onCreateProject});

  final VoidCallback onCreateProject;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _IconTile(icon: Icons.add_a_photo_outlined),
          const SizedBox(height: 12),
          const Text(
            '아직 프로젝트가 없습니다',
            style: TextStyle(color: _ink, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            '모바일에서 방을 만들고 가이드 촬영을 시작하세요.',
            style: TextStyle(color: _muted, height: 1.4),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onCreateProject,
            icon: const Icon(Icons.add),
            label: const Text('프로젝트 만들기'),
          ),
        ],
      ),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 14),
          Text(label, style: const TextStyle(color: _muted)),
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.tone,
    required this.title,
    required this.body,
    this.action,
  });

  final Color tone;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.1),
        border: Border.all(color: tone.withValues(alpha: 0.34)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: tone, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: tone,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(body, style: const TextStyle(color: _muted)),
                    ],
                  ),
                ),
              ],
            ),
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _panel,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _MobileTopBar extends StatelessWidget implements PreferredSizeWidget {
  const _MobileTopBar({
    required this.title,
    required this.leading,
    required this.actions,
    this.workflow,
  });

  final Widget title;
  final Widget leading;
  final List<Widget> actions;
  final _MobileWorkflowState? workflow;

  @override
  Size get preferredSize => Size.fromHeight(workflow == null ? 64 : 96);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: title,
      bottom: workflow == null
          ? null
          : PreferredSize(
              preferredSize: const Size.fromHeight(32),
              child: _WorkflowTitleProgress(state: workflow!),
            ),
      leadingWidth: 54,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Center(child: leading),
      ),
      actions: [
        for (final action in actions)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(child: action),
          ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.06),
        side: const BorderSide(color: _border),
      ),
      icon: Icon(icon),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      color: Colors.white,
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.45),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
      ),
      icon: Icon(icon),
    );
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({
    required this.icon,
    required this.label,
    this.compact = false,
    this.color = Colors.white,
  });

  final IconData icon;
  final String label;
  final bool compact;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.48),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 13,
          vertical: compact ? 6 : 9,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: compact ? 11 : 15),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color == Colors.white ? Colors.white : _ink,
                fontSize: compact ? 11 : 12.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HandoffNote extends StatelessWidget {
  const _HandoffNote({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: _primary, size: 17),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: _dim,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    final label = (session.displayName ?? session.email ?? 'RF')
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part.characters.first)
        .take(2)
        .join()
        .toUpperCase();
    return DecoratedBox(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [_primary, _success]),
      ),
      child: SizedBox(
        width: 34,
        height: 34,
        child: Center(
          child: Text(
            label.isEmpty ? 'RF' : label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

enum _MobileTab { projects, activity, settings }

class _MobileTabBar extends StatelessWidget {
  const _MobileTabBar({required this.active});

  final _MobileTab active;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Color(0xEE08090B),
          border: Border(top: BorderSide(color: _border)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Row(
            children: [
              _TabItem(
                active: active == _MobileTab.projects,
                icon: Icons.dashboard_outlined,
                label: '프로젝트',
                onTap: () => context.go('/projects'),
              ),
              _TabItem(
                active: active == _MobileTab.activity,
                icon: Icons.notifications_none_outlined,
                label: '활동',
                onTap: () => _showUnavailable(context, '활동'),
              ),
              _TabItem(
                active: active == _MobileTab.settings,
                icon: Icons.person_outline,
                label: '설정',
                onTap: () => _showUnavailable(context, '설정'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.active,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool active;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? _primary : _dim;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileBrand extends StatelessWidget {
  const _MobileBrand();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_primary, _success]),
            borderRadius: BorderRadius.all(Radius.circular(6)),
          ),
          child: SizedBox(width: 18, height: 18),
        ),
        SizedBox(width: 9),
        Text(
          'RoomForge',
          style: TextStyle(
            color: _ink,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _MobileBackdrop extends StatelessWidget {
  const _MobileBackdrop({
    required this.child,
    this.opacity = 0.12,
    this.blur = false,
  });

  final Widget child;
  final double opacity;
  final bool blur;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      'assets/design/room.png',
      fit: BoxFit.cover,
      opacity: AlwaysStoppedAnimation(opacity),
    );

    return DecoratedBox(
      decoration: const BoxDecoration(color: _paper),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (blur)
            ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
              child: image,
            )
          else
            image,
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _paper.withValues(alpha: blur ? 0.46 : 0.78),
                  _paper.withValues(alpha: blur ? 0.18 : 0.88),
                  _paper,
                ],
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _NativeCaptureLayout extends StatelessWidget {
  const _NativeCaptureLayout({
    required this.leftRail,
    required this.preview,
    required this.rightRail,
  });

  final Widget leftRail;
  final Widget preview;
  final Widget rightRail;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 640;
        final minLeftWidth = compact ? 58.0 : 72.0;
        final minRightWidth = compact ? 96.0 : 108.0;
        final targetLeftWidth = compact ? 72.0 : 84.0;
        final targetRightWidth = compact ? 112.0 : 128.0;
        final availablePreviewWidth = math.max(
          0.0,
          constraints.maxWidth - minLeftWidth - minRightWidth,
        );
        final desiredPreviewWidth = constraints.maxHeight * _captureAspectRatio;
        final previewWidth = math.min(
          desiredPreviewWidth,
          availablePreviewWidth,
        );
        final previewHeight = previewWidth / _captureAspectRatio;
        final sideWidth = math.max(0.0, constraints.maxWidth - previewWidth);
        final sideRatio =
            targetLeftWidth / (targetLeftWidth + targetRightWidth);
        var leftWidth = sideWidth * sideRatio;
        var rightWidth = sideWidth - leftWidth;
        if (leftWidth < minLeftWidth) {
          leftWidth = minLeftWidth;
          rightWidth = math.max(0.0, sideWidth - leftWidth);
        }
        if (rightWidth < minRightWidth) {
          rightWidth = minRightWidth;
          leftWidth = math.max(0.0, sideWidth - rightWidth);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: leftWidth, child: leftRail),
            SizedBox(
              width: previewWidth,
              child: Center(
                child: SizedBox(
                  width: previewWidth,
                  height: previewHeight,
                  child: preview,
                ),
              ),
            ),
            SizedBox(width: rightWidth, child: rightRail),
          ],
        );
      },
    );
  }
}

class _CaptureLeftRail extends StatelessWidget {
  const _CaptureLeftRail({
    required this.hasUpload,
    required this.onClose,
    required this.onGallery,
  });

  final bool hasUpload;
  final VoidCallback onClose;
  final VoidCallback? onGallery;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Column(
          children: [
            _GlassIconButton(
              tooltip: '닫기',
              icon: Icons.close,
              onPressed: onClose,
            ),
            const Spacer(),
            _RecentCaptureThumb(hasUpload: hasUpload, onPressed: onGallery),
          ],
        ),
      ),
    );
  }
}

class _CaptureRightRail extends StatelessWidget {
  const _CaptureRightRail({
    required this.progress,
    required this.busy,
    required this.uploadedRoleIds,
    required this.currentRoleId,
    required this.onShutter,
    required this.onDone,
  });

  final double progress;
  final bool busy;
  final Set<String> uploadedRoleIds;
  final String? currentRoleId;
  final VoidCallback? onShutter;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.34),
        border: Border(
          left: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Column(
          children: [
            _CaptureMiniMap(
              uploadedRoleIds: uploadedRoleIds,
              currentRoleId: currentRoleId,
            ),
            const Spacer(),
            _ShutterButton(
              busy: busy,
              progress: progress,
              onPressed: onShutter,
            ),
            const Spacer(),
            _DoneCaptureButton(onPressed: onDone),
          ],
        ),
      ),
    );
  }
}

class _CapturePreviewPane extends StatelessWidget {
  const _CapturePreviewPane({
    required this.controller,
    required this.initialization,
    required this.cameraStatus,
    required this.projectName,
    required this.instruction,
    required this.busy,
    required this.onRetry,
  });

  final camera.CameraController? controller;
  final Future<void>? initialization;
  final String? cameraStatus;
  final String projectName;
  final String instruction;
  final bool busy;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: _InAppCameraPreview(
              controller: controller,
              initialization: initialization,
              status: cameraStatus,
              onRetry: onRetry,
            ),
          ),
          const Positioned.fill(child: _CaptureScrim()),
          Positioned.fill(
            child: CustomPaint(painter: _CaptureOverlayPainter()),
          ),
          Positioned(
            top: 10,
            left: 18,
            right: 18,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  projectName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '왼쪽 가로 모드 · 16:9 · $_captureResolutionLabel 목표',
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 12,
            child: _CaptureCoach(busy: busy, text: instruction),
          ),
        ],
      ),
    );
  }
}

class _InAppCameraPreview extends StatelessWidget {
  const _InAppCameraPreview({
    required this.controller,
    required this.initialization,
    required this.status,
    required this.onRetry,
  });

  final camera.CameraController? controller;
  final Future<void>? initialization;
  final String? status;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final activeController = controller;
    if (activeController != null && activeController.value.isInitialized) {
      final previewSize = activeController.value.previewSize;
      final width = previewSize == null
          ? 1920.0
          : math.max(previewSize.width, previewSize.height);
      final height = previewSize == null
          ? 1080.0
          : math.min(previewSize.width, previewSize.height);
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: width,
              height: height,
              child: camera.CameraPreview(activeController),
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      color: Colors.black,
      child: FutureBuilder<void>(
        future: initialization,
        builder: (context, snapshot) {
          final waiting =
              snapshot.connectionState == ConnectionState.waiting &&
              status != null;
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/design/room.png',
                fit: BoxFit.cover,
                color: Colors.black.withValues(alpha: 0.58),
                colorBlendMode: BlendMode.darken,
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.46),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            waiting
                                ? Icons.photo_camera_outlined
                                : Icons.photo_camera_outlined,
                            color: _primary,
                            size: 30,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            status ?? '카메라 프리뷰를 준비하고 있습니다.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              height: 1.35,
                            ),
                          ),
                          if (!waiting) ...[
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: onRetry,
                              icon: const Icon(Icons.refresh),
                              label: const Text('다시 시도'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CaptureScrim extends StatelessWidget {
  const _CaptureScrim();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.58),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.78),
          ],
          stops: const [0, 0.48, 1],
        ),
      ),
    );
  }
}

class _CaptureOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..strokeWidth = 1;
    for (final dx in [size.width / 3, size.width * 2 / 3]) {
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), gridPaint);
    }
    for (final dy in [size.height / 3, size.height * 2 / 3]) {
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), gridPaint);
    }

    final center = Offset(size.width / 2, size.height / 2);

    final ringPaint = Paint()
      ..color = _success.withValues(alpha: 0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    canvas.drawCircle(center, 37, ringPaint);
    canvas.drawCircle(center, 4, Paint()..color = _success);
    final levelPaint = Paint()
      ..color = _success.withValues(alpha: 0.85)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center.translate(-102, 0),
      center.translate(-56, 0),
      levelPaint,
    );
    canvas.drawLine(
      center.translate(56, 0),
      center.translate(102, 0),
      levelPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CaptureMiniMap extends StatelessWidget {
  const _CaptureMiniMap({
    required this.uploadedRoleIds,
    required this.currentRoleId,
  });

  final Set<String> uploadedRoleIds;
  final String? currentRoleId;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: CustomPaint(
                painter: _MiniMapPainter(
                  uploadedRoleIds: uploadedRoleIds,
                  currentRoleId: currentRoleId,
                ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              '${uploadedRoleIds.length} / ${_requiredGuidedCaptureRoles.length} 각도',
              style: const TextStyle(
                color: _ink,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  const _MiniMapPainter({
    required this.uploadedRoleIds,
    required this.currentRoleId,
  });

  final Set<String> uploadedRoleIds;
  final String? currentRoleId;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(4, 4, size.width - 8, size.height - 8);
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(7)),
      line,
    );
    final positions = <String, Offset>{
      'front_wall': Offset(rect.center.dx, rect.top),
      'front_right_corner': Offset(rect.right, rect.top),
      'right_wall': Offset(rect.right, rect.center.dy),
      'back_right_corner': Offset(rect.right, rect.bottom),
      'back_wall': Offset(rect.center.dx, rect.bottom),
      'back_left_corner': Offset(rect.left, rect.bottom),
      'left_wall': Offset(rect.left, rect.center.dy),
      'front_left_corner': Offset(rect.left, rect.top),
    };
    for (final role in _requiredGuidedCaptureRoles) {
      final position = positions[role.id] ?? rect.center;
      final color = uploadedRoleIds.contains(role.id)
          ? Colors.white
          : role.id == currentRoleId
          ? _primary
          : Colors.white.withValues(alpha: 0.28);
      canvas.drawCircle(
        position,
        role.id == currentRoleId ? 5.8 : 4.6,
        Paint()..color = color,
      );
      if (role.id == currentRoleId) {
        canvas.drawCircle(
          position,
          9,
          Paint()
            ..color = _primary.withValues(alpha: 0.18)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MiniMapPainter oldDelegate) {
    return uploadedRoleIds != oldDelegate.uploadedRoleIds ||
        currentRoleId != oldDelegate.currentRoleId;
  }
}

class _CaptureCoach extends StatelessWidget {
  const _CaptureCoach({required this.busy, required this.text});

  final bool busy;
  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _success.withValues(alpha: 0.16),
        border: Border.all(color: _success.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const DecoratedBox(
                decoration: BoxDecoration(
                  color: _success,
                  shape: BoxShape.circle,
                ),
                child: SizedBox(width: 7, height: 7),
              ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFA8F0CF),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentCaptureThumb extends StatelessWidget {
  const _RecentCaptureThumb({required this.hasUpload, required this.onPressed});

  final bool hasUpload;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '기존 사진 선택',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 52,
          height: 52,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              border: Border.all(
                color: hasUpload
                    ? _success.withValues(alpha: 0.58)
                    : Colors.white.withValues(alpha: 0.2),
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.photo_library_outlined,
                  color: onPressed == null ? _dim : _muted,
                  size: 27,
                ),
                if (hasUpload)
                  Positioned(
                    top: 7,
                    right: 7,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _success,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.68),
                          width: 1.5,
                        ),
                      ),
                      child: const SizedBox(width: 9, height: 9),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({
    required this.busy,
    required this.progress,
    required this.onPressed,
  });

  final bool busy;
  final double progress;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '촬영',
      child: GestureDetector(
        onTap: busy ? null : onPressed,
        child: SizedBox(
          width: 82,
          height: 82,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 82,
                height: 82,
                child: CircularProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  strokeWidth: 4,
                  color: _primary,
                  backgroundColor: Colors.white.withValues(alpha: 0.26),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox(
                      width: 50,
                      height: 50,
                      child: busy
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoneCaptureButton extends StatelessWidget {
  const _DoneCaptureButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '완료',
      onPressed: onPressed,
      color: Colors.white,
      style: IconButton.styleFrom(
        fixedSize: const Size(52, 52),
        backgroundColor: Colors.black.withValues(alpha: 0.46),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
      ),
      icon: const Icon(Icons.check),
    );
  }
}

class _UploadRing extends StatelessWidget {
  const _UploadRing({
    required this.value,
    required this.completed,
    required this.total,
  });

  final double value;
  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final percent = (value * 100).round();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        border: Border.all(color: _borderStrong),
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side =
              math.min(constraints.maxWidth, constraints.maxHeight) * 0.56;
          return Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: side,
                  height: side,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: side,
                        height: side,
                        child: CircularProgressIndicator(
                          value: value,
                          strokeWidth: 6,
                          color: _primary,
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      Text(
                        '$percent%',
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  completed >= total ? '업로드 완료' : '업로드 상태',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$completed / $total',
                  style: const TextStyle(
                    color: _dim,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _UploadStatusBoard extends StatelessWidget {
  const _UploadStatusBoard({
    required this.uploadedRoleIds,
    required this.value,
    required this.completed,
    required this.total,
  });

  final Set<String> uploadedRoleIds;
  final double value;
  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '업로드 상태',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: _ink,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$total개 각도 중 $completed개 업로드됨 · ${total - completed}개가 남아 있어요',
          style: const TextStyle(color: _muted, fontSize: 12.5),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: 9,
          itemBuilder: (context, index) {
            final roleId = _sourceImageBoardRoleAt(index);
            if (roleId == null) {
              return _UploadRing(
                value: value,
                completed: completed,
                total: total,
              );
            }

            final role = _guidedCaptureRoleById(roleId)!;
            return _UploadRoleStatusSlot(
              role: role,
              uploaded: uploadedRoleIds.contains(role.id),
            );
          },
        ),
      ],
    );
  }
}

class _UploadRoleStatusSlot extends StatelessWidget {
  const _UploadRoleStatusSlot({required this.role, required this.uploaded});

  final GuidedCaptureRoleInstruction role;
  final bool uploaded;

  @override
  Widget build(BuildContext context) {
    final label = _roleShortLabel(role.id);
    return Semantics(
      label: '$label 업로드 ${uploaded ? '완료' : '대기'}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: uploaded
                    ? _success.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.025),
                border: Border.all(
                  color: uploaded
                      ? _success.withValues(alpha: 0.62)
                      : _borderStrong,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: uploaded ? _success.withValues(alpha: 0.7) : _border,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    uploaded ? Icons.check_circle : Icons.cloud_upload_outlined,
                    color: uploaded ? _success : _muted,
                    size: uploaded ? 32 : 24,
                  ),
                  if (!uploaded) ...[
                    const SizedBox(height: 6),
                    const Text(
                      '대기',
                      style: TextStyle(
                        color: _dim,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              left: 6,
              right: 6,
              bottom: 5,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(icon, color: _primary, size: 20),
      ),
    );
  }
}

class _RoomPreviewPainter extends CustomPainter {
  const _RoomPreviewPainter({
    required this.roomDimensions,
    required this.uploadedCount,
  });

  final RoomDimensions? roomDimensions;
  final int uploadedCount;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFF0A0B0D);
    canvas.drawRect(Offset.zero & size, bg);

    final center = Offset(size.width / 2, size.height * 0.52);
    final roomWidth = size.width * 0.78;
    final roomDepth = size.height * 0.36;
    final floor = Path()
      ..moveTo(center.dx - roomWidth * 0.5, center.dy + roomDepth * 0.28)
      ..lineTo(center.dx + roomWidth * 0.5, center.dy + roomDepth * 0.28)
      ..lineTo(center.dx + roomWidth * 0.34, center.dy - roomDepth * 0.36)
      ..lineTo(center.dx - roomWidth * 0.34, center.dy - roomDepth * 0.36)
      ..close();
    canvas.drawPath(
      floor,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFCDBCA0), Color(0xFF9C8E76)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(floor.getBounds()),
    );

    final wallPaint = Paint()..color = const Color(0xFFE7E8EC);
    final backWall = Path()
      ..moveTo(center.dx - roomWidth * 0.34, center.dy - roomDepth * 0.36)
      ..lineTo(center.dx + roomWidth * 0.34, center.dy - roomDepth * 0.36)
      ..lineTo(center.dx + roomWidth * 0.42, center.dy - roomDepth * 0.88)
      ..lineTo(center.dx - roomWidth * 0.42, center.dy - roomDepth * 0.88)
      ..close();
    canvas.drawPath(backWall, wallPaint);
    canvas.drawPath(
      floor,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    void drawBox(Rect rect, Color color) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()..color = color,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }

    drawBox(
      Rect.fromCenter(
        center: center.translate(-roomWidth * 0.15, roomDepth * 0.02),
        width: roomWidth * 0.52,
        height: roomDepth * 0.34,
      ),
      const Color(0xFF2D2D33),
    );
    drawBox(
      Rect.fromCenter(
        center: center.translate(roomWidth * 0.28, -roomDepth * 0.08),
        width: roomWidth * 0.16,
        height: roomDepth * 0.52,
      ),
      const Color(0xFF17191C),
    );
    drawBox(
      Rect.fromCenter(
        center: center.translate(-roomWidth * 0.36, -roomDepth * 0.2),
        width: roomWidth * 0.12,
        height: roomDepth * 0.32,
      ),
      const Color(0xFF26262B),
    );

    final labelStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.76),
      fontSize: 12,
      fontWeight: FontWeight.w800,
    );
    final dimensions = roomDimensions;
    final label = dimensions == null
        ? 'Metric preview pending'
        : '${dimensions.widthValue.toStringAsFixed(1)} x ${dimensions.depthValue.toStringAsFixed(1)} m';
    final painter = TextPainter(
      text: TextSpan(text: '$label · photos $uploadedCount', style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 40);
    painter.paint(canvas, Offset(20, size.height - 168));
  }

  @override
  bool shouldRepaint(covariant _RoomPreviewPainter oldDelegate) {
    return roomDimensions != oldDelegate.roomDimensions ||
        uploadedCount != oldDelegate.uploadedCount;
  }
}

class _RouteErrorScreen extends StatelessWidget {
  const _RouteErrorScreen({required this.error});

  final Exception? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _MobileBackdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              const _MobileBrand(),
              const SizedBox(height: 28),
              _NoticeCard(
                tone: _danger,
                title: '라우트를 열 수 없습니다',
                body: '${error ?? '정의되지 않은 모바일 경로입니다.'}',
              ),
              OutlinedButton.icon(
                onPressed: () => context.go('/projects'),
                icon: const Icon(Icons.dashboard_outlined),
                label: const Text('프로젝트로 이동'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Set<String> _uploadedRoleIds(CaptureSessionSnapshot? snapshot) {
  return {
    for (final image in snapshot?.images ?? const <CaptureImage>[]) image.role,
  };
}

Set<String> _uploadedRequiredRoleIds(CaptureSessionSnapshot? snapshot) {
  return {
    for (final roleId in _uploadedRoleIds(snapshot))
      if (_requiredGuidedCaptureRoleIds.contains(roleId)) roleId,
  };
}

GuidedCaptureRoleInstruction? _guidedCaptureRoleById(String? roleId) {
  if (roleId == null || roleId.isEmpty) return null;
  for (final role in defaultGuidedCaptureRoles) {
    if (role.id == roleId) return role;
  }
  return null;
}

String? _normalizedCaptureRoleId(String? roleId) {
  return _guidedCaptureRoleById(roleId)?.id;
}

String? _sourceImageBoardRoleAt(int index) {
  return switch (index) {
    0 => 'front_left_corner',
    1 => 'front_wall',
    2 => 'front_right_corner',
    3 => 'left_wall',
    4 => null,
    5 => 'right_wall',
    6 => 'back_left_corner',
    7 => 'back_wall',
    8 => 'back_right_corner',
    _ => null,
  };
}

GuidedCaptureRoleInstruction? _nextRequiredRoleByIds(
  Set<String> uploadedRoleIds,
) {
  for (final role in defaultGuidedCaptureRoles) {
    if (role.required && !uploadedRoleIds.contains(role.id)) {
      return role;
    }
  }
  return null;
}

String _roleShortLabel(String role) {
  return switch (role) {
    'overview' => 'Overview',
    'front_wall' => '정면',
    'front_right_corner' => '정면 우측',
    'right_wall' => '우측',
    'back_right_corner' => '후면 우측',
    'back_wall' => '후면',
    'back_left_corner' => '후면 좌측',
    'left_wall' => '좌측',
    'front_left_corner' => '정면 좌측',
    'extra' => '추가',
    _ => role,
  };
}

Future<({int width, int height})> _decodeImageSize(List<int> bytes) async {
  final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
  final frame = await codec.getNextFrame();
  final image = frame.image;
  try {
    return (width: image.width, height: image.height);
  } finally {
    image.dispose();
  }
}

String _imageContentType(XFile file) {
  final mimeType = file.mimeType;
  if (mimeType != null && mimeType.startsWith('image/')) {
    return mimeType;
  }

  final name = file.name.toLowerCase();
  if (name.endsWith('.png')) return 'image/png';
  if (name.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}

String _captureFilename(String role, String originalName) {
  final extension = _extensionForName(originalName);
  final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
  return '${role}_$timestamp$extension';
}

String _cameraErrorMessage(camera.CameraException error) {
  return switch (error.code) {
    'CameraAccessDenied' ||
    'CameraAccessDeniedWithoutPrompt' ||
    'CameraAccessRestricted' =>
      '카메라 권한이 필요합니다. 시스템 설정에서 RoomForge의 카메라 접근을 허용하세요.',
    _ =>
      '카메라를 시작할 수 없습니다'
          '${error.description == null ? '' : ': ${error.description}'}',
  };
}

String _extensionForName(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) return '.png';
  if (lower.endsWith('.webp')) return '.webp';
  if (lower.endsWith('.jpeg')) return '.jpeg';
  return '.jpg';
}

int _captureOrderForRole(String role) {
  const order = {
    'overview': 0,
    'front_wall': 1,
    'front_right_corner': 2,
    'right_wall': 3,
    'back_right_corner': 4,
    'back_wall': 5,
    'back_left_corner': 6,
    'left_wall': 7,
    'front_left_corner': 8,
    'extra': 9,
  };
  return order[role] ?? 99;
}

Future<void> _copyProjectLink(BuildContext context, String path) async {
  await Clipboard.setData(ClipboardData(text: path));
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('데스크탑 링크를 복사했습니다.')));
}

void _showDesktopHandoff(BuildContext context, String projectId) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: _panel,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '데스크탑에서 계속',
              style: TextStyle(
                color: _ink,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '/projects/$projectId/editor',
              style: const TextStyle(color: _muted),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                unawaited(
                  _copyProjectLink(context, '/projects/$projectId/editor'),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('링크 복사'),
            ),
          ],
        ),
      ),
    ),
  );
}

void _showUnavailable(BuildContext context, String label) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('$label 화면은 모바일 후속 단계에서 연결됩니다.')));
}
