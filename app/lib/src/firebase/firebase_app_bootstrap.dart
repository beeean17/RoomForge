import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../admin/firebase_admin_access_repository.dart';
import '../api/backend_mode.dart';
import '../auth/auth_repository.dart';
import '../auth/firebase_options_from_env.dart';
import '../firebase/firebase_project_repository.dart';
import '../firebase/firebase_repositories.dart';
import '../projects/firebase_source_image_upload.dart';
import '../users/firebase_user_repository.dart';

class FirebaseAppBootstrapResult {
  const FirebaseAppBootstrapResult({
    required this.authRepository,
    required this.adminRepository,
    required this.floorPlanRepository,
    required this.geometryRepository,
    required this.layoutRepository,
    required this.projectRepository,
    required this.reconstructionRepository,
    required this.roomDimensionsRepository,
    required this.sceneUnderstandingRepository,
    required this.sourceImageRepository,
    required this.sourceImageUploader,
    required this.userRepository,
    required this.backendMode,
    this.authSetupMessage,
  });

  final AuthRepository authRepository;
  final FirebaseAdminRepository adminRepository;
  final FirebaseFloorPlanRepository floorPlanRepository;
  final FirebaseGeometryRepository geometryRepository;
  final FirebaseLayoutRepository layoutRepository;
  final FirebaseProjectRepository projectRepository;
  final FirebaseReconstructionRepository reconstructionRepository;
  final FirebaseRoomDimensionsRepository roomDimensionsRepository;
  final FirebaseSceneUnderstandingRepository sceneUnderstandingRepository;
  final FirebaseSourceImageRepository sourceImageRepository;
  final FirebaseSourceImageUploader sourceImageUploader;
  final FirebaseUserRepository userRepository;
  final BackendMode backendMode;
  final String? authSetupMessage;
}

class FirebaseAppBootstrap {
  static const _bootstrapTimeout = Duration(seconds: 20);

  static Future<FirebaseAppBootstrapResult> initialize() async {
    final backendMode = BackendModeConfig.current;

    if (kIsWeb && !FirebaseOptionsFromEnv.isConfigured) {
      return _disabledResult(
        backendMode,
        'Firebase web configuration is missing. Provide ROOMFORGE_FIREBASE_* dart defines to enable Google sign-in.',
      );
    }

    try {
      await _ensureDefaultFirebaseApp().timeout(_bootstrapTimeout);

      final firebaseAuth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;
      final storage = FirebaseStorage.instance;
      if (FirebaseOptionsFromEnv.useAuthEmulator) {
        final emulatorHost = FirebaseOptionsFromEnv.resolvedEmulatorHost;
        await firebaseAuth
            .useAuthEmulator(emulatorHost, 9099)
            .timeout(_bootstrapTimeout);
        firestore.useFirestoreEmulator(emulatorHost, 8080);
        storage.useStorageEmulator(emulatorHost, 9199);
      }

      return FirebaseAppBootstrapResult(
        authRepository: FirebaseAuthRepository(firebaseAuth),
        adminRepository: FirebaseAdminAccessRepository(firestore: firestore),
        floorPlanRepository: FirebaseFirestoreFloorPlanRepository(
          firestore: firestore,
        ),
        geometryRepository: FirebaseFirestoreGeometryRepository(
          firestore: firestore,
        ),
        layoutRepository: FirebaseFirestoreLayoutRepository(
          firestore: firestore,
        ),
        projectRepository: FirebaseFirestoreProjectRepository(
          firestore: firestore,
        ),
        reconstructionRepository: FirebaseFirestoreReconstructionRepository(
          firestore: firestore,
        ),
        roomDimensionsRepository: FirebaseFirestoreRoomDimensionsRepository(
          firestore: firestore,
        ),
        sceneUnderstandingRepository:
            FirebaseFirestoreSceneUnderstandingRepository(firestore: firestore),
        sourceImageRepository: FirebaseFirestoreSourceImageRepository(
          firestore: firestore,
        ),
        sourceImageUploader: FirebaseStorageSourceImageUploader(
          storage: storage,
        ),
        userRepository: FirebaseUserProfileRepository(firestore: firestore),
        backendMode: backendMode,
      );
    } catch (error) {
      return _disabledResult(
        backendMode,
        'Firebase 초기화에 실패했습니다. Android 패키지 이름, google-services.json, Firebase 콘솔 앱 설정, 네트워크와 에뮬레이터 실행 상태를 확인하세요. Error: $error',
      );
    }
  }

  static Future<FirebaseApp> _ensureDefaultFirebaseApp() async {
    if (Firebase.apps.isNotEmpty) {
      return Firebase.app();
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return Firebase.initializeApp();
    }

    if (!FirebaseOptionsFromEnv.isConfigured) {
      return Firebase.initializeApp();
    }

    return Firebase.initializeApp(
      options: FirebaseOptionsFromEnv.currentPlatform,
    );
  }

  static FirebaseAppBootstrapResult _disabledResult(
    BackendMode backendMode,
    String message,
  ) {
    return FirebaseAppBootstrapResult(
      authRepository: DisabledAuthRepository(),
      adminRepository: const DisabledFirebaseAdminRepository(),
      floorPlanRepository: const DisabledFirebaseFloorPlanRepository(),
      geometryRepository: const DisabledFirebaseGeometryRepository(),
      layoutRepository: const DisabledFirebaseLayoutRepository(),
      projectRepository: const DisabledFirebaseProjectRepository(),
      reconstructionRepository:
          const DisabledFirebaseReconstructionRepository(),
      roomDimensionsRepository:
          const DisabledFirebaseRoomDimensionsRepository(),
      sceneUnderstandingRepository:
          const DisabledFirebaseSceneUnderstandingRepository(),
      sourceImageRepository: const DisabledFirebaseSourceImageRepository(),
      sourceImageUploader: const DisabledFirebaseSourceImageUploader(),
      userRepository: DisabledFirebaseUserRepository(),
      backendMode: backendMode,
      authSetupMessage: message,
    );
  }
}
