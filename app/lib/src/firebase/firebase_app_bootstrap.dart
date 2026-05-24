import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../api/backend_mode.dart';
import '../auth/auth_repository.dart';
import '../auth/firebase_options_from_env.dart';
import '../firebase/firebase_repositories.dart';
import '../users/firebase_user_repository.dart';

class FirebaseAppBootstrapResult {
  const FirebaseAppBootstrapResult({
    required this.authRepository,
    required this.userRepository,
    required this.backendMode,
    this.authSetupMessage,
  });

  final AuthRepository authRepository;
  final FirebaseUserRepository userRepository;
  final BackendMode backendMode;
  final String? authSetupMessage;
}

class FirebaseAppBootstrap {
  static Future<FirebaseAppBootstrapResult> initialize() async {
    final backendMode = BackendModeConfig.current;

    if (!FirebaseOptionsFromEnv.isConfigured) {
      return FirebaseAppBootstrapResult(
        authRepository: DisabledAuthRepository(),
        userRepository: DisabledFirebaseUserRepository(),
        backendMode: backendMode,
        authSetupMessage:
            'Firebase web configuration is missing. Provide ROOMFORGE_FIREBASE_* dart defines to enable Google sign-in.',
      );
    }

    await Firebase.initializeApp(
      options: FirebaseOptionsFromEnv.currentPlatform,
    );

    final firebaseAuth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;
    if (FirebaseOptionsFromEnv.useAuthEmulator) {
      await firebaseAuth.useAuthEmulator('localhost', 9099);
      firestore.useFirestoreEmulator('localhost', 8080);
    }

    return FirebaseAppBootstrapResult(
      authRepository: FirebaseAuthRepository(firebaseAuth),
      userRepository: FirebaseUserProfileRepository(firestore: firestore),
      backendMode: backendMode,
    );
  }
}
