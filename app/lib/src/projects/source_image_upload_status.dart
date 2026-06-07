import 'project_api.dart';

class SourceImageUploadActionId {
  const SourceImageUploadActionId._();

  static const choosePhoto = 'choose_photo';
  static const retryUpload = 'retry_upload';
}

class SourceImageUploadAction {
  const SourceImageUploadAction({
    required this.id,
    required this.label,
    this.isPrimary = false,
  });

  final String id;
  final String label;
  final bool isPrimary;

  SourceImageUploadAction copyWith({String? label}) {
    return SourceImageUploadAction(
      id: id,
      label: label ?? this.label,
      isPrimary: isPrimary,
    );
  }
}

const sourceImageChoosePhotoActionLabel = 'Choose photo';
const sourceImageRetryUploadActionLabel = 'Retry upload';
const sourceImageUploadProgressSemanticsLabel = 'Source image upload progress';
const sourceImageUploadRecoverySemanticsLabel = 'Source image upload recovery';

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

List<SourceImageUploadAction> sourceImageUploadActions(
  SourceImageUploadStatus status,
) {
  return [
    const SourceImageUploadAction(
      id: SourceImageUploadActionId.choosePhoto,
      label: sourceImageChoosePhotoActionLabel,
    ),
    if (status.canRetryUpload)
      const SourceImageUploadAction(
        id: SourceImageUploadActionId.retryUpload,
        label: sourceImageRetryUploadActionLabel,
        isPrimary: true,
      ),
  ];
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

String sourceImageUploadGuidance(SourceImageUploadStatus status) {
  return switch (status) {
    SourceImageUploadStatus.ready =>
      'Choose a supported room photo before reconstruction.',
    SourceImageUploadStatus.uploading =>
      'Keep this tab open while the source image is saved.',
    SourceImageUploadStatus.uploaded =>
      'The uploaded photo is ready for reconstruction review.',
    SourceImageUploadStatus.validationError =>
      'Choose a JPEG, PNG, or WebP image up to 10 MB.',
    SourceImageUploadStatus.lowQualityWarning =>
      'Use a sharper, brighter image if reconstruction looks weak.',
    SourceImageUploadStatus.permissionFailure =>
      'Refresh access or retry after confirming this project belongs to your account.',
    SourceImageUploadStatus.metadataSaveFailed =>
      'Storage received the file, but the project metadata did not finish saving.',
    SourceImageUploadStatus.uploadFailed =>
      'Retry upload, or replace the file if the problem repeats.',
    SourceImageUploadStatus.empty =>
      'Choose a room photo to begin reconstruction.',
  };
}

String sourceImageUploadAccessibilitySummary({
  required SourceImageUploadStatus status,
  String? message,
  double? progress,
}) {
  final statusText = status == SourceImageUploadStatus.uploading
      ? uploadProgressLabel(progress)
      : status.label;
  final actionText = sourceImageUploadActions(
    status,
  ).map((action) => action.label).join(', ');
  return [
    sourceImageUploadRecoverySemanticsLabel,
    statusText,
    sourceImageUploadGuidance(status),
    if (message != null && message.isNotEmpty) message,
    if (actionText.isNotEmpty) 'Actions: $actionText',
  ].join('. ');
}

String uploadProgressLabel(double? progress) {
  if (progress == null) {
    return 'Uploading';
  }
  final percent = (progress.clamp(0, 1) * 100).round();
  return 'Uploading $percent%';
}
