// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import 'src/admin/admin_api.dart';
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
import 'src/projects/firebase_source_image_upload.dart';
import 'src/projects/guided_capture_session_section.dart';
import 'src/projects/project_api.dart';
import 'src/projects/source_image_upload_recovery_controls.dart';
import 'src/projects/source_image_upload_status.dart';

const _roomForgeInk = Color(0xFF172033);
const _roomForgeMuted = Color(0xFF5B667A);
const _roomForgeBorder = Color(0xFFD9E2EF);
const _roomForgePanel = Color(0xFFFFFFFF);
const _roomForgeCanvas = Color(0xFFF7F8FB);
const _roomForgePrimary = Color(0xFF2563EB);
const _roomForgeSuccess = Color(0xFF16A34A);
const _roomForgeWarning = Color(0xFFD97706);
const _roomForgeError = Color(0xFFDC2626);
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
  final FirebaseSourceImageRepository sourceImageRepository;
  final FirebaseSourceImageUploader sourceImageUploader;
  final FirebaseUserRepository userRepository;
  final BackendMode backendMode;
  final String? authSetupMessage;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RoomForge',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _roomForgePrimary,
          surface: _roomForgeCanvas,
        ),
        scaffoldBackgroundColor: _roomForgeCanvas,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: _roomForgePanel,
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
          border: OutlineInputBorder(),
          filled: true,
          fillColor: _roomForgePanel,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 44),
            side: const BorderSide(color: _roomForgeBorder),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      home: AuthGate(
        authRepository: authRepository,
        adminRepository: adminRepository,
        floorPlanRepository: floorPlanRepository,
        geometryRepository: geometryRepository,
        layoutRepository: layoutRepository,
        projectRepository: projectRepository,
        reconstructionRepository: reconstructionRepository,
        roomDimensionsRepository: roomDimensionsRepository,
        sourceImageRepository: sourceImageRepository,
        sourceImageUploader: sourceImageUploader,
        userRepository: userRepository,
        backendMode: backendMode,
        authSetupMessage: authSetupMessage,
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({
    required this.authRepository,
    required this.adminRepository,
    required this.floorPlanRepository,
    required this.geometryRepository,
    required this.layoutRepository,
    required this.projectRepository,
    required this.reconstructionRepository,
    required this.roomDimensionsRepository,
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
  final FirebaseSourceImageRepository sourceImageRepository;
  final FirebaseSourceImageUploader sourceImageUploader;
  final FirebaseUserRepository userRepository;
  final BackendMode backendMode;
  final String? authSetupMessage;

  @override
  Widget build(BuildContext context) {
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

        return UserProfileSyncGate(
          userRepository: userRepository,
          session: session,
          child: ProjectWorkspaceScreen(
            authRepository: authRepository,
            adminRepository: adminRepository,
            session: session,
            legacyAdminApi: RoomForgeBackendBindings.legacyAdminApi(
              backendMode: backendMode,
              authRepository: authRepository,
            ),
            backendMode: backendMode,
            projectApi: RoomForgeBackendBindings.projectApi(
              backendMode: backendMode,
              authRepository: authRepository,
              session: session,
              floorPlanRepository: floorPlanRepository,
              geometryRepository: geometryRepository,
              layoutRepository: layoutRepository,
              projectRepository: projectRepository,
              reconstructionRepository: reconstructionRepository,
              roomDimensionsRepository: roomDimensionsRepository,
              sourceImageRepository: sourceImageRepository,
              sourceImageUploader: sourceImageUploader,
            ),
          ),
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

  Future<void> _signIn() async {
    setState(() {
      _isSigningIn = true;
      _errorMessage = null;
    });

    try {
      await widget.authRepository.signInWithGoogle();
    } on AuthUnavailableException catch (error) {
      setState(() => _errorMessage = _localizedAuthErrorMessage(error.message));
    } on FirebaseAuthException catch (error) {
      setState(() => _errorMessage = _localizedFirebaseAuthErrorMessage(error));
    } catch (error) {
      setState(
        () => _errorMessage = _localizedAuthErrorMessage(
          'Google sign-in failed: $error',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSigningIn = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 760;
                  final intro = _SignInIntro(theme: theme);
                  final panel = _SignInPanel(
                    isSigningIn: _isSigningIn,
                    authSetupMessage: widget.authSetupMessage,
                    errorMessage: _errorMessage,
                    onSignIn: _signIn,
                  );

                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [intro, const SizedBox(height: 24), panel],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(flex: 5, child: intro),
                      const SizedBox(width: 32),
                      Expanded(flex: 4, child: panel),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SignInIntro extends StatelessWidget {
  const _SignInIntro({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _RoomForgeWordmark(),
          const SizedBox(height: 28),
          Text(
            rf(
              'Turn room photos into measured planning layouts.',
              '방 사진을 측정 가능한 배치 도면으로 바꿉니다.',
            ),
            style: theme.textTheme.headlineLarge?.copyWith(
              color: _roomForgeInk,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            rf(
              'Sign in to reopen projects, review reconstruction results, and save room layouts across sessions.',
              '로그인하면 프로젝트를 다시 열고, 재구성 결과를 검토하고, 방 배치를 저장할 수 있습니다.',
            ),
            style: theme.textTheme.titleMedium?.copyWith(
              color: _roomForgeMuted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              RoomForgeStatusPill(
                icon: Icons.photo_camera_outlined,
                label: rf('Photo intake', '사진 업로드'),
              ),
              RoomForgeStatusPill(
                icon: Icons.architecture_outlined,
                label: rf('Measured floor plan', '측정된 평면도'),
              ),
              RoomForgeStatusPill(
                icon: Icons.chair_outlined,
                label: rf('Saved furniture layouts', '저장된 가구 배치'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SignInPanel extends StatelessWidget {
  const _SignInPanel({
    required this.isSigningIn,
    required this.onSignIn,
    this.authSetupMessage,
    this.errorMessage,
  });

  final bool isSigningIn;
  final VoidCallback onSignIn;
  final String? authSetupMessage;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RoomForgePanel(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            rf('Sign in', '로그인'),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            rf(
              'Use Google sign-in to access RoomForge workspace data.',
              'Google 계정으로 RoomForge 작업공간에 접근합니다.',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(color: _roomForgeMuted),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: isSigningIn ? null : onSignIn,
            icon: isSigningIn
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login),
            label: Text(
              isSigningIn
                  ? rf('Signing in...', '로그인 중...')
                  : rf('Sign in with Google', 'Google로 로그인'),
            ),
          ),
          if (authSetupMessage != null) ...[
            const SizedBox(height: 16),
            RoomForgeNotice(
              icon: Icons.settings_outlined,
              title: rf(
                'Firebase web configuration missing',
                'Firebase 웹 설정이 없습니다',
              ),
              message: _localizedAuthSetupMessage(authSetupMessage!),
              severity: NoticeSeverity.error,
            ),
          ],
          if (errorMessage != null) ...[
            const SizedBox(height: 16),
            RoomForgeNotice(
              icon: Icons.error_outline,
              title: rf('Google sign-in unavailable', 'Google 로그인을 사용할 수 없습니다'),
              message: _localizedAuthErrorMessage(errorMessage!),
              severity: NoticeSeverity.error,
            ),
          ],
        ],
      ),
    );
  }
}

class _RoomForgeWordmark extends StatelessWidget {
  const _RoomForgeWordmark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _roomForgeInk,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.view_in_ar_outlined, color: _roomForgePanel),
        ),
        const SizedBox(width: 12),
        Text(
          'RoomForge',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: _roomForgeInk,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
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
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
          ],
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
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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

class ProjectWorkspaceScreen extends StatelessWidget {
  const ProjectWorkspaceScreen({
    required this.authRepository,
    required this.adminRepository,
    required this.session,
    required this.legacyAdminApi,
    required this.backendMode,
    required this.projectApi,
    super.key,
  });

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('RoomForge'),
        actions: [
          AdminRouteGuardButton(
            session: session,
            adminRepository: adminRepository,
            legacyAdminApi: legacyAdminApi,
            backendMode: backendMode,
          ),
          TextButton(
            onPressed: authRepository.signOut,
            child: Text(rf('Sign out', '로그아웃')),
          ),
        ],
      ),
      body: ProjectWorkspaceBody(
        displayName: displayName,
        projectApi: projectApi,
      ),
    );
  }
}

class AdminRouteGuardButton extends StatefulWidget {
  const AdminRouteGuardButton({
    required this.session,
    required this.adminRepository,
    required this.legacyAdminApi,
    required this.backendMode,
    super.key,
  });

  final AuthSession session;
  final FirebaseAdminRepository adminRepository;
  final AdminApi? legacyAdminApi;
  final BackendMode backendMode;

  @override
  State<AdminRouteGuardButton> createState() => _AdminRouteGuardButtonState();
}

class _AdminRouteGuardButtonState extends State<AdminRouteGuardButton> {
  bool _isChecking = false;

  Future<void> _openAdmin() async {
    setState(() => _isChecking = true);

    try {
      if (widget.backendMode == BackendMode.legacyApi) {
        await _openLegacyAdmin();
        return;
      }

      final isAdmin = await widget.adminRepository.isCurrentUserAdmin(
        widget.session,
      );
      if (!mounted) {
        return;
      }

      if (!isAdmin) {
        _showDeniedMessage();
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => FirebaseAdminDiagnosticsScreen(
            session: widget.session,
            adminRepository: widget.adminRepository,
          ),
        ),
      );
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

  void _showDeniedMessage() {
    _showSnackBar(
      rf(
        'Admin role required. Refresh role or contact an admin.',
        '관리자 권한이 필요합니다. 권한을 새로고침하거나 관리자에게 문의하세요.',
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

class FirebaseAdminDiagnosticsScreen extends StatefulWidget {
  const FirebaseAdminDiagnosticsScreen({
    required this.session,
    required this.adminRepository,
    super.key,
  });

  final AuthSession session;
  final FirebaseAdminRepository adminRepository;

  @override
  State<FirebaseAdminDiagnosticsScreen> createState() =>
      _FirebaseAdminDiagnosticsScreenState();
}

class _FirebaseAdminDiagnosticsScreenState
    extends State<FirebaseAdminDiagnosticsScreen> {
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
    _jobsStream = widget.adminRepository.watchJobsByStatus(_statusFilter);
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
  }

  void _clearAdminSearch() {
    _adminSearchController.clear();
    setState(() {
      _selectedJob = null;
      _activeSearchLabel = null;
      _jobsStream = widget.adminRepository.watchJobsByStatus(_statusFilter);
    });
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
      appBar: AppBar(title: Text(rf('Admin diagnostics', '관리자 진단'))),
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
                  RoomForgePanel(
                    padding: const EdgeInsets.all(14),
                    child: Semantics(
                      container: true,
                      label: FirebaseAdminDiagnosticsUiText
                          .statusFilterSemanticsLabel,
                      child: DropdownButtonFormField<FirebaseJobStatus>(
                        value: _statusFilter,
                        decoration: InputDecoration(
                          labelText: rf('Job status', '작업 상태'),
                          prefixIcon: const Icon(Icons.filter_alt_outlined),
                        ),
                        items: [
                          for (final status in FirebaseJobStatus.values)
                            DropdownMenuItem(
                              value: status,
                              child: Text(_adminStatusLabel(status.wireValue)),
                            ),
                        ],
                        onChanged: _setStatusFilter,
                      ),
                    ),
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
                        return RoomForgePanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const LinearProgressIndicator(),
                              const SizedBox(height: 12),
                              Text(
                                rf(
                                  FirebaseAdminDiagnosticsUiText
                                      .protectedLoadingMessage,
                                  '보호된 작업 진단 정보를 불러오는 중...',
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return RoomForgeNotice(
                          title: rf('Admin query failed', '관리자 조회 실패'),
                          message: firebaseAdminSafeErrorMessage(
                            snapshot.error!,
                          ),
                          severity: NoticeSeverity.error,
                          icon: Icons.lock_outline,
                        );
                      }
                      final jobs = snapshot.data ?? const [];
                      final jobList = _FirebaseAdminJobList(
                        jobs: jobs,
                        selectedJobId: _selectedJob?.jobId,
                        onSelect: (job) {
                          setState(() => _selectedJob = job);
                        },
                      );
                      final detail = _selectedJob == null
                          ? const _FirebaseAdminEmptyDetail()
                          : _FirebaseAdminJobDetailPanel(
                              job: _selectedJob!,
                              adminRepository: widget.adminRepository,
                              session: widget.session,
                            );
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth < 760) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                jobList,
                                const SizedBox(height: 16),
                                detail,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 2, child: jobList),
                              const SizedBox(width: 16),
                              Expanded(flex: 3, child: detail),
                            ],
                          );
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                rf('Jobs', '작업'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Divider(height: 1),
            for (final job in jobs)
              Semantics(
                container: true,
                button: true,
                selected: job.jobId == selectedJobId,
                label: FirebaseAdminDiagnosticsUiText.jobRowAccessibilityLabel(
                  job,
                ),
                child: ListTile(
                  selected: job.jobId == selectedJobId,
                  onTap: () => onSelect(job),
                  title: Text('${rf('Job', '작업')} ${job.jobId}'),
                  subtitle: Text(
                    '${rf('Owner', '소유자')} ${job.ownerUid}\n${rf('Project', '프로젝트')} ${job.projectId}',
                  ),
                  isThreeLine: true,
                  trailing: RoomForgeStatusPill(
                    label: _adminStatusLabel(job.status.wireValue),
                    color: _adminStatusColor(job.status.wireValue),
                    dense: true,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FirebaseAdminEmptyDetail extends StatelessWidget {
  const _FirebaseAdminEmptyDetail();

  @override
  Widget build(BuildContext context) {
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
  });

  final FirebaseReconstructionJob job;
  final FirebaseAdminRepository adminRepository;
  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: FirebaseAdminDiagnosticsUiText.jobDetailAccessibilitySummary(job),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FirebaseAdminSection(
            title: rf('Job detail', '작업 상세'),
            semanticsLabel:
                FirebaseAdminDiagnosticsUiText.jobDetailSemanticsLabel,
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
                    label: '${rf('Retry', '재시도')} ${job.retryCount}',
                    icon: Icons.refresh,
                    color: _roomForgeMuted,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('${rf('Owner', '소유자')}: ${job.ownerUid}'),
              Text('${rf('Project', '프로젝트')}: ${job.projectId}'),
              Text('${rf('Job', '작업')}: ${job.jobId}'),
              Text('${rf('Source image', '소스 이미지')}: ${job.sourceImageId}'),
              Text('${rf('Provider', '제공자')}: ${job.providerType}'),
              if (job.providerId != null)
                Text('${rf('Provider ID', '제공자 ID')}: ${job.providerId}'),
              if (job.algorithmId != null)
                Text('${rf('Algorithm', '알고리즘')}: ${job.algorithmId}'),
              if (job.openCvVersion != null)
                Text('${rf('OpenCV', 'OpenCV')}: ${job.openCvVersion}'),
              if (job.qualityStatus != null)
                Text(
                  '${rf('Quality', '품질')}: ${job.qualityStatus!.displayLabel}',
                ),
              Text('${rf('Retry count', '재시도 횟수')}: ${job.retryCount}'),
              if (job.latestTransitionId != null)
                Text(
                  '${rf('Latest transition', '최근 전환')}: ${job.latestTransitionId}',
                ),
              if (job.retryOfJobId != null)
                Text('${rf('Retry of', '원본 재시도 작업')}: ${job.retryOfJobId}'),
              if (job.rootJobId != null)
                Text('${rf('Root job', '루트 작업')}: ${job.rootJobId}'),
              if (job.failureReasonCode != null)
                Text('${rf('Failure', '실패 사유')}: ${job.failureReasonCode}'),
              if (job.failureReason != null) Text(job.failureReason!),
              if (job.startedAt != null)
                Text('${rf('Started at', '시작 시각')}: ${job.startedAt}'),
              if (job.completedAt != null)
                Text('${rf('Completed at', '완료 시각')}: ${job.completedAt}'),
              if (job.timeoutAt != null)
                Text('${rf('Timeout at', '시간 초과 시각')}: ${job.timeoutAt}'),
              Text(
                '${rf('Latest result', '최근 결과')}: ${job.latestResultId ?? 'not_generated'}',
              ),
              Text(
                '${rf('Latest geometry', '최근 지오메트리')}: ${job.latestConfirmedGeometryId ?? 'not_generated'}',
              ),
              Text(
                '${rf('Latest floor plan', '최근 평면도')}: ${job.latestFloorPlanId ?? 'not_generated'}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _FirebaseAdminRetryAction(
            job: job,
            adminRepository: adminRepository,
            session: session,
          ),
          const SizedBox(height: 12),
          _FirebaseAdminArtifactRefs(artifactRefs: job.artifactRefs),
          const SizedBox(height: 12),
          _FirebaseAdminTransitions(
            stream: adminRepository.watchTransitionsForJob(jobId: job.jobId),
          ),
          const SizedBox(height: 12),
          _FirebaseAdminResults(
            stream: adminRepository.watchResultsForJob(jobId: job.jobId),
          ),
          const SizedBox(height: 12),
          _FirebaseAdminLayouts(
            jobId: job.jobId,
            stream: adminRepository.watchLayoutsForJob(jobId: job.jobId),
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
        title: rf('Artifact access', '아티팩트 접근'),
        semanticsLabel:
            FirebaseAdminDiagnosticsUiText.artifactAccessSemanticsLabel,
        children: [
          Text(
            rf(
              FirebaseAdminArtifactReadState.notGenerated.wireValue,
              '생성되지 않음',
            ),
          ),
        ],
      );
    }
    return _FirebaseAdminSection(
      title: rf('Artifact access', '아티팩트 접근'),
      semanticsLabel:
          FirebaseAdminDiagnosticsUiText.artifactAccessSemanticsLabel,
      children: [
        for (final ref in widget.artifactRefs)
          FutureBuilder<FirebaseAdminArtifactReadState>(
            future: _artifactStateFuture(ref),
            builder: (context, snapshot) {
              final state =
                  snapshot.data ??
                  (snapshot.connectionState == ConnectionState.waiting
                      ? null
                      : FirebaseAdminArtifactReadState.failedToLoad);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(ref.artifactType),
                subtitle: Text(ref.storagePath),
                trailing: Text(
                  _adminArtifactStateLabel(state?.wireValue ?? 'checking'),
                ),
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

  Future<void> _confirmRetry() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(rf('Retry reconstruction job', '재구성 작업 재시도')),
          content: Text(
            rf(
              'Create a linked retry job for ${widget.job.jobId} and record an admin action?',
              '${widget.job.jobId}에 연결된 재시도 작업을 만들고 관리자 액션을 기록할까요?',
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
        _message =
            '${rf('Retry job created', '재시도 작업이 생성되었습니다')}: ${retryJob.jobId}';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message =
            '${rf('Retry unavailable', '재시도할 수 없습니다')}: ${firebaseAdminSafeErrorMessage(error)}';
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
    return _FirebaseAdminSection(
      title: rf('Admin retry', '관리자 재시도'),
      children: [
        FilledButton(
          onPressed: canRetry && !_isRetrying ? _confirmRetry : null,
          child: Text(
            _isRetrying
                ? rf('Retrying...', '재시도 중...')
                : rf('Retry job', '작업 재시도'),
          ),
        ),
        if (!canRetry)
          Text(
            rf(
              'Only failed or timeout jobs can be retried.',
              '실패 또는 시간 초과 작업만 재시도할 수 있습니다.',
            ),
          ),
        if (_message != null) Text(_message!),
      ],
    );
  }
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
          return const LinearProgressIndicator();
        }
        if (snapshot.hasError) {
          return Text(firebaseAdminSafeErrorMessage(snapshot.error!));
        }
        final transitions = snapshot.data ?? const [];
        return _FirebaseAdminSection(
          title: rf('Transition history', '상태 전환 이력'),
          semanticsLabel:
              FirebaseAdminDiagnosticsUiText.transitionHistorySemanticsLabel,
          children: transitions.isEmpty
              ? [Text(rf('No transitions found.', '상태 전환 이력이 없습니다.'))]
              : [
                  for (final transition in transitions)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        _adminStatusLabel(transition.toStatus.wireValue),
                      ),
                      subtitle: Text(
                        [
                          transition.actorType.wireValue,
                          if (transition.reasonCode != null)
                            transition.reasonCode!,
                          if (transition.reasonMessage != null)
                            transition.reasonMessage!,
                        ].join(' | '),
                      ),
                    ),
                ],
        );
      },
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
          return const LinearProgressIndicator();
        }
        if (snapshot.hasError) {
          return Text(firebaseAdminSafeErrorMessage(snapshot.error!));
        }
        final results = snapshot.data ?? const [];
        return _FirebaseAdminSection(
          title: rf('OpenCV results', 'OpenCV 결과'),
          semanticsLabel:
              FirebaseAdminDiagnosticsUiText.opencvResultsSemanticsLabel,
          children: results.isEmpty
              ? [Text(rf('No OpenCV result found.', 'OpenCV 결과가 없습니다.'))]
              : [
                  for (final result in results)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(result.resultId),
                      subtitle: Text(
                        '${result.coordinateSpace.wireValue} | ${result.qualityStatus.displayLabel}',
                      ),
                    ),
                ],
        );
      },
    );
  }
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
          return const LinearProgressIndicator();
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
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(layout.layoutId),
                      subtitle: Text(
                        '${layout.coordinateSpace.wireValue} | ${_adminStatusLabel(layout.reconstructionStatus.wireValue)}',
                      ),
                    ),
                ],
        );
      },
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

class ProjectWorkspaceBody extends StatefulWidget {
  const ProjectWorkspaceBody({
    required this.displayName,
    required this.projectApi,
    super.key,
  });

  final String displayName;
  final ProjectApi projectApi;

  @override
  State<ProjectWorkspaceBody> createState() => _ProjectWorkspaceBodyState();
}

class _ProjectWorkspaceBodyState extends State<ProjectWorkspaceBody> {
  late Future<List<RoomProject>> _projectsFuture;
  RoomProject? _selectedProject;
  String? _workspaceMessage;
  NoticeSeverity _workspaceSeverity = NoticeSeverity.info;

  @override
  void initState() {
    super.initState();
    _projectsFuture = widget.projectApi.listProjects();
  }

  void _reload() {
    setState(() {
      _projectsFuture = widget.projectApi.listProjects();
    });
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
    final detail = ProjectDetailPanel(
      project: _selectedProject,
      projectApi: widget.projectApi,
      onEdit: _editSelectedProject,
      onDelete: _deleteSelectedProject,
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 820;
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
                    const SizedBox(height: 16),
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
    required this.displayName,
    required this.severity,
    required this.onCreateProject,
    this.message,
  });

  final String displayName;
  final NoticeSeverity severity;
  final VoidCallback onCreateProject;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
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
                    rf('Project workspace', '프로젝트 작업공간'),
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
            FilledButton.icon(
              onPressed: onCreateProject,
              icon: const Icon(Icons.add),
              label: Text(rf('Create project', '프로젝트 생성')),
            ),
          ],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  rf('Rooms', '방 프로젝트'),
                  style: theme.textTheme.titleMedium?.copyWith(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const LinearProgressIndicator(),
          const SizedBox(height: 16),
          Text(rf('Loading saved room projects...', '저장된 방 프로젝트를 불러오는 중...')),
        ],
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
          ? _roomForgePrimary.withValues(alpha: 0.08)
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
              Icon(
                Icons.meeting_room_outlined,
                color: selected ? _roomForgePrimary : _roomForgeMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
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
  bool _isSavingDimensions = false;
  bool _isSubmittingReconstruction = false;
  bool _isCreatingCaptureSession = false;
  bool _guidedCaptureStarted = false;
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
      SourceImageUploadStatus.uploadFailed => theme.colorScheme.error,
      SourceImageUploadStatus.uploaded => theme.colorScheme.primary,
      SourceImageUploadStatus.lowQualityWarning => const Color(0xFFB45309),
      _ => const Color(0xFFE2E8F0),
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
              color: state == SourceImageUploadStatus.ready
                  ? _roomForgePrimary.withValues(alpha: 0.05)
                  : _roomForgePanel,
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _uploadStateIcon(state),
                        color: borderColor,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              liveRegion: true,
                              label: state == SourceImageUploadStatus.uploading
                                  ? progressText
                                  : _uploadStateLabel(state),
                              child: Text(
                                _uploadStateLabel(state),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: _roomForgeInk,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _uploadGuidance(state),
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
                        label: state == SourceImageUploadStatus.uploading
                            ? progressText
                            : _uploadStateLabel(state),
                        color: borderColor,
                        dense: true,
                      ),
                    ],
                  ),
                  if (state == SourceImageUploadStatus.uploading) ...[
                    const SizedBox(height: 14),
                    LinearProgressIndicator(
                      value: progressValue,
                      semanticsLabel: sourceImageUploadProgressSemanticsLabel,
                      semanticsValue: progressText,
                    ),
                    const SizedBox(height: 6),
                    Text(progressText),
                  ],
                  if (sourceImage != null) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        RoomForgeStatusPill(
                          icon: Icons.image_outlined,
                          label: sourceImage!.originalFilename,
                          color: _roomForgeSuccess,
                        ),
                        RoomForgeStatusPill(
                          icon: Icons.data_object_outlined,
                          label: _fileSizeLabel(sourceImage!.byteSize),
                          color: _roomForgeSuccess,
                        ),
                        if (sourceImage!.widthPx != null &&
                            sourceImage!.heightPx != null)
                          RoomForgeStatusPill(
                            icon: Icons.aspect_ratio_outlined,
                            label:
                                '${sourceImage!.widthPx} x ${sourceImage!.heightPx}px',
                            color: _roomForgeSuccess,
                          ),
                      ],
                    ),
                  ],
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
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final fields = [
                TextFormField(
                  controller: widthController,
                  decoration: InputDecoration(
                    labelText: rf('Width', '너비'),
                    suffixText: 'm',
                    helperText: rf('Wall to wall', '벽에서 벽까지'),
                  ),
                  keyboardType: TextInputType.number,
                  validator: _positiveDimensionValidator,
                ),
                TextFormField(
                  controller: depthController,
                  decoration: InputDecoration(
                    labelText: rf('Depth', '깊이'),
                    suffixText: 'm',
                    helperText: rf('Front to back', '앞에서 뒤까지'),
                  ),
                  keyboardType: TextInputType.number,
                  validator: _positiveDimensionValidator,
                ),
                TextFormField(
                  controller: heightController,
                  decoration: InputDecoration(
                    labelText: rf('Height', '높이'),
                    helperText: rf('Blank uses default', '비워두면 기본값 사용'),
                    suffixText: 'm',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return null;
                    }
                    return _positiveDimensionValidator(value);
                  },
                ),
              ];

              if (compact) {
                return Column(
                  children: [
                    for (final field in fields) ...[
                      field,
                      if (field != fields.last) const SizedBox(height: 10),
                    ],
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final field in fields) ...[
                    Expanded(child: field),
                    if (field != fields.last) const SizedBox(width: 10),
                  ],
                ],
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

  static String? _positiveDimensionValidator(String? value) {
    final parsed = double.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed <= 0) {
      return rf('Enter a positive number.', '양수를 입력하세요.');
    }
    return null;
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
            color: statusColor.withValues(alpha: 0.06),
            border: Border.all(color: statusColor.withValues(alpha: 0.35)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
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
                            : _localizedReconstructionStatusLabel(job!.status),
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
          ),
        ),
        if (job != null) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              RoomForgeStatusPill(
                icon: Icons.memory_outlined,
                label: '${rf('Provider', '제공자')} ${job!.provider}',
                color: _roomForgeMuted,
              ),
              RoomForgeStatusPill(
                icon: Icons.update_outlined,
                label:
                    '${rf('Updated', '수정됨')} ${_compactDateLabel(job!.updatedAt)}',
                color: _roomForgeMuted,
              ),
              if (job!.retryOfJobId != null)
                RoomForgeStatusPill(
                  icon: Icons.replay_outlined,
                  label: '${rf('Retry of', '재시도 원본')} ${job!.retryOfJobId}',
                  color: _roomForgeWarning,
                ),
            ],
          ),
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
    super.key,
  });

  final RoomProject project;
  final ProjectApi projectApi;
  final RoomDimensions? initialDimensions;
  final ReconstructionJob? reconstructionJob;
  final SourceImage? sourceImage;
  final String? sourceImageDataUrl;

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
    final width = dimensions?.widthValue ?? 4.2;
    final depth = dimensions?.depthValue ?? 3.6;
    final height = dimensions?.heightValue ?? 2.7;
    final reviewRequired = _effectiveReconstructionStatus == 'review_required';

    return {
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
      'reconstructionStatus': reviewRequired
          ? {'status': 'review_required', 'label': 'Needs review'}
          : null,
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
      insetPadding: const EdgeInsets.all(20),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
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
