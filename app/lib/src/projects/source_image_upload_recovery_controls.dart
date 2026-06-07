import 'package:flutter/material.dart';

import 'source_image_upload_status.dart';

class SourceImageUploadRecoveryControls extends StatelessWidget {
  const SourceImageUploadRecoveryControls({
    required this.status,
    required this.actions,
    required this.onChoosePhoto,
    required this.onRetryUpload,
    this.uploadingLabel = 'Uploading...',
    this.semanticsLabel,
    super.key,
  });

  final SourceImageUploadStatus status;
  final List<SourceImageUploadAction> actions;
  final VoidCallback onChoosePhoto;
  final VoidCallback onRetryUpload;
  final String uploadingLabel;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: semanticsLabel,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [for (final action in actions) _buttonFor(action)],
      ),
    );
  }

  Widget _buttonFor(SourceImageUploadAction action) {
    final onPressed =
        action.id == SourceImageUploadActionId.choosePhoto &&
            status == SourceImageUploadStatus.uploading
        ? null
        : _callbackFor(action.id);
    final icon = switch (action.id) {
      SourceImageUploadActionId.retryUpload => Icons.refresh,
      _ => Icons.photo_outlined,
    };
    final label =
        action.id == SourceImageUploadActionId.choosePhoto &&
            status == SourceImageUploadStatus.uploading
        ? uploadingLabel
        : action.label;

    if (action.isPrimary) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }

  VoidCallback _callbackFor(String actionId) {
    return switch (actionId) {
      SourceImageUploadActionId.retryUpload => onRetryUpload,
      _ => onChoosePhoto,
    };
  }
}
