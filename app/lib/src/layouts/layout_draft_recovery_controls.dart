import 'package:flutter/material.dart';

import 'layout_draft_recovery.dart';

class LayoutDraftRecoveryControls extends StatelessWidget {
  const LayoutDraftRecoveryControls({
    required this.actions,
    required this.isHandlingDraft,
    required this.onRestoreDraft,
    required this.onDiscardDraft,
    required this.onContinueSavedVersion,
    required this.onRetrySave,
    this.semanticsLabel,
    super.key,
  });

  final List<LayoutDraftRecoveryAction> actions;
  final bool isHandlingDraft;
  final VoidCallback onRestoreDraft;
  final VoidCallback onDiscardDraft;
  final VoidCallback onContinueSavedVersion;
  final VoidCallback onRetrySave;
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

  Widget _buttonFor(LayoutDraftRecoveryAction action) {
    final onPressed = isHandlingDraft ? null : _callbackFor(action.id);
    final icon = _iconFor(action.id);
    if (action.id == LayoutDraftRecoveryActionId.restoreDraft) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(action.label),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(action.label),
    );
  }

  VoidCallback _callbackFor(String actionId) {
    return switch (actionId) {
      LayoutDraftRecoveryActionId.restoreDraft => onRestoreDraft,
      LayoutDraftRecoveryActionId.discardDraft => onDiscardDraft,
      LayoutDraftRecoveryActionId.continueSavedVersion =>
        onContinueSavedVersion,
      LayoutDraftRecoveryActionId.retrySave => onRetrySave,
      _ => () {},
    };
  }

  IconData _iconFor(String actionId) {
    return switch (actionId) {
      LayoutDraftRecoveryActionId.restoreDraft => Icons.restore_outlined,
      LayoutDraftRecoveryActionId.discardDraft => Icons.delete_sweep_outlined,
      LayoutDraftRecoveryActionId.continueSavedVersion =>
        Icons.cloud_done_outlined,
      LayoutDraftRecoveryActionId.retrySave => Icons.refresh_outlined,
      _ => Icons.help_outline,
    };
  }
}
