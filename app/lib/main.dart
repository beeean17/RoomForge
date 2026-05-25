// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'src/admin/admin_api.dart';
import 'src/auth/auth_repository.dart';
import 'src/editor/editor_config.dart';
import 'src/api/backend_mode.dart';
import 'src/firebase/firebase_repositories.dart';
import 'src/firebase/firebase_app_bootstrap.dart';
import 'src/layouts/indexed_db_layout_draft_store.dart';
import 'src/layouts/layout_draft_repository.dart';
import 'src/layouts/layout_export_warning.dart';
import 'src/layouts/layout_furniture_bridge_mapper.dart';
import 'src/projects/firebase_project_api.dart';
import 'src/projects/firebase_source_image_upload.dart';
import 'src/projects/project_api.dart';
import 'src/projects/source_image_upload_status.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
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
            adminApi: AdminApi(authRepository: authRepository),
            backendMode: backendMode,
            projectApi: backendMode == BackendMode.firebase
                ? FirebaseProjectApi(
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
                  )
                : ProjectApi(authRepository: authRepository),
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
          return const Scaffold(
            body: Center(child: Text('Syncing profile...')),
          );
        }

        if (snapshot.hasError) {
          return ProjectErrorView(
            message: 'Profile sync failed: ${snapshot.error}',
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
      setState(() => _errorMessage = error.message);
    } on FirebaseAuthException catch (error) {
      setState(() => _errorMessage = error.message ?? error.code);
    } catch (error) {
      setState(() => _errorMessage = 'Google sign-in failed: $error');
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
      appBar: AppBar(title: const Text('RoomForge')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Sign in to RoomForge',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Use Google sign-in to access your room projects and saved layouts.',
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isSigningIn ? null : _signIn,
                  child: Text(
                    _isSigningIn ? 'Signing in...' : 'Sign in with Google',
                  ),
                ),
                if (widget.authSetupMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    widget.authSetupMessage!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ProjectWorkspaceScreen extends StatelessWidget {
  const ProjectWorkspaceScreen({
    required this.authRepository,
    required this.adminRepository,
    required this.session,
    required this.adminApi,
    required this.backendMode,
    required this.projectApi,
    super.key,
  });

  final AuthRepository authRepository;
  final FirebaseAdminRepository adminRepository;
  final AuthSession session;
  final AdminApi adminApi;
  final BackendMode backendMode;
  final ProjectApi projectApi;

  @override
  Widget build(BuildContext context) {
    final displayName =
        session.displayName ?? session.email ?? 'signed-in user';

    return Scaffold(
      appBar: AppBar(
        title: const Text('RoomForge Workspace'),
        actions: [
          AdminRouteGuardButton(
            session: session,
            adminRepository: adminRepository,
            adminApi: adminApi,
            backendMode: backendMode,
          ),
          TextButton(
            onPressed: authRepository.signOut,
            child: const Text('Sign out'),
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
    required this.adminApi,
    required this.backendMode,
    super.key,
  });

  final AuthSession session;
  final FirebaseAdminRepository adminRepository;
  final AdminApi adminApi;
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
          builder: (context) =>
              FirebaseAdminPlaceholderScreen(session: widget.session),
        ),
      );
    } on AdminApiException catch (error) {
      if (!mounted) {
        return;
      }
      final message = error.code == 'unauthorized'
          ? 'Admin role required.'
          : error.message;
      _showSnackBar(message);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar('Admin role could not be refreshed. Try again.');
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  Future<void> _openLegacyAdmin() async {
    final adminSession = await widget.adminApi.loadSession();
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            AdminShellScreen(session: adminSession, adminApi: widget.adminApi),
      ),
    );
  }

  void _showDeniedMessage() {
    _showSnackBar('Admin role required. Refresh role or contact an admin.');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(label: 'Refresh role', onPressed: _openAdmin),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: _isChecking ? null : _openAdmin,
      child: Text(_isChecking ? 'Checking admin role...' : 'Admin'),
    );
  }
}

class FirebaseAdminPlaceholderScreen extends StatelessWidget {
  const FirebaseAdminPlaceholderScreen({required this.session, super.key});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    final displayName = session.displayName ?? session.email ?? session.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Admin')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Admin access verified',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text('Signed in as $displayName.'),
                const SizedBox(height: 12),
                const Text(
                  'Firebase admin diagnostics are not enabled in this story.',
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Back to workspace'),
                ),
              ],
            ),
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
      return;
    }
    setState(() => _searchFuture = widget.adminApi.search(query));
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
        'admin user';

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Operations')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Signed in as $displayName',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text('Role: ${widget.session.admin.role}'),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          labelText: 'Search user, project, layout, or job id',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _search(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _search,
                      child: const Text('Search'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_searchFuture != null)
                  _AdminSearchResultsView(future: _searchFuture!),
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
                          decoration: const InputDecoration(
                            labelText: 'Job status',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('All statuses'),
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
                          Text('Admin jobs failed: ${snapshot.error}')
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
      return const DecoratedBox(
        decoration: BoxDecoration(
          border: Border.fromBorderSide(BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('No jobs match the current filter.'),
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
              title: Text('Job ${job.id} - ${job.statusLabel}'),
              subtitle: Text(
                'Project ${job.projectId} | User ${job.userId} | ${job.provider}',
              ),
              trailing: Text(job.status),
            ),
          ),
      ],
    );
  }
}

class _AdminSearchResultsView extends StatelessWidget {
  const _AdminSearchResultsView({required this.future});

  final Future<List<Map<String, Object?>>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, Object?>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }
        if (snapshot.hasError) {
          return Text('Search failed: ${snapshot.error}');
        }
        final results = snapshot.data ?? const [];
        if (results.isEmpty) {
          return const Text('No matching records.');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final result in results)
              ListTile(
                dense: true,
                title: Text('${result['type']} ${result['id']}'),
                subtitle: Text(result['label']?.toString() ?? ''),
              ),
          ],
        );
      },
    );
  }
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
      _retryMessage = 'Retrying...';
      _retryFuture = widget.adminApi.retryJob(job.id);
    });
    _retryFuture!
        .then((detail) {
          if (mounted) {
            setState(
              () => _retryMessage = 'Retry job ${detail.job.id} created.',
            );
          }
        })
        .catchError((Object error) {
          if (mounted) {
            setState(() => _retryMessage = 'Retry unavailable: $error');
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
          return Text('Job detail failed: ${snapshot.error}');
        }
        final detail = snapshot.data;
        if (detail == null) {
          return const SizedBox.shrink();
        }
        final job = detail.job;
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
                  'Job ${job.id} detail',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text('Status: ${job.statusLabel} (${job.status})'),
                Text('Project: ${job.projectId} | User: ${job.userId}'),
                Text('Provider: ${job.provider}'),
                Text('Retry count: ${detail.retryCount}'),
                if (job.failureReasonCode != null)
                  Text('Failure: ${job.failureReasonCode}'),
                if (job.failureReasonMessage != null)
                  Text(job.failureReasonMessage!),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: job.status == 'failed' || job.status == 'timeout'
                      ? () => _retry(job)
                      : null,
                  child: const Text('Retry job'),
                ),
                if (_retryMessage != null) Text(_retryMessage!),
                const SizedBox(height: 12),
                Text(
                  'Event trail',
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
          return Text('Artifacts unavailable: ${snapshot.error}');
        }
        final data = snapshot.data;
        if (data == null) {
          return const SizedBox.shrink();
        }
        final candidate = data['candidate'] is Map
            ? Map<String, Object?>.from(data['candidate'] as Map)
            : const <String, Object?>{};
        final confirmed = data['confirmed'] is List
            ? (data['confirmed'] as List).length
            : 0;
        final calibration = data['calibration'] is List
            ? (data['calibration'] as List).length
            : 0;
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
                  'OpenCV artifacts',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text('Candidate geometry: ${candidate['coordinate_space']}'),
                Text('Confidence: ${candidate['confidence'] ?? 'unknown'}'),
                Text('Algorithm: ${candidate['algorithm'] ?? 'unknown'}'),
                Text('Confirmed geometries: $confirmed'),
                Text('Calibration summaries: $calibration'),
              ],
            ),
          ),
        );
      },
    );
  }
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
          return Text('Diagnosis unavailable: ${snapshot.error}');
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
                  'Failure diagnosis',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text('Provider: ${providerState['provider'] ?? 'unknown'}'),
                Text(
                  'Provider status: ${providerState['status'] ?? 'unknown'}',
                ),
                Text('Failure source: ${failureSource['source'] ?? 'unknown'}'),
                if (providerState['failure_reason_code'] != null)
                  Text('Reason: ${providerState['failure_reason_code']}'),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _adminStatusLabel(String status) {
  if (status == 'review_required') {
    return 'Needs review';
  }
  return status;
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

    await widget.projectApi.createProject(
      name: result.name,
      description: result.description,
    );
    _reload();
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

    final updated = await widget.projectApi.updateProject(
      projectId: project.id,
      name: result.name,
      description: result.description,
    );
    setState(() {
      _selectedProject = updated;
    });
    _reload();
  }

  Future<void> _deleteSelectedProject() async {
    final project = _selectedProject;
    if (project == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete project'),
        content: Text('Delete "${project.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await widget.projectApi.deleteProject(project.id);
    setState(() {
      _selectedProject = null;
    });
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Signed in as ${widget.displayName}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    'Projects',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _createProject,
                    child: const Text('Create project'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 3,
                      child: FutureBuilder<List<RoomProject>>(
                        future: _projectsFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (snapshot.hasError) {
                            return ProjectErrorView(
                              message: snapshot.error.toString(),
                              onRetry: _reload,
                            );
                          }

                          final projects =
                              snapshot.data ?? const <RoomProject>[];
                          if (projects.isEmpty) {
                            return const Center(
                              child: Text(
                                'No room projects yet. Create your first project.',
                              ),
                            );
                          }

                          return ListView.separated(
                            itemCount: projects.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final project = projects[index];
                              final isSelected =
                                  _selectedProject?.id == project.id;
                              return ListTile(
                                selected: isSelected,
                                title: Text(project.name),
                                subtitle: Text(
                                  project.description?.isNotEmpty == true
                                      ? project.description!
                                      : 'No description',
                                ),
                                onTap: () => _openProject(project),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 2,
                      child: ProjectDetailPanel(
                        project: _selectedProject,
                        projectApi: widget.projectApi,
                        onEdit: _editSelectedProject,
                        onDelete: _deleteSelectedProject,
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
  RoomDimensions? _dimensions;
  ReconstructionJob? _reconstructionJob;
  SourceImageUploadStatus _uploadState = SourceImageUploadStatus.empty;
  String? _uploadMessage;
  double? _uploadProgress;
  html.File? _lastUploadFile;
  bool _isSavingDimensions = false;
  bool _isSubmittingReconstruction = false;
  String? _dimensionMessage;
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
      _dimensions = null;
      _reconstructionJob = null;
      _uploadState = SourceImageUploadStatus.empty;
      _uploadMessage = null;
      _uploadProgress = null;
      _lastUploadFile = null;
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
      _uploadMessage = 'Drop a JPEG, PNG, or WebP room photo.';
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
        _uploadMessage = 'Drop one supported room photo file.';
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
      _uploadMessage = 'Select a JPEG, PNG, or WebP room photo.';
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
      });
      return;
    }

    setState(() {
      _uploadState = SourceImageUploadStatus.uploading;
      _uploadMessage = file.size < _lowQualityImageBytes
          ? 'Uploading. Low-quality warning: this file is small. Use a sharper, brighter image if reconstruction looks weak.'
          : 'Uploading source image to cloud storage.';
      _uploadProgress = 0;
      _lastUploadFile = file;
    });

    try {
      final bytes = await _readFileBytes(file);
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
            _uploadMessage = uploadProgressLabel(_uploadProgress);
          });
        },
      );
      setState(() {
        _sourceImage = sourceImage;
        _uploadState = SourceImageUploadStatus.uploaded;
        _uploadMessage = imageSize == null
            ? 'Uploaded. Image dimensions were not available from the browser.'
            : 'Uploaded ${imageSize.width} x ${imageSize.height}px source image.';
        _uploadProgress = 1;
        _lastUploadFile = null;
      });
    } on ProjectApiException catch (error) {
      setState(() {
        _uploadState = uploadStatusForProjectApiException(error);
        _uploadMessage = uploadRecoveryMessage(error);
        _uploadProgress = null;
        _sourceImage = null;
        if (_uploadState == SourceImageUploadStatus.validationError) {
          _lastUploadFile = null;
        }
      });
    } catch (error) {
      setState(() {
        _uploadState = SourceImageUploadStatus.uploadFailed;
        _uploadMessage = 'Upload failed: $error';
        _uploadProgress = null;
        _sourceImage = null;
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
            ? 'Saved with MVP default height ${dimensions.heightValue.toStringAsFixed(2)} m.'
            : 'Saved room dimensions.';
      });
    } on ProjectApiException catch (error) {
      setState(() => _dimensionMessage = error.message);
    } catch (error) {
      setState(() => _dimensionMessage = 'Saving dimensions failed: $error');
    } finally {
      if (mounted) {
        setState(() => _isSavingDimensions = false);
      }
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
            ? 'Loaded saved dimensions with MVP default height ${dimensions.heightValue.toStringAsFixed(2)} m.'
            : 'Loaded saved room dimensions.';
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
      setState(() => _dimensionMessage = 'Loading dimensions failed: $error');
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
        ),
      ),
    );
  }

  Future<void> _submitReconstruction() async {
    final project = widget.project;
    final sourceImage = _sourceImage;
    if (project == null || sourceImage == null) {
      setState(() {
        _reconstructionMessage =
            'Upload a source image before submitting reconstruction.';
      });
      return;
    }
    if (_dimensions == null) {
      setState(() {
        _reconstructionMessage =
            'Save room dimensions before submitting reconstruction.';
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
        _reconstructionMessage = job.statusLabel;
      });
      _startReconstructionPolling(job.id);
    } on ProjectApiException catch (error) {
      setState(() => _reconstructionMessage = error.message);
    } catch (error) {
      setState(
        () => _reconstructionMessage = 'Reconstruction submit failed: $error',
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
        _reconstructionMessage = job.statusLabel;
      });
      if (job.terminal) {
        _reconstructionPollTimer?.cancel();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _reconstructionMessage = 'Status refresh failed: $error');
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
        _reconstructionMessage = 'Retry available: ${retryJob.statusLabel}';
      });
      _startReconstructionPolling(retryJob.id);
    } on ProjectApiException catch (error) {
      setState(() => _reconstructionMessage = error.message);
    } catch (error) {
      setState(() => _reconstructionMessage = 'Retry failed: $error');
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
      return const DecoratedBox(
        decoration: BoxDecoration(
          border: Border.fromBorderSide(BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: Center(child: Text('Select a project to view details.')),
      );
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border.fromBorderSide(BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(project.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                project.description?.isNotEmpty == true
                    ? project.description!
                    : 'No description',
              ),
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
                child: const Text('Open planning editor'),
              ),
              const SizedBox(height: 8),
              FilledButton(onPressed: widget.onEdit, child: const Text('Edit')),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: widget.onDelete,
                child: const Text('Delete'),
              ),
            ],
          ),
        ),
      ),
    );
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
    final progressText = uploadProgressLabel(progressValue);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Photo intake', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text(
          'Use a sharp, bright room photo with visible floor-wall boundaries, minimal occlusion, low distortion, and JPEG, PNG, or WebP format.',
        ),
        const SizedBox(height: 10),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.fromBorderSide(BorderSide(color: borderColor)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  liveRegion: true,
                  label: state == SourceImageUploadStatus.uploading
                      ? progressText
                      : state.label,
                  child: Text(state.label),
                ),
                if (state == SourceImageUploadStatus.uploading) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progressValue,
                    semanticsLabel: 'Source image upload progress',
                    semanticsValue: progressText,
                  ),
                  const SizedBox(height: 6),
                  Text(progressText),
                ],
                if (message != null) ...[
                  const SizedBox(height: 8),
                  Text(message!),
                ],
                if (sourceImage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${sourceImage!.originalFilename} - ${(sourceImage!.byteSize / 1024).toStringAsFixed(1)} KB',
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: state == SourceImageUploadStatus.uploading
                          ? null
                          : onSelectImage,
                      icon: const Icon(Icons.photo_outlined),
                      label: Text(
                        state == SourceImageUploadStatus.uploading
                            ? 'Uploading...'
                            : 'Choose photo',
                      ),
                    ),
                    if (state.canRetryUpload)
                      FilledButton.icon(
                        onPressed: onRetryUpload,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry upload'),
                      ),
                  ],
                ),
                if (state == SourceImageUploadStatus.validationError) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Choose another photo that matches the format and size requirements.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
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
    final theme = Theme.of(context);

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Room dimensions', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: widthController,
                  decoration: const InputDecoration(
                    labelText: 'Width',
                    suffixText: 'm',
                  ),
                  keyboardType: TextInputType.number,
                  validator: _positiveDimensionValidator,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: depthController,
                  decoration: const InputDecoration(
                    labelText: 'Depth',
                    suffixText: 'm',
                  ),
                  keyboardType: TextInputType.number,
                  validator: _positiveDimensionValidator,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: heightController,
            decoration: const InputDecoration(
              labelText: 'Height',
              helperText: 'Leave blank to use the MVP default height.',
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
          if (message != null) ...[const SizedBox(height: 8), Text(message!)],
          if (dimensions != null) ...[
            const SizedBox(height: 8),
            Text(
              'Saved: ${dimensions!.widthValue.toStringAsFixed(2)} x ${dimensions!.depthValue.toStringAsFixed(2)} x ${dimensions!.heightValue.toStringAsFixed(2)} ${dimensions!.unit}',
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: isSaving ? null : onSave,
            child: Text(isSaving ? 'Saving...' : 'Save dimensions'),
          ),
        ],
      ),
    );
  }

  static String? _positiveDimensionValidator(String? value) {
    final parsed = double.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed <= 0) {
      return 'Enter a positive number.';
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Reconstruction job', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(message ?? 'Submit after source image and dimensions are saved.'),
        if (job != null) ...[
          const SizedBox(height: 8),
          Text('Status: ${job!.statusLabel}'),
          Text('Provider: ${job!.provider}'),
          if (job!.status == 'review_required' || job!.status == 'failed') ...[
            const SizedBox(height: 8),
            Text(
              job!.failureReasonMessage ??
                  'Check blur, lighting, hidden boundaries, occlusion, distortion, unsupported image, OpenCV failure, invalid geometry, or calibration failure.',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
        ],
        const SizedBox(height: 12),
        FilledButton(
          onPressed: isSubmitting ? null : onSubmit,
          child: Text(isSubmitting ? 'Submitting...' : 'Submit reconstruction'),
        ),
        if (job != null &&
            (job!.terminal || job!.status == 'review_required')) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: isSubmitting ? null : onRetry,
            child: const Text('Retry reconstruction'),
          ),
        ],
      ],
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
    super.key,
  });

  final RoomProject project;
  final ProjectApi projectApi;
  final RoomDimensions? initialDimensions;
  final ReconstructionJob? reconstructionJob;
  final SourceImage? sourceImage;

  @override
  State<EditorBridgeScreen> createState() => _EditorBridgeScreenState();
}

class _EditorBridgeScreenState extends State<EditorBridgeScreen> {
  late final LayoutDraftRepository _draftRepository;
  late final String _viewType;
  late final html.IFrameElement _iframe;
  StreamSubscription<html.MessageEvent>? _messageSubscription;
  String _bridgeStatus = 'Waiting for editor frame.';
  String _runtimeStatus = 'Waiting for OpenCV worker.';
  String _sceneStatus = 'Waiting for metric floor plan handoff.';
  String _saveStatus = 'Not saved.';
  String _loadStatus = 'No layout loaded.';
  String _draftStatus = 'No local draft.';
  String _exportStatus = 'Not exported.';
  String _viewMode = '2d';
  bool _isSavingLayout = false;
  bool _isLoadingLayout = false;
  bool _isExportingLayout = false;
  bool _reviewSaveConfirmed = false;
  bool _reviewExportConfirmed = false;
  Map<String, Object?>? _latestScene;
  String? _activeLayoutId;
  DateTime? _activeCloudUpdatedAt;
  bool _draftChangedDuringSave = false;
  var _draftGeneration = 0;
  Future<void> _pendingDraftWrite = Future<void>.value();

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
    unawaited(_detectRecoverableDraft());
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Planning editor: ${widget.project.name}')),
      body: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Wrap(
                spacing: 16,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: '2d', label: Text('2D')),
                      ButtonSegment(value: '3d', label: Text('3D')),
                    ],
                    selected: {_viewMode},
                    onSelectionChanged: (selection) {
                      final viewMode = selection.first;
                      setState(() => _viewMode = viewMode);
                      _postEditorMessage(
                        type: 'roomforge.view.setMode',
                        requestId:
                            'view-mode-${DateTime.now().millisecondsSinceEpoch}',
                        payload: {'viewMode': viewMode},
                      );
                    },
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Text(_sceneStatus),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Text(_bridgeStatus),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Text(_runtimeStatus),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 240),
                    child: Text(_saveStatus),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 240),
                    child: Text(_loadStatus),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 260),
                    child: Text(_draftStatus),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: Text(_exportStatus),
                  ),
                  FilledButton(
                    onPressed: _isSavingLayout ? null : _saveLayout,
                    child: Text(_isSavingLayout ? 'Saving...' : 'Save layout'),
                  ),
                  OutlinedButton(
                    onPressed: _isLoadingLayout ? null : _loadLayout,
                    child: Text(
                      _isLoadingLayout ? 'Loading...' : 'Load layout',
                    ),
                  ),
                  OutlinedButton(
                    onPressed: _isExportingLayout ? null : _exportLayout,
                    child: Text(
                      _isExportingLayout ? 'Exporting...' : 'Export JSON',
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => _postEditorMessage(
                      type: 'roomforge.editor.ping',
                      requestId:
                          'manual-ping-${DateTime.now().millisecondsSinceEpoch}',
                      payload: {'source': 'flutter-shell'},
                    ),
                    child: const Text('Ping editor'),
                  ),
                ],
              ),
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
    setState(() {
      if (type == 'roomforge.editor.ready') {
        _bridgeStatus = 'Editor ready.';
      } else if (type.endsWith('.response')) {
        _bridgeStatus = 'Bridge round trip: $type';
      } else if (type == 'roomforge.opencv.runtimeLoaded') {
        _runtimeStatus = 'OpenCV worker assets loaded.';
      } else if (type == 'roomforge.opencv.runtimeFailed') {
        _runtimeStatus = 'OpenCV worker asset loading failed.';
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
          final statusLabel = hasUnsavedChanges ? 'Unsaved changes' : 'Saved';
          _sceneStatus =
              '${viewMode?.toUpperCase() ?? _viewMode.toUpperCase()} scene: '
              '${label ?? 'Room shell'}; $statusLabel';
        }
      }
    });
    if (draftScene != null) {
      _queuePersistDraft(draftScene!);
    }
  }

  Future<void> _saveLayout() async {
    if (layoutStatusNeedsReview(widget.reconstructionJob?.status) &&
        !_reviewSaveConfirmed) {
      setState(() {
        _reviewSaveConfirmed = true;
        _saveStatus = layoutNeedsReviewSaveWarning;
      });
      return;
    }

    setState(() {
      _isSavingLayout = true;
      _saveStatus = 'Saving...';
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
        _reviewSaveConfirmed = false;
        _draftStatus = draftCleanupSucceeded
            ? 'Saved'
            : 'Draft cleanup unavailable.';
        _saveStatus = 'Saved';
      });
    } on ProjectApiException catch (error) {
      _latestScene = _sceneForSave();
      _queuePersistDraft(_latestScene!);
      if (!mounted) {
        return;
      }
      setState(() {
        _reviewSaveConfirmed = false;
        _saveStatus = 'Save failed: ${error.message}';
      });
    } catch (error) {
      _latestScene = _sceneForSave();
      _queuePersistDraft(_latestScene!);
      if (!mounted) {
        return;
      }
      setState(() {
        _reviewSaveConfirmed = false;
        _saveStatus = 'Save failed: $error';
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

  Future<void> _loadLayout() async {
    setState(() {
      _isLoadingLayout = true;
      _loadStatus = 'Loading...';
    });

    try {
      final layout = await widget.projectApi.loadLatestLayout(
        projectId: widget.project.id,
      );
      final scene = _sceneFromSavedLayout(layout);
      final viewMode = scene['viewMode']?.toString();
      if (!mounted) {
        return;
      }
      setState(() {
        _latestScene = scene;
        _activeLayoutId = layout.id;
        _activeCloudUpdatedAt = layout.updatedAt;
        final nextViewMode = viewMode == '2d' || viewMode == '3d'
            ? viewMode
            : null;
        if (nextViewMode != null) {
          _viewMode = nextViewMode;
        }
        _saveStatus = 'Saved';
        _loadStatus = 'Loaded layout';
      });
      unawaited(_detectRecoverableDraft(layoutId: layout.id));
      _postEditorMessage(
        type: 'roomforge.scene.initialize',
        requestId: 'load-layout-${layout.id}',
        payload: {'scene': scene},
      );
    } on ProjectApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _loadStatus = 'Load failed: ${error.message}');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _loadStatus = 'Load failed: $error');
    } finally {
      if (mounted) {
        setState(() => _isLoadingLayout = false);
      }
    }
  }

  Future<void> _exportLayout() async {
    setState(() {
      _isExportingLayout = true;
      _exportStatus = 'Checking latest saved layout...';
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
          _exportStatus = layoutNeedsReviewExportWarning;
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
            ? 'Exported JSON with $layoutNeedsReviewLabel warning'
            : 'Exported JSON';
      });
    } on ProjectApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _reviewExportConfirmed = false;
        _exportStatus = 'Export failed: ${error.message}';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _reviewExportConfirmed = false;
        _exportStatus = 'Export failed: $error';
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

  Future<void> _detectRecoverableDraft({String? layoutId}) async {
    try {
      final draft = await _draftRepository.getDraft(
        ownerUid: widget.project.userId,
        projectId: widget.project.id,
        layoutId: layoutId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _draftStatus = draft == null || !draft.isRecoverable
            ? 'No local draft.'
            : '${draft.label} available.';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _draftStatus = 'Draft check unavailable.');
    }
  }

  void _queuePersistDraft(Map<String, Object?> scene) {
    if (_isSavingLayout) {
      _draftChangedDuringSave = true;
      return;
    }
    final generation = _draftGeneration;
    _pendingDraftWrite = _pendingDraftWrite
        .catchError((_) {})
        .then((_) => _persistDraft(scene, generation));
    unawaited(_pendingDraftWrite);
  }

  Future<void> _drainDraftWrite(Future<void> pendingDraftWrite) async {
    try {
      await pendingDraftWrite;
    } catch (_) {}
  }

  Future<void> _persistDraft(Map<String, Object?> scene, int generation) async {
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
        reconstructionStatus: widget.reconstructionJob?.status ?? 'created',
        reviewRequired: layoutStatusNeedsReview(
          widget.reconstructionJob?.status,
        ),
      );
      if (!mounted || generation != _draftGeneration) {
        return;
      }
      setState(() => _draftStatus = draft.label);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _draftStatus = 'Draft save failed.');
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
      setState(() => _draftStatus = 'Draft cleanup unavailable.');
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
      'reconstruction_status': widget.reconstructionJob?.status,
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
    final width = dimensions?.widthValue ?? 4.2;
    final depth = dimensions?.depthValue ?? 3.6;
    final height = dimensions?.heightValue ?? 2.7;
    final reviewRequired =
        widget.reconstructionJob?.status == 'review_required';

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
      'reconstructionStatus': reviewRequired
          ? {'status': 'review_required', 'label': 'Needs review'}
          : null,
    };
  }

  String _editorUrlFor(RoomProject project) {
    final uri = Uri.parse(EditorConfig.editorUrl);
    final queryParameters = Map<String, String>.from(uri.queryParameters)
      ..['project_id'] = project.id.toString();
    return uri.replace(queryParameters: queryParameters).toString();
  }
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
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
    return AlertDialog(
      title: Text(
        widget.project == null ? 'Create room project' : 'Edit project',
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Project name'),
              maxLength: 120,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter a project name.';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLength: 1000,
              minLines: 2,
              maxLines: 4,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.project == null ? 'Create' : 'Save'),
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
