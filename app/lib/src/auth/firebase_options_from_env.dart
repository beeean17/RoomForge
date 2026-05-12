import 'package:firebase_core/firebase_core.dart';

class FirebaseOptionsFromEnv {
  static const apiKey = String.fromEnvironment('ROOMFORGE_FIREBASE_API_KEY');
  static const appId = String.fromEnvironment('ROOMFORGE_FIREBASE_APP_ID');
  static const messagingSenderId = String.fromEnvironment(
    'ROOMFORGE_FIREBASE_MESSAGING_SENDER_ID',
  );
  static const projectId = String.fromEnvironment(
    'ROOMFORGE_FIREBASE_PROJECT_ID',
  );
  static const authDomain = String.fromEnvironment(
    'ROOMFORGE_FIREBASE_AUTH_DOMAIN',
  );
  static const storageBucket = String.fromEnvironment(
    'ROOMFORGE_FIREBASE_STORAGE_BUCKET',
  );
  static const useAuthEmulator = bool.fromEnvironment(
    'ROOMFORGE_USE_FIREBASE_EMULATOR',
  );

  static bool get isConfigured {
    return apiKey.isNotEmpty &&
        appId.isNotEmpty &&
        messagingSenderId.isNotEmpty &&
        projectId.isNotEmpty &&
        authDomain.isNotEmpty;
  }

  static FirebaseOptions get currentPlatform {
    return const FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      authDomain: authDomain,
      storageBucket: storageBucket,
    );
  }
}
