// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui_web' as ui_web;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart'
    show
        BrowserPlatformLocation,
        PathUrlStrategy,
        PlatformLocation,
        setUrlStrategy;

import 'src/admin/admin_api.dart';
import 'src/admin/firebase_admin_access_repository.dart';
import 'src/admin/firebase_admin_diagnostics.dart';
import 'src/auth/auth_repository.dart';
import 'src/editor/editor_config.dart';
import 'src/api/backend_bindings.dart';
import 'src/api/backend_mode.dart';
import 'src/firebase/firebase_models.dart';
import 'src/firebase/firebase_repositories.dart';
import 'src/firebase/firebase_app_bootstrap.dart';
import 'src/layouts/indexed_db_layout_draft_store.dart';
import 'src/layouts/layout_draft_models.dart';
import 'src/layouts/layout_draft_recovery.dart';
import 'src/layouts/layout_draft_recovery_controls.dart';
import 'src/layouts/layout_draft_repository.dart';
import 'src/layouts/layout_export_warning.dart';
import 'src/layouts/layout_furniture_bridge_mapper.dart';
import 'src/layouts/layout_remote_update_guard.dart';
import 'src/projects/arcore_depth_capability.dart';
import 'src/projects/firebase_source_image_upload.dart';
import 'src/projects/guided_capture_session_section.dart';
import 'src/projects/project_api.dart';
import 'src/projects/source_image_upload_recovery_controls.dart';
import 'src/projects/source_image_upload_status.dart';

const _roomForgeInk = Color(0xFFF8F8F5);
const _roomForgeInkSoft = Color(0xFFDEDED8);
const _roomForgeMuted = Color(0xFFA7ADB0);
const _roomForgeSubtle = Color(0xFF777D80);
const _roomForgeBorder = Color(0x244B6277);
const _roomForgeBorderStrong = Color(0x4D7992A8);
const _roomForgePaper = Color(0xFF050505);
const _roomForgePanel = Color(0xFF0B0D0F);
const _roomForgeCanvas = Color(0xFF101419);
const _roomForgePrimary = Color(0xFF8FB4FF);
const _roomForgeSuccess = Color(0xFF8BC3A7);
const _roomForgeSelected = Color(0xFFD8B46A);
const _roomForgeWarning = Color(0xFFD49A5C);
const _roomForgeError = Color(0xFFE08B82);
const _roomForgeMeasure = Color(0xFFB9A7E8);
const _roomForgeSave = Color(0xFF80C7C2);
const _roomForgeAdmin = Color(0xFF9BA7B4);
const _roomForgeLightSurface = Color(0xFFEAF0FF);
const _roomForgeLocaleOverride = String.fromEnvironment('ROOMFORGE_LOCALE');

bool get _roomForgeUsesKorean {
  final override = _roomForgeLocaleOverride.toLowerCase();
  if (override.isNotEmpty) {
    return override.startsWith('ko');
  }
  return WidgetsBinding.instance.platformDispatcher.locales.any(
    (locale) => locale.languageCode.toLowerCase() == 'ko',
  );
}

String rf(String english, String korean) {
  return _roomForgeUsesKorean ? korean : english;
}

String _localizedAuthSetupMessage(String message) {
  if (!_roomForgeUsesKorean) {
    return message;
  }
  if (message.contains('Firebase web configuration is missing')) {
    return 'Firebase 웹 설정이 없습니다. Google 로그인을 활성화하려면 ROOMFORGE_FIREBASE_* Dart define을 제공하세요.';
  }
  return message;
}

String _localizedAuthErrorMessage(String message) {
  if (!_roomForgeUsesKorean) {
    return message;
  }
  if (message.contains('Google sign-in is unavailable')) {
    return 'Firebase 설정을 제공할 때까지 Google 로그인을 사용할 수 없습니다.';
  }
  if (message.startsWith('Google sign-in failed:')) {
    return message.replaceFirst('Google sign-in failed:', 'Google 로그인 실패:');
  }
  return message;
}

String _localizedFirebaseAuthErrorMessage(FirebaseAuthException error) {
  if (!_roomForgeUsesKorean) {
    return error.message ?? error.code;
  }
  return switch (error.code) {
    'popup-closed-by-user' => '로그인 창이 닫혔습니다. 다시 시도하세요.',
    'popup-blocked' => '브라우저가 로그인 팝업을 차단했습니다. 팝업을 허용한 뒤 다시 시도하세요.',
    'network-request-failed' => '네트워크 요청에 실패했습니다. 연결을 확인한 뒤 다시 시도하세요.',
    'account-exists-with-different-credential' =>
      '같은 이메일에 다른 로그인 방식이 연결되어 있습니다.',
    'unauthorized-domain' => '현재 도메인이 Firebase 인증 허용 도메인에 등록되어 있지 않습니다.',
    _ => 'Google 로그인 실패: ${error.message ?? error.code}',
  };
}

String _profileSyncFailureMessage(Object error) {
  final prefix = rf('Profile sync failed', '프로필 동기화에 실패했습니다');
  if (error is FirebaseUserProfileSyncException) {
    return '$prefix: ${_localizedProfileSyncExceptionMessage(error)}';
  }

  final rawMessage = error.toString();
  if (rawMessage.contains('Dart exception thrown from converted Future')) {
    return '$prefix: ${rf('Firestore returned a browser error while syncing your profile. Verify that Cloud Firestore exists for the configured Firebase project, then retry.', '프로필 동기화 중 Firestore 브라우저 오류가 발생했습니다. 설정된 Firebase 프로젝트에 Cloud Firestore가 생성되어 있는지 확인한 뒤 다시 시도하세요.')}';
  }

  return '$prefix: $rawMessage';
}

String _localizedProfileSyncExceptionMessage(
  FirebaseUserProfileSyncException error,
) {
  if (!_roomForgeUsesKorean) {
    return error.message;
  }
  return switch (error.code) {
    'firestore_database_not_found' =>
      '설정된 Firebase 프로젝트에 Cloud Firestore 데이터베이스 `(default)`가 없습니다. Firebase Console에서 데이터베이스를 생성하거나 ROOMFORGE_FIREBASE_PROJECT_ID를 확인하세요.',
    'permission_denied' =>
      'Firestore 보안 규칙이 프로필 동기화를 거부했습니다. 로그인한 사용자가 users/{uid} 문서를 읽고 쓸 수 있는지 확인하세요.',
    'firestore_web_error' =>
      '브라우저에서 Firestore 프로필 동기화가 실패했습니다. 설정된 Firebase 프로젝트에 Cloud Firestore가 있는지 확인한 뒤 다시 시도하세요.',
    _ => error.message,
  };
}

enum _RoomForgeRouteShell { desktopApp, mobileApp, admin }

class _RoomForgePathUrlStrategy extends PathUrlStrategy {
  _RoomForgePathUrlStrategy([PlatformLocation? platformLocation])
    : this._(platformLocation ?? BrowserPlatformLocation());

  _RoomForgePathUrlStrategy._(this._platformLocation)
    : super(_platformLocation);

  final PlatformLocation _platformLocation;

  @override
  String getPath() {
    final path = '${_platformLocation.pathname}${_platformLocation.search}';
    if (path.isEmpty) {
      return '/';
    }
    return path.startsWith('/') ? path : '/$path';
  }

  @override
  String prepareExternalUrl(String internalUrl) {
    if (internalUrl.isEmpty) {
      return '/';
    }
    return internalUrl.startsWith('/') ? internalUrl : '/$internalUrl';
  }
}

class _RoomForgeRouteSpec {
  const _RoomForgeRouteSpec._({
    required this.location,
    required this.shell,
    required this.section,
    this.projectId,
    this.adminJobId,
    this.childRoute,
  });

  static const appHome = _RoomForgeRouteSpec._(
    location: '/app',
    shell: _RoomForgeRouteShell.desktopApp,
    section: 'home',
  );

  final String location;
  final _RoomForgeRouteShell shell;
  final String section;
  final String? projectId;
  final String? adminJobId;
  final String? childRoute;

  bool get isAdmin => shell == _RoomForgeRouteShell.admin;
  bool get isMobile => shell == _RoomForgeRouteShell.mobileApp;
  bool get isWorkspace => projectId != null;
  bool get isProjects => !isWorkspace && section == 'projects';
  bool get isHome => !isWorkspace && section == 'home';
  bool get isAdminDashboard => isAdmin && section == 'dashboard';
  bool get isAdminJobs => isAdmin && section == 'jobs';
  bool get isAdminJobDetail => isAdmin && section == 'job';
  bool get isAdminRetries =>
      isAdmin && (section == 'retries' || childRoute == 'retry');
  bool get isAdminAudit =>
      isAdmin && (section == 'audit' || childRoute == 'audit');

  String get productRootPath => isMobile ? '/m/app' : '/app';
  String get projectsPath => '$productRootPath/projects';
  String get adminRootPath => '/admin';
  String get adminJobsPath => '$adminRootPath/jobs';
  String get adminRetriesPath => '$adminRootPath/retries';
  String get adminAuditPath => '$adminRootPath/audit';

  String workspacePath(String projectId, {String? childRoute}) {
    final encodedProjectId = Uri.encodeComponent(projectId);
    final basePath = '$productRootPath/workspaces/$encodedProjectId';
    final child = childRoute?.trim();
    if (child == null || child.isEmpty) {
      return basePath;
    }
    return '$basePath/$child';
  }

  String adminJobPath(String jobId, {String? childRoute}) {
    final encodedJobId = Uri.encodeComponent(jobId);
    final basePath = '$adminJobsPath/$encodedJobId';
    final child = childRoute?.trim();
    if (child == null || child.isEmpty) {
      return basePath;
    }
    return '$basePath/$child';
  }

  static _RoomForgeRouteSpec fromLocation(String? location) {
    final normalized = _normalizeLocation(location);
    final segments = normalized
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);

    if (segments.isEmpty) {
      return appHome;
    }

    if (segments.first == 'admin') {
      return _adminRoute(
        normalized: normalized,
        adminSegments: segments.sublist(1),
      );
    }

    if (segments.length >= 2 && segments[0] == 'm' && segments[1] == 'app') {
      return _productRoute(
        normalized: normalized,
        shell: _RoomForgeRouteShell.mobileApp,
        productSegments: segments.sublist(2),
      );
    }

    if (segments.first == 'app') {
      return _productRoute(
        normalized: normalized,
        shell: _RoomForgeRouteShell.desktopApp,
        productSegments: segments.sublist(1),
      );
    }

    return appHome;
  }

  static _RoomForgeRouteSpec _adminRoute({
    required String normalized,
    required List<String> adminSegments,
  }) {
    if (adminSegments.isEmpty) {
      return _RoomForgeRouteSpec._(
        location: normalized,
        shell: _RoomForgeRouteShell.admin,
        section: 'dashboard',
      );
    }

    if (adminSegments.first == 'jobs') {
      if (adminSegments.length >= 2) {
        return _RoomForgeRouteSpec._(
          location: normalized,
          shell: _RoomForgeRouteShell.admin,
          section: 'job',
          adminJobId: Uri.decodeComponent(adminSegments[1]),
          childRoute: adminSegments.length > 2
              ? adminSegments.sublist(2).join('/')
              : null,
        );
      }
      return _RoomForgeRouteSpec._(
        location: normalized,
        shell: _RoomForgeRouteShell.admin,
        section: 'jobs',
      );
    }

    return _RoomForgeRouteSpec._(
      location: normalized,
      shell: _RoomForgeRouteShell.admin,
      section: adminSegments.first,
      adminJobId: adminSegments.length > 1
          ? Uri.decodeComponent(adminSegments[1])
          : null,
      childRoute: adminSegments.length > 1
          ? adminSegments.sublist(1).join('/')
          : null,
    );
  }

  static _RoomForgeRouteSpec _productRoute({
    required String normalized,
    required _RoomForgeRouteShell shell,
    required List<String> productSegments,
  }) {
    if (productSegments.isEmpty) {
      return _RoomForgeRouteSpec._(
        location: normalized,
        shell: shell,
        section: 'home',
      );
    }

    if (productSegments.first == 'projects') {
      return _RoomForgeRouteSpec._(
        location: normalized,
        shell: shell,
        section: 'projects',
      );
    }

    if (productSegments.length >= 2 && productSegments.first == 'workspaces') {
      return _RoomForgeRouteSpec._(
        location: normalized,
        shell: shell,
        section: productSegments.length > 2 ? productSegments[2] : 'workspace',
        projectId: Uri.decodeComponent(productSegments[1]),
        childRoute: productSegments.length > 2
            ? productSegments.sublist(2).join('/')
            : null,
      );
    }

    return _RoomForgeRouteSpec._(
      location: normalized,
      shell: shell,
      section: productSegments.first,
      childRoute: productSegments.length > 1
          ? productSegments.sublist(1).join('/')
          : null,
    );
  }

  static String _normalizeLocation(String? location) {
    final currentPath = html.window.location.pathname ?? '/app';
    final raw = (location == null || location.trim().isEmpty)
        ? currentPath
        : location.trim();
    final uri = Uri.tryParse(raw);
    var path = uri?.path.isNotEmpty == true ? uri!.path : raw;
    if (!path.startsWith('/')) {
      path = '/$path';
    }
    while (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return path;
  }
}

String _initialRoomForgeRouteName() {
  final path = html.window.location.pathname;
  final normalized = _RoomForgeRouteSpec._normalizeLocation(path);
  if (normalized == '/' || normalized == '/m') {
    return '/app';
  }
  return normalized;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setUrlStrategy(_RoomForgePathUrlStrategy());

  final firebaseBootstrap = await FirebaseAppBootstrap.initialize();

  runApp(
    RoomForgeApp(
      authRepository: firebaseBootstrap.authRepository,
      adminRepository: firebaseBootstrap.adminRepository,
      floorPlanRepository: firebaseBootstrap.floorPlanRepository,
      geometryRepository: firebaseBootstrap.geometryRepository,
      layoutRepository: firebaseBootstrap.layoutRepository,
      projectRepository: firebaseBootstrap.projectRepository,
      reconstructionRepository: firebaseBootstrap.reconstructionRepository,
      roomDimensionsRepository: firebaseBootstrap.roomDimensionsRepository,
      sceneUnderstandingRepository:
          firebaseBootstrap.sceneUnderstandingRepository,
      sourceImageRepository: firebaseBootstrap.sourceImageRepository,
      sourceImageUploader: firebaseBootstrap.sourceImageUploader,
      userRepository: firebaseBootstrap.userRepository,
      backendMode: firebaseBootstrap.backendMode,
      authSetupMessage: firebaseBootstrap.authSetupMessage,
    ),
  );
}

class RoomForgeApp extends StatelessWidget {
  const RoomForgeApp({
    required this.authRepository,
    required this.adminRepository,
    required this.floorPlanRepository,
    required this.geometryRepository,
    required this.layoutRepository,
    required this.projectRepository,
    required this.reconstructionRepository,
    required this.roomDimensionsRepository,
    required this.sceneUnderstandingRepository,
    required this.sourceImageRepository,
    required this.sourceImageUploader,
    required this.userRepository,
    required this.backendMode,
    this.authSetupMessage,
    super.key,
  });

  final AuthRepository authRepository;
  final FirebaseAdminRepository adminRepository;
  final FirebaseFloorPlanRepository floorPlanRepository;
  final FirebaseGeometryRepository geometryRepository;
  final FirebaseLayoutRepository layoutRepository;
  final FirebaseProjectRepository projectRepository;
  final FirebaseReconstructionRepository reconstructionRepository;
  final FirebaseRoomDimensionsRepository roomDimensionsRepository;
  final FirebaseSceneUnderstandingRepository sceneUnderstandingRepository;
  final FirebaseSourceImageRepository sourceImageRepository;
  final FirebaseSourceImageUploader sourceImageUploader;
  final FirebaseUserRepository userRepository;
  final BackendMode backendMode;
  final String? authSetupMessage;

  Widget _buildAuthGate(String routeLocation) {
    return AuthGate(
      routeLocation: routeLocation,
      authRepository: authRepository,
      adminRepository: adminRepository,
      floorPlanRepository: floorPlanRepository,
      geometryRepository: geometryRepository,
      layoutRepository: layoutRepository,
      projectRepository: projectRepository,
      reconstructionRepository: reconstructionRepository,
      roomDimensionsRepository: roomDimensionsRepository,
      sceneUnderstandingRepository: sceneUnderstandingRepository,
      sourceImageRepository: sourceImageRepository,
      sourceImageUploader: sourceImageUploader,
      userRepository: userRepository,
      backendMode: backendMode,
      authSetupMessage: authSetupMessage,
    );
  }

  Route<void> _buildRoute(RouteSettings settings, {bool animate = true}) {
    final routeSpec = _RoomForgeRouteSpec.fromLocation(settings.name);

    if (!animate) {
      return MaterialPageRoute<void>(
        settings: RouteSettings(name: routeSpec.location),
        builder: (context) => _buildAuthGate(routeSpec.location),
      );
    }

    return PageRouteBuilder<void>(
      settings: RouteSettings(name: routeSpec.location),
      transitionDuration: const Duration(milliseconds: 110),
      reverseTransitionDuration: const Duration(milliseconds: 80),
      pageBuilder: (context, animation, secondaryAnimation) =>
          _buildAuthGate(routeSpec.location),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (MediaQuery.of(context).disableAnimations) {
          return child;
        }
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RoomForge',
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: _roomForgePrimary,
          onPrimary: _roomForgePaper,
          secondary: _roomForgeSave,
          onSecondary: _roomForgePaper,
          surface: _roomForgePanel,
          onSurface: _roomForgeInk,
          error: _roomForgeError,
          onError: _roomForgePaper,
        ),
        scaffoldBackgroundColor: _roomForgePaper,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: _roomForgePaper,
          foregroundColor: _roomForgeInk,
          centerTitle: false,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: const CardThemeData(
          color: _roomForgePanel,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            side: BorderSide(color: _roomForgeBorder),
          ),
        ),
        dividerTheme: const DividerThemeData(color: _roomForgeBorder, space: 1),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderSide: BorderSide(color: _roomForgeBorder),
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: _roomForgeBorder),
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: _roomForgePrimary),
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          filled: true,
          fillColor: _roomForgePanel,
          labelStyle: TextStyle(color: _roomForgeInkSoft),
          hintStyle: TextStyle(color: _roomForgeSubtle),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 44),
            backgroundColor: _roomForgePrimary,
            foregroundColor: _roomForgePaper,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 44),
            side: const BorderSide(color: _roomForgeBorder),
            foregroundColor: _roomForgeInk,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 44),
            foregroundColor: _roomForgeInkSoft,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      home: _buildAuthGate(_initialRoomForgeRouteName()),
      onGenerateRoute: _buildRoute,
      onUnknownRoute: (settings) => _buildRoute(
        RouteSettings(
          name: _RoomForgeRouteSpec.appHome.location,
          arguments: settings.arguments,
        ),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({
    this.routeLocation = '/app',
    required this.authRepository,
    required this.adminRepository,
    required this.floorPlanRepository,
    required this.geometryRepository,
    required this.layoutRepository,
    required this.projectRepository,
    required this.reconstructionRepository,
    required this.roomDimensionsRepository,
    required this.sceneUnderstandingRepository,
    required this.sourceImageRepository,
    required this.sourceImageUploader,
    required this.userRepository,
    required this.backendMode,
    this.authSetupMessage,
    super.key,
  });

  final String routeLocation;
  final AuthRepository authRepository;
  final FirebaseAdminRepository adminRepository;
  final FirebaseFloorPlanRepository floorPlanRepository;
  final FirebaseGeometryRepository geometryRepository;
  final FirebaseLayoutRepository layoutRepository;
  final FirebaseProjectRepository projectRepository;
  final FirebaseReconstructionRepository reconstructionRepository;
  final FirebaseRoomDimensionsRepository roomDimensionsRepository;
  final FirebaseSceneUnderstandingRepository sceneUnderstandingRepository;
  final FirebaseSourceImageRepository sourceImageRepository;
  final FirebaseSourceImageUploader sourceImageUploader;
  final FirebaseUserRepository userRepository;
  final BackendMode backendMode;
  final String? authSetupMessage;

  @override
  Widget build(BuildContext context) {
    final routeSpec = _RoomForgeRouteSpec.fromLocation(routeLocation);
    return StreamBuilder<AuthSession?>(
      stream: authRepository.authStateChanges(),
      builder: (context, snapshot) {
        final session = snapshot.data;
        if (session == null) {
          return SignInScreen(
            authRepository: authRepository,
            authSetupMessage: authSetupMessage,
          );
        }

        final legacyAdminApi = RoomForgeBackendBindings.legacyAdminApi(
          backendMode: backendMode,
          authRepository: authRepository,
        );
        final projectApi = RoomForgeBackendBindings.projectApi(
          backendMode: backendMode,
          authRepository: authRepository,
          session: session,
          floorPlanRepository: floorPlanRepository,
          geometryRepository: geometryRepository,
          layoutRepository: layoutRepository,
          projectRepository: projectRepository,
          reconstructionRepository: reconstructionRepository,
          roomDimensionsRepository: roomDimensionsRepository,
          sceneUnderstandingRepository: sceneUnderstandingRepository,
          sourceImageRepository: sourceImageRepository,
          sourceImageUploader: sourceImageUploader,
        );

        final child = routeSpec.isAdmin
            ? _AdminRouteGate(
                routeSpec: routeSpec,
                session: session,
                adminRepository: adminRepository,
                legacyAdminApi: legacyAdminApi,
                backendMode: backendMode,
                onSwitchAccount: authRepository.signOut,
              )
            : _ProjectWorkspaceScreen(
                routeSpec: routeSpec,
                authRepository: authRepository,
                adminRepository: adminRepository,
                session: session,
                legacyAdminApi: legacyAdminApi,
                backendMode: backendMode,
                projectApi: projectApi,
              );

        return UserProfileSyncGate(
          userRepository: userRepository,
          session: session,
          child: child,
        );
      },
    );
  }
}

class UserProfileSyncGate extends StatefulWidget {
  const UserProfileSyncGate({
    required this.userRepository,
    required this.session,
    required this.child,
    super.key,
  });

  final FirebaseUserRepository userRepository;
  final AuthSession session;
  final Widget child;

  @override
  State<UserProfileSyncGate> createState() => _UserProfileSyncGateState();
}

class _UserProfileSyncGateState extends State<UserProfileSyncGate> {
  late Future<void> _syncFuture;

  @override
  void initState() {
    super.initState();
    _syncFuture = _syncProfile();
  }

  @override
  void didUpdateWidget(UserProfileSyncGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.uid != widget.session.uid) {
      _syncFuture = _syncProfile();
    }
  }

  Future<void> _syncProfile() async {
    await widget.userRepository.syncProfile(widget.session);
  }

  void _retry() {
    setState(() => _syncFuture = _syncProfile());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _syncFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            body: Center(
              child: RoomForgePanel(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 14),
                    Text(rf('Syncing profile...', '프로필 동기화 중...')),
                  ],
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return ProjectErrorView(
            message: _profileSyncFailureMessage(snapshot.error!),
            onRetry: _retry,
          );
        }

        return widget.child;
      },
    );
  }
}

class _AdminRouteGate extends StatelessWidget {
  const _AdminRouteGate({
    required this.routeSpec,
    required this.session,
    required this.adminRepository,
    required this.legacyAdminApi,
    required this.backendMode,
    required this.onSwitchAccount,
  });

  final _RoomForgeRouteSpec routeSpec;
  final AuthSession session;
  final FirebaseAdminRepository adminRepository;
  final AdminApi? legacyAdminApi;
  final BackendMode backendMode;
  final Future<void> Function() onSwitchAccount;

  @override
  Widget build(BuildContext context) {
    if (backendMode == BackendMode.legacyApi) {
      return _LegacyAdminRouteGate(adminApi: legacyAdminApi);
    }

    return FutureBuilder<bool>(
      future: adminRepository.isCurrentUserAdmin(session),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _AdminRouteLoadingScreen();
        }
        if (snapshot.hasError || snapshot.data != true) {
          return _AdminRouteDeniedScreen(
            accountLabel:
                session.email ??
                session.displayName ??
                rf('signed-in account', '로그인 계정'),
            onSwitchAccount: onSwitchAccount,
          );
        }
        return _FirebaseAdminDiagnosticsScreen(
          routeSpec: routeSpec,
          session: session,
          adminRepository: adminRepository,
        );
      },
    );
  }
}

class _LegacyAdminRouteGate extends StatefulWidget {
  const _LegacyAdminRouteGate({required this.adminApi});

  final AdminApi? adminApi;

  @override
  State<_LegacyAdminRouteGate> createState() => _LegacyAdminRouteGateState();
}

class _LegacyAdminRouteGateState extends State<_LegacyAdminRouteGate> {
  late final Future<AdminSession> _sessionFuture;

  @override
  void initState() {
    super.initState();
    final adminApi = widget.adminApi;
    _sessionFuture = adminApi == null
        ? Future<AdminSession>.error(
            rf(
              'Legacy admin API is not configured.',
              '레거시 관리자 API가 설정되지 않았습니다.',
            ),
          )
        : adminApi.loadSession();
  }

  @override
  Widget build(BuildContext context) {
    final adminApi = widget.adminApi;
    if (adminApi == null) {
      return _AdminRouteUnavailableScreen(
        message: rf(
          'Legacy admin API is not configured.',
          '레거시 관리자 API가 설정되지 않았습니다.',
        ),
      );
    }

    return FutureBuilder<AdminSession>(
      future: _sessionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _AdminRouteLoadingScreen();
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _AdminRouteUnavailableScreen(
            message:
                '${rf('Admin session could not be loaded.', '관리자 세션을 불러오지 못했습니다.')}: ${snapshot.error ?? 'unknown'}',
          );
        }
        return AdminShellScreen(session: snapshot.data!, adminApi: adminApi);
      },
    );
  }
}

class _AdminRouteLoadingScreen extends StatelessWidget {
  const _AdminRouteLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(rf('Admin', '관리자'))),
      body: const _RoomForgeAppBackground(
        child: Center(
          child: RoomForgePanel(
            child: SizedBox.square(
              dimension: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminRouteDeniedScreen extends StatelessWidget {
  const _AdminRouteDeniedScreen({
    required this.accountLabel,
    required this.onSwitchAccount,
  });

  final String accountLabel;
  final Future<void> Function() onSwitchAccount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(rf('Admin', '관리자'))),
      body: _RoomForgeAppBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: RoomForgePanel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RoomForgeNotice(
                    title: rf('Admin access denied', '관리자 접근 권한이 없습니다'),
                    message:
                        '${rf('The current account cannot open the operations console.', '현재 계정은 운영 콘솔을 열 수 없습니다')} $accountLabel',
                    severity: NoticeSeverity.error,
                    icon: Icons.admin_panel_settings_outlined,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(
                          context,
                        ).pushNamed(_RoomForgeRouteSpec.appHome.location),
                        icon: const Icon(Icons.arrow_back_outlined),
                        label: Text(rf('Back to app', '앱으로 돌아가기')),
                      ),
                      FilledButton.icon(
                        onPressed: onSwitchAccount,
                        icon: const Icon(Icons.logout_outlined),
                        label: Text(rf('Switch account', '계정 전환')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminRouteUnavailableScreen extends StatelessWidget {
  const _AdminRouteUnavailableScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(rf('Admin', '관리자'))),
      body: _RoomForgeAppBackground(
        child: ProjectErrorView(
          message: message,
          onRetry: () => Navigator.of(context).pushNamed('/admin'),
        ),
      ),
    );
  }
}

class SignInScreen extends StatefulWidget {
  const SignInScreen({
    required this.authRepository,
    this.authSetupMessage,
    super.key,
  });

  final AuthRepository authRepository;
  final String? authSetupMessage;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _isSigningIn = false;
  String? _errorMessage;
  late final ScrollController _landingScrollController;
  final GlobalKey _howSectionKey = GlobalKey();
  final GlobalKey _featuresSectionKey = GlobalKey();
  bool _isNavScrolled = false;

  @override
  void initState() {
    super.initState();
    _landingScrollController = ScrollController()
      ..addListener(_handleLandingScroll);
  }

  @override
  void dispose() {
    _landingScrollController
      ..removeListener(_handleLandingScroll)
      ..dispose();
    super.dispose();
  }

  void _handleLandingScroll() {
    final next = _landingScrollController.offset > 40;
    if (next == _isNavScrolled) {
      return;
    }
    setState(() => _isNavScrolled = next);
  }

  Future<void> _scrollToSection(GlobalKey key) async {
    final context = key.currentContext;
    if (context == null) {
      return;
    }
    await Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      alignment: .02,
    );
  }

  Future<void> _scrollToHero() async {
    if (!_landingScrollController.hasClients) {
      return;
    }
    await _landingScrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _showAuthError(String message) async {
    if (!mounted) {
      return;
    }
    setState(() => _errorMessage = message);
    await _scrollToHero();
  }

  Future<void> _signIn() async {
    final authSetupMessage = widget.authSetupMessage;
    if (authSetupMessage != null) {
      await _showAuthError(_localizedAuthSetupMessage(authSetupMessage));
      return;
    }

    setState(() {
      _isSigningIn = true;
      _errorMessage = null;
    });

    try {
      await widget.authRepository.signInWithGoogle();
    } on AuthUnavailableException catch (error) {
      await _showAuthError(_localizedAuthErrorMessage(error.message));
    } on FirebaseAuthException catch (error) {
      await _showAuthError(_localizedFirebaseAuthErrorMessage(error));
    } catch (error) {
      await _showAuthError(
        _localizedAuthErrorMessage('Google sign-in failed: $error'),
      );
    } finally {
      if (mounted) {
        setState(() => _isSigningIn = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 760;
    final topPadding =
        MediaQuery.paddingOf(context).top + (compact ? 64.0 : 72.0);

    return Scaffold(
      body: _RoomForgeAppBackground(
        child: Stack(
          children: [
            Positioned.fill(
              child: SingleChildScrollView(
                controller: _landingScrollController,
                padding: EdgeInsets.only(top: topPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _LandingHero(
                      isSigningIn: _isSigningIn,
                      errorMessage: _errorMessage,
                      onSignIn: _signIn,
                      onDemo: () => _scrollToSection(_howSectionKey),
                    ),
                    _LandingHowSection(key: _howSectionKey),
                    _LandingFeatureSection(key: _featuresSectionKey),
                    _LandingFinalCta(
                      isSigningIn: _isSigningIn,
                      onSignIn: _signIn,
                    ),
                    const _LandingFooter(),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: _LandingNav(
                  isSigningIn: _isSigningIn,
                  isScrolled: _isNavScrolled,
                  onSignIn: _signIn,
                  onHow: () => _scrollToSection(_howSectionKey),
                  onFeatures: () => _scrollToSection(_featuresSectionKey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LandingNav extends StatelessWidget {
  const _LandingNav({
    required this.isSigningIn,
    required this.isScrolled,
    required this.onSignIn,
    required this.onHow,
    required this.onFeatures,
  });

  final bool isSigningIn;
  final bool isScrolled;
  final VoidCallback onSignIn;
  final VoidCallback onHow;
  final VoidCallback onFeatures;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 760;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: isScrolled ? const Color(0xE6050505) : const Color(0x94050505),
        border: Border(
          bottom: BorderSide(
            color: isScrolled ? _roomForgeBorder : Colors.transparent,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 16 : 28,
          vertical: compact ? 12 : (isScrolled ? 10 : 14),
        ),
        child: Row(
          children: [
            const _LandingBrand(),
            if (!compact) ...[
              const SizedBox(width: 24),
              _LandingNavLink(label: rf('How it works', '작동 방식'), onTap: onHow),
              _LandingNavLink(label: rf('Features', '기능'), onTap: onFeatures),
              _LandingNavLink(label: rf('Design', '디자인'), onTap: onFeatures),
            ],
            const Spacer(),
            _LandingButton(
              label: rf('Login', '로그인'),
              onPressed: isSigningIn ? null : onSignIn,
              compact: compact,
            ),
            if (!compact) ...[
              const SizedBox(width: 10),
              _LandingButton(
                label: isSigningIn
                    ? rf('Starting...', '시작 중...')
                    : rf('Start', '시작하기'),
                onPressed: isSigningIn ? null : onSignIn,
                primary: true,
                icon: isSigningIn ? null : Icons.arrow_forward,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LandingBrand extends StatelessWidget {
  const _LandingBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _roomForgePaper,
                Color(0xFF172235),
                Color(0xFF294642),
                _roomForgeSelected,
              ],
              stops: [0, .46, .74, 1],
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x5CDCE8FF), spreadRadius: 1),
            ],
          ),
          child: const SizedBox(width: 16, height: 16),
        ),
        const SizedBox(width: 10),
        Text(
          'RoomForge',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _LandingNavLink extends StatefulWidget {
  const _LandingNavLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_LandingNavLink> createState() => _LandingNavLinkState();
}

class _LandingNavLinkState extends State<_LandingNavLink> {
  bool _hovered = false;
  Offset _magnet = Offset.zero;

  void _updateMagnet(PointerEvent event, Size size) {
    final x = (event.localPosition.dx - size.width / 2) / size.width;
    final y = (event.localPosition.dy - size.height / 2) / size.height;
    final next = Offset(x * 5, y * 3);
    if ((next - _magnet).distance < .45) {
      return;
    }
    setState(() => _magnet = next);
  }

  @override
  Widget build(BuildContext context) {
    final magnetSize = Size(math.max(72, widget.label.length * 12 + 22), 36);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _magnet = Offset.zero;
      }),
      onHover: (event) => _updateMagnet(event, magnetSize),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(_magnet.dx, _magnet.dy, 0),
        decoration: BoxDecoration(
          color: _hovered
              ? Colors.white.withValues(alpha: .06)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(11, 8, 11, 8),
            child: Stack(
              alignment: Alignment.bottomLeft,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    widget.label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: _hovered ? Colors.white : _roomForgeSubtle,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                AnimatedScale(
                  scale: _hovered ? 1 : 0,
                  alignment: Alignment.centerLeft,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: Container(
                    height: 1,
                    width: math.max(1, widget.label.length * 8),
                    color: _hovered ? Colors.white : _roomForgeSubtle,
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

class _LandingButton extends StatefulWidget {
  const _LandingButton({
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.big = false,
    this.compact = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final bool big;
  final bool compact;
  final IconData? icon;

  @override
  State<_LandingButton> createState() => _LandingButtonState();
}

class _LandingButtonState extends State<_LandingButton> {
  bool _hovered = false;
  bool _pressed = false;
  Offset _magnet = Offset.zero;
  Offset? _rippleOrigin;
  int _rippleSeed = 0;

  bool get _enabled => widget.onPressed != null;

  void _updateMagnet(PointerEvent event, Size size) {
    if (!_enabled) {
      return;
    }
    final x = (event.localPosition.dx - size.width / 2) / size.width;
    final y = (event.localPosition.dy - size.height / 2) / size.height;
    final next = Offset(x * 5, y * 3);
    if ((next - _magnet).distance < .45) {
      return;
    }
    setState(() => _magnet = next);
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.compact ? 36.0 : (widget.big ? 54.0 : 40.0);
    final horizontal = widget.compact ? 11.0 : (widget.big ? 24.0 : 16.0);
    final textStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      color: widget.primary ? _roomForgePaper : _roomForgeInk,
      fontWeight: FontWeight.w800,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(
          constraints.maxWidth.isFinite ? constraints.maxWidth : 160,
          height,
        );
        return MouseRegion(
          cursor: _enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.forbidden,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() {
            _hovered = false;
            _pressed = false;
            _magnet = Offset.zero;
          }),
          onHover: (event) => _updateMagnet(event, size),
          child: Listener(
            onPointerDown: (event) {
              if (!_enabled) {
                return;
              }
              setState(() {
                _pressed = true;
                _rippleOrigin = event.localPosition;
                _rippleSeed++;
              });
            },
            onPointerUp: (_) => setState(() => _pressed = false),
            onPointerCancel: (_) => setState(() => _pressed = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(
                _magnet.dx,
                _magnet.dy + (_hovered ? -1 : 0),
                0,
              )..scale(_pressed ? .98 : 1.0),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: widget.onPressed,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      constraints: BoxConstraints(minHeight: height),
                      padding: EdgeInsets.symmetric(horizontal: horizontal),
                      decoration: BoxDecoration(
                        color: widget.primary
                            ? null
                            : (_hovered
                                  ? Colors.white.withValues(alpha: .09)
                                  : Colors.white.withValues(alpha: .04)),
                        gradient: widget.primary
                            ? const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFFDCE8FF),
                                  _roomForgePrimary,
                                  _roomForgeSave,
                                ],
                                stops: [0, .58, 1],
                              )
                            : null,
                        border: Border.all(
                          color: widget.primary
                              ? (_hovered
                                    ? const Color(0xF5DCE8FF)
                                    : const Color(0xDBDCE8FF))
                              : (_hovered
                                    ? _roomForgeBorderStrong
                                    : _roomForgeBorder),
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          if (_hovered)
                            BoxShadow(
                              color: widget.primary
                                  ? const Color(0x478FB4FF)
                                  : const Color(0x57000000),
                              blurRadius: widget.primary ? 58 : 45,
                              offset: const Offset(0, 18),
                            ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_rippleOrigin != null)
                            _LandingRipple(
                              key: ValueKey(_rippleSeed),
                              origin: _rippleOrigin!,
                              color: widget.primary
                                  ? _roomForgePaper
                                  : _roomForgeInk,
                            ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(widget.label, style: textStyle),
                              if (widget.icon != null) ...[
                                const SizedBox(width: 8),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOutCubic,
                                  transform: Matrix4.translationValues(
                                    _hovered ? 2 : 0,
                                    0,
                                    0,
                                  ),
                                  child: Icon(
                                    widget.icon,
                                    size: 16,
                                    color: widget.primary
                                        ? _roomForgePaper
                                        : _roomForgeInk,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LandingRipple extends StatefulWidget {
  const _LandingRipple({required this.origin, required this.color, super.key});

  final Offset origin;
  final Color color;

  @override
  State<_LandingRipple> createState() => _LandingRippleState();
}

class _LandingRippleState extends State<_LandingRipple>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final size =
                140.0 * Curves.easeOutCubic.transform(_controller.value);
            return CustomPaint(
              painter: _LandingRipplePainter(
                origin: widget.origin,
                radius: size,
                color: widget.color.withValues(
                  alpha: (.22 * (1 - _controller.value)).clamp(0, .22),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LandingRipplePainter extends CustomPainter {
  const _LandingRipplePainter({
    required this.origin,
    required this.radius,
    required this.color,
  });

  final Offset origin;
  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(origin, radius, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _LandingRipplePainter oldDelegate) =>
      origin != oldDelegate.origin ||
      radius != oldDelegate.radius ||
      color != oldDelegate.color;
}

class _LandingHero extends StatelessWidget {
  const _LandingHero({
    required this.isSigningIn,
    required this.onSignIn,
    required this.onDemo,
    this.errorMessage,
  });

  final bool isSigningIn;
  final VoidCallback onSignIn;
  final VoidCallback onDemo;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewportHeight = MediaQuery.sizeOf(context).height;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: viewportHeight * .92),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 96, 28, 42),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1220),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 900;
                    final title = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Photo to metric room model',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: _roomForgeSubtle,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FittedBox(
                            alignment: Alignment.centerLeft,
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'RoomForge',
                              maxLines: 1,
                              softWrap: false,
                              style: theme.textTheme.displayLarge?.copyWith(
                                color: Colors.white,
                                fontSize: compact ? 72 : 124,
                                height: .88,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                    final copy = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rf(
                            'Turn a real room photo into a dimension-aware 3D space. Review the source image, CV candidate geometry, and confirmed room model in one flow before placing furniture.',
                            '실제 방 사진을 치수 기반 3D 공간으로 전환합니다. 원본 이미지, 후보 geometry, 확인된 공간 모델을 한 흐름에서 검토하고 바로 배치까지 이어갑니다.',
                          ),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: _roomForgeInkSoft,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _LandingButton(
                              label: isSigningIn
                                  ? rf('Signing in...', '로그인 중...')
                                  : rf('Create space', '공간 만들기'),
                              onPressed: isSigningIn ? null : onSignIn,
                              primary: true,
                              big: true,
                              icon: isSigningIn ? null : Icons.arrow_forward,
                            ),
                            _LandingButton(
                              label: rf('Demo', '데모 보기'),
                              onPressed: onDemo,
                              big: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const _LandingMetrics(),
                        if (errorMessage != null) ...[
                          const SizedBox(height: 16),
                          RoomForgeNotice(
                            icon: Icons.error_outline,
                            title: rf(
                              'Google sign-in unavailable',
                              'Google 로그인을 사용할 수 없습니다',
                            ),
                            message: _localizedAuthErrorMessage(errorMessage!),
                            severity: NoticeSeverity.error,
                          ),
                        ],
                      ],
                    );
                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [title, const SizedBox(height: 18), copy],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(child: title),
                        const SizedBox(width: 28),
                        SizedBox(width: 420, child: copy),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                const _LandingCompareStage(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LandingMetrics extends StatelessWidget {
  const _LandingMetrics();

  @override
  Widget build(BuildContext context) {
    final items = [
      (value: '3D', label: rf('Live space view', '실시간 공간 뷰')),
      (value: 'm', label: rf('Meter calibration', '미터 좌표 보정')),
      (value: 'CV', label: rf('Geometry review', '후보 geometry 검토')),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _roomForgeBorder,
        border: Border.all(color: _roomForgeBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 280;
          return compact
              ? Column(
                  children: [
                    for (final item in items)
                      _LandingMetric(item.value, item.label),
                  ],
                )
              : Row(
                  children: [
                    for (final item in items)
                      Expanded(child: _LandingMetric(item.value, item.label)),
                  ],
                );
        },
      ),
    );
  }
}

class _LandingMetric extends StatelessWidget {
  const _LandingMetric(this.value, this.label);

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(color: Color(0xC7050505)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: _roomForgeSubtle,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingCompareStage extends StatefulWidget {
  const _LandingCompareStage();

  @override
  State<_LandingCompareStage> createState() => _LandingCompareStageState();
}

class _LandingCompareStageState extends State<_LandingCompareStage>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final FocusNode _focusNode;
  double _split = .72;
  double _targetSplit = .72;
  double _stageY = .5;
  double _targetY = .5;
  bool _moved = false;
  bool _hovered = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _ticker = createTicker(_tick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    if (!mounted) {
      return;
    }
    final k = _reduceMotion ? 1.0 : .18;
    final nextSplit = _split + (_targetSplit - _split) * k;
    final nextY = _stageY + (_targetY - _stageY) * k;
    final isSettled =
        (nextSplit - _split).abs() < .0008 && (nextY - _stageY).abs() < .0008;
    if (isSettled) {
      _ticker.stop();
      return;
    }
    setState(() {
      _split = nextSplit.clamp(0, 1).toDouble();
      _stageY = nextY.clamp(0, 1).toDouble();
    });
  }

  void _startStageAnimation() {
    if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  void _setFromLocal(Offset localPosition, double width, double height) {
    if (width <= 0 || height <= 0) {
      return;
    }
    _targetSplit = (localPosition.dx / width).clamp(0, 1).toDouble();
    _targetY = (localPosition.dy / height).clamp(0, 1).toDouble();
    if (!_moved) {
      setState(() => _moved = true);
    }
    _startStageAnimation();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _targetSplit = math.max(0, _targetSplit - .06);
      if (!_moved) {
        setState(() => _moved = true);
      }
      _startStageAnimation();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _targetSplit = math.min(1, _targetSplit + .06);
      if (!_moved) {
        setState(() => _moved = true);
      }
      _startStageAnimation();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    _reduceMotion = MediaQuery.of(context).disableAnimations;
    return RepaintBoundary(
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final height = (constraints.maxWidth * 900 / 1536)
                  .clamp(300.0, 610.0)
                  .toDouble();
              final stageWidth = constraints.maxWidth;
              final tiltMatrix = Matrix4.identity()..setEntry(3, 2, .0008);
              if (!_reduceMotion && _hovered) {
                tiltMatrix
                  ..rotateX((.5 - _targetY) * 2.0 * math.pi / 180)
                  ..rotateY((_targetSplit - .5) * 2.6 * math.pi / 180);
              }
              return Semantics(
                slider: true,
                label: rf(
                  'Compare real room photo and live 3D model',
                  '실제 방 사진과 실시간 3D 모델 비교',
                ),
                value: '${(_split * 100).round()}%',
                child: Focus(
                  focusNode: _focusNode,
                  onKeyEvent: _handleKey,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeLeftRight,
                    onEnter: (_) => setState(() => _hovered = true),
                    onExit: (_) => setState(() => _hovered = false),
                    onHover: (event) =>
                        _setFromLocal(event.localPosition, stageWidth, height),
                    child: GestureDetector(
                      onTapDown: (details) {
                        _focusNode.requestFocus();
                        _setFromLocal(
                          details.localPosition,
                          stageWidth,
                          height,
                        );
                      },
                      onPanUpdate: (details) => _setFromLocal(
                        details.localPosition,
                        stageWidth,
                        height,
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        curve: Curves.easeOutCubic,
                        transform: tiltMatrix,
                        transformAlignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF080808),
                          border: Border.all(
                            color: _hovered
                                ? _roomForgeBorderStrong
                                : _roomForgeBorder,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x78000000),
                              blurRadius: 42,
                              offset: Offset(0, 22),
                            ),
                            BoxShadow(
                              color: Color(0x29FFFFFF),
                              blurRadius: 0,
                              spreadRadius: 1,
                              offset: Offset(0, -1),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            height: height,
                            child: Stack(
                              children: [
                                const Positioned.fill(
                                  child: _LandingPhotoLayer(),
                                ),
                                Positioned.fill(
                                  right: stageWidth * (1 - _split),
                                  child: ColorFiltered(
                                    colorFilter: const ColorFilter.mode(
                                      Color(0x00000000),
                                      BlendMode.saturation,
                                    ),
                                    child: CustomPaint(
                                      painter: _LandingModelPainter(),
                                    ),
                                  ),
                                ),
                                const Positioned.fill(
                                  child: _LandingStageWash(),
                                ),
                                Positioned.fill(
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 220),
                                    opacity: _hovered ? .32 : 0,
                                    child: CustomPaint(
                                      painter: _LandingStageGridPainter(),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: stageWidth * _split - 95,
                                  top: 0,
                                  bottom: 0,
                                  width: 190,
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 220),
                                    opacity: _moved ? 1 : 0,
                                    child: const DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.transparent,
                                            Color(0x29FFFFFF),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 16,
                                  right: 16,
                                  child: _LandingStageBadge(
                                    label: rf(
                                      'Original photo',
                                      'Original photo',
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 16,
                                  left: (stageWidth * _split - 58)
                                      .clamp(16.0, stageWidth - 150)
                                      .toDouble(),
                                  child: _LandingStageBadge(
                                    label: rf('Live 3D model', 'Live 3D model'),
                                  ),
                                ),
                                Positioned(
                                  left: stageWidth * _split,
                                  top: 0,
                                  bottom: 0,
                                  child: _LandingScanHandle(
                                    reduceMotion: _reduceMotion,
                                    hovered: _hovered,
                                  ),
                                ),
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 16,
                                  child: Center(
                                    child: _LandingHint(gone: _moved),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 18,
            runSpacing: 10,
            children: [
              _LandingStagePip(
                label: rf('3D model', '3D 모델'),
                active: _split > .5,
              ),
              _LandingStagePip(
                label: rf('Original photo', '원본 사진'),
                active: _split <= .5,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            rf(
              'The left side recreates the Three.js room model from the design mockup in Flutter. In product, uploaded photos and reconstruction results connect to this comparison view.',
              '왼쪽은 design 목업의 Three.js 공간 모델을 Flutter에서 재현한 장면입니다. 제품에서는 사용자의 업로드 사진과 재구성 결과가 이 비교 뷰에 연결됩니다.',
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: _roomForgeSubtle,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingStageBadge extends StatelessWidget {
  const _LandingStageBadge({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xB8050505),
            border: Border.all(color: _roomForgeBorder),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  icon == Icons.arrow_forward
                      ? const _NudgeIcon()
                      : Icon(icon, size: 14, color: Colors.white),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: .92),
                    fontWeight: FontWeight.w900,
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

class _LandingHint extends StatelessWidget {
  const _LandingHint({required this.gone});

  final bool gone;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: gone ? 0 : 1,
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, gone ? 8 : 0, 0),
        child: _LandingStageBadge(
          icon: Icons.arrow_forward,
          label: rf('Drag to compare', 'Drag to compare'),
        ),
      ),
    );
  }
}

class _LandingStagePip extends StatelessWidget {
  const _LandingStagePip({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      transform: Matrix4.translationValues(0, active ? -1 : 0, 0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: active
                  ? _roomForgePrimary
                  : Colors.white.withValues(alpha: .24),
              borderRadius: BorderRadius.circular(99),
              boxShadow: [
                if (active)
                  const BoxShadow(color: Color(0x298FB4FF), spreadRadius: 4),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: active ? const Color(0xFFEAF0FF) : _roomForgeSubtle,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingStageWash extends StatelessWidget {
  const _LandingStageWash();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0x14FFFFFF),
                    Colors.transparent,
                    Colors.transparent,
                    Color(0x0FFFFFFF),
                  ],
                  stops: [0, .18, .82, 1],
                ),
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
                    Color(0x1FFFFFFF),
                    Colors.transparent,
                    Colors.transparent,
                    Color(0x7A000000),
                  ],
                  stops: [0, .15, .86, 1],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NudgeIcon extends StatelessWidget {
  const _NudgeIcon();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.arrow_forward, size: 14, color: Colors.white);
  }
}

class _LandingScanHandle extends StatelessWidget {
  const _LandingScanHandle({required this.reduceMotion, required this.hovered});

  final bool reduceMotion;
  final bool hovered;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(-.5, 0),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -54,
            width: 108,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      _roomForgePrimary.withValues(alpha: .16),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Color(0xF5DCE8FF),
                  _roomForgePrimary,
                  _roomForgeSave,
                  Colors.transparent,
                ],
                stops: [0, .10, .50, .90, 1],
              ),
              boxShadow: [BoxShadow(color: Color(0x708FB4FF), blurRadius: 34)],
            ),
          ),
          AnimatedScale(
            scale: hovered ? 1.04 : 1,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: hovered
                        ? Colors.white.withValues(alpha: .12)
                        : const Color(0xC8050505),
                    border: Border.all(color: Colors.white70),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: reduceMotion
                        ? const []
                        : const [
                            BoxShadow(
                              color: Color(0x66000000),
                              blurRadius: 24,
                              offset: Offset(0, 14),
                            ),
                          ],
                  ),
                  child: const SizedBox(
                    width: 42,
                    height: 42,
                    child: Icon(
                      Icons.compare_arrows_outlined,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingPhotoLayer extends StatelessWidget {
  const _LandingPhotoLayer();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/design/room.png', fit: BoxFit.cover),
        const DecoratedBox(
          decoration: BoxDecoration(
            color: Color(0x4A000000),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x2EFFFFFF), Color(0x12000000), Color(0x76000000)],
              stops: [0, .42, 1],
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: .86,
              colors: [Color(0x00000000), Color(0x8A000000)],
            ),
          ),
        ),
      ],
    );
  }
}

class _LandingModelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF17191D), Color(0xFF090A0D), Color(0xFF050505)],
        ).createShader(bounds),
    );

    final ceiling = _path([
      Offset(size.width * .08, size.height * .10),
      Offset(size.width * .98, size.height * .08),
      Offset(size.width * .76, size.height * .20),
      Offset(size.width * .34, size.height * .20),
    ]);
    final leftWall = _path([
      Offset(size.width * .08, size.height * .10),
      Offset(size.width * .34, size.height * .20),
      Offset(size.width * .34, size.height * .58),
      Offset(size.width * .08, size.height * .95),
    ]);
    final backWall = _path([
      Offset(size.width * .34, size.height * .20),
      Offset(size.width * .76, size.height * .20),
      Offset(size.width * .76, size.height * .58),
      Offset(size.width * .34, size.height * .58),
    ]);
    final rightWall = _path([
      Offset(size.width * .76, size.height * .20),
      Offset(size.width * .98, size.height * .08),
      Offset(size.width * .98, size.height * .95),
      Offset(size.width * .76, size.height * .58),
    ]);
    final floor = _path([
      Offset(size.width * .08, size.height * .95),
      Offset(size.width * .34, size.height * .58),
      Offset(size.width * .76, size.height * .58),
      Offset(size.width * .98, size.height * .95),
    ]);

    canvas.drawPath(ceiling, Paint()..color = const Color(0xFFE8E4DC));
    canvas.drawPath(leftWall, Paint()..color = const Color(0xFF232326));
    canvas.drawPath(backWall, Paint()..color = const Color(0xFFBEB8AD));
    canvas.drawPath(rightWall, Paint()..color = const Color(0xFFD7D4CC));
    canvas.drawPath(
      floor,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFB9AD9C), Color(0xFF7E746A)],
        ).createShader(bounds),
    );

    final shellLine = Paint()
      ..color = const Color(0x668FB4FF)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (final path in [ceiling, leftWall, backWall, rightWall, floor]) {
      canvas.drawPath(path, shellLine);
    }

    _drawBackWallDetails(canvas, size);
    _drawWindow(canvas, size);
    _drawShelvesAndDesk(canvas, size);
    _drawBed(canvas, size);
    _drawNightstands(canvas, size);
    _drawDresser(canvas, size);
    _drawCalibrationOverlay(canvas, size);

    final vignette = Paint()
      ..shader = const RadialGradient(
        radius: .9,
        colors: [Color(0x00000000), Color(0x9A000000)],
      ).createShader(bounds);
    canvas.drawRect(bounds, vignette);
  }

  static double _lerp(double start, double end, double t) =>
      start + (end - start) * t;

  static Path _path(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  static void _drawBackWallDetails(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * .37,
          size.height * .265,
          size.width * .40,
          size.height * .035,
        ),
        const Radius.circular(12),
      ),
      Paint()
        ..color = const Color(0xAAFFF1D0)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
    _rect(
      canvas,
      Rect.fromLTWH(
        size.width * .49,
        size.height * .29,
        size.width * .19,
        size.height * .13,
      ),
      const Color(0xFF18191B),
      stroke: const Color(0xAA8FB4FF),
      radius: 2,
    );
    _rect(
      canvas,
      Rect.fromLTWH(
        size.width * .50,
        size.height * .305,
        size.width * .17,
        size.height * .10,
      ),
      const Color(0xFFBDB8AF),
      radius: 1,
    );
  }

  static void _drawBed(Canvas canvas, Size size) {
    canvas.drawOval(
      Rect.fromLTWH(
        size.width * .34,
        size.height * .71,
        size.width * .38,
        size.height * .11,
      ),
      Paint()
        ..color = const Color(0x88000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
    );
    final base = _path([
      Offset(size.width * .39, size.height * .58),
      Offset(size.width * .66, size.height * .58),
      Offset(size.width * .75, size.height * .77),
      Offset(size.width * .31, size.height * .77),
    ]);
    final mattress = _path([
      Offset(size.width * .41, size.height * .56),
      Offset(size.width * .64, size.height * .56),
      Offset(size.width * .71, size.height * .69),
      Offset(size.width * .35, size.height * .70),
    ]);
    canvas.drawPath(base, Paint()..color = const Color(0xFF202025));
    canvas.drawPath(mattress, Paint()..color = const Color(0xFF54545A));
    canvas.drawPath(
      mattress,
      Paint()
        ..color = const Color(0xAA8FB4FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
    _rect(
      canvas,
      Rect.fromLTWH(
        size.width * .42,
        size.height * .52,
        size.width * .10,
        size.height * .06,
      ),
      const Color(0xFFC8C4BC),
      radius: 5,
    );
    _rect(
      canvas,
      Rect.fromLTWH(
        size.width * .53,
        size.height * .52,
        size.width * .10,
        size.height * .06,
      ),
      const Color(0xFF2E3034),
      radius: 5,
    );
    _rect(
      canvas,
      Rect.fromLTWH(
        size.width * .49,
        size.height * .57,
        size.width * .08,
        size.height * .055,
      ),
      const Color(0xFFB9B4AA),
      radius: 4,
    );
  }

  static void _drawNightstands(Canvas canvas, Size size) {
    for (final x in [.35, .69]) {
      _rect(
        canvas,
        Rect.fromLTWH(
          size.width * x,
          size.height * .57,
          size.width * .07,
          size.height * .075,
        ),
        const Color(0xFF17181B),
        stroke: const Color(0x557F8DA3),
        radius: 2,
      );
      canvas.drawCircle(
        Offset(size.width * (x + .035), size.height * .545),
        size.width * .010,
        Paint()
          ..color = const Color(0xFFFFE7B5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
  }

  static void _drawShelvesAndDesk(Canvas canvas, Size size) {
    _rect(
      canvas,
      Rect.fromLTWH(
        size.width * .13,
        size.height * .18,
        size.width * .20,
        size.height * .45,
      ),
      const Color(0xFF111214),
      stroke: const Color(0x445E7A92),
    );
    for (final y in [.24, .34, .44]) {
      _rect(
        canvas,
        Rect.fromLTWH(
          size.width * .15,
          size.height * y,
          size.width * .17,
          size.height * .015,
        ),
        const Color(0xFF303239),
      );
    }
    _rect(
      canvas,
      Rect.fromLTWH(
        size.width * .13,
        size.height * .58,
        size.width * .22,
        size.height * .045,
      ),
      const Color(0xFF17181B),
    );
    _rect(
      canvas,
      Rect.fromLTWH(
        size.width * .19,
        size.height * .49,
        size.width * .095,
        size.height * .075,
      ),
      const Color(0xFF0B0C0E),
      stroke: const Color(0x668FB4FF),
      radius: 2,
    );
    _rect(
      canvas,
      Rect.fromLTWH(
        size.width * .23,
        size.height * .62,
        size.width * .075,
        size.height * .115,
      ),
      const Color(0xFF15161A),
      stroke: const Color(0x5580C7C2),
      radius: 4,
    );
  }

  static void _drawWindow(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * .80,
        size.height * .21,
        size.width * .16,
        size.height * .36,
      ),
      Paint()
        ..color = const Color(0x9FEAF2FB)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );
    _rect(
      canvas,
      Rect.fromLTWH(
        size.width * .81,
        size.height * .22,
        size.width * .13,
        size.height * .33,
      ),
      const Color(0xFFE8EDF2),
      stroke: const Color(0xFF111114),
      radius: 2,
    );
    canvas.drawLine(
      Offset(size.width * .875, size.height * .22),
      Offset(size.width * .875, size.height * .55),
      Paint()
        ..color = const Color(0xFF111114)
        ..strokeWidth = 2,
    );
    canvas.drawLine(
      Offset(size.width * .81, size.height * .39),
      Offset(size.width * .94, size.height * .39),
      Paint()
        ..color = const Color(0xFF111114)
        ..strokeWidth = 2,
    );
    _rect(
      canvas,
      Rect.fromLTWH(
        size.width * .78,
        size.height * .18,
        size.width * .035,
        size.height * .58,
      ),
      const Color(0xFF303136),
    );
    _rect(
      canvas,
      Rect.fromLTWH(
        size.width * .94,
        size.height * .18,
        size.width * .035,
        size.height * .58,
      ),
      const Color(0xFF25262A),
    );
  }

  static void _drawDresser(Canvas canvas, Size size) {
    _rect(
      canvas,
      Rect.fromLTWH(
        size.width * .82,
        size.height * .66,
        size.width * .18,
        size.height * .20,
      ),
      const Color(0xFF121316),
      stroke: const Color(0x445E7A92),
      radius: 3,
    );
    _rect(
      canvas,
      Rect.fromLTWH(
        size.width * .875,
        size.height * .61,
        size.width * .032,
        size.height * .055,
      ),
      const Color(0xFF1E2024),
      radius: 2,
    );
    canvas.drawCircle(
      Offset(size.width * .895, size.height * .59),
      size.width * .020,
      Paint()..color = const Color(0xFF51614D),
    );
  }

  static void _drawCalibrationOverlay(Canvas canvas, Size size) {
    final floorGrid = Paint()
      ..color = const Color(0x338FB4FF)
      ..strokeWidth = .9;
    for (var i = 1; i < 7; i++) {
      final t = i / 7;
      canvas.drawLine(
        Offset(_lerp(size.width * .08, size.width * .34, t), size.height * .95),
        Offset(_lerp(size.width * .34, size.width * .76, t), size.height * .58),
        floorGrid,
      );
      canvas.drawLine(
        Offset(_lerp(size.width * .34, size.width * .76, t), size.height * .58),
        Offset(_lerp(size.width * .76, size.width * .98, t), size.height * .95),
        floorGrid,
      );
    }

    final scanOverlay = Paint()
      ..color = const Color(0x3380C7C2)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(size.width * .34, size.height * .20),
      Offset(size.width * .08, size.height * .95),
      scanOverlay,
    );
    canvas.drawLine(
      Offset(size.width * .76, size.height * .20),
      Offset(size.width * .98, size.height * .95),
      scanOverlay,
    );

    final handlePaint = Paint()
      ..color = _roomForgeSelected
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;
    final anchor = Offset(size.width * .53, size.height * .57);
    canvas.drawCircle(anchor, 7, handlePaint);
    canvas.drawLine(
      anchor,
      Offset(size.width * .61, size.height * .52),
      handlePaint,
    );
    canvas.drawCircle(
      Offset(size.width * .61, size.height * .52),
      4,
      Paint()..color = _roomForgeSelected,
    );
  }

  static void _rect(
    Canvas canvas,
    Rect rect,
    Color color, {
    Color? stroke,
    double radius = 0,
  }) {
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.drawRRect(rrect, Paint()..color = color);
    if (stroke != null) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LandingStageGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x18FFFFFF)
      ..strokeWidth = 1;
    const divisions = 12;
    for (var i = 1; i < divisions; i++) {
      final x = size.width * i / divisions;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var i = 1; i < 7; i++) {
      final y = size.height * i / 7;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    final horizonPaint = Paint()
      ..color = const Color(0x3080C7C2)
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset(0, size.height * .42),
      Offset(size.width, size.height * .42),
      horizonPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LandingHowSection extends StatelessWidget {
  const _LandingHowSection({super.key});

  @override
  Widget build(BuildContext context) {
    return _LandingSection(
      title: rf(
        'Reviewable reconstruction results appear on the first screen.',
        '검토 가능한 재구성 결과를 첫 화면에서 바로 보여줍니다',
      ),
      body: rf(
        'The scan line compares a live 3D room model against the source photo, so users can verify candidate geometry before accepting the room.',
        '스캔 라인은 실시간 3D 공간과 원본 사진을 비교합니다. 사용자는 후보 geometry가 실제 방과 얼마나 잘 맞는지 확인한 뒤 공간을 확정할 수 있습니다.',
      ),
    );
  }
}

class _LandingFeatureSection extends StatelessWidget {
  const _LandingFeatureSection({super.key});

  @override
  Widget build(BuildContext context) {
    final features = [
      (
        number: '01',
        icon: Icons.camera_alt_outlined,
        title: rf('Candidate geometry extraction', '후보 geometry 추출'),
        body: rf(
          'Walls, floor, doors, windows, and furniture candidates stay reviewable in source image coordinates.',
          '벽, 바닥, 문, 창문, 가구 후보를 원본 이미지 좌표로 분리해 사용자가 검토할 수 있게 만듭니다.',
        ),
      ),
      (
        number: '02',
        icon: Icons.grid_on_outlined,
        title: rf('Meter scale calibration', '미터 스케일 보정'),
        body: rf(
          'A confirmed reference length converts pixels into meter-space placement surfaces.',
          '확인된 기준 길이를 바탕으로 픽셀 좌표를 실제 미터 좌표로 전환하고 배치 가능한 평면을 만듭니다.',
        ),
      ),
      (
        number: '03',
        icon: Icons.layers_outlined,
        title: rf('2D and 3D placement', '2D와 3D 배치'),
        body: rf(
          'Move, rotate, resize, and save proxy furniture on top of the confirmed room.',
          '확정된 공간 위에서 프록시 가구를 이동, 회전, 크기 조정하고 저장 가능한 layout 상태로 이어갑니다.',
        ),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 76, 28, 88),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _LandingSectionHeader(
                title: rf(
                  'Photos, coordinates, and furniture become one space model.',
                  '사진, 좌표, 가구 배치가 하나의 공간 모델로 이어집니다',
                ),
              ),
              const SizedBox(height: 38),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 900;
                  if (compact) {
                    return Column(
                      children: [
                        for (final feature in features) ...[
                          _LandingFeatureCard(feature: feature),
                          if (feature != features.last)
                            const SizedBox(height: 12),
                        ],
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final feature in features) ...[
                        Expanded(child: _LandingFeatureCard(feature: feature)),
                        if (feature != features.last) const SizedBox(width: 12),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LandingSection extends StatelessWidget {
  const _LandingSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 88, 28, 0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _roomForgeBorder)),
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LandingSectionHeader(title: title),
                  const SizedBox(height: 16),
                  Text(
                    body,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: _roomForgeInkSoft,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LandingSectionHeader extends StatelessWidget {
  const _LandingSectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.displaySmall?.copyWith(
        color: _roomForgeInk,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
    );
  }
}

class _LandingFeatureCard extends StatefulWidget {
  const _LandingFeatureCard({required this.feature});

  final ({String number, IconData icon, String title, String body}) feature;

  @override
  State<_LandingFeatureCard> createState() => _LandingFeatureCardState();
}

class _LandingFeatureCardState extends State<_LandingFeatureCard> {
  bool _hovered = false;
  double _tiltX = 0;
  double _tiltY = 0;

  void _updateTilt(PointerEvent event, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }
    final x = event.localPosition.dx / size.width;
    final y = event.localPosition.dy / size.height;
    final nextTiltX = (x - .5) * 3.2;
    final nextTiltY = (.5 - y) * 2.8;
    if ((nextTiltX - _tiltX).abs() < .18 && (nextTiltY - _tiltY).abs() < .18) {
      return;
    }
    setState(() {
      _tiltX = nextTiltX;
      _tiltY = nextTiltY;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduce = MediaQuery.of(context).disableAnimations;
    final matrix = Matrix4.identity()..setEntry(3, 2, .0011);
    if (!reduce) {
      matrix
        ..rotateX(_tiltY * math.pi / 180)
        ..rotateY(_tiltX * math.pi / 180);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 360.0;
        return MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onHover: (event) => _updateTilt(
            event,
            Size(width, math.max(236, constraints.maxHeight)),
          ),
          onExit: (_) => setState(() {
            _hovered = false;
            _tiltX = 0;
            _tiltY = 0;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            transform: matrix,
            transformAlignment: Alignment.center,
            constraints: const BoxConstraints(minHeight: 236),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: _hovered ? .10 : .08),
                  Colors.transparent,
                  Colors.white.withValues(alpha: .02),
                ],
                stops: const [0, .42, 1],
              ),
              border: Border.all(
                color: _hovered ? _roomForgeBorderStrong : _roomForgeBorder,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 620),
                    curve: Curves.easeOutCubic,
                    left: _hovered ? width : -width,
                    top: 0,
                    bottom: 0,
                    width: width,
                    child: IgnorePointer(
                      child: Transform.rotate(
                        angle: -18 * math.pi / 180,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.white.withValues(alpha: .10),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.feature.number,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: _roomForgeSubtle,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 42),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .06),
                            border: Border.all(color: _roomForgeBorder),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SizedBox(
                            width: 42,
                            height: 42,
                            child: Icon(
                              widget.feature.icon,
                              color: Colors.white,
                              size: 21,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.feature.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: _roomForgeInk,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          widget.feature.body,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: _roomForgeInkSoft,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LandingFinalCta extends StatelessWidget {
  const _LandingFinalCta({required this.isSigningIn, required this.onSignIn});

  final bool isSigningIn;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 92, 28, 108),
      child: Column(
        children: [
          Text(
            rf(
              'The shortest path from photo to space model.',
              '사진을 공간 모델로 바꾸는 가장 짧은 경로',
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              color: _roomForgeInk,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            rf(
              'RoomForge connects reconstruction, review, and placement in one screen flow.',
              'RoomForge는 방 재구성, 검토, 배치를 한 화면 흐름으로 묶어 실제 공간 의사결정에 바로 사용할 수 있게 합니다.',
            ),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: _roomForgeInkSoft),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: isSigningIn ? null : onSignIn,
            icon: isSigningIn
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_forward),
            label: Text(
              isSigningIn
                  ? rf('Signing in...', '로그인 중...')
                  : rf('Start free', '무료로 시작하기'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingFooter extends StatelessWidget {
  const _LandingFooter();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _roomForgeBorder)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          '© RoomForge · 사진이 방이 되는 순간',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: _roomForgeSubtle,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _RoomForgeTopbarBrand extends StatelessWidget {
  const _RoomForgeTopbarBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _RoomForgeBrandMark(size: 30),
        const SizedBox(width: 10),
        Text(
          'RoomForge',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: _roomForgeInk,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _RoomForgeBrandMark extends StatelessWidget {
  const _RoomForgeBrandMark({this.size = 30});

  final double size;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _roomForgePaper,
            Color(0xFF172235),
            Color(0xFF294642),
            _roomForgeSelected,
          ],
          stops: [0, .46, .74, 1],
        ),
        border: Border.all(color: Color(0x5CDCE8FF)),
      ),
      child: SizedBox(width: size, height: size),
    );
  }
}

class _RoomForgeAppBackground extends StatelessWidget {
  const _RoomForgeAppBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: _roomForgePaper,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x140F3D82),
            _roomForgePaper,
            _roomForgePaper,
            Color(0x0E2A6A66),
          ],
          stops: [0, .24, .76, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [const _RoomForgeGridBackdrop(), child],
      ),
    );
  }
}

class _RoomForgeGridBackdrop extends StatelessWidget {
  const _RoomForgeGridBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: CustomPaint(painter: _RoomForgeGridPainter()));
  }
}

class _RoomForgeGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x145E7A92)
      ..strokeWidth = 1;
    const step = 92.0;
    for (var x = 0.0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class RoomForgePanel extends StatelessWidget {
  const RoomForgePanel({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderColor = _roomForgeBorder,
    this.backgroundColor = _roomForgePanel,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color borderColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x52000000),
            blurRadius: 34,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class RoomForgeStatusPill extends StatelessWidget {
  const RoomForgeStatusPill({
    required this.label,
    this.icon,
    this.color = _roomForgePrimary,
    this.dense = false,
    super.key,
  });

  final String label;
  final IconData? icon;
  final Color color;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w700);

    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        border: Border.all(color: color.withValues(alpha: 0.34)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon == null
              ? Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(99),
                  ),
                )
              : Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(child: Text(label, style: textStyle)),
        ],
      ),
    );
  }
}

class RoomForgeNotice extends StatelessWidget {
  const RoomForgeNotice({
    required this.title,
    required this.message,
    this.icon = Icons.info_outline,
    this.severity = NoticeSeverity.info,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;
  final NoticeSeverity severity;

  @override
  Widget build(BuildContext context) {
    final color = switch (severity) {
      NoticeSeverity.success => _roomForgeSuccess,
      NoticeSeverity.warning => _roomForgeWarning,
      NoticeSeverity.error => _roomForgeError,
      NoticeSeverity.info => _roomForgePrimary,
    };
    final theme = Theme.of(context);

    return Semantics(
      liveRegion: severity == NoticeSeverity.error,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          border: Border.all(color: color.withValues(alpha: 0.32)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: _roomForgeInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _roomForgeInk,
                        height: 1.4,
                      ),
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

enum NoticeSeverity { info, success, warning, error }

class RoomForgeEmptyState extends StatelessWidget {
  const RoomForgeEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RoomForgePanel(
      child: Semantics(
        container: true,
        label: '$title. $message',
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RoomForgeStatusPill(
                  label: rf('empty', 'empty'),
                  color: _roomForgeAdmin,
                  icon: Icons.info_outline,
                  dense: true,
                ),
                const SizedBox(height: 12),
                Icon(icon, size: 36, color: _roomForgeMuted),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _roomForgeMuted,
                  ),
                ),
                if (action != null) ...[const SizedBox(height: 16), action!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RoomForgeLoadingState extends StatelessWidget {
  const RoomForgeLoadingState({
    required this.title,
    required this.message,
    this.panel = true,
    super.key,
  });

  final String title;
  final String message;
  final bool panel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Semantics(
      container: true,
      liveRegion: true,
      label: '$title. $message',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              RoomForgeStatusPill(
                label: rf('loading', 'loading'),
                color: _roomForgeSave,
                icon: Icons.hourglass_top_outlined,
                dense: true,
              ),
              const Spacer(),
              Text(
                rf('please wait', '잠시만 기다려 주세요'),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: _roomForgeMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
          const SizedBox(height: 12),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: _roomForgeInk,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: _roomForgeMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          const _RoomForgeSkeletonLine(widthFactor: .82),
          const SizedBox(height: 8),
          const _RoomForgeSkeletonLine(widthFactor: .56),
        ],
      ),
    );

    if (!panel) {
      return content;
    }
    return RoomForgePanel(child: content);
  }
}

class _RoomForgeSkeletonLine extends StatelessWidget {
  const _RoomForgeSkeletonLine({required this.widthFactor});

  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _roomForgeBorderStrong.withValues(alpha: 0.74),
          borderRadius: BorderRadius.circular(99),
        ),
        child: const SizedBox(height: 12),
      ),
    );
  }
}

class RoomForgeMetricTile extends StatelessWidget {
  const RoomForgeMetricTile({
    required this.label,
    required this.value,
    this.icon,
    this.color = _roomForgePrimary,
    super.key,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RoomForgePanel(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: _roomForgeMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: _roomForgeInk,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RoomForgeSectionHeader extends StatelessWidget {
  const RoomForgeSectionHeader({
    required this.title,
    required this.description,
    this.icon,
    super.key,
  });

  final String title;
  final String description;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(icon, color: _roomForgePrimary, size: 22),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: _roomForgeInk,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _roomForgeMuted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProjectWorkspaceScreen extends StatelessWidget {
  const _ProjectWorkspaceScreen({
    required this.routeSpec,
    required this.authRepository,
    required this.adminRepository,
    required this.session,
    required this.legacyAdminApi,
    required this.backendMode,
    required this.projectApi,
  });

  final _RoomForgeRouteSpec routeSpec;
  final AuthRepository authRepository;
  final FirebaseAdminRepository adminRepository;
  final AuthSession session;
  final AdminApi? legacyAdminApi;
  final BackendMode backendMode;
  final ProjectApi projectApi;

  @override
  Widget build(BuildContext context) {
    final displayName =
        session.displayName ?? session.email ?? 'signed-in user';
    final compactTopbar = MediaQuery.sizeOf(context).width < 720;

    return Scaffold(
      appBar: AppBar(
        title: const _RoomForgeTopbarBrand(),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _roomForgeBorder),
        ),
        actions: [
          _ProductRouteNavActions(routeSpec: routeSpec, compact: compactTopbar),
          AdminRouteGuardButton(
            session: session,
            adminRepository: adminRepository,
            legacyAdminApi: legacyAdminApi,
            backendMode: backendMode,
            onSwitchAccount: authRepository.signOut,
            compact: compactTopbar,
          ),
          if (compactTopbar)
            IconButton(
              tooltip: rf('Sign out', '로그아웃'),
              onPressed: authRepository.signOut,
              icon: const Icon(Icons.logout_outlined),
            )
          else
            TextButton(
              onPressed: authRepository.signOut,
              child: Text(rf('Sign out', '로그아웃')),
            ),
        ],
      ),
      body: _RoomForgeAppBackground(
        child: _RoomForgeProductRouteScreen(
          routeSpec: routeSpec,
          displayName: displayName,
          projectApi: projectApi,
        ),
      ),
    );
  }
}

class _ProductRouteNavActions extends StatelessWidget {
  const _ProductRouteNavActions({
    required this.routeSpec,
    required this.compact,
  });

  final _RoomForgeRouteSpec routeSpec;
  final bool compact;

  void _go(BuildContext context, String route) {
    if (routeSpec.location == route) {
      return;
    }
    Navigator.of(context).pushNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: rf('Home', '메인'),
            onPressed: () => _go(context, routeSpec.productRootPath),
            icon: Icon(
              Icons.dashboard_outlined,
              color: routeSpec.isHome ? _roomForgePrimary : null,
            ),
          ),
          IconButton(
            tooltip: rf('My projects', '내 프로젝트'),
            onPressed: () => _go(context, routeSpec.projectsPath),
            icon: Icon(
              Icons.folder_copy_outlined,
              color: routeSpec.isProjects ? _roomForgePrimary : null,
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          onPressed: () => _go(context, routeSpec.productRootPath),
          icon: const Icon(Icons.dashboard_outlined),
          label: Text(rf('Main', '메인')),
          style: TextButton.styleFrom(
            foregroundColor: routeSpec.isHome
                ? _roomForgePrimary
                : _roomForgeInkSoft,
          ),
        ),
        TextButton.icon(
          onPressed: () => _go(context, routeSpec.projectsPath),
          icon: const Icon(Icons.folder_copy_outlined),
          label: Text(rf('My projects', '내 프로젝트')),
          style: TextButton.styleFrom(
            foregroundColor: routeSpec.isProjects
                ? _roomForgePrimary
                : _roomForgeInkSoft,
          ),
        ),
      ],
    );
  }
}

class _RoomForgeProductRouteScreen extends StatelessWidget {
  const _RoomForgeProductRouteScreen({
    required this.routeSpec,
    required this.displayName,
    required this.projectApi,
  });

  final _RoomForgeRouteSpec routeSpec;
  final String displayName;
  final ProjectApi projectApi;

  @override
  Widget build(BuildContext context) {
    final projectId = routeSpec.projectId;
    if (projectId != null) {
      return _WorkspaceScreen(
        routeSpec: routeSpec,
        displayName: displayName,
        projectApi: projectApi,
        projectId: projectId,
      );
    }

    if (routeSpec.isProjects) {
      return _ProjectsScreen(
        routeSpec: routeSpec,
        displayName: displayName,
        projectApi: projectApi,
      );
    }

    return _AppHomeScreen(
      routeSpec: routeSpec,
      displayName: displayName,
      projectApi: projectApi,
    );
  }
}

class _AppHomeScreen extends StatefulWidget {
  const _AppHomeScreen({
    required this.routeSpec,
    required this.displayName,
    required this.projectApi,
  });

  final _RoomForgeRouteSpec routeSpec;
  final String displayName;
  final ProjectApi projectApi;

  @override
  State<_AppHomeScreen> createState() => _AppHomeScreenState();
}

class _AppHomeScreenState extends State<_AppHomeScreen> {
  bool _isCreating = false;
  String? _message;
  NoticeSeverity _severity = NoticeSeverity.info;

  Future<void> _createProject() async {
    if (_isCreating) {
      return;
    }
    final result = await showDialog<_ProjectDraft>(
      context: context,
      builder: (context) => const ProjectEditorDialog(),
    );
    if (result == null) {
      return;
    }

    setState(() {
      _isCreating = true;
      _message = null;
    });

    try {
      final created = await widget.projectApi.createProject(
        name: result.name,
        description: result.description,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(
        context,
      ).pushNamed(widget.routeSpec.workspacePath(created.id));
    } on ProjectApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = '${rf('Create failed', '생성 실패')}: ${error.message}';
        _severity = NoticeSeverity.error;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = '${rf('Create failed', '생성 실패')}: $error';
        _severity = NoticeSeverity.error;
      });
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  void _openProjects() {
    Navigator.of(context).pushNamed(widget.routeSpec.projectsPath);
  }

  @override
  Widget build(BuildContext context) {
    return _AuthenticatedLandingBody(
      routeSpec: widget.routeSpec,
      displayName: widget.displayName,
      isCreating: _isCreating,
      message: _message,
      severity: _severity,
      onCreateProject: _createProject,
      onOpenProjects: _openProjects,
    );
  }
}

class _AuthenticatedLandingBody extends StatelessWidget {
  const _AuthenticatedLandingBody({
    required this.routeSpec,
    required this.displayName,
    required this.isCreating,
    required this.onCreateProject,
    required this.onOpenProjects,
    required this.severity,
    this.message,
  });

  final _RoomForgeRouteSpec routeSpec;
  final String displayName;
  final bool isCreating;
  final VoidCallback onCreateProject;
  final VoidCallback onOpenProjects;
  final NoticeSeverity severity;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 900;
          final sidePadding = compact ? 18.0 : 28.0;

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              sidePadding,
              compact ? 20 : 32,
              sidePadding,
              36,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1220),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(
                      builder: (context, heroConstraints) {
                        final heroCompact = heroConstraints.maxWidth < 940;
                        final titleBlock = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                RoomForgeStatusPill(
                                  label: rf('Signed in', '로그인됨'),
                                  color: _roomForgeSave,
                                  icon: Icons.verified_user_outlined,
                                  dense: true,
                                ),
                                RoomForgeStatusPill(
                                  label: routeSpec.isMobile
                                      ? rf('Mobile web', '모바일 웹')
                                      : rf('Product home', '제품 홈'),
                                  color: _roomForgeAdmin,
                                  dense: true,
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Text(
                              rf('RoomForge', 'RoomForge'),
                              maxLines: 1,
                              softWrap: false,
                              style: theme.textTheme.displayLarge?.copyWith(
                                color: Colors.white,
                                fontSize: heroCompact ? 64 : 104,
                                height: .9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              rf(
                                'Signed-in landing for reconstruction, review, and space planning.',
                                '재구성, 검토, 공간 배치를 시작하는 로그인 후 메인 화면입니다.',
                              ),
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: _roomForgeInkSoft,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '${rf('Account', '계정')}: $displayName',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: _roomForgeMuted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        );

                        final commandPanel = _AuthenticatedLandingCommandPanel(
                          isCreating: isCreating,
                          onCreateProject: onCreateProject,
                          onOpenProjects: onOpenProjects,
                        );

                        if (heroCompact) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              titleBlock,
                              const SizedBox(height: 18),
                              commandPanel,
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(child: titleBlock),
                            const SizedBox(width: 28),
                            SizedBox(width: 420, child: commandPanel),
                          ],
                        );
                      },
                    ),
                    if (message != null) ...[
                      const SizedBox(height: 16),
                      RoomForgeNotice(
                        title: severity == NoticeSeverity.error
                            ? rf('Project change failed', '프로젝트 변경 실패')
                            : rf('Project updated', '프로젝트 업데이트됨'),
                        message: message!,
                        severity: severity,
                        icon: severity == NoticeSeverity.error
                            ? Icons.error_outline
                            : Icons.check_circle_outline,
                      ),
                    ],
                    const SizedBox(height: 26),
                    const _LandingCompareStage(),
                    const SizedBox(height: 28),
                    _AuthenticatedLandingWorkflow(
                      onCreateProject: onCreateProject,
                      onOpenProjects: onOpenProjects,
                      isCreating: isCreating,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AuthenticatedLandingCommandPanel extends StatelessWidget {
  const _AuthenticatedLandingCommandPanel({
    required this.isCreating,
    required this.onCreateProject,
    required this.onOpenProjects,
  });

  final bool isCreating;
  final VoidCallback onCreateProject;
  final VoidCallback onOpenProjects;

  @override
  Widget build(BuildContext context) {
    return RoomForgePanel(
      padding: const EdgeInsets.all(16),
      backgroundColor: const Color(0xD80B0D0F),
      borderColor: _roomForgeBorderStrong,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            rf('Start from here', '여기서 시작'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: _roomForgeInk,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: isCreating ? null : onCreateProject,
            icon: isCreating
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_home_work_outlined),
            label: Text(
              isCreating
                  ? rf('Creating...', '생성 중...')
                  : rf('Create new space', '새 공간 만들기'),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onOpenProjects,
            icon: const Icon(Icons.folder_copy_outlined),
            label: Text(rf('View my projects', '내 프로젝트 보기')),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              RoomForgeStatusPill(
                label: rf('Photo', '사진'),
                color: _roomForgePrimary,
                dense: true,
              ),
              RoomForgeStatusPill(
                label: rf('CV review', 'CV 검토'),
                color: _roomForgeMeasure,
                dense: true,
              ),
              RoomForgeStatusPill(
                label: rf('3D layout', '3D 배치'),
                color: _roomForgeSuccess,
                dense: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AuthenticatedLandingWorkflow extends StatelessWidget {
  const _AuthenticatedLandingWorkflow({
    required this.onCreateProject,
    required this.onOpenProjects,
    required this.isCreating,
  });

  final VoidCallback onCreateProject;
  final VoidCallback onOpenProjects;
  final bool isCreating;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 820;
        final tiles = [
          _AuthenticatedLandingAction(
            label: rf('New space', '새 공간'),
            detail: rf('Photo and dimensions', '사진과 치수 입력'),
            icon: Icons.add_home_work_outlined,
            color: _roomForgePrimary,
            onTap: isCreating ? null : onCreateProject,
          ),
          _AuthenticatedLandingAction(
            label: rf('My projects', '내 프로젝트'),
            detail: rf('Saved room work', '저장된 방 작업'),
            icon: Icons.folder_copy_outlined,
            color: _roomForgeSave,
            onTap: onOpenProjects,
          ),
          _AuthenticatedLandingAction(
            label: rf('Review flow', '검토 흐름'),
            detail: rf('Source, CV, model', '원본, CV, 모델'),
            icon: Icons.compare_arrows_outlined,
            color: _roomForgeMeasure,
            onTap: onCreateProject,
          ),
        ];

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final tile in tiles) ...[
                tile,
                if (tile != tiles.last) const SizedBox(height: 10),
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final tile in tiles) ...[
              Expanded(child: tile),
              if (tile != tiles.last) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }
}

class _AuthenticatedLandingAction extends StatefulWidget {
  const _AuthenticatedLandingAction({
    required this.label,
    required this.detail,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String detail;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  State<_AuthenticatedLandingAction> createState() =>
      _AuthenticatedLandingActionState();
}

class _AuthenticatedLandingActionState
    extends State<_AuthenticatedLandingAction> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = widget.onTap != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(
          0,
          _hovered && enabled ? -2 : 0,
          0,
        ),
        child: Material(
          color: _roomForgePanel.withValues(alpha: enabled ? 1 : .62),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: _hovered && enabled
                  ? widget.color.withValues(alpha: .54)
                  : _roomForgeBorder,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: widget.color.withValues(
                        alpha: _hovered && enabled ? .20 : .12,
                      ),
                      border: Border.all(
                        color: widget.color.withValues(alpha: .36),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(widget.icon, color: widget.color, size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: _roomForgeInk,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _roomForgeMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward,
                    size: 18,
                    color: _hovered && enabled ? widget.color : _roomForgeMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectsScreen extends StatelessWidget {
  const _ProjectsScreen({
    required this.routeSpec,
    required this.displayName,
    required this.projectApi,
  });

  final _RoomForgeRouteSpec routeSpec;
  final String displayName;
  final ProjectApi projectApi;

  @override
  Widget build(BuildContext context) {
    return _ProjectWorkspaceBody(
      routeSpec: routeSpec,
      routeMode: _ProjectWorkspaceRouteMode.projects,
      title: rf('My projects', '내 프로젝트'),
      routeLabel: rf('My projects', '내 프로젝트'),
      displayName: displayName,
      projectApi: projectApi,
    );
  }
}

class _WorkspaceScreen extends StatelessWidget {
  const _WorkspaceScreen({
    required this.routeSpec,
    required this.displayName,
    required this.projectApi,
    required this.projectId,
  });

  final _RoomForgeRouteSpec routeSpec;
  final String displayName;
  final ProjectApi projectApi;
  final String projectId;

  @override
  Widget build(BuildContext context) {
    return _ProjectWorkspaceBody(
      routeSpec: routeSpec,
      routeMode: _ProjectWorkspaceRouteMode.workspace,
      initialProjectId: projectId,
      title: _workspaceRouteTitle(routeSpec),
      routeLabel: _workspaceRouteLabel(routeSpec),
      displayName: displayName,
      projectApi: projectApi,
    );
  }
}

String _workspaceRouteTitle(_RoomForgeRouteSpec routeSpec) {
  if (!routeSpec.isMobile) {
    return rf('Workspace', '워크스페이스');
  }
  return switch (routeSpec.section) {
    'capture' => rf('Capture workspace', '촬영 워크스페이스'),
    'status' => rf('Reconstruction status', '재구성 상태'),
    'review' => rf('Review handoff', '검토 핸드오프'),
    _ => rf('Mobile workspace', '모바일 워크스페이스'),
  };
}

String _workspaceRouteLabel(_RoomForgeRouteSpec routeSpec) {
  if (!routeSpec.isMobile) {
    return rf('Workspace', '워크스페이스');
  }
  return switch (routeSpec.section) {
    'capture' => rf('Capture', '촬영'),
    'status' => rf('Status', '상태'),
    'review' => rf('Review', '검토'),
    _ => rf('Mobile', '모바일'),
  };
}

class AdminRouteGuardButton extends StatefulWidget {
  const AdminRouteGuardButton({
    required this.session,
    required this.adminRepository,
    required this.legacyAdminApi,
    required this.backendMode,
    required this.onSwitchAccount,
    this.compact = false,
    super.key,
  });

  final AuthSession session;
  final FirebaseAdminRepository adminRepository;
  final AdminApi? legacyAdminApi;
  final BackendMode backendMode;
  final Future<void> Function() onSwitchAccount;
  final bool compact;

  @override
  State<AdminRouteGuardButton> createState() => _AdminRouteGuardButtonState();
}

class _AdminRouteGuardButtonState extends State<AdminRouteGuardButton> {
  bool _isChecking = false;

  Future<void> _openAdmin() async {
    if (_isChecking) {
      return;
    }

    var shouldOpenAdmin = false;
    var shouldRetry = false;
    var shouldSwitchAccount = false;

    setState(() => _isChecking = true);

    try {
      if (widget.backendMode == BackendMode.legacyApi) {
        await _openLegacyAdmin();
        return;
      }

      final action = await showDialog<_AdminRouteGuardDialogAction>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _AdminRouteGuardDialog(
          check: _checkFirebaseAdminAccess(),
          accountLabel:
              widget.session.email ??
              widget.session.displayName ??
              rf('signed-in account', '로그인 계정'),
        ),
      );
      if (!mounted) {
        return;
      }

      shouldOpenAdmin = action == _AdminRouteGuardDialogAction.openAdmin;
      shouldRetry = action == _AdminRouteGuardDialogAction.retry;
      shouldSwitchAccount =
          action == _AdminRouteGuardDialogAction.switchAccount;
    } on AdminApiException catch (error) {
      if (!mounted) {
        return;
      }
      final message = error.code == 'unauthorized'
          ? rf('Admin role required.', '관리자 권한이 필요합니다.')
          : error.message;
      _showSnackBar(message);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(
        rf(
          'Admin role could not be refreshed. Try again.',
          '관리자 권한을 새로고침하지 못했습니다. 다시 시도하세요.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }

    if (!mounted) {
      return;
    }
    if (shouldOpenAdmin) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => _FirebaseAdminDiagnosticsScreen(
            routeSpec: _RoomForgeRouteSpec.fromLocation('/admin'),
            session: widget.session,
            adminRepository: widget.adminRepository,
          ),
        ),
      );
      return;
    }
    if (shouldSwitchAccount) {
      await widget.onSwitchAccount();
      return;
    }
    if (shouldRetry) {
      unawaited(_openAdmin());
    }
  }

  Future<_AdminRouteGuardCheckResult> _checkFirebaseAdminAccess() async {
    try {
      final isAdmin = await widget.adminRepository.isCurrentUserAdmin(
        widget.session,
      );
      if (isAdmin) {
        return _AdminRouteGuardCheckResult.allowed();
      }
      return _AdminRouteGuardCheckResult.denied();
    } on AdminApiException catch (error) {
      if (error.code == 'unauthorized') {
        return _AdminRouteGuardCheckResult.denied();
      }
      return _AdminRouteGuardCheckResult.staleRole();
    } catch (_) {
      return _AdminRouteGuardCheckResult.staleRole();
    }
  }

  Future<void> _openLegacyAdmin() async {
    final adminApi = widget.legacyAdminApi;
    if (adminApi == null) {
      _showSnackBar(
        rf('Legacy admin API is not configured.', '레거시 관리자 API가 설정되지 않았습니다.'),
      );
      return;
    }

    final adminSession = await adminApi.loadSession();
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            AdminShellScreen(session: adminSession, adminApi: adminApi),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: rf('Refresh role', '권한 새로고침'),
          onPressed: _openAdmin,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return IconButton(
        tooltip: _isChecking
            ? rf('Checking admin role...', '관리자 권한 확인 중...')
            : rf('Admin', '관리자'),
        onPressed: _isChecking ? null : _openAdmin,
        icon: _isChecking
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.admin_panel_settings_outlined),
      );
    }

    return TextButton.icon(
      onPressed: _isChecking ? null : _openAdmin,
      icon: _isChecking
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.admin_panel_settings_outlined),
      label: Text(
        _isChecking ? rf('Checking role...', '권한 확인 중...') : rf('Admin', '관리자'),
      ),
    );
  }
}

enum _AdminRouteGuardDialogAction { openAdmin, retry, switchAccount, dismiss }

enum _AdminRouteGuardState { checking, denied, staleRole }

class _AdminRouteGuardCheckResult {
  const _AdminRouteGuardCheckResult({
    required this.state,
    required this.allowed,
  });

  factory _AdminRouteGuardCheckResult.allowed() =>
      const _AdminRouteGuardCheckResult(
        state: _AdminRouteGuardState.checking,
        allowed: true,
      );

  factory _AdminRouteGuardCheckResult.denied() =>
      const _AdminRouteGuardCheckResult(
        state: _AdminRouteGuardState.denied,
        allowed: false,
      );

  factory _AdminRouteGuardCheckResult.staleRole() =>
      const _AdminRouteGuardCheckResult(
        state: _AdminRouteGuardState.staleRole,
        allowed: false,
      );

  final _AdminRouteGuardState state;
  final bool allowed;
}

class _AdminRouteGuardDialog extends StatelessWidget {
  const _AdminRouteGuardDialog({
    required this.check,
    required this.accountLabel,
  });

  final Future<_AdminRouteGuardCheckResult> check;
  final String accountLabel;

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width < 560 ? 360.0 : 520.0;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: RoomForgePanel(
          padding: const EdgeInsets.all(18),
          borderColor: _roomForgeBorderStrong,
          backgroundColor: _roomForgePanel,
          child: FutureBuilder<_AdminRouteGuardCheckResult>(
            future: check,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return _AdminRouteGuardPanel(
                  state: _AdminRouteGuardState.checking,
                  accountLabel: accountLabel,
                  showSkeleton: true,
                );
              }

              final result = snapshot.data!;
              if (result.allowed) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(
                      context,
                    ).pop(_AdminRouteGuardDialogAction.openAdmin);
                  }
                });
                return _AdminRouteGuardPanel(
                  state: _AdminRouteGuardState.checking,
                  accountLabel: accountLabel,
                  message: rf(
                    'Admin role confirmed. Opening diagnostics.',
                    '관리자 권한을 확인했습니다. 진단 화면을 여는 중입니다.',
                  ),
                );
              }

              return _AdminRouteGuardPanel(
                state: result.state,
                accountLabel: accountLabel,
                onRetry: () => Navigator.of(
                  context,
                ).pop(_AdminRouteGuardDialogAction.retry),
                onSwitchAccount: () => Navigator.of(
                  context,
                ).pop(_AdminRouteGuardDialogAction.switchAccount),
                onDismiss: () => Navigator.of(
                  context,
                ).pop(_AdminRouteGuardDialogAction.dismiss),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AdminRouteGuardPanel extends StatelessWidget {
  const _AdminRouteGuardPanel({
    required this.state,
    required this.accountLabel,
    this.message,
    this.showSkeleton = false,
    this.onRetry,
    this.onSwitchAccount,
    this.onDismiss,
  });

  final _AdminRouteGuardState state;
  final String accountLabel;
  final String? message;
  final bool showSkeleton;
  final VoidCallback? onRetry;
  final VoidCallback? onSwitchAccount;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _colorForState(state);
    final isChecking = state == _AdminRouteGuardState.checking;
    final title = _titleForState(state);
    final body = message ?? _messageForState(state);

    return Semantics(
      container: true,
      liveRegion: !isChecking,
      label: '$title. $body',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RoomForgeStatusPill(
                label: _chipLabelForState(state),
                color: color,
                icon: isChecking
                    ? Icons.admin_panel_settings_outlined
                    : Icons.privacy_tip_outlined,
                dense: true,
              ),
              const Spacer(),
              if (onDismiss != null)
                IconButton(
                  tooltip: rf('Close', '닫기'),
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: _roomForgeInk,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: _roomForgeInkSoft,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: _roomForgeCanvas,
              border: Border.all(color: color.withValues(alpha: 0.34)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rf('Signed-in account', '로그인 계정'),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: _roomForgeMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    accountLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _roomForgeInk,
                    ),
                  ),
                  if (showSkeleton) ...[
                    const SizedBox(height: 12),
                    const _AdminRouteGuardSkeletonLine(widthFactor: .82),
                    const SizedBox(height: 8),
                    const _AdminRouteGuardSkeletonLine(widthFactor: .56),
                  ],
                ],
              ),
            ),
          ),
          if (!isChecking) ...[
            const SizedBox(height: 12),
            RoomForgeNotice(
              title: _noticeTitleForState(state),
              message: _noticeMessageForState(state),
              severity: state == _AdminRouteGuardState.denied
                  ? NoticeSeverity.error
                  : NoticeSeverity.warning,
              icon: state == _AdminRouteGuardState.denied
                  ? Icons.block_outlined
                  : Icons.update_outlined,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_outlined),
                  label: Text(rf('Check role again', '권한 다시 확인')),
                ),
                OutlinedButton.icon(
                  onPressed: onSwitchAccount,
                  icon: const Icon(Icons.switch_account_outlined),
                  label: Text(rf('Switch account', '계정 전환')),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _colorForState(_AdminRouteGuardState state) {
    return switch (state) {
      _AdminRouteGuardState.checking => _roomForgeSave,
      _AdminRouteGuardState.denied => _roomForgeError,
      _AdminRouteGuardState.staleRole => _roomForgeWarning,
    };
  }

  String _chipLabelForState(_AdminRouteGuardState state) {
    return switch (state) {
      _AdminRouteGuardState.checking => rf('checking', '확인 중'),
      _AdminRouteGuardState.denied => rf('denied', '거부됨'),
      _AdminRouteGuardState.staleRole => rf('stale role', 'stale role'),
    };
  }

  String _titleForState(_AdminRouteGuardState state) {
    return switch (state) {
      _AdminRouteGuardState.checking => rf(
        'Checking admin role',
        '관리자 권한 확인 중',
      ),
      _AdminRouteGuardState.denied => rf('Admin access denied', '접근 권한이 없습니다'),
      _AdminRouteGuardState.staleRole => rf(
        'Role refresh needed',
        '권한 갱신이 필요합니다',
      ),
    };
  }

  String _messageForState(_AdminRouteGuardState state) {
    return switch (state) {
      _AdminRouteGuardState.checking => rf(
        'Verifying the signed-in account before showing operational data.',
        '운영 데이터를 표시하기 전에 로그인 계정의 관리자 역할을 확인하고 있습니다.',
      ),
      _AdminRouteGuardState.denied => rf(
        'Operational data is only available after an admin role is confirmed.',
        '운영 데이터는 관리자 역할이 확인된 계정만 볼 수 있습니다.',
      ),
      _AdminRouteGuardState.staleRole => rf(
        'Your token or role change may not have propagated yet. Refresh the role check before opening admin diagnostics.',
        '토큰 또는 권한 변경이 아직 반영되지 않았을 수 있습니다. 관리자 진단을 열기 전에 권한 확인을 다시 실행하세요.',
      ),
    };
  }

  String _noticeTitleForState(_AdminRouteGuardState state) {
    return switch (state) {
      _AdminRouteGuardState.denied => rf(
        'No sensitive details exposed',
        '민감 정보는 표시하지 않습니다',
      ),
      _ => rf('Stale role notice', '권한 반영 지연 안내'),
    };
  }

  String _noticeMessageForState(_AdminRouteGuardState state) {
    return switch (state) {
      _AdminRouteGuardState.denied => rf(
        'Switch to an admin account or ask an existing admin to update your role.',
        '관리자 계정으로 전환하거나 기존 관리자에게 역할 업데이트를 요청하세요.',
      ),
      _ => rf(
        'If your role changed recently, refresh the check to request a fresh token and role snapshot.',
        '최근 권한이 변경되었다면 새 토큰과 역할 스냅샷을 받도록 권한 확인을 다시 실행하세요.',
      ),
    };
  }
}

class _AdminRouteGuardSkeletonLine extends StatelessWidget {
  const _AdminRouteGuardSkeletonLine({required this.widthFactor});

  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _roomForgeBorderStrong,
          borderRadius: BorderRadius.circular(99),
        ),
        child: const SizedBox(height: 12),
      ),
    );
  }
}

class _FirebaseAdminDiagnosticsScreen extends StatefulWidget {
  const _FirebaseAdminDiagnosticsScreen({
    required this.routeSpec,
    required this.session,
    required this.adminRepository,
  });

  final _RoomForgeRouteSpec routeSpec;
  final AuthSession session;
  final FirebaseAdminRepository adminRepository;

  @override
  State<_FirebaseAdminDiagnosticsScreen> createState() =>
      _FirebaseAdminDiagnosticsScreenState();
}

class _FirebaseAdminDiagnosticsScreenState
    extends State<_FirebaseAdminDiagnosticsScreen> {
  final _adminSearchController = TextEditingController();
  FirebaseJobStatus _statusFilter = FirebaseJobStatus.failed;
  FirebaseReconstructionJob? _selectedJob;
  FirebaseAdminDiagnosticsSearchField _adminSearchField =
      FirebaseAdminDiagnosticsSearchField.jobId;
  String? _activeSearchLabel;
  late Stream<List<FirebaseReconstructionJob>> _jobsStream;

  @override
  void initState() {
    super.initState();
    _configureRouteState(resetSelection: true);
  }

  @override
  void didUpdateWidget(covariant _FirebaseAdminDiagnosticsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.routeSpec.location != widget.routeSpec.location) {
      _configureRouteState(resetSelection: true);
    }
  }

  void _configureRouteState({required bool resetSelection}) {
    final routeJobId = widget.routeSpec.adminJobId;
    if (routeJobId != null) {
      _adminSearchController.text = routeJobId;
      _adminSearchField = FirebaseAdminDiagnosticsSearchField.jobId;
      _activeSearchLabel =
          '${_localizedAdminSearchFieldLabel(_adminSearchField)}: $routeJobId';
      _jobsStream = widget.adminRepository.watchJobs(
        FirebaseAdminJobQuery(jobId: routeJobId, limit: 1),
      );
      if (resetSelection) {
        _selectedJob = null;
      }
      return;
    }

    _adminSearchController.clear();
    _activeSearchLabel = null;
    _statusFilter = widget.routeSpec.isAdminRetries
        ? FirebaseJobStatus.failed
        : _statusFilter;
    _jobsStream = widget.adminRepository.watchJobsByStatus(_statusFilter);
    if (resetSelection) {
      _selectedJob = null;
    }
  }

  void _setStatusFilter(FirebaseJobStatus? status) {
    if (status == null) {
      return;
    }
    setState(() {
      _statusFilter = status;
      _selectedJob = null;
      _activeSearchLabel = null;
      _jobsStream = widget.adminRepository.watchJobsByStatus(status);
    });
    if (widget.routeSpec.adminJobId != null) {
      _goToAdminRoute(widget.routeSpec.adminJobsPath);
    }
  }

  void _setAdminSearchField(FirebaseAdminDiagnosticsSearchField? field) {
    if (field == null) {
      return;
    }
    setState(() => _adminSearchField = field);
  }

  void _searchAdminJobs() {
    final value = _adminSearchController.text.trim();
    if (value.isEmpty) {
      return;
    }
    final query = switch (_adminSearchField) {
      FirebaseAdminDiagnosticsSearchField.ownerUid => FirebaseAdminJobQuery(
        ownerUid: value,
      ),
      FirebaseAdminDiagnosticsSearchField.projectId => FirebaseAdminJobQuery(
        projectId: value,
      ),
      _ => FirebaseAdminJobQuery(jobId: value),
    };
    setState(() {
      _selectedJob = null;
      _activeSearchLabel = '${_adminSearchField.label}: $value';
      _jobsStream = widget.adminRepository.watchJobs(query);
    });
    if (_adminSearchField == FirebaseAdminDiagnosticsSearchField.jobId) {
      _goToAdminRoute(widget.routeSpec.adminJobPath(value));
    } else if (!widget.routeSpec.isAdminJobs) {
      _goToAdminRoute(widget.routeSpec.adminJobsPath);
    }
  }

  void _clearAdminSearch() {
    _adminSearchController.clear();
    setState(() {
      _selectedJob = null;
      _activeSearchLabel = null;
      _jobsStream = widget.adminRepository.watchJobsByStatus(_statusFilter);
    });
    if (widget.routeSpec.adminJobId != null || widget.routeSpec.isAdminAudit) {
      _goToAdminRoute(widget.routeSpec.adminJobsPath);
    }
  }

  void _selectAdminJob(FirebaseReconstructionJob job) {
    setState(() => _selectedJob = job);
    _goToAdminRoute(widget.routeSpec.adminJobPath(job.jobId));
  }

  void _goToAdminRoute(String route) {
    if (route == widget.routeSpec.location) {
      return;
    }
    Navigator.of(context).pushNamed(route);
  }

  FirebaseReconstructionJob? _selectedJobForRoute(
    List<FirebaseReconstructionJob> jobs,
    _RoomForgeRouteSpec routeSpec,
  ) {
    final routeJobId = routeSpec.adminJobId;
    if (routeJobId != null) {
      for (final job in jobs) {
        if (job.jobId == routeJobId) {
          return job;
        }
      }
      return null;
    }
    return _selectedJob;
  }

  @override
  void dispose() {
    _adminSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayName =
        widget.session.displayName ??
        widget.session.email ??
        widget.session.uid;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_adminRouteTitle(widget.routeSpec))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rf('Firebase operations', 'Firebase 운영'),
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: _roomForgeInk,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${rf('Signed in as', '로그인 계정')}: $displayName',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: _roomForgeMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      RoomForgeStatusPill(
                        icon: Icons.admin_panel_settings_outlined,
                        label: rf('Admin access', '관리자 권한'),
                        color: _roomForgeMuted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _FirebaseAdminRouteActions(
                    routeSpec: widget.routeSpec,
                    activeJobId: widget.routeSpec.adminJobId,
                    onNavigate: _goToAdminRoute,
                  ),
                  const SizedBox(height: 12),
                  _FirebaseAdminStatusFilters(
                    selectedStatus: _statusFilter,
                    onChanged: _setStatusFilter,
                  ),
                  const SizedBox(height: 12),
                  RoomForgePanel(
                    padding: const EdgeInsets.all(14),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 720;
                        final fieldPicker =
                            DropdownButtonFormField<
                              FirebaseAdminDiagnosticsSearchField
                            >(
                              value: _adminSearchField,
                              decoration: InputDecoration(
                                labelText: rf('Search field', '검색 필드'),
                                prefixIcon: const Icon(
                                  Icons.manage_search_outlined,
                                ),
                              ),
                              items: [
                                for (final field
                                    in FirebaseAdminDiagnosticsSearchField
                                        .values)
                                  DropdownMenuItem(
                                    value: field,
                                    child: Text(
                                      _localizedAdminSearchFieldLabel(field),
                                    ),
                                  ),
                              ],
                              onChanged: _setAdminSearchField,
                            );
                        final queryInput = Semantics(
                          container: true,
                          textField: true,
                          label: FirebaseAdminDiagnosticsUiText
                              .exactLookupSemanticsLabel,
                          child: TextField(
                            controller: _adminSearchController,
                            decoration: InputDecoration(
                              labelText: rf('Exact admin lookup', '정확한 관리자 조회'),
                              hintText: rf(
                                'Paste job, project, or user id',
                                '작업, 프로젝트, 사용자 ID를 붙여넣기',
                              ),
                            ),
                            onSubmitted: (_) => _searchAdminJobs(),
                          ),
                        );
                        final actions = Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: _searchAdminJobs,
                              icon: const Icon(Icons.search),
                              label: Text(rf('Search', '검색')),
                            ),
                            OutlinedButton.icon(
                              onPressed: _clearAdminSearch,
                              icon: const Icon(Icons.clear),
                              label: Text(rf('Clear', '초기화')),
                            ),
                          ],
                        );

                        if (compact) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              RoomForgeSectionHeader(
                                icon: Icons.manage_search_outlined,
                                title: rf('Global search', '전체 검색'),
                                description: rf(
                                  'Search by exact user, project, or job id without exposing unrelated rows.',
                                  '관련 없는 행을 노출하지 않고 사용자, 프로젝트, 작업 ID를 정확히 검색합니다.',
                                ),
                              ),
                              const SizedBox(height: 12),
                              fieldPicker,
                              const SizedBox(height: 10),
                              queryInput,
                              const SizedBox(height: 10),
                              actions,
                              if (_activeSearchLabel != null) ...[
                                const SizedBox(height: 10),
                                RoomForgeStatusPill(
                                  icon: Icons.search,
                                  label: _activeSearchLabel!,
                                  color: _roomForgeMuted,
                                ),
                              ],
                            ],
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            RoomForgeSectionHeader(
                              icon: Icons.manage_search_outlined,
                              title: rf('Global search', '전체 검색'),
                              description: rf(
                                'Search by exact user, project, or job id without exposing unrelated rows.',
                                '관련 없는 행을 노출하지 않고 사용자, 프로젝트, 작업 ID를 정확히 검색합니다.',
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(width: 190, child: fieldPicker),
                                const SizedBox(width: 10),
                                Expanded(child: queryInput),
                                const SizedBox(width: 10),
                                actions,
                              ],
                            ),
                            if (_activeSearchLabel != null) ...[
                              const SizedBox(height: 10),
                              RoomForgeStatusPill(
                                icon: Icons.search,
                                label: _activeSearchLabel!,
                                color: _roomForgeMuted,
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<List<FirebaseReconstructionJob>>(
                    stream: _jobsStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return RoomForgeLoadingState(
                          title: rf('Loading protected jobs', '보호된 작업을 불러오는 중'),
                          message: rf(
                            FirebaseAdminDiagnosticsUiText
                                .protectedLoadingMessage,
                            '보호된 작업 진단 정보를 불러오는 중...',
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return _FirebaseAdminPermissionRow(
                          error: snapshot.error!,
                        );
                      }
                      final jobs = snapshot.data ?? const [];
                      final selectedJob = _selectedJobForRoute(
                        jobs,
                        widget.routeSpec,
                      );
                      final metrics = _FirebaseAdminDashboardMetrics(
                        jobs: jobs,
                        statusFilter: _statusFilter,
                        activeSearchLabel: _activeSearchLabel,
                      );
                      final jobList = _FirebaseAdminJobList(
                        jobs: jobs,
                        selectedJobId:
                            widget.routeSpec.adminJobId ?? _selectedJob?.jobId,
                        onSelect: _selectAdminJob,
                      );
                      final detail = selectedJob == null
                          ? _FirebaseAdminRouteEmptyDetail(
                              routeSpec: widget.routeSpec,
                            )
                          : _FirebaseAdminJobDetailPanel(
                              job: selectedJob,
                              adminRepository: widget.adminRepository,
                              session: widget.session,
                              focus: _adminDetailFocusForRoute(
                                widget.routeSpec,
                              ),
                            );
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final dashboardBody = constraints.maxWidth < 760
                              ? Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    metrics,
                                    const SizedBox(height: 16),
                                    jobList,
                                    const SizedBox(height: 16),
                                    detail,
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    metrics,
                                    const SizedBox(height: 16),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(flex: 2, child: jobList),
                                        const SizedBox(width: 16),
                                        Expanded(flex: 3, child: detail),
                                      ],
                                    ),
                                  ],
                                );
                          if (constraints.maxWidth < 760) {
                            return dashboardBody;
                          }
                          return dashboardBody;
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _FirebaseAdminDetailFocus { overview, retry, audit }

String _adminRouteTitle(_RoomForgeRouteSpec routeSpec) {
  if (routeSpec.isAdminAudit) {
    return rf('Admin audit', '관리자 감사');
  }
  if (routeSpec.isAdminRetries) {
    return rf('Admin retries', '관리자 재시도');
  }
  if (routeSpec.isAdminJobDetail) {
    return rf('Admin job detail', '관리자 작업 상세');
  }
  if (routeSpec.isAdminJobs) {
    return rf('Admin jobs', '관리자 작업');
  }
  return rf('Admin dashboard', '관리자 대시보드');
}

_FirebaseAdminDetailFocus _adminDetailFocusForRoute(
  _RoomForgeRouteSpec routeSpec,
) {
  if (routeSpec.isAdminAudit) {
    return _FirebaseAdminDetailFocus.audit;
  }
  if (routeSpec.isAdminRetries) {
    return _FirebaseAdminDetailFocus.retry;
  }
  return _FirebaseAdminDetailFocus.overview;
}

class _FirebaseAdminRouteActions extends StatelessWidget {
  const _FirebaseAdminRouteActions({
    required this.routeSpec,
    required this.onNavigate,
    this.activeJobId,
  });

  final _RoomForgeRouteSpec routeSpec;
  final String? activeJobId;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final auditRoute = activeJobId == null
        ? routeSpec.adminAuditPath
        : routeSpec.adminJobPath(activeJobId!, childRoute: 'audit');
    return RoomForgePanel(
      padding: const EdgeInsets.all(10),
      backgroundColor: _roomForgePanel,
      borderColor: _roomForgeBorder,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _FirebaseAdminRouteButton(
            label: rf('Dashboard', '대시보드'),
            icon: Icons.dashboard_outlined,
            active: routeSpec.isAdminDashboard,
            route: routeSpec.adminRootPath,
            onNavigate: onNavigate,
          ),
          _FirebaseAdminRouteButton(
            label: rf('Jobs', '작업'),
            icon: Icons.view_list_outlined,
            active:
                routeSpec.isAdminJobs ||
                (routeSpec.isAdminJobDetail &&
                    !routeSpec.isAdminRetries &&
                    !routeSpec.isAdminAudit),
            route: routeSpec.adminJobsPath,
            onNavigate: onNavigate,
          ),
          _FirebaseAdminRouteButton(
            label: rf('Retries', '재시도'),
            icon: Icons.replay_outlined,
            active: routeSpec.isAdminRetries,
            route: activeJobId == null
                ? routeSpec.adminRetriesPath
                : routeSpec.adminJobPath(activeJobId!, childRoute: 'retry'),
            onNavigate: onNavigate,
          ),
          _FirebaseAdminRouteButton(
            label: rf('Audit', '감사'),
            icon: Icons.fact_check_outlined,
            active: routeSpec.isAdminAudit,
            route: auditRoute,
            onNavigate: onNavigate,
          ),
        ],
      ),
    );
  }
}

class _FirebaseAdminRouteButton extends StatelessWidget {
  const _FirebaseAdminRouteButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.route,
    required this.onNavigate,
  });

  final String label;
  final IconData icon;
  final bool active;
  final String route;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 18), const SizedBox(width: 7), Text(label)],
    );
    if (active) {
      return FilledButton(
        onPressed: null,
        style: FilledButton.styleFrom(
          disabledBackgroundColor: _roomForgeAdmin.withValues(alpha: .24),
          disabledForegroundColor: _roomForgeInk,
          minimumSize: const Size(0, 42),
        ),
        child: content,
      );
    }
    return OutlinedButton(
      onPressed: () => onNavigate(route),
      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
      child: content,
    );
  }
}

class _FirebaseAdminStatusFilters extends StatelessWidget {
  const _FirebaseAdminStatusFilters({
    required this.selectedStatus,
    required this.onChanged,
  });

  final FirebaseJobStatus selectedStatus;
  final ValueChanged<FirebaseJobStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    return RoomForgePanel(
      padding: const EdgeInsets.all(14),
      child: Semantics(
        container: true,
        label: FirebaseAdminDiagnosticsUiText.statusFilterSemanticsLabel,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RoomForgeSectionHeader(
              icon: Icons.filter_alt_outlined,
              title: rf('Status filters', '상태 필터'),
              description: rf(
                'Scan created, processing, Needs review, failed, and timeout jobs quickly.',
                'created, processing, 검토 필요, 실패, 시간 초과 작업을 빠르게 스캔합니다.',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final status in FirebaseJobStatus.values)
                  ChoiceChip(
                    selected: selectedStatus == status,
                    label: Text(_adminStatusLabel(status.wireValue)),
                    avatar: Icon(
                      Icons.circle,
                      size: 10,
                      color: _adminStatusColor(status.wireValue),
                    ),
                    onSelected: (_) => onChanged(status),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FirebaseAdminDashboardMetrics extends StatelessWidget {
  const _FirebaseAdminDashboardMetrics({
    required this.jobs,
    required this.statusFilter,
    required this.activeSearchLabel,
  });

  final List<FirebaseReconstructionJob> jobs;
  final FirebaseJobStatus statusFilter;
  final String? activeSearchLabel;

  @override
  Widget build(BuildContext context) {
    final needsReview = jobs
        .where((job) => job.status == FirebaseJobStatus.reviewRequired)
        .length;
    final failed = jobs
        .where(
          (job) =>
              job.status == FirebaseJobStatus.failed ||
              job.status == FirebaseJobStatus.timeout,
        )
        .length;
    final stateLabel = jobs.isEmpty
        ? rf('empty', 'empty')
        : activeSearchLabel != null
        ? rf('filtered', 'filtered')
        : _adminStatusLabel(statusFilter.wireValue);
    final stateColor = jobs.isEmpty
        ? _roomForgeAdmin
        : activeSearchLabel != null
        ? _roomForgeMeasure
        : _adminStatusColor(statusFilter.wireValue);

    return RoomForgePanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: RoomForgeSectionHeader(
                  icon: Icons.analytics_outlined,
                  title: rf('Operations dashboard', '운영 대시보드'),
                  description: rf(
                    'Visible job volume, review pressure, and failure pressure for the active filter.',
                    '현재 필터의 작업 수, 검토 필요, 실패 압력을 한 번에 확인합니다.',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              RoomForgeStatusPill(
                label: stateLabel,
                color: stateColor,
                icon: Icons.tune_outlined,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 640;
              final cards = [
                _FirebaseAdminMetricCell(
                  value: jobs.length.toString(),
                  label: rf('jobs', '작업'),
                  color: _roomForgeAdmin,
                ),
                _FirebaseAdminMetricCell(
                  value: needsReview.toString(),
                  label: rf('Needs review', '검토 필요'),
                  color: _roomForgeWarning,
                ),
                _FirebaseAdminMetricCell(
                  value: failed.toString(),
                  label: rf('failed or timeout', '실패 또는 시간 초과'),
                  color: _roomForgeError,
                ),
              ];
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final card in cards) ...[
                      card,
                      if (card != cards.last) const SizedBox(height: 8),
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  for (final card in cards) ...[
                    Expanded(child: card),
                    if (card != cards.last) const SizedBox(width: 8),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FirebaseAdminMetricCell extends StatelessWidget {
  const _FirebaseAdminMetricCell({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _roomForgeCanvas,
        border: Border.all(color: color.withValues(alpha: 0.34)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.circle, color: color, size: 12),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: _roomForgeInk,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: _roomForgeMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FirebaseAdminPermissionRow extends StatelessWidget {
  const _FirebaseAdminPermissionRow({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return RoomForgePanel(
      padding: const EdgeInsets.all(14),
      borderColor: _roomForgeError.withValues(alpha: 0.42),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              RoomForgeStatusPill(
                label: rf('permission denied', '권한 거부'),
                color: _roomForgeError,
                icon: Icons.lock_outline,
                dense: true,
              ),
              const Spacer(),
              Text(
                rf('row hidden', '행 숨김'),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: _roomForgeMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          RoomForgeNotice(
            title: rf('Admin query failed', '관리자 조회 실패'),
            message: firebaseAdminSafeErrorMessage(error),
            severity: NoticeSeverity.error,
            icon: Icons.lock_outline,
          ),
        ],
      ),
    );
  }
}

class _FirebaseAdminJobList extends StatelessWidget {
  const _FirebaseAdminJobList({
    required this.jobs,
    required this.selectedJobId,
    required this.onSelect,
  });

  final List<FirebaseReconstructionJob> jobs;
  final String? selectedJobId;
  final ValueChanged<FirebaseReconstructionJob> onSelect;

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) {
      return RoomForgeEmptyState(
        icon: Icons.search_off_outlined,
        title: rf('No matching Firebase jobs', '일치하는 Firebase 작업이 없습니다'),
        message: rf(
          'Change the status filter or wait for a reconstruction job to reach this state.',
          '상태 필터를 바꾸거나 재구성 작업이 이 상태가 될 때까지 기다리세요.',
        ),
      );
    }
    final theme = Theme.of(context);
    return RoomForgePanel(
      padding: EdgeInsets.zero,
      child: Semantics(
        container: true,
        label: FirebaseAdminDiagnosticsUiText.jobListSemanticsLabel,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 640;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          rf('Job table', '작업 테이블'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      RoomForgeStatusPill(
                        icon: Icons.view_list_outlined,
                        label: '${jobs.length} ${rf('rows', '행')}',
                        color: _roomForgeAdmin,
                        dense: true,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                if (!compact) const _FirebaseAdminJobTableHeader(),
                for (final job in jobs) ...[
                  if (compact)
                    _FirebaseAdminJobCompactCard(
                      job: job,
                      selected: job.jobId == selectedJobId,
                      onSelect: () => onSelect(job),
                    )
                  else
                    _FirebaseAdminJobTableRow(
                      job: job,
                      selected: job.jobId == selectedJobId,
                      onSelect: () => onSelect(job),
                    ),
                  const Divider(height: 1),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FirebaseAdminJobTableHeader extends StatelessWidget {
  const _FirebaseAdminJobTableHeader();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: _roomForgeMuted,
      fontWeight: FontWeight.w800,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(rf('Job', '작업'), style: style)),
          Expanded(flex: 2, child: Text(rf('Owner', '소유자'), style: style)),
          Expanded(flex: 2, child: Text(rf('Project', '프로젝트'), style: style)),
          Expanded(flex: 2, child: Text(rf('Status', '상태'), style: style)),
          Expanded(flex: 2, child: Text(rf('Provider', '제공자'), style: style)),
          Expanded(flex: 2, child: Text(rf('Updated', '수정 시각'), style: style)),
          SizedBox(width: 82, child: Text(rf('Action', '액션'), style: style)),
        ],
      ),
    );
  }
}

class _FirebaseAdminJobTableRow extends StatelessWidget {
  const _FirebaseAdminJobTableRow({
    required this.job,
    required this.selected,
    required this.onSelect,
  });

  final FirebaseReconstructionJob job;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rowColor = selected
        ? _roomForgePrimary.withValues(alpha: 0.12)
        : Colors.transparent;
    final valueStyle = theme.textTheme.bodySmall?.copyWith(
      color: _roomForgeInk,
      fontWeight: FontWeight.w600,
    );
    final mutedStyle = theme.textTheme.bodySmall?.copyWith(
      color: _roomForgeMuted,
    );

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: FirebaseAdminDiagnosticsUiText.jobRowAccessibilityLabel(job),
      child: InkWell(
        onTap: onSelect,
        child: DecoratedBox(
          decoration: BoxDecoration(color: rowColor),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    job.jobId,
                    overflow: TextOverflow.ellipsis,
                    style: valueStyle,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    job.ownerUid,
                    overflow: TextOverflow.ellipsis,
                    style: mutedStyle,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    job.projectId,
                    overflow: TextOverflow.ellipsis,
                    style: mutedStyle,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: RoomForgeStatusPill(
                    label: _adminStatusLabel(job.status.wireValue),
                    color: _adminStatusColor(job.status.wireValue),
                    dense: true,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    job.providerType,
                    overflow: TextOverflow.ellipsis,
                    style: mutedStyle,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    _adminTimestampLabel(job.updatedAt),
                    overflow: TextOverflow.ellipsis,
                    style: mutedStyle,
                  ),
                ),
                SizedBox(
                  width: 82,
                  child: TextButton(
                    onPressed: onSelect,
                    child: Text(rf('View', '보기')),
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

class _FirebaseAdminJobCompactCard extends StatelessWidget {
  const _FirebaseAdminJobCompactCard({
    required this.job,
    required this.selected,
    required this.onSelect,
  });

  final FirebaseReconstructionJob job;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: FirebaseAdminDiagnosticsUiText.jobRowAccessibilityLabel(job),
      child: InkWell(
        onTap: onSelect,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected
                ? _roomForgePrimary.withValues(alpha: 0.12)
                : Colors.transparent,
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        job.jobId,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: _roomForgeInk,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    RoomForgeStatusPill(
                      label: _adminStatusLabel(job.status.wireValue),
                      color: _adminStatusColor(job.status.wireValue),
                      dense: true,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${rf('Owner', '소유자')} ${job.ownerUid}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _roomForgeMuted,
                  ),
                ),
                Text(
                  '${rf('Project', '프로젝트')} ${job.projectId}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _roomForgeMuted,
                  ),
                ),
                Text(
                  '${rf('Provider', '제공자')} ${job.providerType}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _roomForgeMuted,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: onSelect,
                  icon: const Icon(Icons.visibility_outlined),
                  label: Text(rf('View job', '작업 보기')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FirebaseAdminRouteEmptyDetail extends StatelessWidget {
  const _FirebaseAdminRouteEmptyDetail({required this.routeSpec});

  final _RoomForgeRouteSpec routeSpec;

  @override
  Widget build(BuildContext context) {
    if (routeSpec.adminJobId != null) {
      return RoomForgeEmptyState(
        icon: Icons.search_off_outlined,
        title: rf('Job not found', '작업을 찾을 수 없습니다'),
        message:
            '${rf('No protected reconstruction job matched this route', '이 route와 일치하는 보호된 재구성 작업이 없습니다')}: ${routeSpec.adminJobId}',
      );
    }
    if (routeSpec.isAdminAudit) {
      return RoomForgeEmptyState(
        icon: Icons.fact_check_outlined,
        title: rf('Select an audit target', '감사 대상을 선택하세요'),
        message: rf(
          'Choose a job first to inspect admin action receipts for that reconstruction job.',
          '재구성 작업의 관리자 action receipt를 확인하려면 먼저 작업을 선택하세요.',
        ),
      );
    }
    return RoomForgeEmptyState(
      icon: Icons.manage_search_outlined,
      title: rf('Select a job', '작업 선택'),
      message: rf(
        'Job metadata, status history, artifacts, OpenCV results, layout references, and retry actions appear here.',
        '작업 메타데이터, 상태 이력, 아티팩트, OpenCV 결과, 레이아웃 참조, 재시도 액션이 여기에 표시됩니다.',
      ),
    );
  }
}

class _FirebaseAdminJobDetailPanel extends StatelessWidget {
  const _FirebaseAdminJobDetailPanel({
    required this.job,
    required this.adminRepository,
    required this.session,
    required this.focus,
  });

  final FirebaseReconstructionJob job;
  final FirebaseAdminRepository adminRepository;
  final AuthSession session;
  final _FirebaseAdminDetailFocus focus;

  @override
  Widget build(BuildContext context) {
    final retryAction = _FirebaseAdminRetryAction(
      job: job,
      adminRepository: adminRepository,
      session: session,
    );
    final auditActions = _FirebaseAdminAuditActions(
      stream: adminRepository.watchAdminActionsForTarget(
        targetType: 'reconstruction_job',
        targetId: job.jobId,
      ),
    );
    final artifactRefs = _FirebaseAdminArtifactRefs(
      artifactRefs: job.artifactRefs,
    );
    final transitions = _FirebaseAdminTransitions(
      stream: adminRepository.watchTransitionsForJob(jobId: job.jobId),
    );
    final results = _FirebaseAdminResults(
      stream: adminRepository.watchResultsForJob(jobId: job.jobId),
    );
    final layouts = _FirebaseAdminLayouts(
      jobId: job.jobId,
      stream: adminRepository.watchLayoutsForJob(jobId: job.jobId),
    );
    final sections = switch (focus) {
      _FirebaseAdminDetailFocus.audit => [
        auditActions,
        retryAction,
        transitions,
        results,
        layouts,
        artifactRefs,
      ],
      _FirebaseAdminDetailFocus.retry => [
        retryAction,
        auditActions,
        transitions,
        results,
        layouts,
        artifactRefs,
      ],
      _FirebaseAdminDetailFocus.overview => [
        retryAction,
        auditActions,
        artifactRefs,
        transitions,
        results,
        layouts,
      ],
    };
    return Semantics(
      container: true,
      label: FirebaseAdminDiagnosticsUiText.jobDetailAccessibilitySummary(job),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FirebaseAdminMetadataHeader(job: job),
          for (final section in sections) ...[
            const SizedBox(height: 12),
            section,
          ],
        ],
      ),
    );
  }
}

class _FirebaseAdminMetadataHeader extends StatelessWidget {
  const _FirebaseAdminMetadataHeader({required this.job});

  final FirebaseReconstructionJob job;

  @override
  Widget build(BuildContext context) {
    final refs = [
      _FirebaseAdminMetadataCell(
        label: rf('Owner', '소유자'),
        value: job.ownerUid,
        icon: Icons.person_outline,
      ),
      _FirebaseAdminMetadataCell(
        label: rf('Project', '프로젝트'),
        value: job.projectId,
        icon: Icons.folder_outlined,
      ),
      _FirebaseAdminMetadataCell(
        label: rf('Job', '작업'),
        value: job.jobId,
        icon: Icons.work_outline,
      ),
      _FirebaseAdminMetadataCell(
        label: rf('Provider', '제공자'),
        value: job.providerType,
        icon: Icons.memory_outlined,
      ),
      _FirebaseAdminMetadataCell(
        label: rf('Attempt', '시도'),
        value: '${job.retryCount + 1}',
        icon: Icons.refresh_outlined,
      ),
      _FirebaseAdminMetadataCell(
        label: rf('Source image', '소스 이미지'),
        value: job.sourceImageId,
        icon: Icons.image_outlined,
      ),
    ];
    final additionalRefs = [
      if (job.providerId != null)
        _FirebaseAdminDetailLine(
          label: rf('Provider ID', '제공자 ID'),
          value: job.providerId!,
        ),
      if (job.algorithmId != null)
        _FirebaseAdminDetailLine(
          label: rf('Algorithm', '알고리즘'),
          value: job.algorithmId!,
        ),
      if (job.openCvVersion != null)
        _FirebaseAdminDetailLine(
          label: rf('OpenCV', 'OpenCV'),
          value: job.openCvVersion!,
        ),
      if (job.qualityStatus != null)
        _FirebaseAdminDetailLine(
          label: rf('Quality', '품질'),
          value: job.qualityStatus!.displayLabel,
        ),
      if (job.latestTransitionId != null)
        _FirebaseAdminDetailLine(
          label: rf('Latest transition', '최근 전환'),
          value: job.latestTransitionId!,
        ),
      _FirebaseAdminDetailLine(
        label: rf('Latest result', '최근 결과'),
        value: job.latestResultId ?? 'not_generated',
      ),
      _FirebaseAdminDetailLine(
        label: rf('Latest geometry', '최근 지오메트리'),
        value: job.latestConfirmedGeometryId ?? 'not_generated',
      ),
      _FirebaseAdminDetailLine(
        label: rf('Latest floor plan', '최근 평면도'),
        value: job.latestFloorPlanId ?? 'not_generated',
      ),
      if (job.failureReasonCode != null)
        _FirebaseAdminDetailLine(
          label: rf('Failure', '실패 사유'),
          value: job.failureReasonCode!,
          color: _roomForgeError,
        ),
      if (job.failureReason != null)
        _FirebaseAdminDetailLine(
          label: rf('Failure detail', '실패 상세'),
          value: job.failureReason!,
          color: _roomForgeError,
        ),
    ];

    return _FirebaseAdminSection(
      title: rf('Metadata header', '메타데이터 헤더'),
      semanticsLabel: FirebaseAdminDiagnosticsUiText.jobDetailSemanticsLabel,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            RoomForgeStatusPill(
              label: _adminStatusLabel(job.status.wireValue),
              color: _adminStatusColor(job.status.wireValue),
            ),
            RoomForgeStatusPill(
              label: '${rf('Attempt', '시도')} ${job.retryCount + 1}',
              icon: Icons.refresh,
              color: _roomForgeAdmin,
            ),
            if (job.retryOfJobId != null)
              RoomForgeStatusPill(
                label: '${rf('Retry of', '원본 작업')} ${job.retryOfJobId}',
                icon: Icons.account_tree_outlined,
                color: _roomForgeWarning,
              ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 620;
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final ref in refs) ...[
                    ref,
                    if (ref != refs.last) const SizedBox(height: 8),
                  ],
                ],
              );
            }
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final ref in refs)
                  SizedBox(width: (constraints.maxWidth - 16) / 3, child: ref),
              ],
            );
          },
        ),
        if (additionalRefs.isNotEmpty) ...[
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: _roomForgeCanvas,
              border: Border.all(color: _roomForgeBorder),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: additionalRefs,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _FirebaseAdminMetadataCell extends StatelessWidget {
  const _FirebaseAdminMetadataCell({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _roomForgeCanvas,
        border: Border.all(color: _roomForgeBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: _roomForgeAdmin),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: _roomForgeMuted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _roomForgeInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FirebaseAdminDetailLine extends StatelessWidget {
  const _FirebaseAdminDetailLine({
    required this.label,
    required this.value,
    this.color = _roomForgeMuted,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: _roomForgeMuted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _FirebaseAdminSection extends StatelessWidget {
  const _FirebaseAdminSection({
    required this.title,
    required this.children,
    this.semanticsLabel,
  });

  final String title;
  final List<Widget> children;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RoomForgePanel(
      child: Semantics(
        container: true,
        label: semanticsLabel ?? title,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: _roomForgeInk,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _FirebaseAdminArtifactRefs extends StatelessWidget {
  const _FirebaseAdminArtifactRefs({required this.artifactRefs});

  final List<FirebaseArtifactRef> artifactRefs;

  @override
  Widget build(BuildContext context) {
    return _FirebaseAdminArtifactRefsPanel(artifactRefs: artifactRefs);
  }
}

class _FirebaseAdminArtifactRefsPanel extends StatefulWidget {
  const _FirebaseAdminArtifactRefsPanel({required this.artifactRefs});

  final List<FirebaseArtifactRef> artifactRefs;

  @override
  State<_FirebaseAdminArtifactRefsPanel> createState() =>
      _FirebaseAdminArtifactRefsPanelState();
}

class _FirebaseAdminArtifactRefsPanelState
    extends State<_FirebaseAdminArtifactRefsPanel> {
  final _artifactStateFutures =
      <String, Future<FirebaseAdminArtifactReadState>>{};

  @override
  void didUpdateWidget(covariant _FirebaseAdminArtifactRefsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final activePaths = widget.artifactRefs
        .map((ref) => ref.storagePath)
        .toSet();
    _artifactStateFutures.removeWhere((path, _) => !activePaths.contains(path));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.artifactRefs.isEmpty) {
      return _FirebaseAdminSection(
        title: rf('Artifact panels', '아티팩트 패널'),
        semanticsLabel:
            FirebaseAdminDiagnosticsUiText.artifactAccessSemanticsLabel,
        children: [
          RoomForgeStatusPill(
            label: _adminArtifactStateLabel(
              FirebaseAdminArtifactReadState.notGenerated.wireValue,
            ),
            color: _adminArtifactStateColor(
              FirebaseAdminArtifactReadState.notGenerated,
            ),
            icon: Icons.inventory_2_outlined,
          ),
        ],
      );
    }
    return _FirebaseAdminSection(
      title: rf('Artifact panels', '아티팩트 패널'),
      semanticsLabel:
          FirebaseAdminDiagnosticsUiText.artifactAccessSemanticsLabel,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 640;
            final width = compact
                ? constraints.maxWidth
                : constraints.maxWidth / 2 - 6;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final ref in widget.artifactRefs)
                  SizedBox(
                    width: width,
                    child: FutureBuilder<FirebaseAdminArtifactReadState>(
                      future: _artifactStateFuture(ref),
                      builder: (context, snapshot) {
                        final state =
                            snapshot.data ??
                            (snapshot.connectionState == ConnectionState.waiting
                                ? null
                                : FirebaseAdminArtifactReadState.failedToLoad);
                        return _FirebaseAdminArtifactCard(
                          ref: ref,
                          state: state,
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<FirebaseAdminArtifactReadState> _artifactStateFuture(
    FirebaseArtifactRef artifactRef,
  ) {
    return _artifactStateFutures.putIfAbsent(
      artifactRef.storagePath,
      () => _readArtifactState(artifactRef),
    );
  }

  Future<FirebaseAdminArtifactReadState> _readArtifactState(
    FirebaseArtifactRef artifactRef,
  ) async {
    try {
      await FirebaseStorage.instance.ref(artifactRef.storagePath).getMetadata();
      return FirebaseAdminArtifactDiagnostics.stateFor(
        artifactRef: artifactRef,
        readSucceeded: true,
      );
    } catch (error) {
      return FirebaseAdminArtifactDiagnostics.stateFor(
        artifactRef: artifactRef,
        readError: error,
      );
    }
  }
}

class _FirebaseAdminArtifactCard extends StatelessWidget {
  const _FirebaseAdminArtifactCard({required this.ref, required this.state});

  final FirebaseArtifactRef ref;
  final FirebaseAdminArtifactReadState? state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final readState = state;
    final color = readState == null
        ? _roomForgeSave
        : _adminArtifactStateColor(readState);
    final label = readState == null
        ? rf('checking', '확인 중')
        : _adminArtifactStateLabel(readState.wireValue);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _roomForgeCanvas,
        border: Border.all(color: color.withValues(alpha: 0.34)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ref.artifactType,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: _roomForgeInk,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                RoomForgeStatusPill(label: label, color: color, dense: true),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              ref.storagePath,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _roomForgeMuted,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                RoomForgeStatusPill(
                  label: ref.contentType.wireValue,
                  color: _roomForgeAdmin,
                  dense: true,
                ),
                if (ref.byteSize != null)
                  RoomForgeStatusPill(
                    label: '${ref.byteSize} b',
                    color: _roomForgeMuted,
                    dense: true,
                  ),
                if (ref.widthPx != null && ref.heightPx != null)
                  RoomForgeStatusPill(
                    label: '${ref.widthPx}x${ref.heightPx}',
                    color: _roomForgeMuted,
                    dense: true,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FirebaseAdminRetryAction extends StatefulWidget {
  const _FirebaseAdminRetryAction({
    required this.job,
    required this.adminRepository,
    required this.session,
  });

  final FirebaseReconstructionJob job;
  final FirebaseAdminRepository adminRepository;
  final AuthSession session;

  @override
  State<_FirebaseAdminRetryAction> createState() =>
      _FirebaseAdminRetryActionState();
}

class _FirebaseAdminRetryActionState extends State<_FirebaseAdminRetryAction> {
  bool _isRetrying = false;
  String? _message;
  _FirebaseAdminRetryReceipt? _receipt;

  Future<void> _confirmRetry() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(rf('Retry reconstruction job', '재구성 작업 재시도')),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RoomForgeStatusPill(
                  label: rf('confirm retry', '재시도 확인'),
                  color: _roomForgeWarning,
                  icon: Icons.warning_amber_outlined,
                ),
                const SizedBox(height: 12),
                Text(
                  rf(
                    'Create a linked retry job from the original attempt and record an admin action receipt.',
                    '원본 attempt에서 연결된 재시도 작업을 만들고 관리자 action receipt를 남깁니다.',
                  ),
                ),
                const SizedBox(height: 12),
                _FirebaseAdminRetryConditionGrid(job: widget.job),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: true,
                  onChanged: null,
                  title: Text(rf('Write admin audit log', '관리자 감사 로그 남기기')),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(rf('Cancel', '취소')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(rf('Create retry', '재시도 생성')),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    await _retry();
  }

  Future<void> _retry() async {
    setState(() {
      _isRetrying = true;
      _message = rf('Retrying...', '재시도 중...');
      _receipt = null;
    });
    try {
      final retryJob = await widget.adminRepository.retryJobWithAdminAction(
        session: widget.session,
        job: widget.job,
        reasonMessage: 'Admin requested retry from diagnostics.',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _message = null;
        _receipt = _FirebaseAdminRetryReceipt(
          actionId: firebaseAdminRetryActionId(retryJob.jobId),
          targetJobId: widget.job.jobId,
          retryJobId: retryJob.jobId,
          createdByUid: widget.session.uid,
          createdAt: retryJob.createdAt,
        );
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message =
            '${rf('Retry unavailable', '재시도할 수 없습니다')}: ${firebaseAdminSafeErrorMessage(error)}';
        _receipt = null;
      });
    } finally {
      if (mounted) {
        setState(() => _isRetrying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canRetry =
        widget.job.status == FirebaseJobStatus.failed ||
        widget.job.status == FirebaseJobStatus.timeout;
    final theme = Theme.of(context);
    return _FirebaseAdminSection(
      title: rf('Admin retry', '관리자 재시도'),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            RoomForgeStatusPill(
              label: canRetry
                  ? rf('confirm', '확인 필요')
                  : rf('unavailable', '재시도 불가'),
              color: canRetry ? _roomForgeWarning : _roomForgeError,
              icon: canRetry ? Icons.fact_check_outlined : Icons.block_outlined,
            ),
            if (_receipt != null)
              RoomForgeStatusPill(
                label: rf('audited', '감사 기록됨'),
                color: _roomForgeSuccess,
                icon: Icons.verified_outlined,
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          canRetry
              ? rf(
                  'Review the original job and retry conditions before creating a linked attempt.',
                  '연결된 attempt를 만들기 전에 원본 작업과 재시도 조건을 확인하세요.',
                )
              : _retryUnavailableMessage(widget.job),
          style: theme.textTheme.bodySmall?.copyWith(
            color: _roomForgeInkSoft,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        _FirebaseAdminRetryConditionGrid(job: widget.job),
        if (!canRetry)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: RoomForgeNotice(
              title: rf('Retry unavailable', '재시도할 수 없습니다'),
              message: _retryUnavailableMessage(widget.job),
              severity: NoticeSeverity.error,
              icon: Icons.block_outlined,
            ),
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: canRetry && !_isRetrying ? _confirmRetry : null,
          icon: _isRetrying
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.replay_outlined),
          label: Text(
            _isRetrying
                ? rf('Retrying...', '재시도 중...')
                : rf('Run retry', '재시도 실행'),
          ),
        ),
        if (_message != null) ...[
          const SizedBox(height: 12),
          RoomForgeNotice(
            title: rf('Retry status', '재시도 상태'),
            message: _message!,
            severity:
                _message!.contains('unavailable') || _message!.contains('불가')
                ? NoticeSeverity.error
                : NoticeSeverity.info,
            icon: Icons.info_outline,
          ),
        ],
        if (_receipt != null) ...[
          const SizedBox(height: 12),
          _FirebaseAdminAuditReceiptCard(receipt: _receipt!),
        ],
      ],
    );
  }
}

class _FirebaseAdminRetryReceipt {
  const _FirebaseAdminRetryReceipt({
    required this.actionId,
    required this.targetJobId,
    required this.retryJobId,
    required this.createdByUid,
    required this.createdAt,
  });

  final String actionId;
  final String targetJobId;
  final String retryJobId;
  final String createdByUid;
  final DateTime createdAt;
}

class _FirebaseAdminRetryConditionGrid extends StatelessWidget {
  const _FirebaseAdminRetryConditionGrid({required this.job});

  final FirebaseReconstructionJob job;

  @override
  Widget build(BuildContext context) {
    final canRetry =
        job.status == FirebaseJobStatus.failed ||
        job.status == FirebaseJobStatus.timeout;
    final cells = [
      _FirebaseAdminRetryConditionCell(
        label: rf('original job', '원본 작업'),
        value: job.jobId,
        color: _roomForgeAdmin,
      ),
      _FirebaseAdminRetryConditionCell(
        label: rf('new job', '새 작업'),
        value: rf('generated on confirm', '확인 후 생성'),
        color: _roomForgeWarning,
      ),
      _FirebaseAdminRetryConditionCell(
        label: rf('eligible status', '가능 상태'),
        value: _adminStatusLabel(job.status.wireValue),
        color: canRetry ? _roomForgeSuccess : _roomForgeError,
      ),
      _FirebaseAdminRetryConditionCell(
        label: rf('audit receipt', '감사 receipt'),
        value: rf('required', '필수'),
        color: _roomForgeSuccess,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final cell in cells) ...[
                cell,
                if (cell != cells.last) const SizedBox(height: 8),
              ],
            ],
          );
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final cell in cells)
              SizedBox(width: (constraints.maxWidth - 8) / 2, child: cell),
          ],
        );
      },
    );
  }
}

class _FirebaseAdminRetryConditionCell extends StatelessWidget {
  const _FirebaseAdminRetryConditionCell({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _roomForgeCanvas,
        border: Border.all(color: color.withValues(alpha: 0.32)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: _roomForgeMuted,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _roomForgeInk,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FirebaseAdminAuditReceiptCard extends StatelessWidget {
  const _FirebaseAdminAuditReceiptCard({required this.receipt});

  final _FirebaseAdminRetryReceipt receipt;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _roomForgeCanvas,
        border: Border.all(color: _roomForgeSuccess.withValues(alpha: 0.36)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RoomForgeStatusPill(
              label: rf('audited', '감사 기록됨'),
              color: _roomForgeSuccess,
              icon: Icons.verified_outlined,
            ),
            const SizedBox(height: 10),
            _FirebaseAdminDetailLine(
              label: rf('Action ID', 'Action ID'),
              value: receipt.actionId,
              color: _roomForgeInk,
            ),
            _FirebaseAdminDetailLine(
              label: rf('Target', '대상'),
              value: receipt.targetJobId,
              color: _roomForgeInk,
            ),
            _FirebaseAdminDetailLine(
              label: rf('Retry job', '재시도 작업'),
              value: receipt.retryJobId,
              color: _roomForgeInk,
            ),
            _FirebaseAdminDetailLine(
              label: rf('Created by', '생성자'),
              value: receipt.createdByUid,
              color: _roomForgeInk,
            ),
            _FirebaseAdminDetailLine(
              label: rf('Created at', '생성 시각'),
              value: _adminTimestampLabel(receipt.createdAt),
              color: _roomForgeInk,
            ),
          ],
        ),
      ),
    );
  }
}

class _FirebaseAdminAuditActions extends StatelessWidget {
  const _FirebaseAdminAuditActions({required this.stream});

  final Stream<List<FirebaseAdminAction>> stream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FirebaseAdminAction>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _FirebaseAdminSection(
            title: rf('Admin audit', '관리자 감사'),
            children: [
              RoomForgeLoadingState(
                title: rf('Loading audit receipts', '감사 receipt를 불러오는 중'),
                message: rf(
                  'Admin actions for this reconstruction job will appear here.',
                  '이 재구성 작업에 대한 관리자 action이 여기에 표시됩니다.',
                ),
                panel: false,
              ),
            ],
          );
        }
        if (snapshot.hasError) {
          return _FirebaseAdminSection(
            title: rf('Admin audit', '관리자 감사'),
            children: [
              RoomForgeNotice(
                title: rf('Audit query failed', '감사 조회 실패'),
                message: firebaseAdminSafeErrorMessage(snapshot.error!),
                severity: NoticeSeverity.error,
                icon: Icons.lock_outline,
              ),
            ],
          );
        }
        final actions = snapshot.data ?? const [];
        return _FirebaseAdminSection(
          title: rf('Admin audit', '관리자 감사'),
          children: actions.isEmpty
              ? [
                  Text(
                    rf(
                      'No admin action receipts have been recorded for this job.',
                      '이 작업에 기록된 관리자 action receipt가 없습니다.',
                    ),
                  ),
                ]
              : [
                  for (final action in actions)
                    _FirebaseAdminAuditActionRow(action: action),
                ],
        );
      },
    );
  }
}

class _FirebaseAdminAuditActionRow extends StatelessWidget {
  const _FirebaseAdminAuditActionRow({required this.action});

  final FirebaseAdminAction action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _roomForgeCanvas,
          border: Border.all(color: _roomForgeAdmin.withValues(alpha: .30)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  RoomForgeStatusPill(
                    label: action.actionType,
                    color: _roomForgeAdmin,
                    icon: Icons.fact_check_outlined,
                    dense: true,
                  ),
                  Text(
                    _adminTimestampLabel(action.createdAt),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: _roomForgeMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _FirebaseAdminDetailLine(
                label: rf('Action ID', 'Action ID'),
                value: action.actionId,
                color: _roomForgeInk,
              ),
              _FirebaseAdminDetailLine(
                label: rf('Target', '대상'),
                value: '${action.targetType}:${action.targetId}',
                color: _roomForgeInk,
              ),
              _FirebaseAdminDetailLine(
                label: rf('Created by', '생성자'),
                value:
                    '${action.createdByRole.wireValue}:${action.createdByUid}',
                color: _roomForgeInk,
              ),
              if (action.retryJobId != null)
                _FirebaseAdminDetailLine(
                  label: rf('Retry job', '재시도 작업'),
                  value: action.retryJobId!,
                  color: _roomForgeInk,
                ),
              if (action.reasonCode != null)
                _FirebaseAdminDetailLine(
                  label: rf('Reason', '사유'),
                  value: action.reasonCode!,
                  color: _roomForgeInkSoft,
                ),
              if (action.reasonMessage != null)
                _FirebaseAdminDetailLine(
                  label: rf('Message', '메시지'),
                  value: action.reasonMessage!,
                  color: _roomForgeMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _retryUnavailableMessage(FirebaseReconstructionJob job) {
  return switch (job.status) {
    FirebaseJobStatus.processing ||
    FirebaseJobStatus.uploading ||
    FirebaseJobStatus.retrying => rf(
      'This job is already active, so a linked retry cannot be created yet.',
      '이 작업은 이미 진행 중이므로 아직 연결된 재시도 작업을 만들 수 없습니다.',
    ),
    FirebaseJobStatus.succeeded => rf(
      'Succeeded jobs do not need an admin retry.',
      '성공한 작업은 관리자 재시도가 필요하지 않습니다.',
    ),
    _ => rf(
      'Only failed or timeout jobs can be retried by an admin.',
      '관리자는 실패 또는 시간 초과 작업만 재시도할 수 있습니다.',
    ),
  };
}

class _FirebaseAdminTransitions extends StatelessWidget {
  const _FirebaseAdminTransitions({required this.stream});

  final Stream<List<FirebaseJobStatusTransition>> stream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FirebaseJobStatusTransition>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _FirebaseAdminSection(
            title: rf('Transition timeline', '상태 전환 타임라인'),
            semanticsLabel:
                FirebaseAdminDiagnosticsUiText.transitionHistorySemanticsLabel,
            children: [
              RoomForgeLoadingState(
                title: rf('Loading transitions', '상태 전환을 불러오는 중'),
                message: rf(
                  'Status changes, actor, and reason details will appear here.',
                  '상태 변화, actor, 사유 정보가 여기에 표시됩니다.',
                ),
                panel: false,
              ),
            ],
          );
        }
        if (snapshot.hasError) {
          return Text(firebaseAdminSafeErrorMessage(snapshot.error!));
        }
        final transitions = snapshot.data ?? const [];
        return _FirebaseAdminSection(
          title: rf('Transition timeline', '상태 전환 타임라인'),
          semanticsLabel:
              FirebaseAdminDiagnosticsUiText.transitionHistorySemanticsLabel,
          children: transitions.isEmpty
              ? [Text(rf('No transitions found.', '상태 전환 이력이 없습니다.'))]
              : [
                  for (final transition in transitions)
                    _FirebaseAdminTimelineRow(transition: transition),
                ],
        );
      },
    );
  }
}

class _FirebaseAdminTimelineRow extends StatelessWidget {
  const _FirebaseAdminTimelineRow({required this.transition});

  final FirebaseJobStatusTransition transition;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _adminStatusColor(transition.toStatus.wireValue);
    final fromLabel = transition.fromStatus == null
        ? rf('start', '시작')
        : _adminStatusLabel(transition.fromStatus!.wireValue);
    final toLabel = _adminStatusLabel(transition.toStatus.wireValue);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _roomForgeCanvas,
          border: Border.all(color: color.withValues(alpha: 0.28)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Icon(Icons.circle, color: color, size: 12),
                  const SizedBox(height: 4),
                  Container(width: 1, height: 34, color: _roomForgeBorder),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        RoomForgeStatusPill(
                          label: '$fromLabel -> $toLabel',
                          color: color,
                          dense: true,
                        ),
                        Text(
                          _adminTimestampLabel(transition.occurredAt),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: _roomForgeMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      [
                        transition.actorType.wireValue,
                        if (transition.actorUid != null) transition.actorUid!,
                        if (transition.reasonCode != null)
                          transition.reasonCode!,
                      ].join(' | '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _roomForgeInkSoft,
                      ),
                    ),
                    if (transition.reasonMessage != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        transition.reasonMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _roomForgeMuted,
                        ),
                      ),
                    ],
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

class _FirebaseAdminResults extends StatelessWidget {
  const _FirebaseAdminResults({required this.stream});

  final Stream<List<FirebaseOpenCvResult>> stream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FirebaseOpenCvResult>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _FirebaseAdminSection(
            title: rf('OpenCV summary', 'OpenCV 요약'),
            semanticsLabel:
                FirebaseAdminDiagnosticsUiText.opencvResultsSemanticsLabel,
            children: [
              RoomForgeLoadingState(
                title: rf('Loading OpenCV results', 'OpenCV 결과를 불러오는 중'),
                message: rf(
                  'Candidate count, runtime, confidence, and failure reason will appear here.',
                  '후보 수, 실행 시간, 신뢰도, 실패 사유가 여기에 표시됩니다.',
                ),
                panel: false,
              ),
            ],
          );
        }
        if (snapshot.hasError) {
          return Text(firebaseAdminSafeErrorMessage(snapshot.error!));
        }
        final results = snapshot.data ?? const [];
        return _FirebaseAdminSection(
          title: rf('OpenCV summary', 'OpenCV 요약'),
          semanticsLabel:
              FirebaseAdminDiagnosticsUiText.opencvResultsSemanticsLabel,
          children: results.isEmpty
              ? [Text(rf('No OpenCV result found.', 'OpenCV 결과가 없습니다.'))]
              : [
                  for (final result in results)
                    _FirebaseAdminOpenCvCard(result: result),
                ],
        );
      },
    );
  }
}

class _FirebaseAdminOpenCvCard extends StatelessWidget {
  const _FirebaseAdminOpenCvCard({required this.result});

  final FirebaseOpenCvResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final candidateCount =
        result.candidateEdges.length +
        result.candidateLines.length +
        result.candidateCorners.length;
    final runtimeLabel = _opencvRuntimeLabel(result);
    final confidenceLabel = result.confidenceScore == null
        ? rf('n/a', '없음')
        : '${(result.confidenceScore! * 100).toStringAsFixed(0)}%';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _roomForgeCanvas,
          border: Border.all(color: _roomForgeBorder),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      result.resultId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: _roomForgeInk,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  RoomForgeStatusPill(
                    label: result.qualityStatus.displayLabel,
                    color: result.failureReasonCode == null
                        ? _roomForgeSuccess
                        : _roomForgeWarning,
                    dense: true,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FirebaseAdminMiniMetric(
                    label: rf('candidates', '후보'),
                    value: candidateCount.toString(),
                  ),
                  _FirebaseAdminMiniMetric(
                    label: rf('runtime', '실행 시간'),
                    value: runtimeLabel,
                  ),
                  _FirebaseAdminMiniMetric(
                    label: rf('confidence', '신뢰도'),
                    value: confidenceLabel,
                  ),
                  _FirebaseAdminMiniMetric(
                    label: rf('space', '좌표계'),
                    value: result.coordinateSpace.wireValue,
                  ),
                ],
              ),
              if (result.failureReasonCode != null ||
                  result.failureReason != null) ...[
                const SizedBox(height: 10),
                RoomForgeNotice(
                  title: rf('Failure reason', '실패 사유'),
                  message: [
                    if (result.failureReasonCode != null)
                      result.failureReasonCode!,
                    if (result.failureReason != null) result.failureReason!,
                  ].join(' | '),
                  severity: NoticeSeverity.warning,
                  icon: Icons.warning_amber_outlined,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FirebaseAdminMiniMetric extends StatelessWidget {
  const _FirebaseAdminMiniMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: _roomForgeBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: theme.textTheme.labelLarge?.copyWith(
                color: _roomForgeInk,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: _roomForgeMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _opencvRuntimeLabel(FirebaseOpenCvResult result) {
  final started = result.processingStartedAt;
  final completed = result.processingCompletedAt;
  if (started == null || completed == null) {
    return rf('n/a', '없음');
  }
  final milliseconds = completed.difference(started).inMilliseconds;
  if (milliseconds < 1000) {
    return '${milliseconds}ms';
  }
  return '${(milliseconds / 1000).toStringAsFixed(1)}s';
}

class _FirebaseAdminLayouts extends StatelessWidget {
  const _FirebaseAdminLayouts({required this.jobId, required this.stream});

  final String jobId;
  final Stream<List<FirebaseSavedLayout>> stream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FirebaseSavedLayout>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _FirebaseAdminSection(
            title: rf('Layout references', '레이아웃 참조'),
            semanticsLabel:
                FirebaseAdminDiagnosticsUiText.layoutReferencesSemanticsLabel,
            children: [
              RoomForgeLoadingState(
                title: rf('Loading layout references', '레이아웃 참조를 불러오는 중'),
                message: rf(
                  'Saved layout references for this reconstruction job will appear here.',
                  '이 재구성 작업의 저장된 레이아웃 참조가 여기에 표시됩니다.',
                ),
                panel: false,
              ),
            ],
          );
        }
        if (snapshot.hasError) {
          return Text(firebaseAdminSafeErrorMessage(snapshot.error!));
        }
        final layouts = (snapshot.data ?? const <FirebaseSavedLayout>[])
            .where((layout) => layout.reconstructionJobId == jobId)
            .toList();
        return _FirebaseAdminSection(
          title: rf('Layout references', '레이아웃 참조'),
          semanticsLabel:
              FirebaseAdminDiagnosticsUiText.layoutReferencesSemanticsLabel,
          children: layouts.isEmpty
              ? [
                  Text(
                    rf(
                      'No saved layout references found.',
                      '저장된 레이아웃 참조가 없습니다.',
                    ),
                  ),
                ]
              : [
                  for (final layout in layouts)
                    _FirebaseAdminLayoutRefCard(layout: layout),
                ],
        );
      },
    );
  }
}

class _FirebaseAdminLayoutRefCard extends StatelessWidget {
  const _FirebaseAdminLayoutRefCard({required this.layout});

  final FirebaseSavedLayout layout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _roomForgeCanvas,
          border: Border.all(
            color: _adminStatusColor(
              layout.reconstructionStatus.wireValue,
            ).withValues(alpha: 0.32),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      layout.layoutId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: _roomForgeInk,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  RoomForgeStatusPill(
                    label: _adminStatusLabel(
                      layout.reconstructionStatus.wireValue,
                    ),
                    color: _adminStatusColor(
                      layout.reconstructionStatus.wireValue,
                    ),
                    dense: true,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FirebaseAdminMiniMetric(
                    label: rf('space', '좌표계'),
                    value: layout.coordinateSpace.wireValue,
                  ),
                  _FirebaseAdminMiniMetric(
                    label: rf('updated', '수정'),
                    value: _adminTimestampLabel(layout.updatedAt),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminShellScreen extends StatefulWidget {
  const AdminShellScreen({
    required this.session,
    required this.adminApi,
    super.key,
  });

  final AdminSession session;
  final AdminApi adminApi;

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  final _searchController = TextEditingController();
  String? _statusFilter;
  Future<AdminJobList>? _jobsFuture;
  Future<AdminJobDetail>? _jobDetailFuture;
  Future<Map<String, Object?>>? _artifactFuture;
  Future<List<Map<String, Object?>>>? _searchFuture;
  Future<Map<String, Object?>>? _diagnosisFuture;

  @override
  void initState() {
    super.initState();
    _jobsFuture = widget.adminApi.loadJobs();
  }

  void _setStatusFilter(String? status) {
    setState(() {
      _statusFilter = status;
      _jobsFuture = widget.adminApi.loadJobs(status: status);
      _jobDetailFuture = null;
      _artifactFuture = null;
      _diagnosisFuture = null;
    });
  }

  void _selectJob(AdminJob job) {
    setState(() {
      _jobDetailFuture = widget.adminApi.loadJobDetail(job.id);
      _artifactFuture = widget.adminApi.loadJobArtifacts(job.id);
      _diagnosisFuture = widget.adminApi.loadJobDiagnosis(job.id);
    });
  }

  void _search() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchFuture = Future.value(const <Map<String, Object?>>[]);
      });
      return;
    }
    setState(() => _searchFuture = widget.adminApi.search(query));
  }

  void _openSearchResult(Map<String, Object?> result) {
    final type = result['type']?.toString();
    final rawId = result['id'];
    final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    if (type != 'job' || id == null) {
      return;
    }
    setState(() {
      _jobDetailFuture = widget.adminApi.loadJobDetail(id);
      _artifactFuture = widget.adminApi.loadJobArtifacts(id);
      _diagnosisFuture = widget.adminApi.loadJobDiagnosis(id);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayName =
        widget.session.admin.displayName ??
        widget.session.admin.email ??
        rf('admin user', '관리자 사용자');

    return Scaffold(
      appBar: AppBar(title: Text(rf('Admin Operations', '관리자 작업'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${rf('Signed in as', '로그인 사용자')} $displayName',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text('${rf('Role', '역할')}: ${widget.session.admin.role}'),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: rf(
                            'Search user, project, layout, or job id',
                            '사용자, 프로젝트, 레이아웃 또는 작업 ID 검색',
                          ),
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _search(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _search,
                      child: Text(rf('Search', '검색')),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_searchFuture != null)
                  _AdminSearchResultsView(
                    future: _searchFuture!,
                    onOpenResult: _openSearchResult,
                  ),
                const SizedBox(height: 24),
                FutureBuilder<AdminJobList>(
                  future: _jobsFuture,
                  builder: (context, snapshot) {
                    final data = snapshot.data;
                    final statuses = data?.allowedStatuses ?? const <String>[];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<String?>(
                          value: _statusFilter,
                          decoration: InputDecoration(
                            labelText: rf('Job status', '작업 상태'),
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text(rf('All statuses', '모든 상태')),
                            ),
                            ...statuses.map(
                              (status) => DropdownMenuItem<String?>(
                                value: status,
                                child: Text(_adminStatusLabel(status)),
                              ),
                            ),
                          ],
                          onChanged: _setStatusFilter,
                        ),
                        const SizedBox(height: 16),
                        if (snapshot.connectionState == ConnectionState.waiting)
                          const LinearProgressIndicator()
                        else if (snapshot.hasError)
                          Text(
                            '${rf('Admin jobs failed', '관리자 작업 불러오기 실패')}: ${snapshot.error}',
                          )
                        else
                          _AdminJobListView(
                            jobs: data?.jobs ?? const [],
                            onSelect: _selectJob,
                          ),
                        const SizedBox(height: 16),
                        if (_jobDetailFuture != null)
                          _AdminJobDetailView(
                            future: _jobDetailFuture!,
                            adminApi: widget.adminApi,
                          ),
                        const SizedBox(height: 16),
                        if (_artifactFuture != null)
                          _AdminArtifactView(future: _artifactFuture!),
                        const SizedBox(height: 16),
                        if (_diagnosisFuture != null)
                          _AdminDiagnosisView(future: _diagnosisFuture!),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminJobListView extends StatelessWidget {
  const _AdminJobListView({required this.jobs, required this.onSelect});

  final List<AdminJob> jobs;
  final ValueChanged<AdminJob> onSelect;

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) {
      return DecoratedBox(
        decoration: const BoxDecoration(
          border: Border.fromBorderSide(BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            rf('No jobs match the current filter.', '현재 필터와 일치하는 작업이 없습니다.'),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final job in jobs)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              onTap: () => onSelect(job),
              title: Text(
                '${rf('Job', '작업')} ${job.id} - ${_adminStatusLabel(job.status)}',
              ),
              subtitle: Text(
                '${rf('Project', '프로젝트')} ${job.projectId} | ${rf('User', '사용자')} ${job.userId} | ${job.provider}',
              ),
              trailing: Text(_adminStatusLabel(job.status)),
            ),
          ),
      ],
    );
  }
}

class _AdminSearchResultsView extends StatelessWidget {
  const _AdminSearchResultsView({
    required this.future,
    required this.onOpenResult,
  });

  final Future<List<Map<String, Object?>>> future;
  final ValueChanged<Map<String, Object?>> onOpenResult;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, Object?>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }
        if (snapshot.hasError) {
          return Text('${rf('Search failed', '검색 실패')}: ${snapshot.error}');
        }
        final results = snapshot.data ?? const [];
        if (results.isEmpty) {
          return Text(rf('No matching records.', '일치하는 기록이 없습니다.'));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final result in results)
              ListTile(
                dense: true,
                title: Text('${result['type']} ${result['id']}'),
                subtitle: Text(_adminSearchResultContextLabel(result)),
                trailing: result['type'] == 'job'
                    ? const Icon(Icons.open_in_new)
                    : null,
                onTap: result['type'] == 'job'
                    ? () => onOpenResult(result)
                    : null,
              ),
          ],
        );
      },
    );
  }
}

String _adminSearchResultContextLabel(Map<String, Object?> result) {
  final label = result['label']?.toString() ?? '';
  final context = result['context'] is Map
      ? Map<String, Object?>.from(result['context'] as Map)
      : const <String, Object?>{};
  final contextLabel = context.entries
      .map((entry) => '${entry.key}: ${entry.value}')
      .join(' | ');
  if (label.isEmpty) {
    return contextLabel;
  }
  if (contextLabel.isEmpty) {
    return label;
  }
  return '$label | $contextLabel';
}

class _AdminJobDetailView extends StatefulWidget {
  const _AdminJobDetailView({required this.future, required this.adminApi});

  final Future<AdminJobDetail> future;
  final AdminApi adminApi;

  @override
  State<_AdminJobDetailView> createState() => _AdminJobDetailViewState();
}

class _AdminJobDetailViewState extends State<_AdminJobDetailView> {
  Future<AdminJobDetail>? _retryFuture;
  String? _retryMessage;

  void _retry(AdminJob job) {
    setState(() {
      _retryMessage = rf('Retrying...', '재시도 중...');
      _retryFuture = widget.adminApi.retryJob(job.id);
    });
    _retryFuture!
        .then((detail) {
          if (mounted) {
            setState(
              () => _retryMessage =
                  '${rf('Retry job created', '재시도 작업이 생성되었습니다')}: ${detail.job.id}',
            );
          }
        })
        .catchError((Object error) {
          if (mounted) {
            setState(
              () => _retryMessage =
                  '${rf('Retry unavailable', '재시도할 수 없습니다')}: $error',
            );
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdminJobDetail>(
      future: widget.future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }
        if (snapshot.hasError) {
          return Text(
            '${rf('Job detail failed', '작업 상세 불러오기 실패')}: ${snapshot.error}',
          );
        }
        final detail = snapshot.data;
        if (detail == null) {
          return const SizedBox.shrink();
        }
        final job = detail.job;
        final retrySupported =
            job.status == 'failed' || job.status == 'timeout';
        return DecoratedBox(
          decoration: const BoxDecoration(
            border: Border.fromBorderSide(BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${rf('Job', '작업')} ${job.id} ${rf('detail', '상세')}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '${rf('Status', '상태')}: ${_adminStatusLabel(job.status)} (${job.status})',
                ),
                Text(
                  '${rf('Project', '프로젝트')}: ${job.projectId} | ${rf('User', '사용자')}: ${job.userId}',
                ),
                Text('${rf('Provider', '제공자')}: ${job.provider}'),
                Text(
                  '${rf('Created', '생성 시각')}: ${_adminTimestampLabel(job.createdAt)}',
                ),
                Text(
                  '${rf('Updated', '수정 시각')}: ${_adminTimestampLabel(job.updatedAt)}',
                ),
                Text('${rf('Retry count', '재시도 횟수')}: ${detail.retryCount}'),
                if (job.retryOfJobId != null)
                  Text('${rf('Retry of job', '원본 작업')}: ${job.retryOfJobId}'),
                if (job.failureReasonCode != null)
                  Text('${rf('Failure', '실패 사유')}: ${job.failureReasonCode}'),
                if (job.failureReasonMessage != null)
                  Text(job.failureReasonMessage!),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: retrySupported ? () => _retry(job) : null,
                  child: Text(rf('Retry job', '작업 재시도')),
                ),
                if (!retrySupported)
                  Text(
                    rf(
                      'Retry unavailable: only failed or timed-out jobs can be retried.',
                      '재시도 불가: 실패 또는 시간 초과 작업만 재시도할 수 있습니다.',
                    ),
                  ),
                if (_retryMessage != null) Text(_retryMessage!),
                const SizedBox(height: 12),
                Text(
                  rf('Event trail', '이벤트 이력'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                for (final transition in detail.transitions)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${_adminStatusLabel(transition.status)} - ${transition.actor}',
                    ),
                    subtitle: Text(
                      [
                        '${rf('At', '시각')}: ${_adminTimestampLabel(transition.createdAt)}',
                        '${rf('Job', '작업')}: ${transition.jobId}',
                        if (job.retryOfJobId != null)
                          '${rf('Retry of job', '원본 작업')}: ${job.retryOfJobId}',
                        if (transition.reasonCode != null)
                          transition.reasonCode!,
                        if (transition.reasonMessage != null)
                          transition.reasonMessage!,
                      ].join(' | '),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AdminArtifactView extends StatelessWidget {
  const _AdminArtifactView({required this.future});

  final Future<Map<String, Object?>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, Object?>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }
        if (snapshot.hasError) {
          return Text(
            '${rf('Artifacts unavailable', '아티팩트를 사용할 수 없습니다')}: ${snapshot.error}',
          );
        }
        final data = snapshot.data;
        if (data == null) {
          return const SizedBox.shrink();
        }
        final job = _adminArtifactMap(data['job']);
        final sourceImage = _adminArtifactMap(data['source_image']);
        final candidate = _adminArtifactMap(data['candidate']);
        final confirmed = _adminArtifactMapList(data['confirmed']);
        final calibration = _adminArtifactMapList(data['calibration']);
        return DecoratedBox(
          decoration: const BoxDecoration(
            border: Border.fromBorderSide(BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  rf('OpenCV artifacts', 'OpenCV 아티팩트'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  rf('Original image access', '원본 이미지 접근'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  '${rf('Source image', '소스 이미지')}: ${sourceImage['id'] ?? rf('unknown', '알 수 없음')}',
                ),
                Text(
                  '${rf('Access', '접근')}: ${sourceImage['access'] ?? rf('unknown', '알 수 없음')}',
                ),
                if (job['failure_reason_code'] != null)
                  Text(
                    '${rf('Failure', '실패 사유')}: ${job['failure_reason_code']}',
                  ),
                if (job['failure_reason_message'] != null)
                  Text('${job['failure_reason_message']}'),
                const Divider(height: 24),
                Text(
                  rf('Candidate preview', '후보 미리보기'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  '${rf('Candidate geometry', '후보 지오메트리')}: ${candidate['coordinate_space']}',
                ),
                Text(
                  '${rf('Confidence', '신뢰도')}: ${candidate['confidence'] ?? rf('unknown', '알 수 없음')}',
                ),
                Text(
                  '${rf('Algorithm', '알고리즘')}: ${candidate['algorithm'] ?? rf('unknown', '알 수 없음')}',
                ),
                Text(
                  '${rf('Geometry preview', '지오메트리 미리보기')}: ${_adminArtifactJsonPreview(candidate['geometry'])}',
                ),
                const Divider(height: 24),
                Text(
                  rf('User-confirmed geometry', '사용자 확정 지오메트리'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (confirmed.isEmpty)
                  Text(rf('No user correction saved.', '저장된 사용자 보정 없음.'))
                else
                  for (final geometry in confirmed) ...[
                    Text(
                      '${rf('Confirmed', '확정')} #${geometry['id']}: ${geometry['geometry_kind']} | ${geometry['coordinate_space']}',
                    ),
                    Text(
                      '${rf('Points', '포인트')}: ${_adminArtifactPointCount(geometry['points'])}',
                    ),
                    Text(
                      '${rf('Geometry preview', '지오메트리 미리보기')}: ${_adminArtifactJsonPreview(geometry['points'])}',
                    ),
                  ],
                const Divider(height: 24),
                Text(
                  rf('Calibration summary', '보정 요약'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (calibration.isEmpty)
                  Text(rf('No calibration saved.', '저장된 보정 없음.'))
                else
                  for (final floorPlan in calibration) ...[
                    Text(
                      '${rf('Floor plan', '평면도')} #${floorPlan['floor_plan_id']}: ${floorPlan['width_value']} x ${floorPlan['depth_value']} ${floorPlan['unit']}',
                    ),
                    Text(
                      '${rf('Deviation', '편차')}: W ${floorPlan['width_deviation_ratio']}, D ${floorPlan['depth_deviation_ratio']}, AR ${floorPlan['aspect_ratio_error']}',
                    ),
                    Text(
                      '${rf('Image geometry', '이미지 지오메트리')}: ${_adminArtifactCoordinateSpace(floorPlan['image_geometry'])}',
                    ),
                    Text(
                      '${rf('Metric geometry', '미터 지오메트리')}: ${_adminArtifactCoordinateSpace(floorPlan['metric_geometry'])}',
                    ),
                  ],
              ],
            ),
          ),
        );
      },
    );
  }
}

Map<String, Object?> _adminArtifactMap(Object? value) {
  if (value is Map) {
    return Map<String, Object?>.from(value);
  }
  return const <String, Object?>{};
}

List<Map<String, Object?>> _adminArtifactMapList(Object? value) {
  if (value is! List) {
    return const <Map<String, Object?>>[];
  }
  return [
    for (final item in value)
      if (item is Map) Map<String, Object?>.from(item),
  ];
}

String _adminArtifactJsonPreview(Object? value) {
  if (value == null) {
    return rf('unknown', '알 수 없음');
  }
  final encoded = jsonEncode(value);
  if (encoded.length <= 240) {
    return encoded;
  }
  return '${encoded.substring(0, 240)}...';
}

String _adminArtifactPointCount(Object? value) {
  if (value is List) {
    return '${value.length}';
  }
  return rf('unknown', '알 수 없음');
}

String _adminArtifactCoordinateSpace(Object? value) {
  if (value is Map && value['coordinate_space'] != null) {
    return '${value['coordinate_space']}';
  }
  return rf('unknown', '알 수 없음');
}

class _AdminDiagnosisView extends StatelessWidget {
  const _AdminDiagnosisView({required this.future});

  final Future<Map<String, Object?>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, Object?>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }
        if (snapshot.hasError) {
          return Text(
            '${rf('Diagnosis unavailable', '진단을 사용할 수 없습니다')}: ${snapshot.error}',
          );
        }
        final data = snapshot.data;
        if (data == null) {
          return const SizedBox.shrink();
        }
        final providerState = data['provider_state'] is Map
            ? Map<String, Object?>.from(data['provider_state'] as Map)
            : const <String, Object?>{};
        final failureSource = data['failure_source'] is Map
            ? Map<String, Object?>.from(data['failure_source'] as Map)
            : const <String, Object?>{};
        final recentFailure = providerState['recent_failure_state'] is Map
            ? Map<String, Object?>.from(
                providerState['recent_failure_state'] as Map,
              )
            : const <String, Object?>{};
        final gpuLifecycle = providerState['gpu_lifecycle'] is Map
            ? Map<String, Object?>.from(providerState['gpu_lifecycle'] as Map)
            : const <String, Object?>{};
        return DecoratedBox(
          decoration: const BoxDecoration(
            border: Border.fromBorderSide(BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  rf('Failure diagnosis', '실패 진단'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '${rf('Provider', '제공자')}: ${providerState['provider'] ?? rf('unknown', '알 수 없음')}',
                ),
                Text(
                  '${rf('Provider status', '제공자 상태')}: ${providerState['status'] ?? rf('unknown', '알 수 없음')}',
                ),
                Text(
                  '${rf('Active jobs', '활성 작업')}: ${providerState['active_job_count'] ?? rf('unknown', '알 수 없음')}',
                ),
                Text(
                  '${rf('GPU lifecycle', 'GPU 수명주기')}: ${gpuLifecycle['state'] ?? rf('not enabled', '비활성')}',
                ),
                if (recentFailure.isNotEmpty) ...[
                  Text(
                    '${rf('Recent failure', '최근 실패')}: ${recentFailure['status']} #${recentFailure['job_id']}',
                  ),
                  if (recentFailure['failure_reason_code'] != null)
                    Text(
                      '${rf('Recent reason', '최근 사유')}: ${recentFailure['failure_reason_code']}',
                    ),
                ],
                Text(
                  '${rf('Failure source', '실패 출처')}: ${failureSource['source'] ?? rf('unknown', '알 수 없음')}',
                ),
                if (providerState['failure_reason_code'] != null)
                  Text(
                    '${rf('Reason', '사유')}: ${providerState['failure_reason_code']}',
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _adminStatusLabel(String status) {
  return switch (status) {
    'created' => rf('created', '생성됨'),
    'uploading' => rf('uploading', '업로드 중'),
    'processing' => rf('processing', '처리 중'),
    'review_required' => rf('Needs review', '검토 필요'),
    'succeeded' => rf('succeeded', '성공'),
    'failed' => rf('failed', '실패'),
    'timeout' => rf('timeout', '시간 초과'),
    'cancelled' => rf('cancelled', '취소됨'),
    'retrying' => rf('retrying', '재시도 중'),
    _ => status,
  };
}

String _adminTimestampLabel(DateTime timestamp) {
  return timestamp.toUtc().toIso8601String();
}

Color _adminStatusColor(String status) {
  return switch (status) {
    'succeeded' => _roomForgeSuccess,
    'review_required' => _roomForgeWarning,
    'failed' || 'timeout' || 'cancelled' => _roomForgeError,
    'processing' || 'uploading' || 'retrying' => _roomForgePrimary,
    _ => _roomForgeMuted,
  };
}

String _adminArtifactStateLabel(String state) {
  return switch (state) {
    'available' => rf('available', '사용 가능'),
    'restricted' => rf('restricted', '제한됨'),
    'missing' => rf('missing', '없음'),
    'failed_to_load' => rf('failed_to_load', '불러오기 실패'),
    'not_generated' => rf('not_generated', '생성되지 않음'),
    'checking' => rf('checking', '확인 중'),
    _ => state,
  };
}

Color _adminArtifactStateColor(FirebaseAdminArtifactReadState state) {
  return switch (state) {
    FirebaseAdminArtifactReadState.available => _roomForgeSuccess,
    FirebaseAdminArtifactReadState.restricted ||
    FirebaseAdminArtifactReadState.failedToLoad => _roomForgeError,
    FirebaseAdminArtifactReadState.missing ||
    FirebaseAdminArtifactReadState.notGenerated => _roomForgeWarning,
  };
}

String _localizedAdminSearchFieldLabel(
  FirebaseAdminDiagnosticsSearchField field,
) {
  return switch (field) {
    FirebaseAdminDiagnosticsSearchField.jobId => rf('Job ID', '작업 ID'),
    FirebaseAdminDiagnosticsSearchField.projectId => rf(
      'Project ID',
      '프로젝트 ID',
    ),
    FirebaseAdminDiagnosticsSearchField.ownerUid => rf('User ID', '사용자 ID'),
  };
}

String _localizedUploadProgressLabel(double? progress) {
  if (!_roomForgeUsesKorean) {
    return uploadProgressLabel(progress);
  }
  if (progress == null) {
    return '업로드 중';
  }
  final percent = (progress.clamp(0, 1) * 100).round();
  return '업로드 중 $percent%';
}

SourceImageUploadAction _localizedSourceImageUploadAction(
  SourceImageUploadAction action,
) {
  final label = switch (action.label) {
    sourceImageChoosePhotoActionLabel => rf('Choose photo', '사진 선택'),
    sourceImageRetryUploadActionLabel => rf('Retry upload', '업로드 재시도'),
    _ => action.label,
  };
  return action.copyWith(label: label);
}

String _localizedSourceImageUploadAccessibilitySummary({
  required SourceImageUploadStatus status,
  required String? message,
  required double? progress,
}) {
  if (!_roomForgeUsesKorean) {
    return sourceImageUploadAccessibilitySummary(
      status: status,
      message: message,
      progress: progress,
    );
  }
  final statusText = status == SourceImageUploadStatus.uploading
      ? _localizedUploadProgressLabel(progress)
      : _localizedSourceImageUploadStateLabel(status);
  final actionText = sourceImageUploadActions(status)
      .map(_localizedSourceImageUploadAction)
      .map((action) => action.label)
      .join(', ');
  return [
    rf(sourceImageUploadRecoverySemanticsLabel, '소스 이미지 업로드 복구'),
    statusText,
    _localizedSourceImageUploadGuidance(status),
    if (message != null && message.isNotEmpty) message,
    if (actionText.isNotEmpty) '${rf('Actions', '작업')}: $actionText',
  ].join('. ');
}

String _localizedSourceImageUploadGuidance(SourceImageUploadStatus state) {
  if (!_roomForgeUsesKorean) {
    return sourceImageUploadGuidance(state);
  }
  return switch (state) {
    SourceImageUploadStatus.ready => '재구성 전에 지원되는 방 사진을 선택하세요.',
    SourceImageUploadStatus.uploading => '소스 이미지가 저장되는 동안 이 탭을 열어 두세요.',
    SourceImageUploadStatus.uploaded => '업로드된 사진을 재구성 검토에 사용할 수 있습니다.',
    SourceImageUploadStatus.validationError =>
      'JPEG, PNG, WebP 형식과 10 MB 이하 파일을 선택하세요.',
    SourceImageUploadStatus.lowQualityWarning =>
      '재구성 결과가 약하면 더 선명하고 밝은 이미지를 사용하세요.',
    SourceImageUploadStatus.permissionFailure =>
      '프로젝트 접근 권한을 확인한 뒤 새로고침하거나 다시 시도하세요.',
    SourceImageUploadStatus.metadataSaveFailed =>
      '파일은 Storage에 도착했지만 프로젝트 메타데이터 저장이 완료되지 않았습니다.',
    SourceImageUploadStatus.uploadFailed => '업로드를 다시 시도하거나 문제가 반복되면 파일을 교체하세요.',
    SourceImageUploadStatus.empty => '재구성을 시작하려면 방 사진을 선택하세요.',
  };
}

String _localizedSourceImageUploadStateLabel(SourceImageUploadStatus state) {
  if (!_roomForgeUsesKorean) {
    return state.label;
  }
  return switch (state) {
    SourceImageUploadStatus.ready => '선택 준비됨',
    SourceImageUploadStatus.uploading => '업로드 중',
    SourceImageUploadStatus.uploaded => '업로드됨',
    SourceImageUploadStatus.validationError => '검증 오류',
    SourceImageUploadStatus.lowQualityWarning => '품질 경고',
    SourceImageUploadStatus.permissionFailure => '권한 차단',
    SourceImageUploadStatus.metadataSaveFailed => '메타데이터 저장 실패',
    SourceImageUploadStatus.uploadFailed => '업로드 실패',
    SourceImageUploadStatus.empty => '선택된 소스 이미지 없음',
  };
}

String _localizedReconstructionStatusLabel(String status) {
  return _adminStatusLabel(status);
}

String _localizedDraftLabel(String label) {
  return switch (label) {
    'Unsaved draft' => rf('Unsaved draft', '저장되지 않은 드래프트'),
    'Saving' => rf('Saving', '저장 중'),
    'Sync failed' => rf('Sync failed', '동기화 실패'),
    'Conflict' => rf('Conflict', '충돌'),
    'Saved' => rf('Saved', '저장됨'),
    _ => label,
  };
}

String _localizedDraftRecoveryActionLabel(String label) {
  return switch (label) {
    draftRecoveryRestoreActionLabel => rf('Restore draft', '드래프트 복원'),
    draftRecoveryDiscardActionLabel => rf('Discard draft', '드래프트 버리기'),
    draftRecoveryContinueSavedActionLabel => rf(
      'Continue saved version',
      '저장된 버전 계속 사용',
    ),
    draftRecoveryRetrySaveActionLabel => rf('Retry save', '저장 재시도'),
    _ => label,
  };
}

LayoutDraftRecoveryAction _localizedDraftRecoveryAction(
  LayoutDraftRecoveryAction action,
) {
  return action.copyWith(
    label: _localizedDraftRecoveryActionLabel(action.label),
  );
}

String _localizedLayoutDraftRecoveryMessage({
  required LayoutDraft draft,
  required DateTime? latestCloudUpdatedAt,
}) {
  if (!_roomForgeUsesKorean) {
    return layoutDraftRecoveryMessage(
      draft: draft,
      latestCloudUpdatedAt: latestCloudUpdatedAt,
    );
  }
  return layoutDraftHasCloudConflict(draft, latestCloudUpdatedAt)
      ? '클라우드에 저장된 레이아웃이 이 드래프트 이후 변경되었습니다.'
      : '저장되지 않은 로컬 드래프트가 있습니다.';
}

String _localizedLayoutDraftRecoveryAccessibilitySummary({
  required LayoutDraft draft,
  required DateTime? latestCloudUpdatedAt,
  bool includeContinueSavedVersion = false,
  bool includeRetry = false,
}) {
  if (!_roomForgeUsesKorean) {
    return layoutDraftRecoveryAccessibilitySummary(
      draft: draft,
      latestCloudUpdatedAt: latestCloudUpdatedAt,
      includeContinueSavedVersion: includeContinueSavedVersion,
      includeRetry: includeRetry,
    );
  }
  final actionLabels =
      layoutDraftRecoveryActions(
            draft: draft,
            latestCloudUpdatedAt: latestCloudUpdatedAt,
            includeContinueSavedVersion: includeContinueSavedVersion,
            includeRetry: includeRetry,
          )
          .map((action) => _localizedDraftRecoveryActionLabel(action.label))
          .join(', ');
  return '${_localizedLayoutDraftRecoveryMessage(draft: draft, latestCloudUpdatedAt: latestCloudUpdatedAt)} ${_localizedDraftLabel(draft.label)}. ${rf('Actions', '작업')}: $actionLabels.';
}

String _localizedEditorObjectLabel(String? label) {
  if (!_roomForgeUsesKorean) {
    return label ?? 'Room shell';
  }
  return switch (label) {
    'Room shell' || null => '방 외곽',
    'Chair' => '의자',
    'Table' => '테이블',
    'Sofa' => '소파',
    _ => label,
  };
}

enum _ProjectWorkspaceRouteMode { projects, workspace }

class _ProjectWorkspaceBody extends StatefulWidget {
  const _ProjectWorkspaceBody({
    required this.routeSpec,
    required this.routeMode,
    required this.title,
    required this.routeLabel,
    required this.displayName,
    required this.projectApi,
    this.initialProjectId,
  });

  final _RoomForgeRouteSpec routeSpec;
  final _ProjectWorkspaceRouteMode routeMode;
  final String title;
  final String routeLabel;
  final String displayName;
  final ProjectApi projectApi;
  final String? initialProjectId;

  @override
  State<_ProjectWorkspaceBody> createState() => _ProjectWorkspaceBodyState();
}

class _ProjectWorkspaceBodyState extends State<_ProjectWorkspaceBody> {
  late Future<List<RoomProject>> _projectsFuture;
  RoomProject? _selectedProject;
  String? _loadingProjectId;
  String? _workspaceMessage;
  NoticeSeverity _workspaceSeverity = NoticeSeverity.info;

  @override
  void initState() {
    super.initState();
    _projectsFuture = widget.projectApi.listProjects();
    final initialProjectId = widget.initialProjectId;
    if (initialProjectId != null) {
      _loadingProjectId = initialProjectId;
      unawaited(_loadRouteProject(initialProjectId));
    }
  }

  @override
  void didUpdateWidget(_ProjectWorkspaceBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectApi != widget.projectApi) {
      _projectsFuture = widget.projectApi.listProjects();
    }
    if (oldWidget.initialProjectId != widget.initialProjectId) {
      final initialProjectId = widget.initialProjectId;
      setState(() {
        _selectedProject = null;
        _loadingProjectId = initialProjectId;
        _workspaceMessage = null;
      });
      if (initialProjectId != null) {
        unawaited(_loadRouteProject(initialProjectId));
      }
    }
  }

  void _reload() {
    setState(() {
      _projectsFuture = widget.projectApi.listProjects();
    });
  }

  Future<void> _loadRouteProject(String projectId) async {
    try {
      final detail = await widget.projectApi.getProject(projectId);
      if (!mounted || widget.initialProjectId != projectId) {
        return;
      }
      setState(() {
        _selectedProject = detail;
        _loadingProjectId = null;
        _workspaceMessage = null;
      });
    } on ProjectApiException catch (error) {
      if (!mounted || widget.initialProjectId != projectId) {
        return;
      }
      setState(() {
        _selectedProject = null;
        _loadingProjectId = null;
        _workspaceMessage =
            '${rf('Workspace could not be loaded', '워크스페이스를 불러오지 못했습니다')}: ${error.message}';
        _workspaceSeverity = NoticeSeverity.error;
      });
    } catch (error) {
      if (!mounted || widget.initialProjectId != projectId) {
        return;
      }
      setState(() {
        _selectedProject = null;
        _loadingProjectId = null;
        _workspaceMessage =
            '${rf('Workspace could not be loaded', '워크스페이스를 불러오지 못했습니다')}: $error';
        _workspaceSeverity = NoticeSeverity.error;
      });
    }
  }

  void _navigateToWorkspace(String projectId) {
    final route = widget.routeSpec.workspacePath(projectId);
    if (widget.routeSpec.location == route) {
      return;
    }
    Navigator.of(context).pushNamed(route);
  }

  Future<void> _createProject() async {
    final result = await showDialog<_ProjectDraft>(
      context: context,
      builder: (context) => const ProjectEditorDialog(),
    );
    if (result == null) {
      return;
    }

    try {
      final created = await widget.projectApi.createProject(
        name: result.name,
        description: result.description,
      );
      setState(() {
        _selectedProject = created;
        _workspaceMessage = '${rf('Created', '생성됨')} "${created.name}".';
        _workspaceSeverity = NoticeSeverity.success;
      });
      _reload();
      if (mounted) {
        _navigateToWorkspace(created.id);
      }
    } on ProjectApiException catch (error) {
      setState(() {
        _workspaceMessage = '${rf('Create failed', '생성 실패')}: ${error.message}';
        _workspaceSeverity = NoticeSeverity.error;
      });
    } catch (error) {
      setState(() {
        _workspaceMessage = '${rf('Create failed', '생성 실패')}: $error';
        _workspaceSeverity = NoticeSeverity.error;
      });
    }
  }

  Future<void> _openProject(RoomProject project) async {
    if (widget.initialProjectId != project.id ||
        widget.routeMode != _ProjectWorkspaceRouteMode.workspace) {
      _navigateToWorkspace(project.id);
      return;
    }

    final detail = await widget.projectApi.getProject(project.id);
    setState(() {
      _selectedProject = detail;
    });
  }

  Future<void> _editSelectedProject() async {
    final project = _selectedProject;
    if (project == null) {
      return;
    }

    final result = await showDialog<_ProjectDraft>(
      context: context,
      builder: (context) => ProjectEditorDialog(project: project),
    );
    if (result == null) {
      return;
    }

    try {
      final updated = await widget.projectApi.updateProject(
        projectId: project.id,
        name: result.name,
        description: result.description,
      );
      setState(() {
        _selectedProject = updated;
        _workspaceMessage = '${rf('Saved', '저장됨')} "${updated.name}".';
        _workspaceSeverity = NoticeSeverity.success;
      });
      _reload();
    } on ProjectApiException catch (error) {
      setState(() {
        _workspaceMessage = '${rf('Save failed', '저장 실패')}: ${error.message}';
        _workspaceSeverity = NoticeSeverity.error;
      });
    } catch (error) {
      setState(() {
        _workspaceMessage = '${rf('Save failed', '저장 실패')}: $error';
        _workspaceSeverity = NoticeSeverity.error;
      });
    }
  }

  Future<void> _deleteSelectedProject() async {
    final project = _selectedProject;
    if (project == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(rf('Delete project', '프로젝트 삭제')),
        content: Text(
          rf('Delete "${project.name}"?', '"${project.name}" 프로젝트를 삭제할까요?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(rf('Cancel', '취소')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(rf('Delete', '삭제')),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await widget.projectApi.deleteProject(project.id);
      setState(() {
        _selectedProject = null;
        _workspaceMessage = '${rf('Deleted', '삭제됨')} "${project.name}".';
        _workspaceSeverity = NoticeSeverity.success;
      });
      _reload();
      if (mounted && widget.routeMode == _ProjectWorkspaceRouteMode.workspace) {
        Navigator.of(context).pushNamed(widget.routeSpec.projectsPath);
      }
    } on ProjectApiException catch (error) {
      setState(() {
        _workspaceMessage = '${rf('Delete failed', '삭제 실패')}: ${error.message}';
        _workspaceSeverity = NoticeSeverity.error;
      });
    } catch (error) {
      setState(() {
        _workspaceMessage = '${rf('Delete failed', '삭제 실패')}: $error';
        _workspaceSeverity = NoticeSeverity.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final header = _WorkspaceHeader(
      title: widget.title,
      routeLabel: widget.routeLabel,
      displayName: widget.displayName,
      message: _workspaceMessage,
      severity: _workspaceSeverity,
      onCreateProject: _createProject,
    );
    final projectList = _ProjectListPanel(
      projectsFuture: _projectsFuture,
      selectedProjectId: _selectedProject?.id,
      onOpenProject: _openProject,
      onCreateProject: _createProject,
      onRetry: _reload,
    );
    final detail = _loadingProjectId != null && _selectedProject == null
        ? RoomForgePanel(
            child: RoomForgeLoadingState(
              title: rf('Loading workspace', '워크스페이스를 불러오는 중'),
              message: rf(
                'Project data, room inputs, and reconstruction status will appear here.',
                '프로젝트 데이터, 방 입력값, 재구성 상태가 여기에 표시됩니다.',
              ),
              panel: false,
            ),
          )
        : ProjectDetailPanel(
            project: _selectedProject,
            projectApi: widget.projectApi,
            onEdit: _editSelectedProject,
            onDelete: _deleteSelectedProject,
          );
    final mobileWorkspaceRoute =
        widget.routeSpec.isMobile &&
        widget.routeMode == _ProjectWorkspaceRouteMode.workspace &&
        widget.initialProjectId != null;
    final mobileRouteActions = mobileWorkspaceRoute
        ? _MobileWorkspaceRouteActions(
            routeSpec: widget.routeSpec,
            projectId: widget.initialProjectId!,
          )
        : null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1440),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 980;
                if (widget.routeMode == _ProjectWorkspaceRouteMode.projects) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      header,
                      const SizedBox(height: 20),
                      Expanded(child: projectList),
                    ],
                  );
                }

                if (mobileWorkspaceRoute) {
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        header,
                        const SizedBox(height: 12),
                        mobileRouteActions!,
                        const SizedBox(height: 16),
                        detail,
                      ],
                    ),
                  );
                }

                if (compact) {
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        header,
                        const SizedBox(height: 16),
                        SizedBox(height: 420, child: projectList),
                        const SizedBox(height: 16),
                        detail,
                      ],
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    const SizedBox(height: 20),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 5, child: projectList),
                          const SizedBox(width: 16),
                          Expanded(flex: 4, child: detail),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({
    required this.title,
    required this.routeLabel,
    required this.displayName,
    required this.severity,
    required this.onCreateProject,
    this.message,
  });

  final String title;
  final String routeLabel;
  final String displayName;
  final NoticeSeverity severity;
  final VoidCallback onCreateProject;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final createButton = FilledButton.icon(
      onPressed: onCreateProject,
      icon: const Icon(Icons.add),
      label: Text(rf('Create project', '프로젝트 생성')),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 680;
            final titleBlock = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    RoomForgeStatusPill(
                      label: routeLabel,
                      color: _roomForgeAdmin,
                      dense: true,
                    ),
                    RoomForgeStatusPill(
                      label: rf('Cloud workspace', '클라우드 작업공간'),
                      color: _roomForgeSave,
                      dense: true,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: _roomForgeInk,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${rf('Signed in as', '로그인 계정')}: $displayName',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: _roomForgeMuted,
                  ),
                ),
              ],
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  titleBlock,
                  const SizedBox(height: 12),
                  SizedBox(height: 48, child: createButton),
                  const SizedBox(height: 12),
                  _ResponsiveLayoutModeStrip(width: constraints.maxWidth),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: titleBlock),
                    const SizedBox(width: 12),
                    createButton,
                  ],
                ),
                const SizedBox(height: 12),
                _ResponsiveLayoutModeStrip(width: constraints.maxWidth),
              ],
            );
          },
        ),
        if (message != null) ...[
          const SizedBox(height: 12),
          RoomForgeNotice(
            title: severity == NoticeSeverity.error
                ? rf('Project change failed', '프로젝트 변경 실패')
                : rf('Project updated', '프로젝트 업데이트됨'),
            message: message!,
            severity: severity,
            icon: severity == NoticeSeverity.error
                ? Icons.error_outline
                : Icons.check_circle_outline,
          ),
        ],
      ],
    );
  }
}

class _MobileWorkspaceRouteActions extends StatelessWidget {
  const _MobileWorkspaceRouteActions({
    required this.routeSpec,
    required this.projectId,
  });

  final _RoomForgeRouteSpec routeSpec;
  final String projectId;

  @override
  Widget build(BuildContext context) {
    return RoomForgePanel(
      padding: const EdgeInsets.all(10),
      backgroundColor: _roomForgePanel,
      borderColor: _roomForgeBorder,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _MobileWorkspaceRouteButton(
            label: rf('Overview', '개요'),
            icon: Icons.view_agenda_outlined,
            active: routeSpec.section == 'workspace',
            route: routeSpec.workspacePath(projectId),
          ),
          _MobileWorkspaceRouteButton(
            label: rf('Capture', '촬영'),
            icon: Icons.add_a_photo_outlined,
            active: routeSpec.section == 'capture',
            route: routeSpec.workspacePath(projectId, childRoute: 'capture'),
          ),
          _MobileWorkspaceRouteButton(
            label: rf('Status', '상태'),
            icon: Icons.timeline_outlined,
            active: routeSpec.section == 'status',
            route: routeSpec.workspacePath(projectId, childRoute: 'status'),
          ),
          _MobileWorkspaceRouteButton(
            label: rf('Review', '검토'),
            icon: Icons.rate_review_outlined,
            active: routeSpec.section == 'review',
            route: routeSpec.workspacePath(projectId, childRoute: 'review'),
          ),
        ],
      ),
    );
  }
}

class _MobileWorkspaceRouteButton extends StatelessWidget {
  const _MobileWorkspaceRouteButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.route,
  });

  final String label;
  final IconData icon;
  final bool active;
  final String route;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 18), const SizedBox(width: 7), Text(label)],
    );

    if (active) {
      return FilledButton(
        onPressed: null,
        style: FilledButton.styleFrom(
          disabledBackgroundColor: _roomForgePrimary.withValues(alpha: .22),
          disabledForegroundColor: _roomForgeInk,
          minimumSize: const Size(0, 46),
        ),
        child: content,
      );
    }

    return OutlinedButton(
      onPressed: () => Navigator.of(context).pushNamed(route),
      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
      child: content,
    );
  }
}

class _ResponsiveLayoutModeStrip extends StatelessWidget {
  const _ResponsiveLayoutModeStrip({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final motionReduced = media.disableAnimations || media.accessibleNavigation;
    final activeMode = _responsiveModeForWidth(width);
    final modes = [
      _ResponsiveLayoutMode(
        id: 'mobile',
        label: rf('mobile', '모바일'),
        detail: rf('capture first', '촬영 우선'),
        color: _roomForgePrimary,
      ),
      _ResponsiveLayoutMode(
        id: 'tablet',
        label: rf('tablet', '태블릿'),
        detail: rf('review tray', '리뷰 tray'),
        color: _roomForgeMeasure,
      ),
      _ResponsiveLayoutMode(
        id: 'desktop',
        label: rf('desktop', '데스크톱'),
        detail: rf('editor shell', '편집 shell'),
        color: _roomForgeSuccess,
      ),
      _ResponsiveLayoutMode(
        id: 'wide',
        label: rf('wide ops', 'wide ops'),
        detail: rf('admin split', '관리자 split'),
        color: _roomForgeAdmin,
      ),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final mode in modes)
          RoomForgeStatusPill(
            label: mode.id == activeMode
                ? '${mode.label} · ${mode.detail}'
                : mode.label,
            color: mode.id == activeMode ? mode.color : _roomForgeMuted,
            icon: mode.id == activeMode ? Icons.check_circle_outline : null,
            dense: true,
          ),
        RoomForgeStatusPill(
          label: motionReduced
              ? rf('reduced motion', 'reduced motion')
              : rf('motion normal', 'motion normal'),
          color: motionReduced ? _roomForgeAdmin : _roomForgeMuted,
          icon: motionReduced
              ? Icons.motion_photos_off_outlined
              : Icons.motion_photos_on_outlined,
          dense: true,
        ),
      ],
    );
  }
}

class _ResponsiveLayoutMode {
  const _ResponsiveLayoutMode({
    required this.id,
    required this.label,
    required this.detail,
    required this.color,
  });

  final String id;
  final String label;
  final String detail;
  final Color color;
}

String _responsiveModeForWidth(double width) {
  if (width < 600) {
    return 'mobile';
  }
  if (width < 980) {
    return 'tablet';
  }
  if (width < 1280) {
    return 'desktop';
  }
  return 'wide';
}

class _ProjectListPanel extends StatelessWidget {
  const _ProjectListPanel({
    required this.projectsFuture,
    required this.selectedProjectId,
    required this.onOpenProject,
    required this.onCreateProject,
    required this.onRetry,
  });

  final Future<List<RoomProject>> projectsFuture;
  final String? selectedProjectId;
  final ValueChanged<RoomProject> onOpenProject;
  final VoidCallback onCreateProject;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RoomForgePanel(
      padding: EdgeInsets.zero,
      backgroundColor: _roomForgePanel,
      borderColor: _roomForgeBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  rf('My projects', '내 프로젝트'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: _roomForgeInk,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                RoomForgeStatusPill(
                  label: rf('Cloud saved', '클라우드 저장'),
                  icon: Icons.cloud_done_outlined,
                  dense: true,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 18),
                    hintText: rf('Search by name or state', '이름·상태로 검색'),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    RoomForgeStatusPill(
                      label: rf('All', '전체'),
                      color: _roomForgePrimary,
                      dense: true,
                    ),
                    RoomForgeStatusPill(
                      label: rf('Processing', '처리 중'),
                      color: _roomForgeSave,
                      dense: true,
                    ),
                    RoomForgeStatusPill(
                      label: rf('Needs review', '검토 필요'),
                      color: _roomForgeWarning,
                      dense: true,
                    ),
                    RoomForgeStatusPill(
                      label: rf('Complete', '완료'),
                      color: _roomForgeSuccess,
                      dense: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<RoomProject>>(
              future: projectsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _ProjectListLoadingState();
                }
                if (snapshot.hasError) {
                  return ProjectErrorView(
                    message: snapshot.error.toString(),
                    onRetry: onRetry,
                  );
                }

                final projects = snapshot.data ?? const <RoomProject>[];
                if (projects.isEmpty) {
                  return RoomForgeEmptyState(
                    icon: Icons.add_home_work_outlined,
                    title: rf('No room projects yet', '아직 방 프로젝트가 없습니다'),
                    message: rf(
                      'Start from a room photo, then add dimensions, reconstruction review, and layout saves.',
                      '방 사진에서 시작한 뒤 치수, 재구성 검토, 레이아웃 저장을 이어서 진행하세요.',
                    ),
                    action: FilledButton.icon(
                      onPressed: onCreateProject,
                      icon: const Icon(Icons.add),
                      label: Text(rf('Create first project', '첫 프로젝트 생성')),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: projects.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final project = projects[index];
                    final isSelected = selectedProjectId == project.id;
                    return _ProjectListTile(
                      project: project,
                      selected: isSelected,
                      onTap: () => onOpenProject(project),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectListLoadingState extends StatelessWidget {
  const _ProjectListLoadingState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: RoomForgeLoadingState(
        title: rf('Loading saved room projects', '저장된 방 프로젝트를 불러오는 중'),
        message: rf(
          'Saved projects, latest room status, and cloud metadata will appear here.',
          '저장된 프로젝트, 최신 방 상태, 클라우드 메타데이터가 여기에 표시됩니다.',
        ),
        panel: false,
      ),
    );
  }
}

class _ProjectListTile extends StatelessWidget {
  const _ProjectListTile({
    required this.project,
    required this.selected,
    required this.onTap,
  });

  final RoomProject project;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = project.description?.trim();

    return Material(
      color: selected
          ? _roomForgePrimary.withValues(alpha: 0.12)
          : _roomForgePanel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: selected ? _roomForgePrimary : _roomForgeBorder,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _ProjectThumbnail(selected: selected),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: _roomForgeInk,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description?.isNotEmpty == true
                          ? description!
                          : rf('No description', '설명 없음'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _roomForgeMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${rf('Updated', '수정됨')} ${_compactDateLabel(project.updatedAt)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: _roomForgeMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected ? Icons.check_circle : Icons.chevron_right,
                color: selected ? _roomForgePrimary : _roomForgeMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectThumbnail extends StatelessWidget {
  const _ProjectThumbnail({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final accent = selected ? _roomForgePrimary : _roomForgeAdmin;
    return Container(
      width: 92,
      height: 70,
      decoration: BoxDecoration(
        color: _roomForgeCanvas,
        border: Border.all(color: _roomForgeBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: _RoomForgeGridBackdrop()),
          Positioned(
            left: 14,
            right: 14,
            top: 14,
            bottom: 14,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _roomForgeLightSurface.withValues(alpha: .28),
                border: Border.all(color: _roomForgeInk, width: 1.5),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          Positioned(
            left: 28,
            top: 24,
            width: 28,
            height: 24,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .18),
                border: Border.all(color: accent, width: 1.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectDetailPreview extends StatelessWidget {
  const _ProjectDetailPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: _roomForgeCanvas,
        border: Border.all(color: _roomForgeBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: _RoomForgeGridBackdrop()),
          Positioned(
            left: 36,
            right: 36,
            top: 48,
            bottom: 32,
            child: Transform(
              alignment: Alignment.bottomCenter,
              transform: Matrix4.identity()
                ..setEntry(3, 2, .0012)
                ..rotateX(.78),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _roomForgeLightSurface.withValues(alpha: .30),
                  border: Border.all(color: _roomForgeInk, width: 2.5),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ),
          Positioned(
            left: 116,
            top: 82,
            width: 86,
            height: 54,
            child: Transform(
              alignment: Alignment.bottomCenter,
              transform: Matrix4.identity()
                ..setEntry(3, 2, .0012)
                ..rotateX(.78),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _roomForgePrimary.withValues(alpha: .18),
                  border: Border.all(color: _roomForgePrimary, width: 2),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            top: 14,
            child: RoomForgeStatusPill(
              label: rf('meters', 'meters'),
              color: _roomForgeMeasure,
              dense: true,
            ),
          ),
        ],
      ),
    );
  }
}

class ProjectDetailPanel extends StatefulWidget {
  const ProjectDetailPanel({
    required this.project,
    required this.projectApi,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final RoomProject? project;
  final ProjectApi projectApi;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<ProjectDetailPanel> createState() => _ProjectDetailPanelState();
}

class _ProjectDetailPanelState extends State<ProjectDetailPanel> {
  static const _allowedImageTypes = {'image/jpeg', 'image/png', 'image/webp'};
  static const _maxImageBytes = 10 * 1024 * 1024;
  static const _lowQualityImageBytes = 100 * 1024;

  final _dimensionFormKey = GlobalKey<FormState>();
  final _widthController = TextEditingController();
  final _depthController = TextEditingController();
  final _heightController = TextEditingController();
  final _arCoreDepthCapabilityProvider = const ArCoreDepthCapabilityProvider();

  SourceImage? _sourceImage;
  String? _sourceImageDataUrl;
  RoomDimensions? _dimensions;
  ReconstructionJob? _reconstructionJob;
  CaptureSession? _captureSession;
  SourceImageUploadStatus _uploadState = SourceImageUploadStatus.empty;
  String? _uploadMessage;
  double? _uploadProgress;
  html.File? _lastUploadFile;
  final Map<String, GuidedCaptureRoleUploadSnapshot> _guidedRoleUploads = {};
  final Map<String, html.File> _lastGuidedRoleFiles = {};
  ArCoreDepthCapability _arCoreDepthCapability =
      const ArCoreDepthCapability.unsupported();
  bool _isSavingDimensions = false;
  bool _isSubmittingReconstruction = false;
  bool _isCreatingCaptureSession = false;
  bool _guidedCaptureStarted = false;
  bool _depthEnhancementEnabled = false;
  String? _dimensionMessage;
  String? _captureSessionMessage;
  String? _reconstructionMessage;
  StreamSubscription<html.MouseEvent>? _dragOverSubscription;
  StreamSubscription<html.MouseEvent>? _dragLeaveSubscription;
  StreamSubscription<html.MouseEvent>? _dropSubscription;
  Timer? _reconstructionPollTimer;

  @override
  void initState() {
    super.initState();
    if (widget.project != null) {
      unawaited(_loadDimensions());
      unawaited(_loadLatestCaptureSession());
      unawaited(_loadArCoreDepthCapability());
    }
    final body = html.document.body;
    if (body == null) {
      return;
    }
    _dragOverSubscription = body.onDragOver.listen(_handleDragOver);
    _dragLeaveSubscription = body.onDragLeave.listen(_handleDragLeave);
    _dropSubscription = body.onDrop.listen(_handleDrop);
  }

  @override
  void didUpdateWidget(ProjectDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project?.id != widget.project?.id) {
      _sourceImage = null;
      _sourceImageDataUrl = null;
      _dimensions = null;
      _reconstructionJob = null;
      _captureSession = null;
      _uploadState = SourceImageUploadStatus.empty;
      _uploadMessage = null;
      _uploadProgress = null;
      _lastUploadFile = null;
      _guidedRoleUploads.clear();
      _lastGuidedRoleFiles.clear();
      _arCoreDepthCapability = const ArCoreDepthCapability.unsupported();
      _depthEnhancementEnabled = false;
      _guidedCaptureStarted = false;
      _captureSessionMessage = null;
      _dimensionMessage = null;
      _reconstructionMessage = null;
      _widthController.clear();
      _depthController.clear();
      _heightController.clear();
      _reconstructionPollTimer?.cancel();
      if (widget.project != null) {
        unawaited(_loadDimensions());
        unawaited(_loadLatestCaptureSession());
        unawaited(_loadArCoreDepthCapability());
      }
    }
  }

  @override
  void dispose() {
    _dragOverSubscription?.cancel();
    _dragLeaveSubscription?.cancel();
    _dropSubscription?.cancel();
    _reconstructionPollTimer?.cancel();
    _widthController.dispose();
    _depthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _handleDragOver(html.MouseEvent event) {
    if (widget.project == null) {
      return;
    }
    event.preventDefault();
    if (_uploadState == SourceImageUploadStatus.uploading) {
      return;
    }
    setState(() {
      _uploadState = SourceImageUploadStatus.ready;
      _uploadMessage = rf(
        'Drop a JPEG, PNG, or WebP room photo.',
        'JPEG, PNG, WebP 방 사진을 놓으세요.',
      );
      _uploadProgress = null;
    });
  }

  void _handleDragLeave(html.MouseEvent event) {
    if (widget.project == null ||
        _uploadState != SourceImageUploadStatus.ready) {
      return;
    }
    setState(() {
      _uploadState = _sourceImage == null
          ? SourceImageUploadStatus.empty
          : SourceImageUploadStatus.uploaded;
      _uploadMessage = _sourceImage == null ? null : _uploadMessage;
      _uploadProgress = null;
    });
  }

  void _handleDrop(html.MouseEvent event) {
    if (widget.project == null) {
      return;
    }
    event.preventDefault();
    if (_uploadState == SourceImageUploadStatus.uploading) {
      return;
    }
    final files = event.dataTransfer.files;
    final file = files?.isNotEmpty == true ? files!.first : null;
    if (file == null) {
      setState(() {
        _uploadState = SourceImageUploadStatus.validationError;
        _uploadMessage = rf(
          'Drop one supported room photo file.',
          '지원되는 방 사진 파일 하나를 놓으세요.',
        );
        _uploadProgress = null;
      });
      return;
    }
    unawaited(_uploadFile(file));
  }

  Future<void> _selectAndUploadImage() async {
    final project = widget.project;
    if (project == null || _uploadState == SourceImageUploadStatus.uploading) {
      return;
    }

    setState(() {
      _uploadState = SourceImageUploadStatus.ready;
      _uploadMessage = rf(
        'Select a JPEG, PNG, or WebP room photo.',
        'JPEG, PNG, WebP 방 사진을 선택하세요.',
      );
      _uploadProgress = null;
    });

    final input = html.FileUploadInputElement()
      ..accept = _allowedImageTypes.join(',')
      ..multiple = false;
    input.click();
    await input.onChange.first;

    final file = input.files?.isNotEmpty == true ? input.files!.first : null;
    if (file == null) {
      setState(() {
        _uploadState = _sourceImage == null
            ? SourceImageUploadStatus.empty
            : SourceImageUploadStatus.uploaded;
        _uploadMessage = _sourceImage == null ? null : _uploadMessage;
        _uploadProgress = null;
      });
      return;
    }

    await _uploadFile(file);
  }

  Future<void> _retryUpload() async {
    final file = _lastUploadFile;
    if (file == null ||
        widget.project == null ||
        _uploadState == SourceImageUploadStatus.uploading) {
      return;
    }
    await _uploadFile(file);
  }

  Future<void> _uploadFile(html.File file) async {
    final project = widget.project;
    if (project == null || _uploadState == SourceImageUploadStatus.uploading) {
      return;
    }

    final contentType = _normalizedContentType(file);
    final validationMessage = _clientImageValidationMessage(file, contentType);
    if (validationMessage != null) {
      setState(() {
        _uploadState = SourceImageUploadStatus.validationError;
        _uploadMessage = validationMessage;
        _uploadProgress = null;
        _lastUploadFile = null;
        _sourceImage = null;
        _sourceImageDataUrl = null;
      });
      return;
    }

    setState(() {
      _uploadState = SourceImageUploadStatus.uploading;
      _uploadMessage = file.size < _lowQualityImageBytes
          ? rf(
              'Uploading. Low-quality warning: this file is small. Use a sharper, brighter image if reconstruction looks weak.',
              '업로드 중입니다. 파일이 작아 품질 경고가 있습니다. 재구성이 약하면 더 선명하고 밝은 이미지를 사용하세요.',
            )
          : rf(
              'Uploading source image to cloud storage.',
              '소스 이미지를 클라우드 저장소에 업로드 중입니다.',
            );
      _uploadProgress = 0;
      _lastUploadFile = file;
    });

    try {
      final bytes = await _readFileBytes(file);
      final sourceImageDataUrl =
          'data:$contentType;base64,${base64Encode(bytes)}';
      final imageSize = await _readImageSize(file);
      final sourceImage = await widget.projectApi.uploadSourceImage(
        projectId: project.id,
        filename: file.name,
        contentType: contentType,
        bytes: bytes,
        widthPx: imageSize?.width,
        heightPx: imageSize?.height,
        onProgress: (progress) {
          if (!mounted) {
            return;
          }
          setState(() {
            _uploadState = SourceImageUploadStatus.uploading;
            _uploadProgress = progress.clamp(0, 1).toDouble();
            _uploadMessage = _localizedUploadProgressLabel(_uploadProgress);
          });
        },
      );
      setState(() {
        _sourceImage = sourceImage;
        _sourceImageDataUrl = sourceImageDataUrl;
        _uploadState = SourceImageUploadStatus.uploaded;
        _uploadMessage = imageSize == null
            ? rf(
                'Uploaded. Image dimensions were not available from the browser.',
                '업로드되었습니다. 브라우저에서 이미지 크기를 확인하지 못했습니다.',
              )
            : rf(
                'Uploaded ${imageSize.width} x ${imageSize.height}px source image.',
                '${imageSize.width} x ${imageSize.height}px 소스 이미지를 업로드했습니다.',
              );
        _uploadProgress = 1;
        _lastUploadFile = null;
      });
    } on ProjectApiException catch (error) {
      setState(() {
        _uploadState = uploadStatusForProjectApiException(error);
        _uploadMessage = uploadRecoveryMessage(error);
        _uploadProgress = null;
        _sourceImage = null;
        _sourceImageDataUrl = null;
        if (_uploadState == SourceImageUploadStatus.validationError) {
          _lastUploadFile = null;
        }
      });
    } catch (error) {
      setState(() {
        _uploadState = SourceImageUploadStatus.uploadFailed;
        _uploadMessage = '${rf('Upload failed', '업로드 실패')}: $error';
        _uploadProgress = null;
        _sourceImage = null;
        _sourceImageDataUrl = null;
      });
    }
  }

  Future<void> _saveDimensions() async {
    final project = widget.project;
    if (project == null || !_dimensionFormKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSavingDimensions = true;
      _dimensionMessage = null;
    });

    try {
      final dimensions = await widget.projectApi.saveRoomDimensions(
        projectId: project.id,
        widthValue: double.parse(_widthController.text.trim()),
        depthValue: double.parse(_depthController.text.trim()),
        heightValue: _heightController.text.trim().isEmpty
            ? null
            : double.parse(_heightController.text.trim()),
      );
      setState(() {
        _dimensions = dimensions;
        _dimensionMessage = dimensions.usesDefaultHeight
            ? rf(
                'Saved with MVP default height ${dimensions.heightValue.toStringAsFixed(2)} m.',
                'MVP 기본 높이 ${dimensions.heightValue.toStringAsFixed(2)} m로 저장했습니다.',
              )
            : rf('Saved room dimensions.', '방 치수를 저장했습니다.');
      });
    } on ProjectApiException catch (error) {
      setState(() => _dimensionMessage = error.message);
    } catch (error) {
      setState(
        () => _dimensionMessage =
            '${rf('Saving dimensions failed', '치수 저장 실패')}: $error',
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingDimensions = false);
      }
    }
  }

  Future<void> _loadArCoreDepthCapability() async {
    final project = widget.project;
    if (project == null) {
      return;
    }
    final capability = await _arCoreDepthCapabilityProvider.check();
    if (!mounted || widget.project?.id != project.id) {
      return;
    }
    setState(() {
      _arCoreDepthCapability = capability;
      if (!capability.canEnableDepth) {
        _depthEnhancementEnabled = false;
      }
    });
  }

  Future<void> _startGuidedCaptureSession() async {
    final project = widget.project;
    if (project == null) {
      return;
    }
    if (_dimensions == null) {
      setState(() {
        _dimensionMessage = rf(
          'Save room dimensions before starting guided capture.',
          '가이드 촬영을 시작하기 전에 방 치수를 저장하세요.',
        );
      });
      return;
    }
    if (_isCreatingCaptureSession) {
      return;
    }
    final existingSession = _captureSession;
    if (existingSession != null) {
      setState(() {
        _guidedCaptureStarted = true;
        _captureSessionMessage =
            '${rf('Capture session ready', '촬영 세션 준비됨')}: ${existingSession.id}';
      });
      return;
    }

    setState(() {
      _isCreatingCaptureSession = true;
      _captureSessionMessage = rf(
        'Creating guided capture session...',
        '가이드 촬영 세션을 생성 중입니다...',
      );
    });

    try {
      final session = await widget.projectApi.createCaptureSession(
        projectId: project.id,
        depthEnabled:
            _arCoreDepthCapability.canEnableDepth && _depthEnhancementEnabled,
      );
      setState(() {
        _captureSession = session;
        _guidedCaptureStarted = true;
        _captureSessionMessage =
            '${rf('Capture session ready', '촬영 세션 준비됨')}: ${session.id}';
      });
    } on ProjectApiException catch (error) {
      setState(() => _captureSessionMessage = error.message);
    } catch (error) {
      setState(
        () => _captureSessionMessage =
            '${rf('Capture session failed', '촬영 세션 생성 실패')}: $error',
      );
    } finally {
      if (mounted) {
        setState(() => _isCreatingCaptureSession = false);
      }
    }
  }

  Future<void> _selectAndUploadGuidedRole(String roleId) async {
    if (_captureSession == null) {
      await _startGuidedCaptureSession();
    }
    if (_captureSession == null) {
      return;
    }

    final input = html.FileUploadInputElement()
      ..accept = _allowedImageTypes.join(',')
      ..multiple = false;
    input.click();
    await input.onChange.first;

    final file = input.files?.isNotEmpty == true ? input.files!.first : null;
    if (file == null) {
      return;
    }
    await _uploadGuidedRoleFile(roleId, file);
  }

  Future<void> _retryGuidedRoleUpload(String roleId) async {
    final file = _lastGuidedRoleFiles[roleId];
    if (file == null) {
      setState(() {
        _guidedRoleUploads[roleId] = GuidedCaptureRoleUploadSnapshot(
          status: SourceImageUploadStatus.uploadFailed,
          image: _guidedRoleUploads[roleId]?.image,
          message: rf(
            'Choose a photo again before retrying this role.',
            '이 역할을 다시 시도하려면 사진을 다시 선택하세요.',
          ),
        );
      });
      return;
    }
    await _uploadGuidedRoleFile(roleId, file);
  }

  Future<void> _uploadGuidedRoleFile(String roleId, html.File file) async {
    final project = widget.project;
    final session = _captureSession;
    if (project == null || session == null) {
      return;
    }

    final contentType = _normalizedContentType(file);
    final validationMessage = _clientImageValidationMessage(file, contentType);
    if (validationMessage != null) {
      setState(() {
        _lastGuidedRoleFiles.remove(roleId);
        _guidedRoleUploads[roleId] = GuidedCaptureRoleUploadSnapshot(
          status: SourceImageUploadStatus.validationError,
          image: _guidedRoleUploads[roleId]?.image,
          message: validationMessage,
        );
      });
      return;
    }

    setState(() {
      _lastGuidedRoleFiles[roleId] = file;
      _guidedRoleUploads[roleId] = GuidedCaptureRoleUploadSnapshot(
        status: SourceImageUploadStatus.uploading,
        image: _guidedRoleUploads[roleId]?.image,
        message: rf('Uploading role photo...', '역할 사진을 업로드 중입니다...'),
      );
    });

    try {
      final bytes = await _readFileBytes(file);
      final imageSize = await _readImageSize(file);
      final captureImage = await widget.projectApi.uploadCaptureImage(
        projectId: project.id,
        captureSessionId: session.id,
        role: roleId,
        filename: file.name,
        contentType: contentType,
        bytes: bytes,
        widthPx: imageSize?.width,
        heightPx: imageSize?.height,
        captureOrder: _guidedRoleCaptureOrder(roleId),
        onProgress: (progress) {
          if (!mounted) {
            return;
          }
          setState(() {
            _guidedRoleUploads[roleId] = GuidedCaptureRoleUploadSnapshot(
              status: SourceImageUploadStatus.uploading,
              image: _guidedRoleUploads[roleId]?.image,
              message: _localizedUploadProgressLabel(
                progress.clamp(0, 1).toDouble(),
              ),
            );
          });
        },
      );
      setState(() {
        _lastGuidedRoleFiles.remove(roleId);
        _guidedRoleUploads[roleId] = GuidedCaptureRoleUploadSnapshot(
          status: SourceImageUploadStatus.uploaded,
          image: captureImage,
          message:
              '${rf('Uploaded', '업로드됨')}: ${captureImage.role} (${captureImage.widthPx} x ${captureImage.heightPx}px)',
        );
      });
    } on ProjectApiException catch (error) {
      setState(() {
        _guidedRoleUploads[roleId] = GuidedCaptureRoleUploadSnapshot(
          status: uploadStatusForProjectApiException(error),
          image: _guidedRoleUploads[roleId]?.image,
          message: uploadRecoveryMessage(error),
        );
      });
    } catch (error) {
      setState(() {
        _guidedRoleUploads[roleId] = GuidedCaptureRoleUploadSnapshot(
          status: SourceImageUploadStatus.uploadFailed,
          image: _guidedRoleUploads[roleId]?.image,
          message: '${rf('Upload failed', '업로드 실패')}: $error',
        );
      });
    }
  }

  Future<void> _loadDimensions() async {
    final project = widget.project;
    if (project == null) {
      return;
    }

    try {
      final dimensions = await widget.projectApi.getRoomDimensions(
        projectId: project.id,
      );
      if (!mounted || widget.project?.id != project.id) {
        return;
      }
      if (dimensions == null) {
        return;
      }
      setState(() {
        _dimensions = dimensions;
        _widthController.text = dimensions.widthValue.toString();
        _depthController.text = dimensions.depthValue.toString();
        _heightController.text = dimensions.usesDefaultHeight
            ? ''
            : dimensions.heightValue.toString();
        _dimensionMessage = dimensions.usesDefaultHeight
            ? rf(
                'Loaded saved dimensions with MVP default height ${dimensions.heightValue.toStringAsFixed(2)} m.',
                '저장된 치수를 MVP 기본 높이 ${dimensions.heightValue.toStringAsFixed(2)} m와 함께 불러왔습니다.',
              )
            : rf('Loaded saved room dimensions.', '저장된 방 치수를 불러왔습니다.');
      });
    } on ProjectApiException catch (error) {
      if (!mounted || widget.project?.id != project.id) {
        return;
      }
      if (error.code == 'not_found') {
        return;
      }
      setState(() => _dimensionMessage = error.message);
    } catch (error) {
      if (!mounted || widget.project?.id != project.id) {
        return;
      }
      setState(
        () => _dimensionMessage =
            '${rf('Loading dimensions failed', '치수 불러오기 실패')}: $error',
      );
    }
  }

  Future<void> _loadLatestCaptureSession() async {
    final project = widget.project;
    if (project == null) {
      return;
    }

    try {
      final snapshot = await widget.projectApi.loadLatestCaptureSession(
        projectId: project.id,
      );
      if (!mounted || widget.project?.id != project.id || snapshot == null) {
        return;
      }
      final roleUploads = <String, GuidedCaptureRoleUploadSnapshot>{
        for (final image in snapshot.images)
          image.role: GuidedCaptureRoleUploadSnapshot(
            status: SourceImageUploadStatus.uploaded,
            image: image,
            message:
                '${rf('Uploaded', '업로드됨')}: ${image.role} (${image.widthPx} x ${image.heightPx}px)',
          ),
      };
      setState(() {
        _captureSession = snapshot.session;
        _guidedCaptureStarted = true;
        _depthEnhancementEnabled = snapshot.session.depthEnabled;
        _guidedRoleUploads
          ..clear()
          ..addAll(roleUploads);
        _captureSessionMessage = rf(
          'Loaded guided capture session for desktop review.',
          '데스크톱 검토용 가이드 촬영 세션을 불러왔습니다.',
        );
      });
    } on ProjectApiException catch (error) {
      if (!mounted || widget.project?.id != project.id) {
        return;
      }
      setState(() => _captureSessionMessage = error.message);
    } catch (error) {
      if (!mounted || widget.project?.id != project.id) {
        return;
      }
      setState(
        () => _captureSessionMessage =
            '${rf('Loading capture session failed', '촬영 세션 불러오기 실패')}: $error',
      );
    }
  }

  List<CaptureImage> get _uploadedCaptureImages {
    final imagesByRole = {
      for (final entry in _guidedRoleUploads.entries)
        if (entry.value.image != null) entry.key: entry.value.image!,
    };
    return [
      for (final role in defaultGuidedCaptureRoles)
        if (imagesByRole.remove(role.id) != null)
          _guidedRoleUploads[role.id]!.image!,
      ...imagesByRole.values,
    ];
  }

  Future<void> _openReconstruction() async {
    final project = widget.project;
    if (project == null) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => EditorBridgeScreen(
          project: project,
          projectApi: widget.projectApi,
          initialDimensions: _dimensions,
          reconstructionJob: _reconstructionJob,
          sourceImage: _sourceImage,
          sourceImageDataUrl: _sourceImageDataUrl,
          captureSession: _captureSession,
          captureImages: _uploadedCaptureImages,
        ),
      ),
    );
  }

  Future<void> _submitReconstruction() async {
    final project = widget.project;
    final sourceImage = _sourceImage;
    if (project == null || sourceImage == null) {
      setState(() {
        _reconstructionMessage = rf(
          'Upload a source image before submitting reconstruction.',
          '재구성을 제출하기 전에 소스 이미지를 업로드하세요.',
        );
      });
      return;
    }
    if (_dimensions == null) {
      setState(() {
        _reconstructionMessage = rf(
          'Save room dimensions before submitting reconstruction.',
          '재구성을 제출하기 전에 방 치수를 저장하세요.',
        );
      });
      return;
    }

    setState(() {
      _isSubmittingReconstruction = true;
      _reconstructionMessage = null;
    });

    try {
      final job = await widget.projectApi.createReconstructionJob(
        projectId: project.id,
        sourceImageId: sourceImage.id,
      );
      setState(() {
        _reconstructionJob = job;
        _reconstructionMessage = _localizedReconstructionStatusLabel(
          job.status,
        );
      });
      _startReconstructionPolling(job.id);
    } on ProjectApiException catch (error) {
      setState(() => _reconstructionMessage = error.message);
    } catch (error) {
      setState(
        () => _reconstructionMessage =
            '${rf('Reconstruction submit failed', '재구성 제출 실패')}: $error',
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmittingReconstruction = false);
      }
    }
  }

  void _startReconstructionPolling(String jobId) {
    _reconstructionPollTimer?.cancel();
    _reconstructionPollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_pollReconstructionJob(jobId));
    });
  }

  Future<void> _pollReconstructionJob(String jobId) async {
    final project = widget.project;
    if (project == null) {
      return;
    }

    try {
      final job = await widget.projectApi.getReconstructionJob(
        projectId: project.id,
        jobId: jobId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _reconstructionJob = job;
        _reconstructionMessage = _localizedReconstructionStatusLabel(
          job.status,
        );
      });
      if (job.terminal) {
        _reconstructionPollTimer?.cancel();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(
        () => _reconstructionMessage =
            '${rf('Status refresh failed', '상태 새로고침 실패')}: $error',
      );
    }
  }

  Future<void> _retryReconstruction() async {
    final project = widget.project;
    final job = _reconstructionJob;
    if (project == null || job == null) {
      return;
    }

    setState(() {
      _isSubmittingReconstruction = true;
      _reconstructionMessage = null;
    });

    try {
      final retryJob = await widget.projectApi.retryReconstructionJob(
        projectId: project.id,
        jobId: job.id,
      );
      setState(() {
        _reconstructionJob = retryJob;
        _reconstructionMessage =
            '${rf('Retry available', '재시도 가능')}: ${_localizedReconstructionStatusLabel(retryJob.status)}';
      });
      _startReconstructionPolling(retryJob.id);
    } on ProjectApiException catch (error) {
      setState(() => _reconstructionMessage = error.message);
    } catch (error) {
      setState(
        () =>
            _reconstructionMessage = '${rf('Retry failed', '재시도 실패')}: $error',
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmittingReconstruction = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    if (project == null) {
      return RoomForgeEmptyState(
        icon: Icons.dashboard_customize_outlined,
        title: rf('Select a project', '프로젝트를 선택하세요'),
        message: rf(
          'Project details, upload state, room dimensions, reconstruction status, and editor entry appear here.',
          '프로젝트 상세, 업로드 상태, 방 치수, 재구성 상태, 편집기 진입점이 여기에 표시됩니다.',
        ),
      );
    }

    final theme = Theme.of(context);
    final description = project.description?.trim();

    return RoomForgePanel(
      padding: EdgeInsets.zero,
      backgroundColor: _roomForgePanel,
      borderColor: _roomForgeBorder,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: _roomForgeInk,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          description?.isNotEmpty == true
                              ? description!
                              : rf('No description', '설명 없음'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: _roomForgeMuted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  RoomForgeStatusPill(
                    label: rf('Selected', '선택됨'),
                    icon: Icons.check_circle_outline,
                    dense: true,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const _ProjectDetailPreview(),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: 160,
                    child: RoomForgeMetricTile(
                      icon: Icons.schedule_outlined,
                      label: rf('Updated', '수정됨'),
                      value: _compactDateLabel(project.updatedAt),
                    ),
                  ),
                  SizedBox(
                    width: 160,
                    child: RoomForgeMetricTile(
                      icon: Icons.event_available_outlined,
                      label: rf('Created', '생성됨'),
                      value: _compactDateLabel(project.createdAt),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${rf('Project ID', '프로젝트 ID')}: ${project.id}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: _roomForgeMuted,
                ),
              ),
              const SizedBox(height: 20),
              RoomDimensionsSection(
                formKey: _dimensionFormKey,
                widthController: _widthController,
                depthController: _depthController,
                heightController: _heightController,
                dimensions: _dimensions,
                message: _dimensionMessage,
                isSaving: _isSavingDimensions,
                onSave: _saveDimensions,
              ),
              const SizedBox(height: 20),
              GuidedCaptureSessionSection(
                dimensions: _dimensions,
                started: _guidedCaptureStarted,
                onStart: () => unawaited(_startGuidedCaptureSession()),
                copy: _guidedCaptureCopy(),
                roles: _guidedCaptureRoles(),
                roleUploads: _guidedRoleUploads,
                depthCapability: _arCoreDepthCapability,
                depthEnhancementEnabled: _depthEnhancementEnabled,
                onDepthEnhancementChanged: (value) {
                  setState(() => _depthEnhancementEnabled = value);
                },
                onUploadRole: (role) =>
                    unawaited(_selectAndUploadGuidedRole(role.id)),
                onRetryRole: (role) =>
                    unawaited(_retryGuidedRoleUpload(role.id)),
              ),
              if (_captureSessionMessage != null) ...[
                const SizedBox(height: 12),
                RoomForgeNotice(
                  title:
                      _captureSessionMessage!.toLowerCase().contains('failed')
                      ? rf('Capture session issue', '촬영 세션 문제')
                      : rf('Capture session state', '촬영 세션 상태'),
                  message: _captureSessionMessage!,
                  severity:
                      _captureSessionMessage!.toLowerCase().contains('failed')
                      ? NoticeSeverity.error
                      : NoticeSeverity.info,
                ),
              ],
              const SizedBox(height: 20),
              PhotoIntakeSection(
                state: _uploadState,
                message: _uploadMessage,
                progress: _uploadProgress,
                sourceImage: _sourceImage,
                onSelectImage: _selectAndUploadImage,
                onRetryUpload: _retryUpload,
              ),
              const SizedBox(height: 20),
              ReconstructionJobSection(
                job: _reconstructionJob,
                message: _reconstructionMessage,
                isSubmitting: _isSubmittingReconstruction,
                onSubmit: _submitReconstruction,
                onRetry: _retryReconstruction,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _openReconstruction,
                child: Text(rf('Open planning editor', '배치 편집기 열기')),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: widget.onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(rf('Edit project', '프로젝트 수정')),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete_outline),
                    label: Text(rf('Delete', '삭제')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  GuidedCaptureSessionCopy _guidedCaptureCopy() {
    return GuidedCaptureSessionCopy(
      title: rf('Guided room capture', '가이드 방 촬영'),
      description: rf(
        'Start a role-based capture session after confirming room dimensions.',
        '방 치수를 확인한 뒤 역할 기반 촬영 세션을 시작하세요.',
      ),
      missingDimensionsTitle: rf('Room dimensions required', '방 치수가 필요합니다'),
      missingDimensionsMessage: rf(
        'Enter or confirm room width, depth, and height in meters before starting guided capture.',
        '가이드 촬영을 시작하기 전에 방의 너비, 깊이, 높이를 미터 단위로 입력하거나 확인하세요.',
      ),
      readyTitle: rf('Ready for guided capture', '가이드 촬영 준비됨'),
      readyMessage: rf(
        'Use the guided roles below to collect photos for browser CV scene understanding.',
        '아래 촬영 역할에 따라 브라우저 CV 장면 인식에 사용할 사진을 모으세요.',
      ),
      startedTitle: rf('Capture session ready', '촬영 세션 준비됨'),
      startedMessage: rf(
        'Capture each required role, then continue on desktop for review and correction.',
        '필수 역할별 사진을 촬영한 뒤 데스크톱에서 검토와 수정을 이어가세요.',
      ),
      rolesTitle: rf('Photo roles', '사진 역할'),
      requiredLabel: rf('Required', '필수'),
      optionalLabel: rf('Optional', '선택'),
      startLabel: rf('Start guided capture', '가이드 촬영 시작'),
      startedLabel: rf('Guided capture started', '가이드 촬영 시작됨'),
      occlusionTitle: rf('Blocked walls are acceptable', '가려진 벽도 괜찮습니다'),
      occlusionMessage: rf(
        'If furniture blocks a wall, capture the visible wall and floor evidence from that side. You can manually correct room shape and object placement later.',
        '가구가 벽을 가리면 그쪽에서 보이는 벽과 바닥 단서만 촬영하세요. 방 모양과 오브젝트 배치는 나중에 직접 수정할 수 있습니다.',
      ),
      dimensionsLabel: rf('Room dimensions', '방 치수'),
      widthLabel: rf('Width', '너비'),
      depthLabel: rf('Depth', '깊이'),
      heightLabel: rf('Height', '높이'),
      defaultHeightLabel: rf('default height', '기본 높이'),
      userHeightLabel: rf('user height', '사용자 입력 높이'),
      sessionStateLabel: rf('Guided capture session state', '가이드 촬영 세션 상태'),
      uploadRoleLabel: rf('Upload photo', '사진 업로드'),
      replaceRoleLabel: rf('Replace photo', '사진 교체'),
      retryRoleLabel: rf('Retry role', '역할 재시도'),
      uploadingRoleLabel: rf('Uploading...', '업로드 중...'),
      uploadedRoleLabel: rf('Uploaded', '업로드됨'),
      noRolePhotoLabel: rf('No photo yet', '아직 사진 없음'),
      roleUploadFailedLabel: rf('Upload failed', '업로드 실패'),
      depthToggleTitle: rf('Accuracy enhancement', '정확도 향상'),
      depthToggleLabel: rf('Use distance metadata', '거리 메타데이터 사용'),
      depthSupportedMessage: rf(
        'On supported Android devices, RoomForge can attach ARCore Depth distance metadata to improve placement estimates. It is approximate and remains editable.',
        '지원되는 Android 기기에서는 ARCore Depth 거리 메타데이터를 첨부해 배치 추정을 보강할 수 있습니다. 값은 근사치이며 나중에 수정할 수 있습니다.',
      ),
      depthUnsupportedMessage: rf(
        'This device will use normal guided photos because ARCore Depth distance metadata is unavailable.',
        '이 기기에서는 ARCore Depth 거리 메타데이터를 사용할 수 없어 일반 가이드 사진 촬영을 사용합니다.',
      ),
      depthDisabledMessage: rf(
        'Distance metadata is off. Guided photos still work, and no depth metadata is required.',
        '거리 메타데이터가 꺼져 있습니다. 가이드 사진은 그대로 동작하며 depth 메타데이터는 필요하지 않습니다.',
      ),
    );
  }

  List<GuidedCaptureRoleInstruction> _guidedCaptureRoles() {
    return [
      GuidedCaptureRoleInstruction(
        id: 'overview',
        label: rf('Overview', '전체'),
        description: rf(
          'Capture the room from the widest available corner or doorway.',
          '가능한 가장 넓게 보이는 모서리나 문 근처에서 방 전체를 촬영하세요.',
        ),
        icon: Icons.photo_size_select_large_outlined,
      ),
      GuidedCaptureRoleInstruction(
        id: 'front_wall',
        label: rf('Front wall', '앞 벽'),
        description: rf(
          'Stand near the opposite side and capture the front wall.',
          '반대쪽 근처에 서서 앞 벽을 촬영하세요.',
        ),
        icon: Icons.border_top_outlined,
      ),
      GuidedCaptureRoleInstruction(
        id: 'right_wall',
        label: rf('Right wall', '오른쪽 벽'),
        description: rf(
          'Capture the right wall with visible floor-wall evidence.',
          '바닥과 벽의 단서가 보이도록 오른쪽 벽을 촬영하세요.',
        ),
        icon: Icons.border_right_outlined,
      ),
      GuidedCaptureRoleInstruction(
        id: 'back_wall',
        label: rf('Back wall', '뒤 벽'),
        description: rf(
          'Capture the back wall from the clearest available angle.',
          '가장 잘 보이는 각도에서 뒤 벽을 촬영하세요.',
        ),
        icon: Icons.border_bottom_outlined,
      ),
      GuidedCaptureRoleInstruction(
        id: 'left_wall',
        label: rf('Left wall', '왼쪽 벽'),
        description: rf(
          'Capture the left wall with any doors or windows visible.',
          '문이나 창문이 있다면 함께 보이도록 왼쪽 벽을 촬영하세요.',
        ),
        icon: Icons.border_left_outlined,
      ),
      GuidedCaptureRoleInstruction(
        id: 'extra',
        label: rf('Extra', '추가'),
        description: rf(
          'Add another photo when a wall or large object is unclear.',
          '벽이나 큰 오브젝트가 불명확하면 사진을 추가하세요.',
        ),
        icon: Icons.add_photo_alternate_outlined,
        required: false,
      ),
    ];
  }

  int _guidedRoleCaptureOrder(String roleId) {
    return switch (roleId) {
      'overview' => 0,
      'front_wall' => 1,
      'right_wall' => 2,
      'back_wall' => 3,
      'left_wall' => 4,
      _ => 5,
    };
  }

  String _normalizedContentType(html.File file) {
    if (file.type.isNotEmpty) {
      return file.type;
    }
    final lowerName = file.name.toLowerCase();
    if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lowerName.endsWith('.png')) {
      return 'image/png';
    }
    if (lowerName.endsWith('.webp')) {
      return 'image/webp';
    }
    return 'application/octet-stream';
  }

  String? _clientImageValidationMessage(html.File file, String contentType) {
    if (!_allowedImageTypes.contains(contentType)) {
      return 'Unsupported image type. Use JPEG, PNG, or WebP.';
    }
    if (file.size > _maxImageBytes) {
      return 'Room photo must be 10 MB or smaller.';
    }
    return null;
  }

  Future<Uint8List> _readFileBytes(html.File file) async {
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoad.first;
    final result = reader.result;
    if (result is ByteBuffer) {
      return Uint8List.view(result);
    }
    if (result is Uint8List) {
      return result;
    }
    throw StateError('Could not read selected image bytes.');
  }

  Future<_ImageSize?> _readImageSize(html.File file) async {
    final url = html.Url.createObjectUrl(file);
    final image = html.ImageElement(src: url);
    try {
      await image.onLoad.first.timeout(const Duration(seconds: 3));
      final width = image.naturalWidth;
      final height = image.naturalHeight;
      if (width <= 0 || height <= 0) {
        return null;
      }
      return _ImageSize(width: width, height: height);
    } on TimeoutException {
      return null;
    } finally {
      html.Url.revokeObjectUrl(url);
    }
  }
}

class PhotoIntakeSection extends StatelessWidget {
  const PhotoIntakeSection({
    required this.state,
    required this.message,
    required this.progress,
    required this.sourceImage,
    required this.onSelectImage,
    required this.onRetryUpload,
    super.key,
  });

  final SourceImageUploadStatus state;
  final String? message;
  final double? progress;
  final SourceImage? sourceImage;
  final VoidCallback onSelectImage;
  final VoidCallback onRetryUpload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = switch (state) {
      SourceImageUploadStatus.validationError ||
      SourceImageUploadStatus.permissionFailure ||
      SourceImageUploadStatus.metadataSaveFailed ||
      SourceImageUploadStatus.uploadFailed => _roomForgeError,
      SourceImageUploadStatus.uploaded => _roomForgeSuccess,
      SourceImageUploadStatus.lowQualityWarning => _roomForgeWarning,
      SourceImageUploadStatus.uploading => _roomForgeSave,
      SourceImageUploadStatus.ready => _roomForgePrimary,
      SourceImageUploadStatus.empty => _roomForgeBorderStrong,
    };
    final progressValue = progress?.clamp(0, 1).toDouble();
    final progressText = _localizedUploadProgressLabel(progressValue);
    final isProblemState =
        state.isFailure || state == SourceImageUploadStatus.lowQualityWarning;
    final noticeSeverity = state.isFailure
        ? NoticeSeverity.error
        : NoticeSeverity.warning;
    final uploadActions = sourceImageUploadActions(
      state,
    ).map(_localizedSourceImageUploadAction).toList();
    final uploadSemantics = _localizedSourceImageUploadAccessibilitySummary(
      status: state,
      message: message,
      progress: progressValue,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RoomForgeSectionHeader(
          icon: Icons.photo_camera_outlined,
          title: rf('Source image upload', '소스 이미지 업로드'),
          description: rf(
            'Use a sharp, bright JPEG, PNG, or WebP room photo with visible floor-wall boundaries.',
            '바닥과 벽 경계가 잘 보이는 선명하고 밝은 JPEG, PNG, WebP 방 사진을 사용하세요.',
          ),
        ),
        const SizedBox(height: 12),
        Semantics(
          container: true,
          liveRegion: true,
          label: uploadSemantics,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _roomForgeCanvas,
              border: Border.all(
                color: borderColor,
                width: state == SourceImageUploadStatus.ready ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 760;
                      final dropZone = _SourceImageDropZone(
                        state: state,
                        color: borderColor,
                        progressText: progressText,
                        stateLabel: _uploadStateLabel(state),
                        guidance: _uploadGuidance(state),
                        icon: _uploadStateIcon(state),
                        onSelectImage: onSelectImage,
                      );
                      final fileCard = _SourceImageFileCard(
                        sourceImage: sourceImage,
                        state: state,
                        progressValue: progressValue,
                        progressText: progressText,
                      );

                      if (compact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            dropZone,
                            const SizedBox(height: 12),
                            fileCard,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 6, child: dropZone),
                          const SizedBox(width: 14),
                          Expanded(flex: 4, child: fileCard),
                        ],
                      );
                    },
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 14),
                    isProblemState
                        ? RoomForgeNotice(
                            title: state.isFailure
                                ? rf('Upload needs attention', '업로드 확인 필요')
                                : rf('Image quality warning', '이미지 품질 경고'),
                            message: message!,
                            severity: noticeSeverity,
                            icon: state.isFailure
                                ? Icons.error_outline
                                : Icons.warning_amber_outlined,
                          )
                        : Text(
                            message!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: _roomForgeMuted,
                            ),
                          ),
                  ],
                  const SizedBox(height: 14),
                  SourceImageUploadRecoveryControls(
                    status: state,
                    actions: uploadActions,
                    uploadingLabel: rf('Uploading...', '업로드 중...'),
                    semanticsLabel: rf(
                      'Source image upload actions',
                      '소스 이미지 업로드 작업',
                    ),
                    onChoosePhoto: onSelectImage,
                    onRetryUpload: onRetryUpload,
                  ),
                  if (state == SourceImageUploadStatus.validationError) ...[
                    const SizedBox(height: 8),
                    Text(
                      rf(
                        'Accepted formats: JPEG, PNG, WebP. Maximum size: 10 MB.',
                        '지원 형식: JPEG, PNG, WebP. 최대 크기: 10 MB.',
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  IconData _uploadStateIcon(SourceImageUploadStatus state) {
    return switch (state) {
      SourceImageUploadStatus.ready => Icons.file_upload_outlined,
      SourceImageUploadStatus.uploading => Icons.cloud_upload_outlined,
      SourceImageUploadStatus.uploaded => Icons.cloud_done_outlined,
      SourceImageUploadStatus.validationError => Icons.rule_folder_outlined,
      SourceImageUploadStatus.lowQualityWarning => Icons.warning_amber_outlined,
      SourceImageUploadStatus.permissionFailure => Icons.lock_outline,
      SourceImageUploadStatus.metadataSaveFailed => Icons.sync_problem,
      SourceImageUploadStatus.uploadFailed => Icons.error_outline,
      SourceImageUploadStatus.empty => Icons.add_photo_alternate_outlined,
    };
  }

  String _uploadGuidance(SourceImageUploadStatus state) {
    return switch (state) {
      SourceImageUploadStatus.ready => rf(
        'Drop the room photo here, or choose a file from this browser.',
        '방 사진을 여기에 놓거나 브라우저에서 파일을 선택하세요.',
      ),
      SourceImageUploadStatus.uploading => rf(
        'Keep this tab open while the source image is saved.',
        '소스 이미지가 저장되는 동안 이 탭을 열어 두세요.',
      ),
      SourceImageUploadStatus.uploaded => rf(
        'The uploaded photo is ready for reconstruction review.',
        '업로드된 사진은 재구성 검토에 사용할 수 있습니다.',
      ),
      SourceImageUploadStatus.validationError => rf(
        'Choose another file that matches the format and size requirements.',
        '형식과 크기 조건에 맞는 다른 파일을 선택하세요.',
      ),
      SourceImageUploadStatus.lowQualityWarning => rf(
        'The file may work, but reconstruction might need manual correction.',
        '파일은 사용할 수 있지만 재구성에 수동 보정이 필요할 수 있습니다.',
      ),
      SourceImageUploadStatus.permissionFailure => rf(
        'Refresh access or retry after confirming this project belongs to your account.',
        '프로젝트 접근 권한을 확인한 뒤 다시 시도하세요.',
      ),
      SourceImageUploadStatus.metadataSaveFailed => rf(
        'Storage received the file, but the project metadata did not finish saving.',
        '파일은 저장소에 업로드됐지만 프로젝트 메타데이터 저장이 완료되지 않았습니다.',
      ),
      SourceImageUploadStatus.uploadFailed => rf(
        'Retry upload, or replace the file if the problem repeats.',
        '업로드를 재시도하고, 문제가 반복되면 파일을 교체하세요.',
      ),
      SourceImageUploadStatus.empty => rf(
        'Drag a photo into the page or choose a file to start reconstruction.',
        '사진을 페이지에 끌어오거나 파일을 선택해 재구성을 시작하세요.',
      ),
    };
  }

  String _uploadStateLabel(SourceImageUploadStatus state) {
    return switch (state) {
      SourceImageUploadStatus.ready => rf('Ready to select', '선택 준비됨'),
      SourceImageUploadStatus.uploading => rf('Uploading', '업로드 중'),
      SourceImageUploadStatus.uploaded => rf('Uploaded', '업로드됨'),
      SourceImageUploadStatus.validationError => rf(
        'Validation error',
        '검증 오류',
      ),
      SourceImageUploadStatus.lowQualityWarning => rf(
        'Low-quality warning',
        '품질 경고',
      ),
      SourceImageUploadStatus.permissionFailure => rf(
        'Permission blocked',
        '권한 차단',
      ),
      SourceImageUploadStatus.metadataSaveFailed => rf(
        'Metadata save failed',
        '메타데이터 저장 실패',
      ),
      SourceImageUploadStatus.uploadFailed => rf('Upload failed', '업로드 실패'),
      SourceImageUploadStatus.empty => rf(
        'No source image selected',
        '선택된 소스 이미지 없음',
      ),
    };
  }
}

class _SourceImageDropZone extends StatelessWidget {
  const _SourceImageDropZone({
    required this.state,
    required this.color,
    required this.progressText,
    required this.stateLabel,
    required this.guidance,
    required this.icon,
    required this.onSelectImage,
  });

  final SourceImageUploadStatus state;
  final Color color;
  final String progressText;
  final String stateLabel;
  final String guidance;
  final IconData icon;
  final VoidCallback onSelectImage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUploading = state == SourceImageUploadStatus.uploading;
    final isInteractive = !isUploading;

    return Material(
      color: color.withValues(alpha: .08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: color.withValues(
            alpha: state == SourceImageUploadStatus.ready ? .74 : .34,
          ),
          width: state == SourceImageUploadStatus.ready ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: isInteractive ? onSelectImage : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _roomForgePanel,
                  border: Border.all(color: color.withValues(alpha: .50)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(height: 14),
              Semantics(
                liveRegion: true,
                label: isUploading ? progressText : stateLabel,
                child: Text(
                  rf('Drop a room photo here', '방 사진을 여기에 놓기'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: _roomForgeInk,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                guidance,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _roomForgeMuted,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              RoomForgeStatusPill(
                label: isUploading ? progressText : stateLabel,
                color: color,
                dense: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceImageFileCard extends StatelessWidget {
  const _SourceImageFileCard({
    required this.sourceImage,
    required this.state,
    required this.progressValue,
    required this.progressText,
  });

  final SourceImage? sourceImage;
  final SourceImageUploadStatus state;
  final double? progressValue;
  final String progressText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUploading = state == SourceImageUploadStatus.uploading;
    final hasImage = sourceImage != null;
    final statusColor = isUploading
        ? _roomForgeSave
        : hasImage
        ? _roomForgeSuccess
        : _roomForgeAdmin;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _roomForgePanel,
        border: Border.all(color: _roomForgeBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 82,
              decoration: BoxDecoration(
                color: _roomForgeLightSurface.withValues(alpha: .10),
                border: Border.all(color: statusColor.withValues(alpha: .42)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                children: [
                  const Positioned.fill(child: _RoomForgeGridBackdrop()),
                  Positioned(
                    left: 14,
                    right: 14,
                    top: 18,
                    bottom: 18,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: .18),
                        border: Border.all(color: statusColor, width: 1.5),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              hasImage
                  ? sourceImage!.originalFilename
                  : rf('No file selected', '선택된 파일 없음'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                color: _roomForgeInk,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                if (hasImage) ...[
                  RoomForgeStatusPill(
                    icon: Icons.data_object_outlined,
                    label: _fileSizeLabel(sourceImage!.byteSize),
                    color: _roomForgeSuccess,
                    dense: true,
                  ),
                  if (sourceImage!.widthPx != null &&
                      sourceImage!.heightPx != null)
                    RoomForgeStatusPill(
                      icon: Icons.aspect_ratio_outlined,
                      label:
                          '${sourceImage!.widthPx} x ${sourceImage!.heightPx}px',
                      color: _roomForgeSuccess,
                      dense: true,
                    ),
                ] else
                  RoomForgeStatusPill(
                    icon: Icons.photo_size_select_actual_outlined,
                    label: rf('JPG PNG WebP', 'JPG PNG WebP'),
                    color: _roomForgeAdmin,
                    dense: true,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: isUploading
                  ? progressValue
                  : hasImage
                  ? 1
                  : 0,
              semanticsLabel: sourceImageUploadProgressSemanticsLabel,
              semanticsValue: isUploading
                  ? progressText
                  : hasImage
                  ? rf('Uploaded', '업로드됨')
                  : rf('Waiting for file', '파일 대기 중'),
            ),
            const SizedBox(height: 6),
            Text(
              isUploading
                  ? progressText
                  : hasImage
                  ? rf('Storage and metadata saved.', 'Storage와 메타데이터 저장됨.')
                  : rf('Choose a room image to start.', '방 이미지를 선택해 시작하세요.'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: _roomForgeMuted,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RoomDimensionsSection extends StatelessWidget {
  const RoomDimensionsSection({
    required this.formKey,
    required this.widthController,
    required this.depthController,
    required this.heightController,
    required this.dimensions,
    required this.message,
    required this.isSaving,
    required this.onSave,
    super.key,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController widthController;
  final TextEditingController depthController;
  final TextEditingController heightController;
  final RoomDimensions? dimensions;
  final String? message;
  final bool isSaving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RoomForgeSectionHeader(
            icon: Icons.straighten_outlined,
            title: rf('Room dimensions', '방 치수'),
            description: rf(
              'Enter the room footprint in meters. Height can use the MVP default when unknown.',
              '방의 가로/세로를 미터 단위로 입력하세요. 높이를 모르면 MVP 기본값을 사용할 수 있습니다.',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              RoomForgeStatusPill(
                label: rf('meters locked', 'meters 고정'),
                color: _roomForgeMeasure,
                dense: true,
              ),
              RoomForgeStatusPill(
                label: rf('default height 2.40 m', '기본 높이 2.40 m'),
                color: _roomForgeWarning,
                dense: true,
              ),
              RoomForgeStatusPill(
                label: rf('positive values only', '양수만 입력'),
                color: _roomForgeError,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 680;
              final fields = _dimensionFields(context);
              final formFields = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final field in fields) ...[
                    field,
                    if (field != fields.last) const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 12),
                  RoomForgeNotice(
                    title: rf('Default height available', '기본 높이를 사용할 수 있습니다'),
                    message: rf(
                      'If you do not know the measured height, leave it blank or apply 2.40 m before saving.',
                      '실측 높이를 모르면 비워 두거나 저장 전에 2.40 m 기본 높이를 적용하세요.',
                    ),
                    severity: NoticeSeverity.warning,
                    icon: Icons.height_outlined,
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: isSaving
                          ? null
                          : () {
                              heightController.text = '2.40';
                            },
                      icon: const Icon(Icons.vertical_align_top_outlined),
                      label: Text(rf('Apply default height', '기본 높이 적용')),
                    ),
                  ),
                ],
              );
              final preview = _RoomDimensionPreview(
                widthController: widthController,
                depthController: depthController,
                heightController: heightController,
                dimensions: dimensions,
              );

              if (compact) {
                return DecoratedBox(
                  decoration: _dimensionSceneDecoration,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        formFields,
                        const SizedBox(height: 14),
                        preview,
                      ],
                    ),
                  ),
                );
              }

              return DecoratedBox(
                decoration: _dimensionSceneDecoration,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: formFields),
                      const SizedBox(width: 16),
                      Expanded(flex: 4, child: preview),
                    ],
                  ),
                ),
              );
            },
          ),
          if (message != null) ...[
            const SizedBox(height: 12),
            RoomForgeNotice(
              title: message!.toLowerCase().contains('failed')
                  ? rf('Dimension save issue', '치수 저장 문제')
                  : rf('Dimension state', '치수 상태'),
              message: message!,
              severity: message!.toLowerCase().contains('failed')
                  ? NoticeSeverity.error
                  : NoticeSeverity.info,
            ),
          ],
          if (dimensions != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                RoomForgeStatusPill(
                  icon: Icons.check_circle_outline,
                  label:
                      '${dimensions!.widthValue.toStringAsFixed(2)} x ${dimensions!.depthValue.toStringAsFixed(2)} m',
                  color: _roomForgeSuccess,
                ),
                RoomForgeStatusPill(
                  icon: Icons.height_outlined,
                  label:
                      '${rf('Height', '높이')} ${dimensions!.heightValue.toStringAsFixed(2)} ${dimensions!.unit}',
                  color: dimensions!.usesDefaultHeight
                      ? _roomForgeWarning
                      : _roomForgeSuccess,
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: isSaving ? null : onSave,
            icon: isSaving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(
              isSaving
                  ? rf('Saving...', '저장 중...')
                  : rf('Save dimensions', '치수 저장'),
            ),
          ),
        ],
      ),
    );
  }

  Decoration get _dimensionSceneDecoration {
    return BoxDecoration(
      color: _roomForgeCanvas,
      border: Border.all(color: _roomForgeBorder),
      borderRadius: BorderRadius.circular(8),
    );
  }

  List<Widget> _dimensionFields(BuildContext context) {
    return [
      TextFormField(
        controller: widthController,
        decoration: InputDecoration(
          labelText: rf('Width', '가로'),
          suffixText: 'm',
          helperText: rf('Wall to wall', '벽에서 벽까지'),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: (value) => _dimensionValidator(value, maxMeters: 50),
      ),
      TextFormField(
        controller: depthController,
        decoration: InputDecoration(
          labelText: rf('Depth', '세로'),
          suffixText: 'm',
          helperText: rf('Front to back', '앞에서 뒤까지'),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: (value) => _dimensionValidator(value, maxMeters: 50),
      ),
      TextFormField(
        controller: heightController,
        decoration: InputDecoration(
          labelText: rf('Height', '높이'),
          helperText: rf('Blank uses default', '비워두면 기본값 사용'),
          suffixText: 'm',
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: (value) =>
            _dimensionValidator(value, maxMeters: 15, allowBlank: true),
      ),
    ];
  }

  static String? _dimensionValidator(
    String? value, {
    required double maxMeters,
    bool allowBlank = false,
  }) {
    final trimmed = value?.trim() ?? '';
    if (allowBlank && trimmed.isEmpty) {
      return null;
    }
    final parsed = double.tryParse(trimmed);
    if (parsed == null || parsed <= 0) {
      return rf('Enter a positive number.', '양수를 입력하세요.');
    }
    if (parsed > maxMeters) {
      return rf('Enter a realistic meter value.', '현실적인 미터 값을 입력하세요.');
    }
    return null;
  }
}

class _RoomDimensionPreview extends StatelessWidget {
  const _RoomDimensionPreview({
    required this.widthController,
    required this.depthController,
    required this.heightController,
    required this.dimensions,
  });

  final TextEditingController widthController;
  final TextEditingController depthController;
  final TextEditingController heightController;
  final RoomDimensions? dimensions;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widthController,
        depthController,
        heightController,
      ]),
      builder: (context, _) {
        final width = _value(widthController.text, dimensions?.widthValue, 3.6);
        final depth = _value(depthController.text, dimensions?.depthValue, 4.2);
        final heightText = heightController.text.trim();
        final height = _value(heightText, dimensions?.heightValue, 2.4);
        final usesDefaultHeight =
            heightText.isEmpty || dimensions?.usesDefaultHeight == true;

        return Semantics(
          label: rf(
            'Metric room preview. Width ${width.toStringAsFixed(2)} meters, depth ${depth.toStringAsFixed(2)} meters, height ${height.toStringAsFixed(2)} meters.',
            '미터 기반 방 미리보기. 가로 ${width.toStringAsFixed(2)}미터, 세로 ${depth.toStringAsFixed(2)}미터, 높이 ${height.toStringAsFixed(2)}미터.',
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _roomForgePanel,
              border: Border.all(color: _roomForgeBorder),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      RoomForgeStatusPill(
                        label: rf('metric preview', '미터 프리뷰'),
                        color: _roomForgeMeasure,
                        dense: true,
                      ),
                      const Spacer(),
                      RoomForgeStatusPill(
                        label: usesDefaultHeight
                            ? rf('default height', '기본 높이')
                            : rf('measured height', '실측 높이'),
                        color: usesDefaultHeight
                            ? _roomForgeWarning
                            : _roomForgeSuccess,
                        dense: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 190,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final safeWidth = width.clamp(0.8, 50.0);
                        final safeDepth = depth.clamp(0.8, 50.0);
                        final scale = [
                          (constraints.maxWidth - 34) / safeWidth,
                          136 / safeDepth,
                        ].reduce((a, b) => a < b ? a : b);
                        final roomWidth = (safeWidth * scale).clamp(
                          112.0,
                          constraints.maxWidth - 28,
                        );
                        final roomDepth = (safeDepth * scale).clamp(
                          86.0,
                          136.0,
                        );

                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            const Positioned.fill(
                              child: _RoomForgeGridBackdrop(),
                            ),
                            SizedBox(
                              width: roomWidth,
                              height: roomDepth,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: _roomForgeLightSurface.withValues(
                                    alpha: .22,
                                  ),
                                  border: Border.all(
                                    color: _roomForgeInk,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Stack(
                                  children: [
                                    Positioned(
                                      left: roomWidth * .25,
                                      top: roomDepth * .24,
                                      width: roomWidth * .30,
                                      height: roomDepth * .28,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: _roomForgePrimary.withValues(
                                            alpha: .22,
                                          ),
                                          border: Border.all(
                                            color: _roomForgePrimary,
                                            width: 1.5,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              child: Text(
                                '${width.toStringAsFixed(2)} m',
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: _roomForgeMeasure,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              child: RotatedBox(
                                quarterTurns: 1,
                                child: Text(
                                  '${depth.toStringAsFixed(2)} m',
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(
                                        color: _roomForgeMeasure,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    rf(
                      'Height ${height.toStringAsFixed(2)} m - saved as meters',
                      '높이 ${height.toStringAsFixed(2)} m - meters로 저장',
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _roomForgeMuted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static double _value(String input, double? saved, double fallback) {
    final parsed = double.tryParse(input.trim());
    if (parsed != null && parsed > 0) {
      return parsed;
    }
    return saved ?? fallback;
  }
}

class ReconstructionJobSection extends StatelessWidget {
  const ReconstructionJobSection({
    required this.job,
    required this.message,
    required this.isSubmitting,
    required this.onSubmit,
    required this.onRetry,
    super.key,
  });

  final ReconstructionJob? job;
  final String? message;
  final bool isSubmitting;
  final VoidCallback onSubmit;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = job == null
        ? _roomForgeMuted
        : _reconstructionStatusColor(job!.status);
    final hasProblem =
        job?.status == 'review_required' ||
        job?.status == 'failed' ||
        job?.status == 'timeout';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RoomForgeSectionHeader(
          icon: Icons.auto_fix_high_outlined,
          title: rf('Reconstruction status', '재구성 상태'),
          description: rf(
            'Submit the uploaded photo for OpenCV-assisted outline detection, then review the result before planning.',
            '업로드한 사진을 OpenCV 기반 윤곽 감지에 제출하고, 배치 전에 결과를 검토하세요.',
          ),
        ),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            color: _roomForgeCanvas,
            border: Border.all(color: statusColor.withValues(alpha: 0.35)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      job == null
                          ? Icons.pending_actions_outlined
                          : _reconstructionStatusIcon(job!.status),
                      color: statusColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job == null
                                ? rf('Ready after setup', '설정 후 준비됨')
                                : _localizedReconstructionStatusLabel(
                                    job!.status,
                                  ),
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: _roomForgeInk,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            message ??
                                rf(
                                  'Submit after source image and dimensions are saved.',
                                  '소스 이미지와 치수가 저장된 뒤 제출하세요.',
                                ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: _roomForgeMuted,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    RoomForgeStatusPill(
                      label: job == null
                          ? rf('Not submitted', '미제출')
                          : _localizedReconstructionStatusLabel(job!.status),
                      icon: job == null
                          ? Icons.schedule_outlined
                          : _reconstructionStatusIcon(job!.status),
                      color: statusColor,
                      dense: true,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _ReconstructionTimeline(
                  status: job?.status,
                  statusColorFor: _reconstructionStatusColor,
                  statusIconFor: _reconstructionStatusIcon,
                ),
                if (job != null) ...[
                  const SizedBox(height: 14),
                  _ReconstructionJobStrip(job: job!),
                  const SizedBox(height: 10),
                  Text(
                    _reconstructionStatusGuidance(job!.status),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _roomForgeMuted,
                      height: 1.35,
                    ),
                  ),
                  if (hasProblem) ...[
                    const SizedBox(height: 12),
                    RoomForgeNotice(
                      title: job!.status == 'review_required'
                          ? rf('Needs review', '검토 필요')
                          : rf('Reconstruction needs attention', '재구성 확인 필요'),
                      message:
                          job!.failureReasonMessage ??
                          rf(
                            'Check blur, lighting, hidden boundaries, occlusion, distortion, unsupported image, OpenCV failure, invalid geometry, or calibration failure.',
                            '흐림, 조명, 숨겨진 경계, 가림, 왜곡, 지원되지 않는 이미지, OpenCV 실패, 잘못된 지오메트리, 보정 실패를 확인하세요.',
                          ),
                      severity: job!.status == 'review_required'
                          ? NoticeSeverity.warning
                          : NoticeSeverity.error,
                      icon: job!.status == 'review_required'
                          ? Icons.rate_review_outlined
                          : Icons.error_outline,
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            RoomForgeStatusPill(
              label: 'created',
              color: _roomForgeAdmin,
              dense: true,
            ),
            RoomForgeStatusPill(
              label: 'processing',
              color: _roomForgeSave,
              dense: true,
            ),
            RoomForgeStatusPill(
              label: rf('Needs review', '검토 필요'),
              color: _roomForgeWarning,
              dense: true,
            ),
            RoomForgeStatusPill(
              label: 'succeeded',
              color: _roomForgeSuccess,
              dense: true,
            ),
            RoomForgeStatusPill(
              label: 'failed',
              color: _roomForgeError,
              dense: true,
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: isSubmitting ? null : onSubmit,
          icon: isSubmitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.play_arrow_outlined),
          label: Text(
            isSubmitting
                ? rf('Submitting...', '제출 중...')
                : rf('Submit reconstruction', '재구성 제출'),
          ),
        ),
        if (job != null &&
            (job!.terminal || job!.status == 'review_required')) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: isSubmitting ? null : onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(rf('Retry reconstruction', '재구성 재시도')),
          ),
        ],
      ],
    );
  }

  Color _reconstructionStatusColor(String status) {
    return switch (status) {
      'succeeded' => _roomForgeSuccess,
      'review_required' => _roomForgeWarning,
      'failed' || 'timeout' || 'cancelled' => _roomForgeError,
      'processing' || 'uploading' || 'retrying' => _roomForgePrimary,
      _ => _roomForgeMuted,
    };
  }

  IconData _reconstructionStatusIcon(String status) {
    return switch (status) {
      'succeeded' => Icons.check_circle_outline,
      'review_required' => Icons.rate_review_outlined,
      'failed' => Icons.error_outline,
      'timeout' => Icons.timer_off_outlined,
      'cancelled' => Icons.cancel_outlined,
      'processing' => Icons.hourglass_top_outlined,
      'uploading' => Icons.cloud_upload_outlined,
      'retrying' => Icons.refresh,
      _ => Icons.pending_actions_outlined,
    };
  }

  String _reconstructionStatusGuidance(String status) {
    return switch (status) {
      'created' => rf(
        'The job record exists and is waiting for processing.',
        '작업 레코드가 생성되었고 처리를 기다리는 중입니다.',
      ),
      'uploading' => rf(
        'Source artifacts are still being prepared before OpenCV processing.',
        'OpenCV 처리 전에 소스 아티팩트를 준비하는 중입니다.',
      ),
      'processing' => rf(
        'OpenCV is extracting candidate room geometry.',
        'OpenCV가 후보 방 지오메트리를 추출하는 중입니다.',
      ),
      'review_required' => rf(
        'Open the editor, compare candidate and confirmed geometry, and correct the outline if needed.',
        '편집기를 열어 후보/확정 지오메트리를 비교하고 필요하면 윤곽을 보정하세요.',
      ),
      'succeeded' => rf(
        'A metric floor plan can be reviewed and used in the planning editor.',
        '미터 단위 평면도를 검토하고 배치 편집기에서 사용할 수 있습니다.',
      ),
      'failed' => rf(
        'Retry with a clearer photo or inspect the failure reason before continuing.',
        '더 선명한 사진으로 재시도하거나 실패 사유를 확인한 뒤 계속하세요.',
      ),
      'timeout' => rf(
        'Retry is available after the previous job exceeded time.',
        '이전 작업이 제한 시간을 초과해 재시도할 수 있습니다.',
      ),
      'cancelled' => rf(
        'Submit a new reconstruction when ready.',
        '준비되면 새 재구성을 제출하세요.',
      ),
      'retrying' => rf(
        'A linked retry job is being prepared.',
        '연결된 재시도 작업을 준비 중입니다.',
      ),
      _ => rf(
        'Review the latest reconstruction state before opening the editor.',
        '편집기를 열기 전에 최신 재구성 상태를 확인하세요.',
      ),
    };
  }
}

class _ReconstructionTimeline extends StatelessWidget {
  const _ReconstructionTimeline({
    required this.status,
    required this.statusColorFor,
    required this.statusIconFor,
  });

  final String? status;
  final Color Function(String status) statusColorFor;
  final IconData Function(String status) statusIconFor;

  @override
  Widget build(BuildContext context) {
    final current = status ?? 'created';
    final finalStatus = switch (current) {
      'succeeded' => 'succeeded',
      'failed' => 'failed',
      'timeout' => 'timeout',
      'cancelled' => 'cancelled',
      _ => 'review_required',
    };
    final steps = [
      _ReconstructionStepSpec(
        status: 'created',
        title: 'created',
        description: rf('Job record created', '작업 레코드 생성'),
      ),
      _ReconstructionStepSpec(
        status: 'uploading',
        title: 'uploading',
        description: rf('Source image stored', '소스 이미지 저장'),
      ),
      _ReconstructionStepSpec(
        status: current == 'retrying' ? 'retrying' : 'processing',
        title: current == 'retrying' ? 'retrying' : 'processing',
        description: current == 'retrying'
            ? rf('Linked retry preparing', '연결된 재시도 준비')
            : rf('OpenCV worker extracting candidates', 'OpenCV 후보 추출 중'),
      ),
      _ReconstructionStepSpec(
        status: finalStatus,
        title: finalStatus == 'review_required'
            ? rf('Needs review', '검토 필요')
            : _localizedReconstructionStatusLabel(finalStatus),
        description: finalStatus == 'review_required'
            ? rf(
                'Manual review opens when candidates are ready',
                '후보가 준비되면 수동 검토로 이동',
              )
            : rf('Terminal job state', '최종 작업 상태'),
      ),
    ];
    final activeIndex = _activeIndexFor(current);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < steps.length; index++) ...[
          _ReconstructionTimelineRow(
            index: index + 1,
            spec: steps[index],
            done: index < activeIndex || current == 'succeeded',
            active: index == activeIndex,
            color: statusColorFor(steps[index].status),
            icon: statusIconFor(steps[index].status),
          ),
          if (index != steps.length - 1)
            const Padding(
              padding: EdgeInsets.only(left: 14),
              child: SizedBox(
                width: 30,
                height: 12,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 2,
                    height: 12,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: _roomForgeBorder),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }

  static int _activeIndexFor(String status) {
    return switch (status) {
      'created' => 0,
      'uploading' => 1,
      'processing' || 'retrying' => 2,
      _ => 3,
    };
  }
}

class _ReconstructionStepSpec {
  const _ReconstructionStepSpec({
    required this.status,
    required this.title,
    required this.description,
  });

  final String status;
  final String title;
  final String description;
}

class _ReconstructionTimelineRow extends StatelessWidget {
  const _ReconstructionTimelineRow({
    required this.index,
    required this.spec,
    required this.done,
    required this.active,
    required this.color,
    required this.icon,
  });

  final int index;
  final _ReconstructionStepSpec spec;
  final bool done;
  final bool active;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nodeColor = done || active ? color : _roomForgeSubtle;

    return Semantics(
      label:
          '${spec.title}. ${spec.description}. ${active
              ? rf('Current step', '현재 단계')
              : done
              ? rf('Done', '완료')
              : rf('Pending', '대기')}.',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: nodeColor.withValues(alpha: .14),
              border: Border.all(color: nodeColor.withValues(alpha: .48)),
              borderRadius: BorderRadius.circular(999),
            ),
            child: done
                ? Icon(Icons.check, color: nodeColor, size: 16)
                : active
                ? Icon(icon, color: nodeColor, size: 16)
                : Text(
                    '$index',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: nodeColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    spec.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: _roomForgeInk,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    spec.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _roomForgeMuted,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          RoomForgeStatusPill(
            label: active
                ? rf('active', '진행 중')
                : done
                ? rf('done', '완료')
                : rf('pending', '대기'),
            color: nodeColor,
            dense: true,
          ),
        ],
      ),
    );
  }
}

class _ReconstructionJobStrip extends StatelessWidget {
  const _ReconstructionJobStrip({required this.job});

  final ReconstructionJob job;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _roomForgePanel,
        border: Border.all(color: _roomForgeBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            RoomForgeStatusPill(
              icon: Icons.tag_outlined,
              label: job.id,
              color: _roomForgeAdmin,
              dense: true,
            ),
            RoomForgeStatusPill(
              icon: Icons.memory_outlined,
              label: '${rf('Provider', '제공자')} ${job.provider}',
              color: _roomForgeAdmin,
              dense: true,
            ),
            RoomForgeStatusPill(
              icon: Icons.image_outlined,
              label: '${rf('Source image', '소스 이미지')} ${job.sourceImageId}',
              color: _roomForgeAdmin,
              dense: true,
            ),
            RoomForgeStatusPill(
              icon: Icons.update_outlined,
              label:
                  '${rf('Updated', '수정됨')} ${_compactDateLabel(job.updatedAt)}',
              color: _roomForgeAdmin,
              dense: true,
            ),
            if (job.retryOfJobId != null)
              RoomForgeStatusPill(
                icon: Icons.replay_outlined,
                label: '${rf('Retry of', '재시도 원본')} ${job.retryOfJobId}',
                color: _roomForgeWarning,
                dense: true,
              ),
          ],
        ),
      ),
    );
  }
}

class _ImageSize {
  const _ImageSize({required this.width, required this.height});

  final int width;
  final int height;
}

class EditorBridgeScreen extends StatefulWidget {
  const EditorBridgeScreen({
    required this.project,
    required this.projectApi,
    this.initialDimensions,
    this.reconstructionJob,
    this.sourceImage,
    this.sourceImageDataUrl,
    this.captureSession,
    this.captureImages = const [],
    super.key,
  });

  final RoomProject project;
  final ProjectApi projectApi;
  final RoomDimensions? initialDimensions;
  final ReconstructionJob? reconstructionJob;
  final SourceImage? sourceImage;
  final String? sourceImageDataUrl;
  final CaptureSession? captureSession;
  final List<CaptureImage> captureImages;

  @override
  State<EditorBridgeScreen> createState() => _EditorBridgeScreenState();
}

class _EditorBridgeScreenState extends State<EditorBridgeScreen> {
  late final LayoutDraftRepository _draftRepository;
  late final String _viewType;
  late final html.IFrameElement _iframe;
  StreamSubscription<html.MessageEvent>? _messageSubscription;
  String _bridgeStatus = rf('Waiting for editor frame.', '편집기 프레임 대기 중.');
  String _runtimeStatus = rf('Waiting for OpenCV worker.', 'OpenCV 워커 대기 중.');
  String _sceneStatus = rf(
    'Waiting for metric floor plan handoff.',
    '미터 단위 평면도 전달 대기 중.',
  );
  String _saveStatus = rf('Not saved.', '저장되지 않음.');
  String _loadStatus = rf('No layout loaded.', '불러온 레이아웃 없음.');
  String _draftStatus = rf('No local draft.', '로컬 드래프트 없음.');
  String _exportStatus = rf('Not exported.', '내보내지 않음.');
  String _artifactStatus = rf('CV artifacts not saved yet.', 'CV 아티팩트 미저장.');
  String _viewMode = '2d';
  bool _isSavingLayout = false;
  bool _isLoadingLayout = false;
  bool _isExportingLayout = false;
  bool _isPersistingArtifacts = false;
  bool _reviewSaveConfirmed = false;
  bool _reviewExportConfirmed = false;
  Map<String, Object?>? _latestScene;
  String? _latestOpenCvResultId;
  String? _latestConfirmedGeometryId;
  String? _latestFloorPlanId;
  String? _latestSceneUnderstandingResultId;
  Map<String, Object?>? _latestSceneUnderstandingBridgePayload;
  String? _persistedJobStatus;
  String? _activeLayoutId;
  DateTime? _activeCloudUpdatedAt;
  bool _draftChangedDuringSave = false;
  bool _syncFailureVisible = false;
  var _draftGeneration = 0;
  Future<void> _pendingDraftWrite = Future<void>.value();
  Future<void> _pendingArtifactWrite = Future<void>.value();
  Future<void>? _pendingOpenCvResultWrite;
  LayoutDraft? _recoverableDraft;
  bool _isHandlingDraft = false;

  @override
  void initState() {
    super.initState();
    _draftRepository = LayoutDraftRepository(
      store: const IndexedDbLayoutDraftStore(),
    );
    _viewType =
        'roomforge-editor-${widget.project.id}-${DateTime.now().microsecondsSinceEpoch}';
    _iframe = html.IFrameElement()
      ..src = _editorUrlFor(widget.project)
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..allow = 'fullscreen'
      ..tabIndex = 0;

    _iframe.onLoad.listen((_) {
      _postEditorMessage(
        type: 'roomforge.reconstruction.open',
        requestId: 'open-project-${widget.project.id}',
        payload: {
          'projectId': widget.project.id,
          'projectName': widget.project.name,
        },
      );
      _postEditorMessage(
        type: 'roomforge.scene.initialize',
        requestId: 'initialize-scene-${widget.project.id}',
        payload: _sceneInitializePayload(),
      );
    });

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      return _iframe;
    });

    _messageSubscription = html.window.onMessage.listen(_handleEditorMessage);
    unawaited(_detectRecoverableDraftWithLatestCloud());
    unawaited(_loadPersistedSceneUnderstandingResult());
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${rf('Planning editor', '배치 편집기')}: ${widget.project.name}',
        ),
      ),
      body: Column(
        children: [
          _EditorBridgeCommandBar(
            viewMode: _viewMode,
            sceneStatus: _sceneStatus,
            bridgeStatus: _bridgeStatus,
            runtimeStatus: _isPersistingArtifacts
                ? '$_runtimeStatus ${rf('Saving CV artifacts...', 'CV 아티팩트 저장 중...')}'
                : '$_runtimeStatus $_artifactStatus',
            saveStatus: _saveStatus,
            loadStatus: _loadStatus,
            draftStatus: _draftStatus,
            exportStatus: _exportStatus,
            recoverableDraft: _recoverableDraft,
            activeCloudUpdatedAt: _activeCloudUpdatedAt,
            isSavingLayout: _isSavingLayout,
            isLoadingLayout: _isLoadingLayout,
            isExportingLayout: _isExportingLayout,
            isHandlingDraft: _isHandlingDraft,
            isSyncFailureVisible: _syncFailureVisible,
            onViewModeChanged: (viewMode) {
              setState(() => _viewMode = viewMode);
              _postEditorMessage(
                type: 'roomforge.view.setMode',
                requestId: 'view-mode-${DateTime.now().millisecondsSinceEpoch}',
                payload: {'viewMode': viewMode},
              );
            },
            onSaveLayout: _saveLayout,
            onLoadLayout: () => _loadLayout(),
            onExportLayout: _exportLayout,
            onRestoreDraft: _restoreDraft,
            onDiscardDraft: _discardDraft,
            onContinueSavedVersion: _continueSavedVersion,
            onPingEditor: () => _postEditorMessage(
              type: 'roomforge.editor.ping',
              requestId: 'manual-ping-${DateTime.now().millisecondsSinceEpoch}',
              payload: {'source': 'flutter-shell'},
            ),
          ),
          Expanded(child: HtmlElementView(viewType: _viewType)),
        ],
      ),
    );
  }

  void _handleEditorMessage(html.MessageEvent event) {
    final data = event.data;
    if (data is! Map) {
      return;
    }

    final type = data['type']?.toString();
    final version = data['version'];
    if (type == null || version != 1) {
      return;
    }

    Map<String, Object?>? draftScene;
    Map<String, Object?>? openCvPayload;
    Map<String, Object?>? confirmedGeometryPayload;
    Map<String, Object?>? floorPlanPayload;
    Map<String, Object?>? sceneUnderstandingPayload;
    setState(() {
      if (type == 'roomforge.editor.ready') {
        _bridgeStatus = rf('Editor ready.', '편집기 준비됨.');
      } else if (type.endsWith('.response')) {
        _bridgeStatus = '${rf('Bridge round trip', '브리지 왕복')}: $type';
      } else if (type == 'roomforge.opencv.runtimeLoaded') {
        _runtimeStatus = rf('OpenCV.js worker loaded.', 'OpenCV.js 워커 로드됨.');
      } else if (type == 'roomforge.opencv.runtimeFailed') {
        _runtimeStatus = rf(
          'OpenCV worker asset loading failed.',
          'OpenCV 워커 자산 로드 실패.',
        );
      } else if (type == 'roomforge.opencv.candidatesExtracted') {
        final payload = _recordValue(data['payload']);
        openCvPayload = payload;
        final confidence = _numberValueOrNull(payload['confidence']);
        final qualityStatus = payload['qualityStatus']?.toString();
        final qualityLabel = qualityStatus == 'failed'
            ? rf('failed', '실패')
            : qualityStatus == 'success'
            ? rf('success', '성공')
            : rf('needs review', '검토 필요');
        _runtimeStatus =
            '${rf('OpenCV candidates extracted', 'OpenCV 후보 추출됨')}: $qualityLabel'
            '${confidence == null ? '' : ' (${confidence.toStringAsFixed(2)})'}';
      } else if (type == 'roomforge.geometry.confirmedChanged') {
        final payload = _recordValue(data['payload']);
        confirmedGeometryPayload = payload;
        _sceneStatus = rf('Confirmed geometry updated.', '확정 지오메트리 업데이트됨.');
      } else if (type == 'roomforge.calibration.floorPlanGenerated') {
        final payload = _recordValue(data['payload']);
        floorPlanPayload = payload;
        _sceneStatus = rf('Metric floor plan generated.', '미터 평면도 생성됨.');
      } else if (type == 'roomforge.sceneUnderstanding.candidatesExtracted') {
        final payload = _recordValue(data['payload']);
        sceneUnderstandingPayload = payload;
        final result = _recordValue(payload['sceneUnderstandingResult']);
        final candidates = _listValue(result['candidateObjects']).length;
        _runtimeStatus = rf(
          'Scene understanding candidates extracted: $candidates',
          '장면 이해 후보 추출됨: $candidates개',
        );
      } else if (type == 'roomforge.sceneUnderstanding.candidatesFailed') {
        final payload = _recordValue(data['payload']);
        sceneUnderstandingPayload = payload;
        final error = _recordValue(payload['error']);
        _runtimeStatus =
            '${rf('Scene understanding failed', '장면 이해 실패')}: ${error['message'] ?? error['code'] ?? 'unknown'}';
      } else if (type == 'roomforge.scene.initialized' ||
          type == 'roomforge.view.changed' ||
          type == 'roomforge.selection.changed' ||
          type == 'roomforge.scene.updated') {
        final payload = data['payload'];
        if (payload is Map) {
          _latestScene = Map<String, Object?>.from(payload);
          final viewMode = payload['viewMode']?.toString();
          final nextViewMode = viewMode == '2d' || viewMode == '3d'
              ? viewMode
              : null;
          if (nextViewMode != null) {
            _viewMode = nextViewMode;
          }
          final hasUnsavedChanges = payload['hasUnsavedChanges'] == true;
          if (hasUnsavedChanges) {
            draftScene = Map<String, Object?>.from(payload);
          }
          final room = payload['room'];
          final label = room is Map ? room['label']?.toString() : null;
          final statusLabel = hasUnsavedChanges
              ? rf('Unsaved changes', '저장되지 않은 변경')
              : rf('Saved', '저장됨');
          final modeLabel = viewMode?.toUpperCase() ?? _viewMode.toUpperCase();
          _sceneStatus = rf(
            '$modeLabel scene: ${_localizedEditorObjectLabel(label)}; $statusLabel',
            '$modeLabel 장면: ${_localizedEditorObjectLabel(label)}; $statusLabel',
          );
        }
      }
    });
    if (draftScene != null) {
      _queuePersistDraft(draftScene!);
    }
    if (openCvPayload != null) {
      final payload = openCvPayload!;
      final pending = _queuePersistArtifact(
        () => _persistOpenCvPayload(payload),
      );
      _pendingOpenCvResultWrite = pending;
    }
    if (confirmedGeometryPayload != null) {
      final payload = confirmedGeometryPayload!;
      _queuePersistArtifact(() => _persistConfirmedGeometryPayload(payload));
    }
    if (floorPlanPayload != null) {
      final payload = floorPlanPayload!;
      _queuePersistArtifact(() => _persistFloorPlanPayload(payload));
    }
    if (sceneUnderstandingPayload != null) {
      final payload = sceneUnderstandingPayload!;
      _queuePersistArtifact(() => _persistSceneUnderstandingPayload(payload));
    }
  }

  Future<void> _queuePersistArtifact(Future<void> Function() persist) {
    final queued = _pendingArtifactWrite
        .catchError((_) {})
        .then((_) => persist());
    _pendingArtifactWrite = queued;
    unawaited(queued);
    return queued;
  }

  Future<void> _persistOpenCvPayload(Map<String, Object?> payload) async {
    final job = widget.reconstructionJob;
    final sourceImage = widget.sourceImage;
    if (job == null || sourceImage == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _artifactStatus = rf(
          'CV result pending source image and job.',
          '소스 이미지와 작업 생성 후 CV 결과 저장 가능.',
        );
      });
      return;
    }

    final candidateGeometry = _recordValue(payload['candidateGeometry']);
    setState(() {
      _isPersistingArtifacts = true;
      _artifactStatus = rf('Saving OpenCV result...', 'OpenCV 결과 저장 중...');
    });

    try {
      final result = await widget.projectApi.persistOpenCvResult(
        projectId: widget.project.id,
        jobId: job.id,
        sourceImageId: sourceImage.id,
        candidateGeometry: candidateGeometry,
        confidence: _numberValueOrNull(payload['confidence']),
        algorithm:
            payload['algorithm']?.toString() ?? 'opencv-js-canny-hough-v1',
        coordinateSpace:
            payload['coordinateSpace']?.toString() ?? 'image_pixels',
        qualityStatus: payload['qualityStatus']?.toString(),
        failureReasonCode: payload['reasonCode']?.toString(),
        failureReason: payload['reasonMessage']?.toString(),
        openCvVersion: payload['openCvVersion']?.toString(),
      );
      final qualityStatus = payload['qualityStatus']?.toString();
      await _persistJobStatusForOpenCvResult(
        qualityStatus: qualityStatus,
        reasonCode: payload['reasonCode']?.toString(),
        reasonMessage: payload['reasonMessage']?.toString(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _latestOpenCvResultId = result.id;
        _artifactStatus = rf('OpenCV result saved.', 'OpenCV 결과 저장됨.');
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _artifactStatus =
            '${rf('OpenCV result save failed', 'OpenCV 결과 저장 실패')}: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _isPersistingArtifacts = false);
      }
    }
  }

  Future<void> _persistConfirmedGeometryPayload(
    Map<String, Object?> payload,
  ) async {
    final job = widget.reconstructionJob;
    final sourceImage = widget.sourceImage;
    final points = _pointMaps(payload['points']);
    if (job == null || sourceImage == null || points.length < 3) {
      return;
    }
    await _pendingOpenCvResultWrite?.catchError((_) {});

    setState(() {
      _isPersistingArtifacts = true;
      _artifactStatus = rf('Saving confirmed geometry...', '확정 지오메트리 저장 중...');
    });

    try {
      final geometry = await widget.projectApi.persistConfirmedGeometry(
        projectId: widget.project.id,
        jobId: job.id,
        sourceImageId: sourceImage.id,
        openCvResultId: _latestOpenCvResultId,
        points: points,
        coordinateSpace:
            payload['coordinateSpace']?.toString() ?? 'image_pixels',
        geometryKind: payload['geometryKind']?.toString() ?? 'room_boundary',
        correctionMethod: 'manual_editor',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _latestConfirmedGeometryId = geometry.id;
        _artifactStatus = rf('Confirmed geometry saved.', '확정 지오메트리 저장됨.');
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _artifactStatus =
            '${rf('Confirmed geometry save failed', '확정 지오메트리 저장 실패')}: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _isPersistingArtifacts = false);
      }
    }
  }

  Future<void> _persistFloorPlanPayload(Map<String, Object?> payload) async {
    final job = widget.reconstructionJob;
    final sourceImage = widget.sourceImage;
    if (job == null || sourceImage == null) {
      return;
    }

    final imageGeometry = _recordValue(payload['imageGeometry']);
    final metricGeometry = _recordValue(payload['metricGeometry']);
    final metricPoints = _pointMaps(metricGeometry['points']);
    final referenceLengthValue =
        _numberValueOrNull(payload['referenceLengthValue']) ?? 0;
    if (metricPoints.length < 3 || referenceLengthValue <= 0) {
      return;
    }
    await _pendingOpenCvResultWrite?.catchError((_) {});

    setState(() {
      _isPersistingArtifacts = true;
      _artifactStatus = rf('Saving floor plan...', '평면도 저장 중...');
    });

    try {
      var confirmedGeometryId = _latestConfirmedGeometryId;
      if (confirmedGeometryId == null) {
        final imagePoints = _pointMaps(imageGeometry['points']);
        if (imagePoints.length >= 3) {
          final geometry = await widget.projectApi.persistConfirmedGeometry(
            projectId: widget.project.id,
            jobId: job.id,
            sourceImageId: sourceImage.id,
            openCvResultId: _latestOpenCvResultId,
            points: imagePoints,
            coordinateSpace:
                imageGeometry['coordinateSpace']?.toString() ?? 'image_pixels',
            geometryKind:
                imageGeometry['geometryKind']?.toString() ?? 'room_boundary',
            correctionMethod: 'manual_editor',
          );
          confirmedGeometryId = geometry.id;
        }
      }
      if (confirmedGeometryId == null) {
        return;
      }

      final floorPlan = await widget.projectApi.persistFloorPlanResult(
        projectId: widget.project.id,
        jobId: job.id,
        sourceImageId: sourceImage.id,
        confirmedGeometryId: confirmedGeometryId,
        referenceLine: _recordValue(payload['referenceLine']),
        referenceLengthValue: referenceLengthValue,
        imageGeometry: imageGeometry,
        metricGeometry: {...metricGeometry, 'points': metricPoints},
        perspectiveAssumptions: _recordValue(payload['perspectiveAssumptions']),
        unit: payload['unit']?.toString() ?? 'meters',
        qualityStatus: 'success',
      );
      await _persistJobStatusIfNeeded(
        status: 'succeeded',
        reasonCode: 'floor_plan_generated',
        reasonMessage:
            'User generated a metric floor plan from confirmed geometry.',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _latestConfirmedGeometryId = confirmedGeometryId;
        _latestFloorPlanId = floorPlan.id;
        _artifactStatus = rf('Floor plan saved.', '평면도 저장됨.');
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _artifactStatus =
            '${rf('Floor plan save failed', '평면도 저장 실패')}: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _isPersistingArtifacts = false);
      }
    }
  }

  Future<void> _persistSceneUnderstandingPayload(
    Map<String, Object?> payload,
  ) async {
    final resultPayload = _recordValue(payload['sceneUnderstandingResult']);
    if (resultPayload.isEmpty) {
      return;
    }

    setState(() {
      _isPersistingArtifacts = true;
      _artifactStatus = rf(
        'Saving scene understanding result...',
        '장면 이해 결과 저장 중...',
      );
    });

    try {
      final result = await widget.projectApi.persistSceneUnderstandingResult(
        projectId: widget.project.id,
        sceneUnderstandingResult: resultPayload,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _latestSceneUnderstandingResultId = result.id;
        _latestSceneUnderstandingBridgePayload = {
          'sceneUnderstandingResult': resultPayload,
        };
        _artifactStatus = rf(
          'Scene understanding result saved.',
          '장면 이해 결과 저장됨.',
        );
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _artifactStatus =
            '${rf('Scene understanding save failed', '장면 이해 저장 실패')}: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _isPersistingArtifacts = false);
      }
    }
  }

  Future<void> _persistJobStatusForOpenCvResult({
    required String? qualityStatus,
    required String? reasonCode,
    required String? reasonMessage,
  }) async {
    final status = qualityStatus == 'failed' && reasonCode != 'no_source_image'
        ? 'failed'
        : 'review_required';
    await _persistJobStatusIfNeeded(
      status: status,
      reasonCode: reasonCode ?? 'opencv_candidates_extracted',
      reasonMessage:
          reasonMessage ??
          (status == 'failed'
              ? 'OpenCV candidate extraction failed.'
              : 'OpenCV extracted candidate geometry that requires review.'),
      failureReasonCode: status == 'failed' ? reasonCode : null,
      failureReasonMessage: status == 'failed' ? reasonMessage : null,
    );
  }

  Future<void> _persistJobStatusIfNeeded({
    required String status,
    required String reasonCode,
    required String reasonMessage,
    String? failureReasonCode,
    String? failureReasonMessage,
  }) async {
    final job = widget.reconstructionJob;
    if (job == null) {
      return;
    }
    final currentStatus = _persistedJobStatus ?? job.status;
    if (currentStatus == status ||
        currentStatus == 'succeeded' ||
        currentStatus == 'failed' ||
        currentStatus == 'timeout' ||
        currentStatus == 'cancelled') {
      return;
    }
    try {
      final updated = await widget.projectApi.updateReconstructionJobStatus(
        projectId: widget.project.id,
        jobId: job.id,
        status: status,
        reasonCode: reasonCode,
        reasonMessage: reasonMessage,
        failureReasonCode: failureReasonCode,
        failureReasonMessage: failureReasonMessage,
      );
      _persistedJobStatus = updated.status;
    } catch (_) {
      // Artifact persistence can still succeed if the job-status transition races
      // another client or an already-terminal job.
    }
  }

  String? get _effectiveReconstructionStatus =>
      _persistedJobStatus ?? widget.reconstructionJob?.status;

  Future<void> _saveLayout() async {
    if (layoutStatusNeedsReview(_effectiveReconstructionStatus) &&
        !_reviewSaveConfirmed) {
      setState(() {
        _reviewSaveConfirmed = true;
        _saveStatus = rf(
          layoutNeedsReviewSaveWarning,
          '검토 필요 상태입니다. 다시 저장하면 계속 진행합니다.',
        );
      });
      return;
    }

    setState(() {
      _isSavingLayout = true;
      _saveStatus = rf('Saving...', '저장 중...');
    });

    try {
      final scene = _sceneForSave();
      _draftGeneration += 1;
      final pendingDraftWrite = _pendingDraftWrite;
      final saved = await widget.projectApi.saveLayout(
        projectId: widget.project.id,
        roomDimensions: _roomDimensionsPayload(),
        floorPlan: _floorPlanPayload(scene),
        sourceMetadata: _sourceMetadataPayload(),
        furnitureObjects: _furniturePayload(scene),
        editorScene: _editorScenePayload(scene),
      );
      if (!mounted) {
        return;
      }
      await _drainDraftWrite(pendingDraftWrite);
      final draftCleanupSucceeded = await _clearDraftAfterCloudSave(saved);
      setState(() {
        _activeLayoutId = saved.id;
        _activeCloudUpdatedAt = saved.updatedAt;
        _recoverableDraft = null;
        _reviewSaveConfirmed = false;
        _syncFailureVisible = false;
        _draftStatus = draftCleanupSucceeded
            ? rf('Saved', '저장됨')
            : rf('Draft cleanup unavailable.', '드래프트 정리를 사용할 수 없습니다.');
        _saveStatus = rf('Saved', '저장됨');
      });
    } on ProjectApiException catch (error) {
      _latestScene = _sceneForSave();
      _queuePersistDraft(
        _latestScene!,
        syncState: LayoutDraftSyncState.syncFailed,
        lastErrorCode: error.code,
        lastErrorMessage: error.message,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _reviewSaveConfirmed = false;
        _syncFailureVisible = true;
        _draftStatus =
            '${rf(layoutSyncFailedLabel, '동기화 실패')}. ${rf(layoutRetryAvailableLabel, '재시도 가능')}.';
        _saveStatus = '${rf('Save failed', '저장 실패')}: ${error.message}';
      });
    } catch (error) {
      _latestScene = _sceneForSave();
      _queuePersistDraft(
        _latestScene!,
        syncState: LayoutDraftSyncState.syncFailed,
        lastErrorMessage: error.toString(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _reviewSaveConfirmed = false;
        _syncFailureVisible = true;
        _draftStatus =
            '${rf(layoutSyncFailedLabel, '동기화 실패')}. ${rf(layoutRetryAvailableLabel, '재시도 가능')}.';
        _saveStatus = '${rf('Save failed', '저장 실패')}: $error';
      });
    } finally {
      if (mounted) {
        final shouldPersistPostSaveDraft =
            _draftChangedDuringSave && _latestScene != null;
        _draftChangedDuringSave = false;
        setState(() => _isSavingLayout = false);
        if (shouldPersistPostSaveDraft) {
          _queuePersistDraft(_latestScene!);
        }
      }
    }
  }

  Future<void> _loadLayout({bool forceApplyCloud = false}) async {
    setState(() {
      _isLoadingLayout = true;
      _loadStatus = rf('Loading...', '불러오는 중...');
    });

    try {
      final layout = await widget.projectApi.loadLatestLayout(
        projectId: widget.project.id,
      );
      final activeDraft = await _recoverableDraftForCloudApply(layout);
      final remoteLayout = guardedRemoteLayout(
        layout: layout,
        draft: activeDraft,
        forceApplyCloud: forceApplyCloud,
        latestCloudUpdatedAt: layout.updatedAt,
      );
      final remoteDecision = remoteLayout.decision;
      if (!remoteDecision.applyRemoteLayout) {
        if (!mounted) {
          return;
        }
        setState(() {
          _recoverableDraft = activeDraft;
          _activeCloudUpdatedAt = layout.updatedAt;
          _draftStatus = rf(
            remoteDecision.message ?? layoutRemoteUpdateHeldMessage,
            '로컬 드래프트가 있어 클라우드 레이아웃 적용을 보류했습니다.',
          );
          _loadStatus = rf(
            remoteDecision.message ?? layoutRemoteUpdateHeldMessage,
            '로컬 드래프트가 있어 클라우드 레이아웃 적용을 보류했습니다.',
          );
        });
        return;
      }
      final appliedLayout = remoteLayout.layout ?? layout;
      final scene = _sceneFromSavedLayout(appliedLayout);
      final viewMode = scene['viewMode']?.toString();
      if (!mounted) {
        return;
      }
      setState(() {
        _latestScene = scene;
        _activeLayoutId = appliedLayout.id;
        _activeCloudUpdatedAt = appliedLayout.updatedAt;
        _recoverableDraft = null;
        _syncFailureVisible = false;
        final nextViewMode = viewMode == '2d' || viewMode == '3d'
            ? viewMode
            : null;
        if (nextViewMode != null) {
          _viewMode = nextViewMode;
        }
        _saveStatus = rf('Saved', '저장됨');
        _loadStatus = rf('Loaded layout', '레이아웃 불러옴');
      });
      if (!forceApplyCloud) {
        unawaited(
          _detectRecoverableDraft(
            layoutId: appliedLayout.id,
            latestCloudUpdatedAt: appliedLayout.updatedAt,
          ),
        );
      }
      _postEditorMessage(
        type: 'roomforge.scene.initialize',
        requestId: 'load-layout-${appliedLayout.id}',
        payload: {'scene': scene},
      );
    } on ProjectApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(
        () => _loadStatus = '${rf('Load failed', '불러오기 실패')}: ${error.message}',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _loadStatus = '${rf('Load failed', '불러오기 실패')}: $error');
    } finally {
      if (mounted) {
        setState(() => _isLoadingLayout = false);
      }
    }
  }

  Future<void> _exportLayout() async {
    setState(() {
      _isExportingLayout = true;
      _exportStatus = rf(
        'Checking latest saved layout...',
        '최근 저장된 레이아웃 확인 중...',
      );
    });

    try {
      final exportPayload = await widget.projectApi.exportLatestLayout(
        projectId: widget.project.id,
      );
      final needsReview = layoutExportNeedsReviewWarning(exportPayload);
      if (needsReview && !_reviewExportConfirmed) {
        if (!mounted) {
          return;
        }
        setState(() {
          _reviewExportConfirmed = true;
          _exportStatus = rf(
            layoutNeedsReviewExportWarning,
            '검토 필요 경고가 있습니다. 다시 내보내면 계속 진행합니다.',
          );
        });
        return;
      }
      _downloadLayoutExport(exportPayload);
      if (!mounted) {
        return;
      }
      setState(() {
        _reviewExportConfirmed = false;
        _exportStatus = needsReview
            ? rf(
                'Exported JSON with $layoutNeedsReviewLabel warning',
                '검토 필요 경고와 함께 JSON을 내보냈습니다',
              )
            : rf('Exported JSON', 'JSON 내보내기 완료');
      });
    } on ProjectApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _reviewExportConfirmed = false;
        _exportStatus = '${rf('Export failed', '내보내기 실패')}: ${error.message}';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _reviewExportConfirmed = false;
        _exportStatus = '${rf('Export failed', '내보내기 실패')}: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _isExportingLayout = false);
      }
    }
  }

  void _downloadLayoutExport(Map<String, Object?> exportPayload) {
    final encoded = const JsonEncoder.withIndent('  ').convert(exportPayload);
    final blob = html.Blob([encoded], 'application/json');
    final url = html.Url.createObjectUrlFromBlob(blob);
    try {
      html.AnchorElement(href: url)
        ..download = 'roomforge-project-${widget.project.id}-layout.json'
        ..click();
    } finally {
      html.Url.revokeObjectUrl(url);
    }
  }

  Future<void> _detectRecoverableDraftWithLatestCloud() async {
    SavedLayout? latestLayout;
    try {
      latestLayout = await widget.projectApi.loadLatestLayout(
        projectId: widget.project.id,
      );
    } on ProjectApiException catch (error) {
      if (error.code != 'not_found' && mounted) {
        setState(
          () => _loadStatus =
              '${rf('Latest layout check failed', '최근 레이아웃 확인 실패')}: ${error.message}',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _loadStatus =
              '${rf('Latest layout check failed', '최근 레이아웃 확인 실패')}: $error',
        );
      }
    }

    await _detectRecoverableDraft(
      layoutId: latestLayout?.id,
      latestCloudUpdatedAt: latestLayout?.updatedAt,
    );
  }

  Future<void> _loadPersistedSceneUnderstandingResult() async {
    try {
      final payload = await widget.projectApi
          .loadLatestSceneUnderstandingResult(projectId: widget.project.id);
      if (payload == null) {
        return;
      }
      final result = _recordValue(payload['sceneUnderstandingResult']);
      if (!mounted || result.isEmpty) {
        return;
      }
      setState(() {
        _latestSceneUnderstandingBridgePayload = payload;
        _latestSceneUnderstandingResultId = result['resultId']?.toString();
        _artifactStatus = rf(
          'Loaded saved scene understanding result.',
          '저장된 장면 이해 결과를 불러왔습니다.',
        );
      });
      _postEditorMessage(
        type: 'roomforge.scene.initialize',
        requestId: 'load-scene-understanding-${result['resultId']}',
        payload: _sceneInitializePayload(),
      );
    } on ProjectApiException catch (error) {
      if (error.code == 'unsupported_backend' || error.code == 'not_found') {
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _artifactStatus =
            '${rf('Scene understanding load failed', '장면 이해 불러오기 실패')}: ${error.message}';
      });
    } catch (_) {
      // Scene understanding replay is optional; manual editing and layout load still work.
    }
  }

  Future<void> _detectRecoverableDraft({
    String? layoutId,
    DateTime? latestCloudUpdatedAt,
  }) async {
    try {
      var draft = await _draftRepository.getDraft(
        ownerUid: widget.project.userId,
        projectId: widget.project.id,
        layoutId: layoutId,
      );
      if (draft == null && layoutId != null) {
        draft = await _draftRepository.getDraft(
          ownerUid: widget.project.userId,
          projectId: widget.project.id,
        );
      }
      if (!mounted) {
        return;
      }
      setState(() {
        if (latestCloudUpdatedAt != null) {
          _activeCloudUpdatedAt = latestCloudUpdatedAt;
        }
        _recoverableDraft = draft?.isRecoverable == true ? draft : null;
        _draftStatus = draft == null || !draft.isRecoverable
            ? rf('No local draft.', '로컬 드래프트 없음.')
            : _localizedLayoutDraftRecoveryMessage(
                draft: draft,
                latestCloudUpdatedAt:
                    latestCloudUpdatedAt ?? _activeCloudUpdatedAt,
              );
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(
        () => _draftStatus = rf('Draft check unavailable.', '드래프트 확인 불가.'),
      );
    }
  }

  Future<LayoutDraft?> _recoverableDraftForCloudApply(
    SavedLayout layout,
  ) async {
    final layoutDraft = await _draftRepository.getDraft(
      ownerUid: widget.project.userId,
      projectId: widget.project.id,
      layoutId: layout.id,
    );
    final currentDraft =
        layoutDraft ??
        await _draftRepository.getDraft(
          ownerUid: widget.project.userId,
          projectId: widget.project.id,
        );
    return currentDraft?.isRecoverable == true ? currentDraft : null;
  }

  Future<void> _restoreDraft() async {
    final draft = _recoverableDraft;
    if (draft == null) {
      return;
    }
    setState(() => _isHandlingDraft = true);
    try {
      final scene = _sceneFromDraft(draft);
      if (!mounted) {
        return;
      }
      setState(() {
        _latestScene = scene;
        _activeLayoutId = draft.layoutId;
        _activeCloudUpdatedAt = draft.baseCloudUpdatedAt;
        _recoverableDraft = null;
        _syncFailureVisible = false;
        _draftStatus = rf('Unsaved draft', '저장되지 않은 드래프트');
        _saveStatus = rf('Unsaved draft', '저장되지 않은 드래프트');
      });
      _postEditorMessage(
        type: 'roomforge.scene.initialize',
        requestId: 'restore-draft-${draft.localRevision}',
        payload: {'scene': scene},
      );
    } finally {
      if (mounted) {
        setState(() => _isHandlingDraft = false);
      }
    }
  }

  Future<void> _discardDraft() async {
    final draft = _recoverableDraft;
    if (draft == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(rf(draftRecoveryDiscardConfirmationTitle, '드래프트를 버릴까요?')),
          content: Text(
            rf(draftRecoveryDiscardConfirmationMessage, '로컬 드래프트만 삭제합니다.'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(rf('Cancel', '취소')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(rf('Discard draft', '드래프트 버리기')),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    setState(() => _isHandlingDraft = true);
    try {
      await _draftRepository.clearDraft(
        ownerUid: widget.project.userId,
        projectId: widget.project.id,
      );
      if (draft.layoutId != null) {
        await _draftRepository.clearDraft(
          ownerUid: widget.project.userId,
          projectId: widget.project.id,
          layoutId: draft.layoutId,
        );
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _recoverableDraft = null;
        _syncFailureVisible = false;
        _draftStatus = rf('No local draft.', '로컬 드래프트 없음.');
      });
    } finally {
      if (mounted) {
        setState(() => _isHandlingDraft = false);
      }
    }
  }

  void _continueSavedVersion() {
    setState(() {
      _recoverableDraft = null;
      _syncFailureVisible = false;
      _draftStatus = rf('Using saved cloud layout.', '저장된 클라우드 레이아웃 사용 중.');
    });
    unawaited(_loadLayout(forceApplyCloud: true));
  }

  void _queuePersistDraft(
    Map<String, Object?> scene, {
    String syncState = LayoutDraftSyncState.unsavedDraft,
    String? lastErrorCode,
    String? lastErrorMessage,
  }) {
    if (_isSavingLayout && syncState == LayoutDraftSyncState.unsavedDraft) {
      _draftChangedDuringSave = true;
      return;
    }
    final generation = _draftGeneration;
    _pendingDraftWrite = _pendingDraftWrite
        .catchError((_) {})
        .then(
          (_) => _persistDraft(
            scene,
            generation,
            syncState: syncState,
            lastErrorCode: lastErrorCode,
            lastErrorMessage: lastErrorMessage,
          ),
        );
    unawaited(_pendingDraftWrite);
  }

  Future<void> _drainDraftWrite(Future<void> pendingDraftWrite) async {
    try {
      await pendingDraftWrite;
    } catch (_) {}
  }

  Future<void> _persistDraft(
    Map<String, Object?> scene,
    int generation, {
    required String syncState,
    String? lastErrorCode,
    String? lastErrorMessage,
  }) async {
    if (generation != _draftGeneration) {
      return;
    }
    try {
      final draft = await _draftRepository.saveDraft(
        ownerUid: widget.project.userId,
        projectId: widget.project.id,
        layoutId: _activeLayoutId,
        baseCloudLayoutId: _activeLayoutId,
        baseCloudUpdatedAt: _activeCloudUpdatedAt,
        roomDimensionsSnapshot: _roomDimensionsPayload(),
        floorPlanSnapshot: _floorPlanPayload(scene),
        sourceMetadataSnapshot: _sourceMetadataPayload(),
        editorScene: _editorScenePayload(scene),
        furnitureObjects: _furniturePayload(scene),
        reconstructionStatus: _effectiveReconstructionStatus ?? 'created',
        reviewRequired: layoutStatusNeedsReview(_effectiveReconstructionStatus),
        syncState: syncState,
        lastErrorCode: lastErrorCode,
        lastErrorMessage: lastErrorMessage,
      );
      if (!mounted || generation != _draftGeneration) {
        return;
      }
      if (syncState == LayoutDraftSyncState.syncFailed) {
        setState(() => _recoverableDraft = draft);
        return;
      }
      if (!_syncFailureVisible) {
        setState(() => _draftStatus = _localizedDraftLabel(draft.label));
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _draftStatus = rf('Draft save failed.', '드래프트 저장 실패.'));
    }
  }

  Future<bool> _clearDraftAfterCloudSave(SavedLayout saved) async {
    try {
      final previousLayoutId = _activeLayoutId;
      await _draftRepository.clearDraft(
        ownerUid: widget.project.userId,
        projectId: widget.project.id,
      );
      if (previousLayoutId != null && previousLayoutId != saved.id) {
        await _draftRepository.clearDraft(
          ownerUid: widget.project.userId,
          projectId: widget.project.id,
          layoutId: previousLayoutId,
        );
      }
      await _draftRepository.clearDraft(
        ownerUid: widget.project.userId,
        projectId: widget.project.id,
        layoutId: saved.id,
      );
      await _draftRepository.saveProjectCache(
        ownerUid: widget.project.userId,
        projects: [_projectCacheSnapshot(latestLayoutId: saved.id)],
      );
      return true;
    } catch (_) {
      if (!mounted) {
        return false;
      }
      setState(
        () => _draftStatus = rf('Draft cleanup unavailable.', '드래프트 정리 불가.'),
      );
      return false;
    }
  }

  Map<String, Object?> _projectCacheSnapshot({String? latestLayoutId}) {
    return {
      'project_id': widget.project.id,
      'owner_uid': widget.project.userId,
      'name': widget.project.name,
      'description': widget.project.description,
      'latest_layout_id': latestLayoutId,
      'updated_at': widget.project.updatedAt.toUtc().toIso8601String(),
    };
  }

  Map<String, Object?> _sceneForSave() {
    final scene = _latestScene;
    if (scene != null) {
      return scene;
    }
    final payload = _sceneInitializePayload();
    return Map<String, Object?>.from(payload['scene'] as Map);
  }

  Map<String, Object?> _roomDimensionsPayload() {
    final dimensions = widget.initialDimensions;
    return {
      'unit': dimensions?.unit ?? 'meters',
      'width_value': dimensions?.widthValue ?? 4.2,
      'depth_value': dimensions?.depthValue ?? 3.6,
      'height_value': dimensions?.heightValue ?? 2.7,
    };
  }

  Map<String, Object?> _floorPlanPayload(Map<String, Object?> scene) {
    final room = _recordValue(scene['room']);
    final floorPlan = _recordValue(room['floorPlan']);
    final metricGeometry = _recordValue(floorPlan['metricGeometry']);
    final points = _listValue(metricGeometry['points'])
        .map(_recordValue)
        .map(
          (point) => {
            'x': _numberValue(point['x'], 0),
            'y': _numberValue(point['y'], 0),
          },
        )
        .toList();

    return {
      'floor_plan_id':
          _latestFloorPlanId ??
          floorPlan['floorPlanId']?.toString() ??
          'project-${widget.project.id}-metric-floor-plan',
      'metric_geometry': {
        'coordinate_space':
            metricGeometry['coordinateSpace']?.toString() ?? 'meters',
        'points': points,
      },
    };
  }

  Map<String, Object?> _sourceMetadataPayload() {
    final sourceImage = widget.sourceImage;
    return {
      'source_image_id': sourceImage?.id,
      'project_id': sourceImage?.projectId,
      'owner_uid': sourceImage?.userId,
      'original_filename': sourceImage?.originalFilename,
      'stored_filename': sourceImage?.storedName,
      'content_type': sourceImage?.contentType,
      'byte_size': sourceImage?.byteSize,
      'width_px': sourceImage?.widthPx,
      'height_px': sourceImage?.heightPx,
      'sha256_hex': sourceImage?.sha256Hex,
      'retention_status': sourceImage?.retentionStatus,
      'uploaded_at': sourceImage?.uploadedAt.toUtc().toIso8601String(),
      'reconstruction_job_id': widget.reconstructionJob?.id,
      'reconstruction_status': _effectiveReconstructionStatus,
      'opencv_result_id': _latestOpenCvResultId,
      'confirmed_geometry_id': _latestConfirmedGeometryId,
      'floor_plan_id': _latestFloorPlanId,
    };
  }

  Map<String, Object?> _sceneFromSavedLayout(SavedLayout layout) {
    final roomDimensions = layout.roomDimensions;
    final width = _numberValue(roomDimensions['width_value'], 4.2);
    final depth = _numberValue(roomDimensions['depth_value'], 3.6);
    final height = _numberValue(roomDimensions['height_value'], 2.7);
    final floorPlan = layout.floorPlan;
    final metricGeometry = _recordValue(floorPlan['metric_geometry']);
    final points = _savedMetricPoints(floorPlan, metricGeometry, width, depth);
    final editorScene = layout.editorScene;
    final viewMode = editorScene['view_mode']?.toString() == '3d' ? '3d' : '2d';

    return {
      'sceneId':
          editorScene['scene_id']?.toString() ??
          'project-${widget.project.id}-planning-scene',
      'coordinateSpace': 'meters',
      'unit': roomDimensions['unit']?.toString() ?? 'meters',
      'viewMode': viewMode,
      'selected': _savedSelection(editorScene),
      'hasUnsavedChanges': false,
      'scale': {'metersPerSceneUnit': 1},
      'room': {
        'objectId': 'room-shell',
        'label': 'Room shell',
        'heightMeters': height,
        'floorPlan': {
          'floorPlanId':
              floorPlan['floor_plan_id']?.toString() ??
              'project-${widget.project.id}-metric-floor-plan',
          'metricGeometry': {
            'coordinateSpace':
                metricGeometry['coordinate_space']?.toString() ??
                floorPlan['coordinate_space']?.toString() ??
                'meters',
            'points': points,
          },
        },
      },
      'furniture': _savedFurniture(layout.furnitureObjects),
    };
  }

  Map<String, Object?> _sceneFromDraft(LayoutDraft draft) {
    final roomDimensions = draft.roomDimensionsSnapshot;
    final width = _numberValue(roomDimensions['width_value'], 4.2);
    final depth = _numberValue(roomDimensions['depth_value'], 3.6);
    final height = _numberValue(roomDimensions['height_value'], 2.7);
    final floorPlan = draft.floorPlanSnapshot;
    final metricGeometry = _recordValue(floorPlan['metric_geometry']);
    final points = _savedMetricPoints(floorPlan, metricGeometry, width, depth);
    final editorScene = draft.editorScene;
    final viewMode = editorScene['view_mode']?.toString() == '3d' ? '3d' : '2d';

    return {
      'sceneId':
          editorScene['scene_id']?.toString() ??
          'project-${widget.project.id}-planning-scene',
      'coordinateSpace': 'meters',
      'unit': roomDimensions['unit']?.toString() ?? 'meters',
      'viewMode': viewMode,
      'selected': _savedSelection(editorScene),
      'hasUnsavedChanges': true,
      'scale': {'metersPerSceneUnit': 1},
      'room': {
        'objectId': 'room-shell',
        'label': 'Room shell',
        'heightMeters': height,
        'floorPlan': {
          'floorPlanId':
              floorPlan['floor_plan_id']?.toString() ??
              'project-${widget.project.id}-metric-floor-plan',
          'metricGeometry': {
            'coordinateSpace':
                metricGeometry['coordinate_space']?.toString() ??
                floorPlan['coordinate_space']?.toString() ??
                'meters',
            'points': points,
          },
        },
      },
      'furniture': savedFurnitureToBridge(draft.furnitureObjects),
    };
  }

  List<Map<String, double>> _savedMetricPoints(
    Map<String, Object?> floorPlan,
    Map<String, Object?> metricGeometry,
    double width,
    double depth,
  ) {
    final rawPoints = _listValue(metricGeometry['points']).isNotEmpty
        ? _listValue(metricGeometry['points'])
        : _listValue(floorPlan['points']);
    final points = rawPoints
        .map(_recordValue)
        .map(
          (point) => {
            'x': _numberValue(point['x'], 0),
            'y': _numberValue(point['y'], 0),
          },
        )
        .toList();
    if (points.length >= 3) {
      return points;
    }
    return [
      {'x': 0.0, 'y': 0.0},
      {'x': width, 'y': 0.0},
      {'x': width, 'y': depth},
      {'x': 0.0, 'y': depth},
    ];
  }

  Map<String, Object?> _savedSelection(Map<String, Object?> editorScene) {
    final selected = _recordValue(editorScene['selected']);
    final objectId = selected['object_id'] ?? selected['objectId'];
    if (objectId == null) {
      return {'objectId': 'room-shell', 'objectType': 'room'};
    }
    return {
      'objectId': objectId.toString(),
      'objectType': selected['object_type']?.toString() == 'furniture'
          ? 'furniture'
          : 'room',
    };
  }

  List<Map<String, Object?>> _savedFurniture(List<Object?> furnitureObjects) {
    return savedFurnitureToBridge(furnitureObjects);
  }

  List<Map<String, Object?>> _furniturePayload(Map<String, Object?> scene) {
    return bridgeFurnitureToLayoutPayload(scene['furniture']);
  }

  Map<String, Object?> _editorScenePayload(Map<String, Object?> scene) {
    final selected = _recordValue(scene['selected']);
    return {
      'scene_id':
          scene['sceneId']?.toString() ??
          'project-${widget.project.id}-planning-scene',
      'view_mode': scene['viewMode']?.toString() ?? _viewMode,
      'selected': selected.isEmpty
          ? null
          : {
              'object_id': selected['objectId']?.toString(),
              'object_type': selected['objectType']?.toString(),
            },
      'has_unsaved_changes': scene['hasUnsavedChanges'] == true,
    };
  }

  Map<String, Object?> _recordValue(Object? value) {
    return value is Map ? Map<String, Object?>.from(value) : {};
  }

  List<Object?> _listValue(Object? value) {
    return value is List ? value.cast<Object?>() : const [];
  }

  double _numberValue(Object? value, double fallback) {
    return value is num ? value.toDouble() : fallback;
  }

  double? _numberValueOrNull(Object? value) {
    return value is num ? value.toDouble() : null;
  }

  List<Map<String, Object?>> _pointMaps(Object? value) {
    return _listValue(value)
        .map(_recordValue)
        .where((point) => point['x'] is num && point['y'] is num)
        .map(
          (point) => {
            'x': (point['x'] as num).toDouble(),
            'y': (point['y'] as num).toDouble(),
          },
        )
        .toList();
  }

  void _postEditorMessage({
    required String type,
    required String requestId,
    required Map<String, Object?> payload,
  }) {
    _iframe.contentWindow?.postMessage({
      'type': type,
      'version': 1,
      'requestId': requestId,
      'payload': payload,
    }, '*');
  }

  Map<String, Object?> _sceneInitializePayload() {
    final dimensions = widget.initialDimensions;
    final sourceImage = widget.sourceImage;
    final captureSession = _captureSessionBridgePayload();
    final width = dimensions?.widthValue ?? 4.2;
    final depth = dimensions?.depthValue ?? 3.6;
    final height = dimensions?.heightValue ?? 2.7;
    final reviewRequired = _effectiveReconstructionStatus == 'review_required';

    final payload = <String, Object?>{
      'scene': {
        'sceneId': 'project-${widget.project.id}-planning-scene',
        'viewMode': _viewMode,
        'hasUnsavedChanges': false,
        'selected': {'objectId': 'room-shell', 'objectType': 'room'},
        'room': {
          'objectId': 'room-shell',
          'label': 'Room shell',
          'heightMeters': height,
          'floorPlan': {
            'floorPlanId': 'project-${widget.project.id}-metric-floor-plan',
            'metricGeometry': {
              'coordinateSpace': 'meters',
              'points': [
                {'x': 0.0, 'y': 0.0},
                {'x': width, 'y': 0.0},
                {'x': width, 'y': depth},
                {'x': 0.0, 'y': depth},
              ],
            },
          },
        },
      },
      'sourceImage': sourceImage == null
          ? null
          : {
              'sourceImageId': sourceImage.id,
              'contentType': sourceImage.contentType,
              'widthPx': sourceImage.widthPx,
              'heightPx': sourceImage.heightPx,
              'dataUrl': widget.sourceImageDataUrl,
            },
      'captureSession': captureSession,
      'reconstructionStatus': reviewRequired
          ? {'status': 'review_required', 'label': 'Needs review'}
          : null,
      'sceneUnderstandingResultId': _latestSceneUnderstandingResultId,
    };
    final sceneUnderstandingPayload = _latestSceneUnderstandingBridgePayload;
    if (sceneUnderstandingPayload != null) {
      payload.addAll(sceneUnderstandingPayload);
    }
    return payload;
  }

  Map<String, Object?>? _captureSessionBridgePayload() {
    final session = widget.captureSession;
    if (session == null) {
      return null;
    }
    final images = [...widget.captureImages]
      ..sort(
        (a, b) => (a.captureOrder ?? _captureRoleOrder(a.role)).compareTo(
          b.captureOrder ?? _captureRoleOrder(b.role),
        ),
      );
    return _compactPayload({
      'captureSessionId': session.id,
      'projectId': session.projectId,
      'roomDimensionsId': session.roomDimensionsId,
      'captureMethod': session.captureMethod,
      'depthEnabled': session.depthEnabled,
      'startedAt': session.startedAt?.toUtc().toIso8601String(),
      'completedAt': session.completedAt?.toUtc().toIso8601String(),
      'notes': session.notes,
      'availableRoles': images
          .map((image) => image.role)
          .toSet()
          .toList(growable: false),
      'images': images
          .map(
            (image) => _compactPayload({
              'captureImageId': image.id,
              'captureSessionId': image.captureSessionId,
              'sourceImageId': image.sourceImageId,
              'role': image.role,
              'storagePath': image.storagePath,
              'contentType': image.contentType,
              'widthPx': image.widthPx,
              'heightPx': image.heightPx,
              'captureOrder': image.captureOrder,
              'guidanceState': image.guidanceState,
              'depthArtifactRefs': image.depthArtifactRefs
                  .map(
                    (ref) => _compactPayload({
                      'artifactId': ref.artifactId,
                      'artifactType': ref.artifactType,
                      'storagePath': ref.storagePath,
                      'contentType': ref.contentType,
                      'byteSize': ref.byteSize,
                    }),
                  )
                  .toList(),
              'cameraPose': _camelCaseNested(image.cameraPose),
            }),
          )
          .toList(),
    });
  }

  Map<String, Object?> _compactPayload(Map<String, Object?> value) {
    return {
      for (final entry in value.entries)
        if (entry.value != null) entry.key: entry.value,
    };
  }

  Object? _camelCaseNested(Object? value) {
    if (value is Map) {
      return {
        for (final entry in value.entries)
          _snakeToCamel(entry.key.toString()): _camelCaseNested(entry.value),
      };
    }
    if (value is Iterable) {
      return value.map(_camelCaseNested).toList();
    }
    return value;
  }

  String _snakeToCamel(String value) {
    final parts = value.split('_');
    if (parts.isEmpty) {
      return value;
    }
    return [
      parts.first,
      ...parts
          .skip(1)
          .map(
            (part) => part.isEmpty
                ? part
                : '${part[0].toUpperCase()}${part.substring(1)}',
          ),
    ].join();
  }

  int _captureRoleOrder(String role) {
    return switch (role) {
      'overview' => 0,
      'front_wall' => 1,
      'right_wall' => 2,
      'back_wall' => 3,
      'left_wall' => 4,
      'extra' => 5,
      _ => 99,
    };
  }

  String _editorUrlFor(RoomProject project) {
    final uri = Uri.parse(EditorConfig.editorUrl);
    final queryParameters = Map<String, String>.from(uri.queryParameters)
      ..['project_id'] = project.id.toString();
    if (_roomForgeUsesKorean) {
      queryParameters['locale'] = 'ko';
    }
    return uri.replace(queryParameters: queryParameters).toString();
  }
}

class _EditorBridgeCommandBar extends StatelessWidget {
  const _EditorBridgeCommandBar({
    required this.viewMode,
    required this.sceneStatus,
    required this.bridgeStatus,
    required this.runtimeStatus,
    required this.saveStatus,
    required this.loadStatus,
    required this.draftStatus,
    required this.exportStatus,
    required this.isSavingLayout,
    required this.isLoadingLayout,
    required this.isExportingLayout,
    required this.isHandlingDraft,
    required this.isSyncFailureVisible,
    required this.onViewModeChanged,
    required this.onSaveLayout,
    required this.onLoadLayout,
    required this.onExportLayout,
    required this.onRestoreDraft,
    required this.onDiscardDraft,
    required this.onContinueSavedVersion,
    required this.onPingEditor,
    this.recoverableDraft,
    this.activeCloudUpdatedAt,
  });

  final String viewMode;
  final String sceneStatus;
  final String bridgeStatus;
  final String runtimeStatus;
  final String saveStatus;
  final String loadStatus;
  final String draftStatus;
  final String exportStatus;
  final LayoutDraft? recoverableDraft;
  final DateTime? activeCloudUpdatedAt;
  final bool isSavingLayout;
  final bool isLoadingLayout;
  final bool isExportingLayout;
  final bool isHandlingDraft;
  final bool isSyncFailureVisible;
  final ValueChanged<String> onViewModeChanged;
  final VoidCallback onSaveLayout;
  final VoidCallback onLoadLayout;
  final VoidCallback onExportLayout;
  final VoidCallback onRestoreDraft;
  final VoidCallback onDiscardDraft;
  final VoidCallback onContinueSavedVersion;
  final VoidCallback onPingEditor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recoveryDraft = recoverableDraft;
    final includeContinueSavedVersion =
        recoveryDraft != null &&
        layoutDraftHasCloudConflict(recoveryDraft, activeCloudUpdatedAt);
    final recoveryActions = recoveryDraft == null
        ? const <LayoutDraftRecoveryAction>[]
        : layoutDraftRecoveryActions(
            draft: recoveryDraft,
            latestCloudUpdatedAt: activeCloudUpdatedAt,
            includeContinueSavedVersion: includeContinueSavedVersion,
            includeRetry: isSyncFailureVisible,
          ).map(_localizedDraftRecoveryAction).toList();
    final saveActionLabel = isSyncFailureVisible
        ? _localizedDraftRecoveryActionLabel(draftRecoveryRetrySaveActionLabel)
        : rf('Save layout', '레이아웃 저장');

    return Material(
      color: _roomForgePanel,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _roomForgeBorder)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 860;
              final controls = [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: '2d', label: Text('2D')),
                    ButtonSegment(value: '3d', label: Text('3D')),
                  ],
                  selected: {viewMode},
                  onSelectionChanged: (selection) =>
                      onViewModeChanged(selection.first),
                ),
                FilledButton.icon(
                  onPressed: isSavingLayout ? null : onSaveLayout,
                  icon: isSavingLayout
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    isSavingLayout
                        ? rf('Saving...', '저장 중...')
                        : saveActionLabel,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: isLoadingLayout ? null : onLoadLayout,
                  icon: const Icon(Icons.cloud_download_outlined),
                  label: Text(
                    isLoadingLayout
                        ? rf('Loading...', '불러오는 중...')
                        : rf('Load layout', '레이아웃 불러오기'),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: isExportingLayout ? null : onExportLayout,
                  icon: const Icon(Icons.file_download_outlined),
                  label: Text(
                    isExportingLayout
                        ? rf('Exporting...', '내보내는 중...')
                        : rf('Export JSON', 'JSON 내보내기'),
                  ),
                ),
                IconButton.outlined(
                  tooltip: rf('Ping editor bridge', '편집기 브리지 확인'),
                  onPressed: onPingEditor,
                  icon: const Icon(Icons.sensors_outlined),
                ),
              ];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(spacing: 8, runSpacing: 8, children: controls),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _EditorStatusPill(
                        icon: Icons.grid_view_outlined,
                        label: sceneStatus,
                        color: _statusColor(sceneStatus),
                        maxWidth: compact ? constraints.maxWidth : 320,
                      ),
                      _EditorStatusPill(
                        icon: Icons.cable_outlined,
                        label: bridgeStatus,
                        color: _statusColor(bridgeStatus),
                        maxWidth: compact ? constraints.maxWidth : 280,
                      ),
                      _EditorStatusPill(
                        icon: Icons.memory_outlined,
                        label: runtimeStatus,
                        color: _statusColor(runtimeStatus),
                        maxWidth: compact ? constraints.maxWidth : 280,
                      ),
                      _EditorStatusPill(
                        icon: Icons.save_outlined,
                        label: saveStatus,
                        color: _statusColor(saveStatus),
                        maxWidth: compact ? constraints.maxWidth : 220,
                      ),
                      _EditorStatusPill(
                        icon: Icons.cloud_sync_outlined,
                        label: loadStatus,
                        color: _statusColor(loadStatus),
                        maxWidth: compact ? constraints.maxWidth : 220,
                      ),
                      _EditorStatusPill(
                        icon: Icons.edit_note_outlined,
                        label: draftStatus,
                        color: _statusColor(draftStatus),
                        maxWidth: compact ? constraints.maxWidth : 260,
                      ),
                      _EditorStatusPill(
                        icon: Icons.file_download_outlined,
                        label: exportStatus,
                        color: _statusColor(exportStatus),
                        maxWidth: compact ? constraints.maxWidth : 260,
                      ),
                    ],
                  ),
                  if (isSyncFailureVisible) ...[
                    const SizedBox(height: 10),
                    _SyncFailurePanel(
                      saveStatus: saveStatus,
                      draftStatus: draftStatus,
                      onRetry: onSaveLayout,
                      onKeepLocal: () {},
                      onShowLogs: onPingEditor,
                      onReopenProject: onLoadLayout,
                    ),
                  ],
                  if (recoverableDraft != null) ...[
                    const SizedBox(height: 10),
                    Semantics(
                      container: true,
                      liveRegion: true,
                      label: _localizedLayoutDraftRecoveryAccessibilitySummary(
                        draft: recoverableDraft!,
                        latestCloudUpdatedAt: activeCloudUpdatedAt,
                        includeContinueSavedVersion:
                            includeContinueSavedVersion,
                        includeRetry: isSyncFailureVisible,
                      ),
                      child: RoomForgeNotice(
                        title: rf('Unsaved draft recovery', '저장되지 않은 드래프트 복구'),
                        message: _localizedLayoutDraftRecoveryMessage(
                          draft: recoverableDraft!,
                          latestCloudUpdatedAt: activeCloudUpdatedAt,
                        ),
                        severity: NoticeSeverity.warning,
                        icon: Icons.restore_page_outlined,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _DraftRecoveryDiffSummary(
                      draft: recoverableDraft!,
                      latestCloudUpdatedAt: activeCloudUpdatedAt,
                      hasCloudConflict: includeContinueSavedVersion,
                    ),
                    const SizedBox(height: 8),
                    LayoutDraftRecoveryControls(
                      actions: recoveryActions,
                      isHandlingDraft: isHandlingDraft,
                      semanticsLabel:
                          _localizedLayoutDraftRecoveryAccessibilitySummary(
                            draft: recoverableDraft!,
                            latestCloudUpdatedAt: activeCloudUpdatedAt,
                            includeContinueSavedVersion:
                                includeContinueSavedVersion,
                            includeRetry: isSyncFailureVisible,
                          ),
                      onRestoreDraft: onRestoreDraft,
                      onDiscardDraft: onDiscardDraft,
                      onContinueSavedVersion: onContinueSavedVersion,
                      onRetrySave: onSaveLayout,
                    ),
                  ],
                  if (compact) ...[
                    const SizedBox(height: 4),
                    Text(
                      rf(
                        'Canvas controls remain inside the editor frame.',
                        '캔버스 컨트롤은 편집기 프레임 안에 있습니다.',
                      ),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: _roomForgeMuted,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Color _statusColor(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('failed') ||
        lower.contains('unavailable') ||
        lower.contains('warning') ||
        lower.contains('review') ||
        lower.contains('conflict') ||
        lower.contains('실패') ||
        lower.contains('사용할 수 없') ||
        lower.contains('불가') ||
        lower.contains('경고') ||
        lower.contains('검토') ||
        lower.contains('충돌')) {
      return lower.contains('review') ||
              lower.contains('warning') ||
              lower.contains('conflict') ||
              lower.contains('경고') ||
              lower.contains('검토') ||
              lower.contains('충돌')
          ? _roomForgeWarning
          : _roomForgeError;
    }
    if (lower.contains('saved') ||
        lower.contains('ready') ||
        lower.contains('loaded') ||
        lower.contains('exported') ||
        lower.contains('저장됨') ||
        lower.contains('준비됨') ||
        lower.contains('로드됨') ||
        lower.contains('불러옴') ||
        lower.contains('내보내기 완료')) {
      return _roomForgeSuccess;
    }
    if (lower.contains('saving') ||
        lower.contains('loading') ||
        lower.contains('waiting') ||
        lower.contains('unsaved') ||
        lower.contains('retry') ||
        lower.contains('저장 중') ||
        lower.contains('불러오는 중') ||
        lower.contains('내보내는 중') ||
        lower.contains('대기') ||
        lower.contains('저장되지') ||
        lower.contains('재시도')) {
      return _roomForgePrimary;
    }
    return _roomForgeMuted;
  }
}

class _SyncFailurePanel extends StatelessWidget {
  const _SyncFailurePanel({
    required this.saveStatus,
    required this.draftStatus,
    required this.onRetry,
    required this.onKeepLocal,
    required this.onShowLogs,
    required this.onReopenProject,
  });

  final String saveStatus;
  final String draftStatus;
  final VoidCallback onRetry;
  final VoidCallback onKeepLocal;
  final VoidCallback onShowLogs;
  final VoidCallback onReopenProject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = _issueState();
    return Semantics(
      container: true,
      liveRegion: true,
      label: rf(
        'Layout sync failed. ${state.label}. Actions: retry, keep local draft, inspect logs, reopen project.',
        '레이아웃 동기화 실패. ${state.label}. 작업: 재시도, 로컬 draft 유지, 로그 확인, 프로젝트 다시 열기.',
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _roomForgeCanvas,
          border: Border.all(color: state.color.withValues(alpha: 0.56)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DraftRecoveryChip(label: state.label, color: state.color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rf('Sync failed', '동기화 실패'),
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: _roomForgeInk,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _messageForState(state.id),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _roomForgeMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: _roomForgePanel,
                  border: Border.all(color: _roomForgeBorder),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rf('Reupload bridge', '재업로드 연결'),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: _roomForgeInk,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        rf(
                          'Existing dimensions, CV candidates, and manual corrections remain in the local draft while you retry or reupload.',
                          '재시도하거나 새 사진을 업로드하는 동안 기존 치수, CV 후보, 수동 수정값은 로컬 draft에 유지됩니다.',
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _roomForgeMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _DraftRecoveryChip(
                            label: rf('dimensions', '치수'),
                            color: _roomForgeSuccess,
                          ),
                          _DraftRecoveryChip(
                            label: rf('CV candidates', 'CV 후보'),
                            color: _roomForgeSuccess,
                          ),
                          _DraftRecoveryChip(
                            label: rf('manual edits', '수동 수정값'),
                            color: _roomForgeSuccess,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_outlined),
                    label: Text(rf('Retry sync', '동기화 재시도')),
                  ),
                  OutlinedButton.icon(
                    onPressed: onKeepLocal,
                    icon: const Icon(Icons.edit_note_outlined),
                    label: Text(rf('Keep local', '로컬 유지')),
                  ),
                  OutlinedButton.icon(
                    onPressed: onShowLogs,
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: Text(rf('View logs', '로그 보기')),
                  ),
                  OutlinedButton.icon(
                    onPressed: onReopenProject,
                    icon: const Icon(Icons.folder_open_outlined),
                    label: Text(rf('Reopen project', '프로젝트 다시 열기')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  _SyncIssueState _issueState() {
    final lower = '$saveStatus $draftStatus'.toLowerCase();
    if (lower.contains('retrying') ||
        lower.contains('saving') ||
        lower.contains('저장 중') ||
        lower.contains('재시도 중')) {
      return _SyncIssueState(
        id: 'retrying',
        label: rf('retrying', '재시도 중'),
        color: _roomForgePrimary,
      );
    }
    if (lower.contains('permission') ||
        lower.contains('token') ||
        lower.contains('auth') ||
        lower.contains('권한') ||
        lower.contains('토큰')) {
      return _SyncIssueState(
        id: 'permission',
        label: rf('permission', '권한'),
        color: _roomForgeError,
      );
    }
    if (lower.contains('network') ||
        lower.contains('offline') ||
        lower.contains('timeout') ||
        lower.contains('네트워크') ||
        lower.contains('오프라인')) {
      return _SyncIssueState(
        id: 'network',
        label: rf('network', '네트워크'),
        color: _roomForgeWarning,
      );
    }
    return _SyncIssueState(
      id: 'server',
      label: rf('server', '서버'),
      color: _roomForgeError,
    );
  }

  String _messageForState(String state) {
    return switch (state) {
      'retrying' => rf(
        'Retry is running now. Keep the local draft open until the latest save confirms.',
        '재시도가 진행 중입니다. 최신 저장이 확인될 때까지 로컬 draft를 열린 상태로 유지하세요.',
      ),
      'permission' => rf(
        'Your session or project permission blocked the save. Refresh access, then retry sync.',
        '세션 또는 프로젝트 권한 때문에 저장이 차단되었습니다. 접근 권한을 새로고침한 뒤 동기화를 재시도하세요.',
      ),
      'network' => rf(
        'Network connectivity interrupted the save. Keep the local draft and retry when online.',
        '네트워크 연결 문제로 저장이 중단되었습니다. 로컬 draft를 유지하고 온라인 상태에서 다시 시도하세요.',
      ),
      _ => rf(
        'The server did not accept the latest layout save. Keep the local draft while you inspect logs or retry.',
        '서버가 최신 레이아웃 저장을 수락하지 않았습니다. 로그를 확인하거나 재시도하는 동안 로컬 draft를 유지하세요.',
      ),
    };
  }
}

class _SyncIssueState {
  const _SyncIssueState({
    required this.id,
    required this.label,
    required this.color,
  });

  final String id;
  final String label;
  final Color color;
}

class _DraftRecoveryDiffSummary extends StatelessWidget {
  const _DraftRecoveryDiffSummary({
    required this.draft,
    required this.latestCloudUpdatedAt,
    required this.hasCloudConflict,
  });

  final LayoutDraft draft;
  final DateTime? latestCloudUpdatedAt;
  final bool hasCloudConflict;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dirtySummary = _dirtyFieldSummary(draft.dirtyFields);
    final localLines = [
      rf(
        '${draft.furnitureObjects.length} furniture objects',
        '가구 ${draft.furnitureObjects.length}개',
      ),
      rf(
        'Updated ${_timeLabel(draft.updatedAt)}',
        '${_timeLabel(draft.updatedAt)} 수정',
      ),
      dirtySummary,
    ];
    final cloudLines = [
      hasCloudConflict
          ? rf('Cloud changed after this draft', '클라우드가 이 드래프트 이후 변경됨')
          : rf('Cloud version is unchanged', '클라우드 버전 변경 없음'),
      rf(
        'Saved ${_timeLabel(latestCloudUpdatedAt ?? draft.baseCloudUpdatedAt)}',
        '${_timeLabel(latestCloudUpdatedAt ?? draft.baseCloudUpdatedAt)} 저장',
      ),
      draft.baseCloudLayoutId == null
          ? rf('No cloud layout id', '클라우드 layout id 없음')
          : rf(
              'Base ${draft.baseCloudLayoutId}',
              '기준 ${draft.baseCloudLayoutId}',
            ),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _roomForgeCanvas,
        border: Border.all(color: _roomForgeBorderStrong),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 560;
            final cards = [
              _diffCard(
                context,
                chipLabel: rf('local draft', '로컬 draft'),
                chipColor: _roomForgeWarning,
                title: rf('Recoverable local draft', '복구 가능한 로컬 draft'),
                lines: localLines,
              ),
              _diffCard(
                context,
                chipLabel: hasCloudConflict
                    ? rf('cloud newer', '클라우드 최신')
                    : rf('cloud saved', '클라우드 저장본'),
                chipColor: hasCloudConflict
                    ? _roomForgePrimary
                    : _roomForgeSuccess,
                title: rf('Cloud saved layout', '클라우드 저장본'),
                lines: cloudLines,
              ),
            ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  rf(
                    'Compare before choosing recovery.',
                    '복구 선택 전에 차이를 비교하세요.',
                  ),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: _roomForgeInk,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  rf(
                    'RoomForge will not auto-merge conflicting drafts.',
                    'RoomForge는 충돌 draft를 자동 병합하지 않습니다.',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _roomForgeMuted,
                  ),
                ),
                const SizedBox(height: 10),
                if (stacked)
                  Column(
                    children: [cards[0], const SizedBox(height: 8), cards[1]],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: cards[0]),
                      const SizedBox(width: 8),
                      Expanded(child: cards[1]),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _diffCard(
    BuildContext context, {
    required String chipLabel,
    required Color chipColor,
    required String title,
    required List<String> lines,
  }) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _roomForgePanel,
        border: Border.all(color: _roomForgeBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DraftRecoveryChip(label: chipLabel, color: chipColor),
            const SizedBox(height: 8),
            Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: _roomForgeInk,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  line,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _roomForgeMuted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _dirtyFieldSummary(List<String> dirtyFields) {
    if (dirtyFields.isEmpty) {
      return rf('No changed fields listed', '변경 필드 없음');
    }
    final labels = dirtyFields
        .map((field) {
          return switch (field) {
            'editor_scene' => rf('editor scene', '편집 장면'),
            'furniture_objects' => rf('furniture', '가구'),
            'room_dimensions' => rf('room dimensions', '방 치수'),
            'floor_plan' => rf('floor plan', '평면도'),
            _ => field,
          };
        })
        .join(', ');
    return rf('Changed: $labels', '변경: $labels');
  }

  String _timeLabel(DateTime? value) {
    if (value == null) {
      return rf('unknown time', '시간 없음');
    }
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}.$month.$day $hour:$minute';
  }
}

class _DraftRecoveryChip extends StatelessWidget {
  const _DraftRecoveryChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.52)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: const SizedBox.square(dimension: 6),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: _roomForgeInk,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorStatusPill extends StatelessWidget {
  const _EditorStatusPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.maxWidth,
  });

  final IconData icon;
  final String label;
  final Color color;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: RoomForgeStatusPill(
        icon: icon,
        label: label,
        color: color,
        dense: true,
      ),
    );
  }
}

String _compactDateLabel(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$month/$day $hour:$minute';
}

String _fileSizeLabel(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024).toStringAsFixed(1)} KB';
}

class ProjectErrorView extends StatelessWidget {
  const ProjectErrorView({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: RoomForgePanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RoomForgeNotice(
                title: rf('Could not load this view', '이 화면을 불러오지 못했습니다'),
                message: message,
                severity: NoticeSeverity.error,
                icon: Icons.error_outline,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: Text(rf('Retry', '재시도')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProjectEditorDialog extends StatefulWidget {
  const ProjectEditorDialog({this.project, super.key});

  final RoomProject? project;

  @override
  State<ProjectEditorDialog> createState() => _ProjectEditorDialogState();
}

class _ProjectEditorDialogState extends State<ProjectEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final project = widget.project;
    if (project != null) {
      _nameController.text = project.name;
      _descriptionController.text = project.description ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      _ProjectDraft(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCreate = widget.project == null;
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: _roomForgePanel,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: _roomForgeBorderStrong),
      ),
      title: Row(
        children: [
          Icon(
            isCreate ? Icons.add_home_work_outlined : Icons.edit_outlined,
            color: _roomForgePrimary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isCreate
                  ? rf('Create room project', '방 프로젝트 생성')
                  : rf('Edit project', '프로젝트 수정'),
              style: theme.textTheme.titleLarge?.copyWith(
                color: _roomForgeInk,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isCreate
                    ? rf(
                        'Name the room before uploading a source photo.',
                        '소스 사진을 업로드하기 전에 방 이름을 정하세요.',
                      )
                    : rf(
                        'Update the visible project metadata. Saved layouts remain attached to this project.',
                        '보이는 프로젝트 메타데이터를 수정합니다. 저장된 레이아웃은 이 프로젝트에 계속 연결됩니다.',
                      ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _roomForgeMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  RoomForgeStatusPill(
                    label: isCreate ? 'create' : 'edit',
                    color: _roomForgePrimary,
                    dense: true,
                  ),
                  RoomForgeStatusPill(
                    label: rf('save footer', '저장 footer'),
                    color: _roomForgeSave,
                    dense: true,
                  ),
                  if (!isCreate)
                    RoomForgeStatusPill(
                      label: rf('danger zone', '삭제 영역'),
                      color: _roomForgeError,
                      dense: true,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: rf('Project name', '프로젝트 이름'),
                  helperText: rf(
                    'Shown in the workspace and layout export.',
                    '작업공간과 레이아웃 내보내기에 표시됩니다.',
                  ),
                ),
                maxLength: 120,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return rf('Enter a project name.', '프로젝트 이름을 입력하세요.');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: rf('Description', '설명'),
                  helperText: rf(
                    'Optional notes such as room, client, or goal.',
                    '방, 고객, 목표 같은 선택 메모입니다.',
                  ),
                  alignLabelWithHint: true,
                ),
                maxLength: 1000,
                minLines: 3,
                maxLines: 5,
              ),
              if (!isCreate) ...[
                const SizedBox(height: 12),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: _roomForgeError.withValues(alpha: .12),
                    border: Border.all(
                      color: _roomForgeError.withValues(alpha: .38),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.delete_outline,
                          color: _roomForgeError,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            rf(
                              'Project deletion is handled from the detail panel with a final confirmation.',
                              '프로젝트 삭제는 상세 패널에서 최종 확인 후 실행됩니다.',
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: _roomForgeInkSoft,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(rf('Cancel', '취소')),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: Icon(isCreate ? Icons.add : Icons.check),
          label: Text(isCreate ? rf('Create', '생성') : rf('Save', '저장')),
        ),
      ],
    );
  }
}

class _ProjectDraft {
  const _ProjectDraft({required this.name, this.description});

  final String name;
  final String? description;
}
