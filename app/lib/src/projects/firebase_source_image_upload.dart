import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseSourceImageUpload {
  FirebaseSourceImageUpload._();

  static const maxBytes = 10 * 1024 * 1024;

  static const allowedContentTypes = {'image/jpeg', 'image/png', 'image/webp'};

  static bool isAllowedContentType(String contentType) {
    return allowedContentTypes.contains(contentType);
  }

  static String sha256Hex(Uint8List bytes) {
    return sha256.convert(bytes).toString();
  }

  static String sanitizeFilename(String filename) {
    final basename = filename.split(RegExp(r'[/\\]')).last.trim();
    final sanitized = basename.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    if (sanitized.isEmpty || sanitized == '.' || sanitized == '..') {
      return 'source-image';
    }
    return sanitized;
  }

  static String storagePath({
    required String ownerUid,
    required String projectId,
    required String sourceImageId,
    required String storedFilename,
  }) {
    return 'users/$ownerUid/projects/$projectId/source-images/$sourceImageId/$storedFilename';
  }
}

abstract class FirebaseSourceImageUploader {
  Future<void> uploadBytes({
    required String storagePath,
    required Uint8List bytes,
    required String contentType,
    required Map<String, String> metadata,
    void Function(double progress)? onProgress,
  });
}

class FirebaseStorageSourceImageUploader
    implements FirebaseSourceImageUploader {
  const FirebaseStorageSourceImageUploader({required FirebaseStorage storage})
    : _storage = storage;

  final FirebaseStorage _storage;

  @override
  Future<void> uploadBytes({
    required String storagePath,
    required Uint8List bytes,
    required String contentType,
    required Map<String, String> metadata,
    void Function(double progress)? onProgress,
  }) async {
    final task = _storage
        .ref(storagePath)
        .putData(
          bytes,
          SettableMetadata(contentType: contentType, customMetadata: metadata),
        );
    StreamSubscription<TaskSnapshot>? subscription;
    if (onProgress != null) {
      subscription = task.snapshotEvents.listen(
        (snapshot) {
          final totalBytes = snapshot.totalBytes;
          if (totalBytes <= 0) {
            return;
          }
          onProgress(snapshot.bytesTransferred / totalBytes);
        },
        onError: (_) {
          // The awaited upload task below surfaces the failure path.
        },
      );
    }

    try {
      await task;
      onProgress?.call(1);
    } finally {
      await subscription?.cancel();
    }
  }
}

class DisabledFirebaseSourceImageUploader
    implements FirebaseSourceImageUploader {
  const DisabledFirebaseSourceImageUploader();

  @override
  Future<void> uploadBytes({
    required String storagePath,
    required Uint8List bytes,
    required String contentType,
    required Map<String, String> metadata,
    void Function(double progress)? onProgress,
  }) {
    throw UnsupportedError('Firebase source image upload is unavailable.');
  }
}
