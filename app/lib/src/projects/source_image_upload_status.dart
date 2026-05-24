import 'project_api.dart';

enum SourceImageUploadStatus {
  empty,
  ready,
  uploading,
  uploaded,
  validationError,
  lowQualityWarning,
  permissionFailure,
  metadataSaveFailed,
  uploadFailed,
}

extension SourceImageUploadStatusView on SourceImageUploadStatus {
  String get label {
    return switch (this) {
      SourceImageUploadStatus.ready => 'Ready to select',
      SourceImageUploadStatus.uploading => 'Uploading',
      SourceImageUploadStatus.uploaded => 'Uploaded',
      SourceImageUploadStatus.validationError => 'Validation error',
      SourceImageUploadStatus.lowQualityWarning => 'Low-quality warning',
      SourceImageUploadStatus.permissionFailure => 'Permission blocked',
      SourceImageUploadStatus.metadataSaveFailed => 'Metadata save failed',
      SourceImageUploadStatus.uploadFailed => 'Upload failed',
      SourceImageUploadStatus.empty => 'No source image selected',
    };
  }

  bool get isFailure {
    return switch (this) {
      SourceImageUploadStatus.validationError ||
      SourceImageUploadStatus.permissionFailure ||
      SourceImageUploadStatus.metadataSaveFailed ||
      SourceImageUploadStatus.uploadFailed => true,
      _ => false,
    };
  }

  bool get canRetryUpload {
    return switch (this) {
      SourceImageUploadStatus.permissionFailure ||
      SourceImageUploadStatus.metadataSaveFailed ||
      SourceImageUploadStatus.uploadFailed => true,
      _ => false,
    };
  }
}

SourceImageUploadStatus uploadStatusForProjectApiException(
  ProjectApiException error,
) {
  return switch (error.code) {
    'invalid_content_type' ||
    'file_too_large' ||
    'missing_image_dimensions' => SourceImageUploadStatus.validationError,
    'permission_denied' ||
    'permission-denied' ||
    'unauthorized' => SourceImageUploadStatus.permissionFailure,
    'metadata_save_failed' => SourceImageUploadStatus.metadataSaveFailed,
    _ => SourceImageUploadStatus.uploadFailed,
  };
}

String uploadRecoveryMessage(ProjectApiException error) {
  final status = uploadStatusForProjectApiException(error);
  return switch (status) {
    SourceImageUploadStatus.permissionFailure =>
      'Permission blocked the upload. Check that you still have access to this project, then retry.',
    SourceImageUploadStatus.metadataSaveFailed =>
      'Upload reached storage, but the image metadata was not saved. Retry upload; if it keeps failing, ask support to clean up the incomplete storage object.',
    SourceImageUploadStatus.validationError => error.message,
    _ => error.message,
  };
}

String uploadProgressLabel(double? progress) {
  if (progress == null) {
    return 'Uploading';
  }
  final percent = (progress.clamp(0, 1) * 100).round();
  return 'Uploading $percent%';
}
