import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

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
  static const emulatorHost = String.fromEnvironment(
    'ROOMFORGE_FIREBASE_EMULATOR_HOST',
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

  static String get resolvedEmulatorHost {
    if (emulatorHost.isNotEmpty) {
      return emulatorHost;
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return '10.0.2.2';
    }

    return 'localhost';
  }
}
