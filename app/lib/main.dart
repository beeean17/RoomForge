import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'src/api/backend_bindings.dart';
import 'src/auth/auth_repository.dart';
import 'src/firebase/firebase_app_bootstrap.dart';
import 'src/projects/arcore_depth_capability.dart';
import 'src/projects/guided_capture_session_section.dart';
import 'src/projects/project_api.dart';
import 'src/projects/source_image_upload_status.dart';

const _ink = Color(0xFFF8F8F5);
const _muted = Color(0xFFA7ADB0);
const _paper = Color(0xFF050505);
const _panel = Color(0xFF0B0D0F);
const _border = Color(0x244B6277);
const _primary = Color(0xFF8FB4FF);
const _success = Color(0xFF80C7C2);
const _warning = Color(0xFFD49A5C);
const _danger = Color(0xFFE08B82);

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

class RoomForgeMobileApp extends StatelessWidget {
  const RoomForgeMobileApp({required this.bootstrap, super.key});

  final FirebaseAppBootstrapResult bootstrap;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RoomForge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
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
          backgroundColor: _paper,
          foregroundColor: _ink,
          elevation: 0,
          centerTitle: false,
        ),
      ),
      home: _MobileAuthGate(bootstrap: bootstrap),
    );
  }
}

class _MobileAuthGate extends StatelessWidget {
  const _MobileAuthGate({required this.bootstrap});

  final FirebaseAppBootstrapResult bootstrap;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthSession?>(
      stream: bootstrap.authRepository.authStateChanges(),
      builder: (context, snapshot) {
        final session = snapshot.data;
        if (session == null) {
          return _MobileSignInScreen(
            authRepository: bootstrap.authRepository,
            setupMessage: bootstrap.authSetupMessage,
          );
        }

        return _MobileProjectShell(
          bootstrap: bootstrap,
          session: session,
          projectApi: RoomForgeBackendBindings.projectApi(
            backendMode: bootstrap.backendMode,
            authRepository: bootstrap.authRepository,
            session: session,
            floorPlanRepository: bootstrap.floorPlanRepository,
            geometryRepository: bootstrap.geometryRepository,
            layoutRepository: bootstrap.layoutRepository,
            projectRepository: bootstrap.projectRepository,
            reconstructionRepository: bootstrap.reconstructionRepository,
            roomDimensionsRepository: bootstrap.roomDimensionsRepository,
            sceneUnderstandingRepository:
                bootstrap.sceneUnderstandingRepository,
            sourceImageRepository: bootstrap.sourceImageRepository,
            sourceImageUploader: bootstrap.sourceImageUploader,
          ),
        );
      },
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
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _MobileBrand(),
                const Spacer(),
                Text(
                  'RoomForge Mobile',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: _ink,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Guided capture, upload status, and lightweight project handoff for the React desktop workspace.',
                  style: TextStyle(color: _muted, fontSize: 15, height: 1.45),
                ),
                const SizedBox(height: 24),
                if (widget.setupMessage != null)
                  _NoticeCard(
                    tone: _warning,
                    title: 'Firebase setup required',
                    body: widget.setupMessage!,
                  ),
                if (_error != null)
                  _NoticeCard(
                    tone: _danger,
                    title: 'Sign-in failed',
                    body: _error!,
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy ? null : _signIn,
                    child: Text(
                      _busy ? 'Preparing sign-in...' : 'Continue with Google',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Mobile web remains limited. Desktop editing and admin operations now live in the React web app.',
                  style: TextStyle(color: _muted, fontSize: 12.5, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileProjectShell extends StatefulWidget {
  const _MobileProjectShell({
    required this.bootstrap,
    required this.session,
    required this.projectApi,
  });

  final FirebaseAppBootstrapResult bootstrap;
  final AuthSession session;
  final ProjectApi projectApi;

  @override
  State<_MobileProjectShell> createState() => _MobileProjectShellState();
}

class _MobileProjectShellState extends State<_MobileProjectShell> {
  final ImagePicker _imagePicker = ImagePicker();
  late Future<List<RoomProject>> _projectsFuture;
  RoomProject? _selectedProject;
  RoomDimensions? _dimensions;
  CaptureSessionSnapshot? _captureSnapshot;
  String? _status;

  @override
  void initState() {
    super.initState();
    _projectsFuture = _loadProjects();
  }

  Future<List<RoomProject>> _loadProjects() async {
    try {
      final projects = await widget.projectApi.listProjects();
      if (mounted && projects.isNotEmpty) {
        _selectedProject ??= projects.first;
        unawaited(_loadProjectContext(projects.first));
      }
      return projects;
    } catch (error) {
      if (!mounted) rethrow;
      setState(() => _status = 'Project load failed: $error');
      return const [];
    }
  }

  Future<void> _loadProjectContext(RoomProject project) async {
    setState(() {
      _selectedProject = project;
      _status = null;
    });
    try {
      final dimensions = await widget.projectApi.getRoomDimensions(
        projectId: project.id,
      );
      final captureSnapshot = await widget.projectApi.loadLatestCaptureSession(
        projectId: project.id,
      );
      if (!mounted || _selectedProject?.id != project.id) return;
      setState(() {
        _dimensions = dimensions;
        _captureSnapshot = captureSnapshot;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = 'Project context unavailable: $error');
    }
  }

  Future<void> _createDemoProject() async {
    setState(() => _status = 'Creating project...');
    try {
      final project = await widget.projectApi.createProject(
        name: 'Mobile capture ${DateTime.now().millisecondsSinceEpoch}',
        description: 'Created from RoomForge mobile app shell.',
      );
      if (!mounted) return;
      setState(() {
        _selectedProject = project;
        _projectsFuture = _loadProjects();
      });
      unawaited(_loadProjectContext(project));
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = 'Project creation failed: $error');
    }
  }

  Future<void> _saveDefaultDimensions() async {
    final project = _selectedProject;
    if (project == null) return;
    setState(() => _status = 'Saving dimensions...');
    try {
      final dimensions = await widget.projectApi.saveRoomDimensions(
        projectId: project.id,
        widthValue: 5.2,
        depthValue: 6.0,
        heightValue: 2.8,
      );
      if (!mounted) return;
      setState(() {
        _dimensions = dimensions;
        _status = 'Dimensions saved.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = 'Dimension save failed: $error');
    }
  }

  Future<void> _startGuidedCapture(bool depthEnabled) async {
    final project = _selectedProject;
    if (project == null) return;
    setState(() => _status = 'Starting guided capture...');
    try {
      await widget.projectApi.createCaptureSession(
        projectId: project.id,
        depthEnabled: depthEnabled,
      );
      final snapshot = await widget.projectApi.loadLatestCaptureSession(
        projectId: project.id,
      );
      if (!mounted) return;
      setState(() {
        _captureSnapshot = snapshot;
        _status = 'Guided capture session ready.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = 'Guided capture failed: $error');
    }
  }

  Future<void> _captureRole(GuidedCaptureRoleInstruction role) async {
    final project = _selectedProject;
    final session = _captureSnapshot?.session;
    if (project == null || session == null) {
      setState(
        () => _status = 'Start guided capture before taking role photos.',
      );
      return;
    }

    setState(() => _status = 'Opening camera for ${role.label}...');
    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 88,
        requestFullMetadata: false,
      );
      if (photo == null) {
        if (!mounted) return;
        setState(() => _status = 'Capture cancelled.');
        return;
      }

      final bytes = await photo.readAsBytes();
      final imageSize = await _decodeImageSize(bytes);
      final image = await widget.projectApi.uploadCaptureImage(
        projectId: project.id,
        captureSessionId: session.id,
        role: role.id,
        filename: _captureFilename(role.id, photo.name),
        contentType: _imageContentType(photo),
        bytes: bytes,
        widthPx: imageSize.width,
        heightPx: imageSize.height,
        captureOrder: _captureOrderForRole(role.id),
        onProgress: (progress) {
          if (!mounted) return;
          setState(
            () => _status =
                'Uploading ${role.label}: ${(progress * 100).round()}%',
          );
        },
      );
      final snapshot = await widget.projectApi.loadLatestCaptureSession(
        projectId: project.id,
      );
      if (!mounted) return;
      setState(() {
        _captureSnapshot = snapshot;
        _status = '${role.label} uploaded as ${image.sourceImageId}.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = 'Capture upload failed: $error');
    }
  }

  Future<void> _signOut() async {
    await widget.bootstrap.authRepository.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final project = _selectedProject;
    return Scaffold(
      appBar: AppBar(
        title: const _MobileBrand(),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: _signOut,
            icon: const Icon(Icons.logout_outlined),
          ),
        ],
      ),
      body: _MobileBackdrop(
        child: SafeArea(
          top: false,
          child: FutureBuilder<List<RoomProject>>(
            future: _projectsFuture,
            builder: (context, snapshot) {
              final projects = snapshot.data ?? const <RoomProject>[];
              return RefreshIndicator(
                onRefresh: () async {
                  setState(() => _projectsFuture = _loadProjects());
                  await _projectsFuture;
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                  children: [
                    _MobileHero(
                      session: widget.session,
                      onCreateProject: _createDemoProject,
                    ),
                    if (_status != null)
                      _NoticeCard(
                        tone: _primary,
                        title: 'Status',
                        body: _status!,
                      ),
                    const SizedBox(height: 16),
                    Text(
                      'Projects',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: _ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const _ProjectSkeleton()
                    else if (projects.isEmpty)
                      _EmptyProjectCard(onCreateProject: _createDemoProject)
                    else
                      ...projects.map(
                        (item) => _ProjectListTile(
                          project: item,
                          selected: item.id == project?.id,
                          onTap: () => _loadProjectContext(item),
                        ),
                      ),
                    const SizedBox(height: 18),
                    if (project != null)
                      _CaptureSection(
                        project: project,
                        dimensions: _dimensions,
                        captureSnapshot: _captureSnapshot,
                        onSaveDefaultDimensions: _saveDefaultDimensions,
                        onStartGuidedCapture: _startGuidedCapture,
                        onCaptureRole: _captureRole,
                      ),
                    const SizedBox(height: 18),
                    _DesktopHandoffCard(project: project),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
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
    'right_wall': 2,
    'back_wall': 3,
    'left_wall': 4,
    'extra': 5,
  };
  return order[role] ?? 99;
}

class _MobileHero extends StatelessWidget {
  const _MobileHero({required this.session, required this.onCreateProject});

  final AuthSession session;
  final VoidCallback onCreateProject;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            session.displayName ?? session.email ?? 'RoomForge user',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: _ink,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Capture-first mobile workflow. Reconstruction review, 2D/3D editing, and admin remain in React desktop web.',
            style: TextStyle(color: _muted, height: 1.45),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onCreateProject,
            icon: const Icon(Icons.add),
            label: const Text('Create capture project'),
          ),
        ],
      ),
    );
  }
}

class _CaptureSection extends StatelessWidget {
  const _CaptureSection({
    required this.project,
    required this.dimensions,
    required this.captureSnapshot,
    required this.onSaveDefaultDimensions,
    required this.onStartGuidedCapture,
    required this.onCaptureRole,
  });

  final RoomProject project;
  final RoomDimensions? dimensions;
  final CaptureSessionSnapshot? captureSnapshot;
  final VoidCallback onSaveDefaultDimensions;
  final Future<void> Function(bool depthEnabled) onStartGuidedCapture;
  final ValueChanged<GuidedCaptureRoleInstruction> onCaptureRole;

  @override
  Widget build(BuildContext context) {
    final roleUploads = {
      for (final image in captureSnapshot?.images ?? const <CaptureImage>[])
        image.role: GuidedCaptureRoleUploadSnapshot(
          status: SourceImageUploadStatus.uploaded,
          image: image,
        ),
    };

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  project.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: _ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _Pill(
                label: captureSnapshot?.session == null ? 'capture' : 'active',
              ),
            ],
          ),
          const SizedBox(height: 14),
          GuidedCaptureSessionSection(
            dimensions: dimensions,
            started: captureSnapshot?.session != null,
            roleUploads: roleUploads,
            depthCapability: const ArCoreDepthCapability(
              isAndroid: false,
              isSupported: false,
              reason:
                  'Native camera and ARCore depth plugins will be attached in the next mobile phase.',
            ),
            onStart: () => unawaited(onStartGuidedCapture(false)),
            onUploadRole: onCaptureRole,
          ),
          if (dimensions == null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onSaveDefaultDimensions,
              icon: const Icon(Icons.straighten_outlined),
              label: const Text('Use sample dimensions'),
            ),
          ],
        ],
      ),
    );
  }
}

class _DesktopHandoffCard extends StatelessWidget {
  const _DesktopHandoffCard({required this.project});

  final RoomProject? project;

  @override
  Widget build(BuildContext context) {
    final path = project == null
        ? '/projects'
        : '/projects/${Uri.encodeComponent(project!.id)}';
    return _NoticeCard(
      tone: _success,
      title: 'Continue on desktop',
      body:
          'Open React web at $path for reconstruction review, metric floor-plan correction, furniture editing, export, and admin operations.',
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? _primary.withValues(alpha: .12) : _panel,
            border: Border.all(color: selected ? _primary : _border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.meeting_room_outlined, color: _primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.name,
                        style: const TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        project.description ?? project.id,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const _Pill(label: 'project'),
              ],
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
          const Icon(Icons.add_a_photo_outlined, color: _primary),
          const SizedBox(height: 12),
          const Text(
            'No projects yet',
            style: TextStyle(color: _ink, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Create a project from mobile, capture guided source photos, then continue on desktop.',
            style: TextStyle(color: _muted, height: 1.4),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onCreateProject,
            icon: const Icon(Icons.add),
            label: const Text('Create project'),
          ),
        ],
      ),
    );
  }
}

class _ProjectSkeleton extends StatelessWidget {
  const _ProjectSkeleton();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Row(
        children: [
          const CircularProgressIndicator(strokeWidth: 2),
          const SizedBox(width: 14),
          Text(
            'Loading projects...',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: _muted),
          ),
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
  });

  final Color tone;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tone.withValues(alpha: .1),
          border: Border.all(color: tone.withValues(alpha: .34)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
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
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _primary.withValues(alpha: .12),
        border: Border.all(color: _primary.withValues(alpha: .34)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          label,
          style: const TextStyle(
            color: _primary,
            fontSize: 11,
            fontWeight: FontWeight.w900,
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
            color: _primary,
            borderRadius: BorderRadius.all(Radius.circular(5)),
          ),
          child: SizedBox(width: 16, height: 16),
        ),
        SizedBox(width: 9),
        Text(
          'RoomForge',
          style: TextStyle(
            color: _ink,
            fontWeight: FontWeight.w900,
            letterSpacing: .2,
          ),
        ),
      ],
    );
  }
}

class _MobileBackdrop extends StatelessWidget {
  const _MobileBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: _paper,
        image: DecorationImage(
          image: AssetImage('assets/design/room.png'),
          fit: BoxFit.cover,
          opacity: .12,
        ),
      ),
      child: child,
    );
  }
}
