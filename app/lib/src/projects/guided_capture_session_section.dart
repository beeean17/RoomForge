import 'package:flutter/material.dart';

import 'arcore_depth_capability.dart';
import 'project_api.dart';
import 'source_image_upload_status.dart';

const guidedCaptureSessionStartButtonKey = Key(
  'guided-capture-session-start-button',
);
const guidedCaptureDepthToggleKey = Key('guided-capture-depth-toggle');

class GuidedCaptureSessionCopy {
  const GuidedCaptureSessionCopy({
    this.title = 'Guided room capture',
    this.description =
        'Start a role-based capture session after confirming room dimensions.',
    this.missingDimensionsTitle = 'Room dimensions required',
    this.missingDimensionsMessage =
        'Enter or confirm room width, depth, and height in meters before starting guided capture.',
    this.readyTitle = 'Ready for guided capture',
    this.readyMessage =
        'Use the guided roles below to collect photos for browser CV scene understanding.',
    this.startedTitle = 'Capture session ready',
    this.startedMessage =
        'Capture each required role, then continue on desktop for review and correction.',
    this.rolesTitle = 'Photo roles',
    this.requiredLabel = 'Required',
    this.optionalLabel = 'Optional',
    this.startLabel = 'Start guided capture',
    this.startedLabel = 'Guided capture started',
    this.occlusionTitle = 'Blocked walls are acceptable',
    this.occlusionMessage =
        'If furniture blocks a wall, capture the visible wall and floor evidence from that side. You can manually correct room shape and object placement later.',
    this.dimensionsLabel = 'Room dimensions',
    this.widthLabel = 'Width',
    this.depthLabel = 'Depth',
    this.heightLabel = 'Height',
    this.defaultHeightLabel = 'default height',
    this.userHeightLabel = 'user height',
    this.sessionStateLabel = 'Guided capture session state',
    this.uploadRoleLabel = 'Upload photo',
    this.replaceRoleLabel = 'Replace photo',
    this.retryRoleLabel = 'Retry role',
    this.uploadingRoleLabel = 'Uploading...',
    this.uploadedRoleLabel = 'Uploaded',
    this.noRolePhotoLabel = 'No photo yet',
    this.roleUploadFailedLabel = 'Upload failed',
    this.depthToggleTitle = 'Accuracy enhancement',
    this.depthToggleLabel = 'Use distance metadata',
    this.depthSupportedMessage =
        'On supported Android devices, RoomForge can attach ARCore Depth distance metadata to improve placement estimates. It is approximate and remains editable.',
    this.depthUnsupportedMessage =
        'This device will use normal guided photos because ARCore Depth distance metadata is unavailable.',
    this.depthDisabledMessage =
        'Distance metadata is off. Guided photos still work, and no depth metadata is required.',
  });

  final String title;
  final String description;
  final String missingDimensionsTitle;
  final String missingDimensionsMessage;
  final String readyTitle;
  final String readyMessage;
  final String startedTitle;
  final String startedMessage;
  final String rolesTitle;
  final String requiredLabel;
  final String optionalLabel;
  final String startLabel;
  final String startedLabel;
  final String occlusionTitle;
  final String occlusionMessage;
  final String dimensionsLabel;
  final String widthLabel;
  final String depthLabel;
  final String heightLabel;
  final String defaultHeightLabel;
  final String userHeightLabel;
  final String sessionStateLabel;
  final String uploadRoleLabel;
  final String replaceRoleLabel;
  final String retryRoleLabel;
  final String uploadingRoleLabel;
  final String uploadedRoleLabel;
  final String noRolePhotoLabel;
  final String roleUploadFailedLabel;
  final String depthToggleTitle;
  final String depthToggleLabel;
  final String depthSupportedMessage;
  final String depthUnsupportedMessage;
  final String depthDisabledMessage;
}

class GuidedCaptureRoleInstruction {
  const GuidedCaptureRoleInstruction({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    this.required = true,
  });

  final String id;
  final String label;
  final String description;
  final IconData icon;
  final bool required;
}

const defaultGuidedCaptureRoles = [
  GuidedCaptureRoleInstruction(
    id: 'overview',
    label: 'Overview',
    description:
        'Capture the room from the widest available corner or doorway.',
    icon: Icons.photo_size_select_large_outlined,
  ),
  GuidedCaptureRoleInstruction(
    id: 'front_wall',
    label: 'Front wall',
    description: 'Stand near the opposite side and capture the front wall.',
    icon: Icons.border_top_outlined,
  ),
  GuidedCaptureRoleInstruction(
    id: 'right_wall',
    label: 'Right wall',
    description: 'Capture the right wall with visible floor-wall evidence.',
    icon: Icons.border_right_outlined,
  ),
  GuidedCaptureRoleInstruction(
    id: 'back_wall',
    label: 'Back wall',
    description: 'Capture the back wall from the clearest available angle.',
    icon: Icons.border_bottom_outlined,
  ),
  GuidedCaptureRoleInstruction(
    id: 'left_wall',
    label: 'Left wall',
    description: 'Capture the left wall with any doors or windows visible.',
    icon: Icons.border_left_outlined,
  ),
  GuidedCaptureRoleInstruction(
    id: 'extra',
    label: 'Extra',
    description: 'Add another photo when a wall or large object is unclear.',
    icon: Icons.add_photo_alternate_outlined,
    required: false,
  ),
];

class GuidedCaptureRoleUploadSnapshot {
  const GuidedCaptureRoleUploadSnapshot({
    required this.status,
    this.image,
    this.message,
  });

  final SourceImageUploadStatus status;
  final CaptureImage? image;
  final String? message;

  bool get isUploading => status == SourceImageUploadStatus.uploading;

  bool get isUploaded =>
      image != null && status == SourceImageUploadStatus.uploaded;

  bool get isFailure => status.isFailure;
}

class GuidedCaptureSessionSection extends StatelessWidget {
  const GuidedCaptureSessionSection({
    required this.dimensions,
    required this.started,
    required this.onStart,
    this.copy = const GuidedCaptureSessionCopy(),
    this.roles = defaultGuidedCaptureRoles,
    this.roleUploads = const {},
    this.depthCapability = const ArCoreDepthCapability.unsupported(),
    this.depthEnhancementEnabled = false,
    this.onDepthEnhancementChanged,
    this.onUploadRole,
    this.onRetryRole,
    super.key,
  });

  final RoomDimensions? dimensions;
  final bool started;
  final VoidCallback onStart;
  final GuidedCaptureSessionCopy copy;
  final List<GuidedCaptureRoleInstruction> roles;
  final Map<String, GuidedCaptureRoleUploadSnapshot> roleUploads;
  final ArCoreDepthCapability depthCapability;
  final bool depthEnhancementEnabled;
  final ValueChanged<bool>? onDepthEnhancementChanged;
  final ValueChanged<GuidedCaptureRoleInstruction>? onUploadRole;
  final ValueChanged<GuidedCaptureRoleInstruction>? onRetryRole;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasDimensions = dimensions != null;
    final stateColor = !hasDimensions
        ? colorScheme.error
        : started
        ? colorScheme.primary
        : colorScheme.tertiary;

    return Semantics(
      container: true,
      label: copy.sessionStateLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.camera_enhance_outlined, color: colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        copy.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      copy.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.72,
                        ),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _CaptureStateBanner(
            title: !hasDimensions
                ? copy.missingDimensionsTitle
                : started
                ? copy.startedTitle
                : copy.readyTitle,
            message: !hasDimensions
                ? copy.missingDimensionsMessage
                : started
                ? copy.startedMessage
                : copy.readyMessage,
            color: stateColor,
            icon: !hasDimensions
                ? Icons.straighten_outlined
                : started
                ? Icons.check_circle_outline
                : Icons.flag_outlined,
          ),
          if (hasDimensions) ...[
            const SizedBox(height: 12),
            _DimensionSummary(dimensions: dimensions!, copy: copy),
            const SizedBox(height: 12),
            _DepthEnhancementToggle(
              capability: depthCapability,
              enabled: depthEnhancementEnabled,
              locked: started,
              copy: copy,
              onChanged: onDepthEnhancementChanged,
            ),
          ],
          const SizedBox(height: 12),
          _RoleInstructionList(
            title: copy.rolesTitle,
            roles: roles,
            roleUploads: roleUploads,
            captureActive: hasDimensions && started,
            requiredLabel: copy.requiredLabel,
            optionalLabel: copy.optionalLabel,
            copy: copy,
            onUploadRole: onUploadRole,
            onRetryRole: onRetryRole,
          ),
          const SizedBox(height: 12),
          _CaptureStateBanner(
            title: copy.occlusionTitle,
            message: copy.occlusionMessage,
            color: colorScheme.secondary,
            icon: Icons.visibility_outlined,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: guidedCaptureSessionStartButtonKey,
            onPressed: hasDimensions && !started ? onStart : null,
            icon: Icon(
              started ? Icons.check_circle_outline : Icons.play_arrow_outlined,
            ),
            label: Text(started ? copy.startedLabel : copy.startLabel),
          ),
        ],
      ),
    );
  }
}

class _CaptureStateBanner extends StatelessWidget {
  const _CaptureStateBanner({
    required this.title,
    required this.message,
    required this.color,
    required this.icon,
  });

  final String title;
  final String message;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DimensionSummary extends StatelessWidget {
  const _DimensionSummary({required this.dimensions, required this.copy});

  final RoomDimensions dimensions;
  final GuidedCaptureSessionCopy copy;

  @override
  Widget build(BuildContext context) {
    final heightSource = dimensions.usesDefaultHeight
        ? copy.defaultHeightLabel
        : copy.userHeightLabel;
    final values = [
      '${copy.widthLabel} ${dimensions.widthValue.toStringAsFixed(2)} m',
      '${copy.depthLabel} ${dimensions.depthValue.toStringAsFixed(2)} m',
      '${copy.heightLabel} ${dimensions.heightValue.toStringAsFixed(2)} m',
      heightSource,
    ];

    return Semantics(
      label: '${copy.dimensionsLabel}: ${values.join(', ')}',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final value in values)
            Chip(label: Text(value), visualDensity: VisualDensity.compact),
        ],
      ),
    );
  }
}

class _DepthEnhancementToggle extends StatelessWidget {
  const _DepthEnhancementToggle({
    required this.capability,
    required this.enabled,
    required this.locked,
    required this.copy,
    required this.onChanged,
  });

  final ArCoreDepthCapability capability;
  final bool enabled;
  final bool locked;
  final GuidedCaptureSessionCopy copy;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canEnable = capability.canEnableDepth && !locked;
    final effectiveEnabled = capability.canEnableDepth && enabled;
    final message = !capability.canEnableDepth
        ? copy.depthUnsupportedMessage
        : effectiveEnabled
        ? copy.depthSupportedMessage
        : copy.depthDisabledMessage;

    return Semantics(
      container: true,
      label: '${copy.depthToggleTitle}. $message',
      child: SwitchListTile(
        key: guidedCaptureDepthToggleKey,
        value: effectiveEnabled,
        onChanged: canEnable ? onChanged : null,
        secondary: Icon(
          Icons.speed_outlined,
          color: capability.canEnableDepth
              ? theme.colorScheme.primary
              : theme.colorScheme.outline,
        ),
        title: Text(
          copy.depthToggleTitle,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          '${copy.depthToggleLabel}. $message',
          style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
        ),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}

class _RoleInstructionList extends StatelessWidget {
  const _RoleInstructionList({
    required this.title,
    required this.roles,
    required this.roleUploads,
    required this.captureActive,
    required this.requiredLabel,
    required this.optionalLabel,
    required this.copy,
    required this.onUploadRole,
    required this.onRetryRole,
  });

  final String title;
  final List<GuidedCaptureRoleInstruction> roles;
  final Map<String, GuidedCaptureRoleUploadSnapshot> roleUploads;
  final bool captureActive;
  final String requiredLabel;
  final String optionalLabel;
  final GuidedCaptureSessionCopy copy;
  final ValueChanged<GuidedCaptureRoleInstruction>? onUploadRole;
  final ValueChanged<GuidedCaptureRoleInstruction>? onRetryRole;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        for (final role in roles) ...[
          _RoleInstructionTile(
            role: role,
            stateLabel: role.required ? requiredLabel : optionalLabel,
            upload: roleUploads[role.id],
            captureActive: captureActive,
            copy: copy,
            onUpload: onUploadRole == null ? null : () => onUploadRole!(role),
            onRetry: onRetryRole == null ? null : () => onRetryRole!(role),
          ),
          if (role != roles.last) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _RoleInstructionTile extends StatelessWidget {
  const _RoleInstructionTile({
    required this.role,
    required this.stateLabel,
    required this.upload,
    required this.captureActive,
    required this.copy,
    required this.onUpload,
    required this.onRetry,
  });

  final GuidedCaptureRoleInstruction role;
  final String stateLabel;
  final GuidedCaptureRoleUploadSnapshot? upload;
  final bool captureActive;
  final GuidedCaptureSessionCopy copy;
  final VoidCallback? onUpload;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final uploadState = upload?.status ?? SourceImageUploadStatus.empty;
    final isUploading = uploadState == SourceImageUploadStatus.uploading;
    final isUploaded = upload?.isUploaded == true;
    final isFailure = uploadState.isFailure;
    final uploadLabel = isUploading
        ? copy.uploadingRoleLabel
        : isUploaded
        ? copy.uploadedRoleLabel
        : isFailure
        ? copy.roleUploadFailedLabel
        : copy.noRolePhotoLabel;
    final uploadColor = isFailure
        ? colorScheme.error
        : isUploaded
        ? colorScheme.primary
        : colorScheme.outline;

    return Semantics(
      container: true,
      label:
          '${role.label}, ${role.id}, $stateLabel. $uploadLabel. ${role.description}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(role.icon, color: colorScheme.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${role.label} (${role.id})',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      role.description,
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _RoleUploadPill(
                          label: uploadLabel,
                          color: uploadColor,
                          icon: isUploading
                              ? Icons.cloud_upload_outlined
                              : isUploaded
                              ? Icons.cloud_done_outlined
                              : isFailure
                              ? Icons.error_outline
                              : Icons.image_not_supported_outlined,
                        ),
                        if (upload?.image != null)
                          _RoleUploadPill(
                            label:
                                '${upload!.image!.widthPx} x ${upload!.image!.heightPx}px',
                            color: colorScheme.primary,
                            icon: Icons.aspect_ratio_outlined,
                          ),
                      ],
                    ),
                    if (upload?.message != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        upload!.message!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isFailure ? colorScheme.error : null,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    stateLabel,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: role.required
                          ? colorScheme.primary
                          : colorScheme.secondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: captureActive && !isUploading ? onUpload : null,
                    icon: Icon(
                      isUploaded
                          ? Icons.swap_horiz_outlined
                          : Icons.file_upload_outlined,
                      size: 18,
                    ),
                    label: Text(
                      isUploaded ? copy.replaceRoleLabel : copy.uploadRoleLabel,
                    ),
                  ),
                  if (isFailure) ...[
                    const SizedBox(height: 6),
                    TextButton.icon(
                      onPressed: captureActive && !isUploading
                          ? (onRetry ?? onUpload)
                          : null,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(copy.retryRoleLabel),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleUploadPill extends StatelessWidget {
  const _RoleUploadPill({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
