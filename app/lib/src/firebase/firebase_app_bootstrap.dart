import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
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
    required this.geometryRepository,
    required this.projectRepository,
    required this.reconstructionRepository,
    required this.roomDimensionsRepository,
    required this.sourceImageRepository,
    required this.sourceImageUploader,
    required this.userRepository,
    required this.backendMode,
    this.authSetupMessage,
  });

  final AuthRepository authRepository;
  final FirebaseAdminRepository adminRepository;
  final FirebaseGeometryRepository geometryRepository;
  final FirebaseProjectRepository projectRepository;
  final FirebaseReconstructionRepository reconstructionRepository;
  final FirebaseRoomDimensionsRepository roomDimensionsRepository;
  final FirebaseSourceImageRepository sourceImageRepository;
  final FirebaseSourceImageUploader sourceImageUploader;
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
        adminRepository: const DisabledFirebaseAdminRepository(),
        geometryRepository: const DisabledFirebaseGeometryRepository(),
        projectRepository: const DisabledFirebaseProjectRepository(),
        reconstructionRepository:
            const DisabledFirebaseReconstructionRepository(),
        roomDimensionsRepository:
            const DisabledFirebaseRoomDimensionsRepository(),
        sourceImageRepository: const DisabledFirebaseSourceImageRepository(),
        sourceImageUploader: const DisabledFirebaseSourceImageUploader(),
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
    final storage = FirebaseStorage.instance;
    if (FirebaseOptionsFromEnv.useAuthEmulator) {
      await firebaseAuth.useAuthEmulator('localhost', 9099);
      firestore.useFirestoreEmulator('localhost', 8080);
      storage.useStorageEmulator('localhost', 9199);
    }

    return FirebaseAppBootstrapResult(
      authRepository: FirebaseAuthRepository(firebaseAuth),
      adminRepository: FirebaseAdminAccessRepository(firestore: firestore),
      geometryRepository: FirebaseFirestoreGeometryRepository(
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
      sourceImageRepository: FirebaseFirestoreSourceImageRepository(
        firestore: firestore,
      ),
      sourceImageUploader: FirebaseStorageSourceImageUploader(storage: storage),
      userRepository: FirebaseUserProfileRepository(firestore: firestore),
      backendMode: backendMode,
    );
  }
}
