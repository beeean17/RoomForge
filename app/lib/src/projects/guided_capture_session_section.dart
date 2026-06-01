import 'package:flutter/material.dart';

import 'project_api.dart';

const guidedCaptureSessionStartButtonKey = Key(
  'guided-capture-session-start-button',
);

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

class GuidedCaptureSessionSection extends StatelessWidget {
  const GuidedCaptureSessionSection({
    required this.dimensions,
    required this.started,
    required this.onStart,
    this.copy = const GuidedCaptureSessionCopy(),
    this.roles = defaultGuidedCaptureRoles,
    super.key,
  });

  final RoomDimensions? dimensions;
  final bool started;
  final VoidCallback onStart;
  final GuidedCaptureSessionCopy copy;
  final List<GuidedCaptureRoleInstruction> roles;

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
          ],
          const SizedBox(height: 12),
          _RoleInstructionList(
            title: copy.rolesTitle,
            roles: roles,
            requiredLabel: copy.requiredLabel,
            optionalLabel: copy.optionalLabel,
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

class _RoleInstructionList extends StatelessWidget {
  const _RoleInstructionList({
    required this.title,
    required this.roles,
    required this.requiredLabel,
    required this.optionalLabel,
  });

  final String title;
  final List<GuidedCaptureRoleInstruction> roles;
  final String requiredLabel;
  final String optionalLabel;

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
          ),
          if (role != roles.last) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _RoleInstructionTile extends StatelessWidget {
  const _RoleInstructionTile({required this.role, required this.stateLabel});

  final GuidedCaptureRoleInstruction role;
  final String stateLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      container: true,
      label: '${role.label}, ${role.id}, $stateLabel. ${role.description}',
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
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                stateLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: role.required
                      ? colorScheme.primary
                      : colorScheme.secondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
