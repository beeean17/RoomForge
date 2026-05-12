import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'src/auth/auth_repository.dart';
import 'src/auth/firebase_options_from_env.dart';

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
    super.key,
  });

  final AuthRepository authRepository;
  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    final displayName =
        session.displayName ?? session.email ?? 'signed-in user';

    return Scaffold(
      appBar: AppBar(
        title: const Text('RoomForge Workspace'),
        actions: [
          TextButton(
            onPressed: authRepository.signOut,
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Signed in as $displayName',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your project workspace is ready. Project list and creation flows are implemented in the next stories.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
