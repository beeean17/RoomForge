import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../api/backend_mode.dart';
import '../auth/auth_repository.dart';
import '../auth/firebase_options_from_env.dart';

class FirebaseAppBootstrapResult {
  const FirebaseAppBootstrapResult({
    required this.authRepository,
    required this.backendMode,
    this.authSetupMessage,
  });

  final AuthRepository authRepository;
  final BackendMode backendMode;
  final String? authSetupMessage;
}

class FirebaseAppBootstrap {
  static Future<FirebaseAppBootstrapResult> initialize() async {
    final backendMode = BackendModeConfig.current;

    if (!FirebaseOptionsFromEnv.isConfigured) {
      return FirebaseAppBootstrapResult(
        authRepository: DisabledAuthRepository(),
        backendMode: backendMode,
        authSetupMessage:
            'Firebase web configuration is missing. Provide ROOMFORGE_FIREBASE_* dart defines to enable Google sign-in.',
      );
    }

    await Firebase.initializeApp(
      options: FirebaseOptionsFromEnv.currentPlatform,
    );

    final firebaseAuth = FirebaseAuth.instance;
    if (FirebaseOptionsFromEnv.useAuthEmulator) {
      await firebaseAuth.useAuthEmulator('localhost', 9099);
    }

    return FirebaseAppBootstrapResult(
      authRepository: FirebaseAuthRepository(firebaseAuth),
      backendMode: backendMode,
    );
  }
}
