import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'src/admin/admin_api.dart';
import 'src/auth/auth_repository.dart';
import 'src/auth/firebase_options_from_env.dart';
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

class ProjectDetailPanel extends StatelessWidget {
  const ProjectDetailPanel({
    required this.project,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final RoomProject? project;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final project = this.project;
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
            const Text('Next action: add room photo and dimensions.'),
            const Spacer(),
            FilledButton(onPressed: onEdit, child: const Text('Edit')),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: onDelete, child: const Text('Delete')),
          ],
        ),
      ),
    );
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
