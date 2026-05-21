// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'src/admin/admin_api.dart';
import 'src/auth/auth_repository.dart';
import 'src/auth/firebase_options_from_env.dart';
import 'src/editor/editor_config.dart';
import 'src/projects/project_api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final AuthRepository authRepository;
  String? authSetupMessage;

  if (FirebaseOptionsFromEnv.isConfigured) {
    await Firebase.initializeApp(
      options: FirebaseOptionsFromEnv.currentPlatform,
    );
    final firebaseAuth = FirebaseAuth.instance;
    if (FirebaseOptionsFromEnv.useAuthEmulator) {
      await firebaseAuth.useAuthEmulator('localhost', 9099);
    }
    authRepository = FirebaseAuthRepository(firebaseAuth);
  } else {
    authRepository = DisabledAuthRepository();
    authSetupMessage =
        'Firebase web configuration is missing. Provide ROOMFORGE_FIREBASE_* dart defines to enable Google sign-in.';
  }

  runApp(
    RoomForgeApp(
      authRepository: authRepository,
      authSetupMessage: authSetupMessage,
    ),
  );
}

class RoomForgeApp extends StatelessWidget {
  const RoomForgeApp({
    required this.authRepository,
    this.authSetupMessage,
    super.key,
  });

  final AuthRepository authRepository;
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
        authSetupMessage: authSetupMessage,
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({
    required this.authRepository,
    this.authSetupMessage,
    super.key,
  });

  final AuthRepository authRepository;
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

        return ProjectWorkspaceScreen(
          authRepository: authRepository,
          session: session,
          adminApi: AdminApi(authRepository: authRepository),
          projectApi: ProjectApi(authRepository: authRepository),
        );
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
    required this.session,
    required this.adminApi,
    required this.projectApi,
    super.key,
  });

  final AuthRepository authRepository;
  final AuthSession session;
  final AdminApi adminApi;
  final ProjectApi projectApi;

  Future<void> _openAdmin(BuildContext context) async {
    try {
      final adminSession = await adminApi.loadSession();
      if (!context.mounted) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => AdminShellScreen(session: adminSession),
        ),
      );
    } on AdminApiException catch (error) {
      if (!context.mounted) {
        return;
      }
      final message = error.code == 'unauthorized'
          ? 'Admin access is required.'
          : error.message;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Admin access check failed: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName =
        session.displayName ?? session.email ?? 'signed-in user';

    return Scaffold(
      appBar: AppBar(
        title: const Text('RoomForge Workspace'),
        actions: [
          TextButton(
            onPressed: () => _openAdmin(context),
            child: const Text('Admin'),
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

class AdminShellScreen extends StatelessWidget {
  const AdminShellScreen({required this.session, super.key});

  final AdminSession session;

  @override
  Widget build(BuildContext context) {
    final displayName =
        session.admin.displayName ?? session.admin.email ?? 'admin user';

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
                Text('Role: ${session.admin.role}'),
                const SizedBox(height: 24),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.fromBorderSide(
                      BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No operational records yet.'),
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
  String _uploadState = 'empty';
  String? _uploadMessage;
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
      _uploadState = 'empty';
      _uploadMessage = null;
      _dimensionMessage = null;
      _reconstructionMessage = null;
      _widthController.clear();
      _depthController.clear();
      _heightController.clear();
      _reconstructionPollTimer?.cancel();
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
    setState(() {
      _uploadState = 'dragging';
      _uploadMessage = 'Drop a JPEG, PNG, or WebP room photo.';
    });
  }

  void _handleDragLeave(html.MouseEvent event) {
    if (widget.project == null || _uploadState != 'dragging') {
      return;
    }
    setState(() {
      _uploadState = _sourceImage == null ? 'empty' : 'uploaded';
      _uploadMessage = _sourceImage == null ? null : _uploadMessage;
    });
  }

  void _handleDrop(html.MouseEvent event) {
    if (widget.project == null) {
      return;
    }
    event.preventDefault();
    final files = event.dataTransfer.files;
    final file = files?.isNotEmpty == true ? files!.first : null;
    if (file == null) {
      setState(() {
        _uploadState = 'rejected';
        _uploadMessage = 'Drop one supported room photo file.';
      });
      return;
    }
    unawaited(_uploadFile(file));
  }

  Future<void> _selectAndUploadImage() async {
    final project = widget.project;
    if (project == null) {
      return;
    }

    setState(() {
      _uploadState = 'dragging';
      _uploadMessage = 'Select a JPEG, PNG, or WebP room photo.';
    });

    final input = html.FileUploadInputElement()
      ..accept = _allowedImageTypes.join(',')
      ..multiple = false;
    input.click();
    await input.onChange.first;

    final file = input.files?.isNotEmpty == true ? input.files!.first : null;
    if (file == null) {
      setState(() {
        _uploadState = 'empty';
        _uploadMessage = null;
      });
      return;
    }

    await _uploadFile(file);
  }

  Future<void> _uploadFile(html.File file) async {
    final project = widget.project;
    if (project == null) {
      return;
    }

    final contentType = _normalizedContentType(file);
    final validationMessage = _clientImageValidationMessage(file, contentType);
    if (validationMessage != null) {
      setState(() {
        _uploadState = 'rejected';
        _uploadMessage = validationMessage;
        _sourceImage = null;
      });
      return;
    }

    setState(() {
      _uploadState = file.size < _lowQualityImageBytes
          ? 'lowQualityWarning'
          : 'uploading';
      _uploadMessage = file.size < _lowQualityImageBytes
          ? 'Low-quality warning: this file is small. Use a sharper, brighter image if reconstruction looks weak.'
          : 'Uploading source image metadata.';
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
      );
      setState(() {
        _sourceImage = sourceImage;
        _uploadState = 'uploaded';
        _uploadMessage = imageSize == null
            ? 'Uploaded. Image dimensions were not available from the browser.'
            : 'Uploaded ${imageSize.width} x ${imageSize.height}px source image.';
      });
    } on ProjectApiException catch (error) {
      setState(() {
        _uploadState = 'rejected';
        _uploadMessage = error.message;
        _sourceImage = null;
      });
    } catch (error) {
      setState(() {
        _uploadState = 'rejected';
        _uploadMessage = 'Upload failed: $error';
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

  void _startReconstructionPolling(int jobId) {
    _reconstructionPollTimer?.cancel();
    _reconstructionPollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_pollReconstructionJob(jobId));
    });
  }

  Future<void> _pollReconstructionJob(int jobId) async {
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
                sourceImage: _sourceImage,
                onSelectImage: _selectAndUploadImage,
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
    required this.sourceImage,
    required this.onSelectImage,
    super.key,
  });

  final String state;
  final String? message;
  final SourceImage? sourceImage;
  final VoidCallback onSelectImage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = switch (state) {
      'rejected' => theme.colorScheme.error,
      'uploaded' => theme.colorScheme.primary,
      'lowQualityWarning' => const Color(0xFFB45309),
      _ => const Color(0xFFE2E8F0),
    };

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
                Text(_stateLabel),
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
                OutlinedButton(
                  onPressed: state == 'uploading' ? null : onSelectImage,
                  child: Text(
                    state == 'uploading' ? 'Uploading...' : 'Choose photo',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String get _stateLabel {
    return switch (state) {
      'dragging' => 'Ready to select',
      'uploading' => 'Uploading',
      'uploaded' => 'Uploaded',
      'rejected' => 'Rejected',
      'lowQualityWarning' => 'Low-quality warning',
      _ => 'No source image selected',
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
  late final String _viewType;
  late final html.IFrameElement _iframe;
  StreamSubscription<html.MessageEvent>? _messageSubscription;
  String _bridgeStatus = 'Waiting for editor frame.';
  String _runtimeStatus = 'Waiting for OpenCV worker.';
  String _sceneStatus = 'Waiting for metric floor plan handoff.';
  String _saveStatus = 'Not saved.';
  String _viewMode = '2d';
  bool _isSavingLayout = false;
  Map<String, Object?>? _latestScene;

  @override
  void initState() {
    super.initState();
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
                  FilledButton(
                    onPressed: _isSavingLayout ? null : _saveLayout,
                    child: Text(_isSavingLayout ? 'Saving...' : 'Save layout'),
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
          if (viewMode == '2d' || viewMode == '3d') {
            _viewMode = viewMode;
          }
          final hasUnsavedChanges = payload['hasUnsavedChanges'] == true;
          final room = payload['room'];
          final label = room is Map ? room['label']?.toString() : null;
          final statusLabel = hasUnsavedChanges ? 'Unsaved changes' : 'Saved';
          _sceneStatus =
              '${viewMode?.toUpperCase() ?? _viewMode.toUpperCase()} scene: '
              '${label ?? 'Room shell'}; $statusLabel';
        }
      }
    });
  }

  Future<void> _saveLayout() async {
    setState(() {
      _isSavingLayout = true;
      _saveStatus = 'Saving...';
    });

    try {
      final scene = _sceneForSave();
      await widget.projectApi.saveLayout(
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
      setState(() => _saveStatus = 'Saved');
    } on ProjectApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _saveStatus = 'Save failed: ${error.message}');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _saveStatus = 'Save failed: $error');
    } finally {
      if (mounted) {
        setState(() => _isSavingLayout = false);
      }
    }
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
    return {
      'source_image_id': widget.sourceImage?.id,
      'reconstruction_job_id': widget.reconstructionJob?.id,
      'reconstruction_status': widget.reconstructionJob?.status,
    };
  }

  List<Map<String, Object?>> _furniturePayload(Map<String, Object?> scene) {
    final objects = <Map<String, Object?>>[];
    for (final item in _listValue(scene['furniture'])) {
      final furniture = _recordValue(item);
      if (furniture.isEmpty) {
        continue;
      }
      final size = _recordValue(furniture['size']);
      final position = _recordValue(furniture['position']);
      objects.add({
        'id': furniture['objectId']?.toString() ?? '',
        'category': furniture['category']?.toString() ?? 'unknown',
        'position': {
          'x': _numberValue(position['x'], 0),
          'y': _numberValue(position['y'], 0),
        },
        'size': {
          'width_meters': _numberValue(size['widthMeters'], 0),
          'depth_meters': _numberValue(size['depthMeters'], 0),
          'height_meters': _numberValue(size['heightMeters'], 0),
        },
        'rotation_degrees': _numberValue(furniture['rotationDegrees'], 0),
        'color': furniture['color']?.toString() ?? '#64748b',
      });
    }
    return objects;
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
