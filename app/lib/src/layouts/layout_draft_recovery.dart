import 'layout_draft_models.dart';

class LayoutDraftRecoveryActionId {
  const LayoutDraftRecoveryActionId._();

  static const restoreDraft = 'restore_draft';
  static const discardDraft = 'discard_draft';
  static const continueSavedVersion = 'continue_saved_version';
  static const retrySave = 'retry_save';
}

class LayoutDraftRecoveryAction {
  const LayoutDraftRecoveryAction({
    required this.id,
    required this.label,
    this.isDestructive = false,
    this.requiresConfirmation = false,
  });

  final String id;
  final String label;
  final bool isDestructive;
  final bool requiresConfirmation;

  LayoutDraftRecoveryAction copyWith({String? label}) {
    return LayoutDraftRecoveryAction(
      id: id,
      label: label ?? this.label,
      isDestructive: isDestructive,
      requiresConfirmation: requiresConfirmation,
    );
  }
}

const draftRecoveryUnsavedMessage = 'Unsaved draft available.';
const draftRecoveryConflictMessage =
    'Cloud saved layout changed since this Unsaved draft.';
const draftRecoveryRestoreActionLabel = 'Restore draft';
const draftRecoveryDiscardActionLabel = 'Discard draft';
const draftRecoveryContinueSavedActionLabel = 'Continue saved version';
const draftRecoveryRetrySaveActionLabel = 'Retry save';
const draftRecoveryDiscardConfirmationTitle = 'Discard draft?';
const draftRecoveryDiscardConfirmationMessage =
    'This removes the local draft only.';

bool layoutDraftHasCloudConflict(
  LayoutDraft draft,
  DateTime? latestCloudUpdatedAt,
) {
  final baseUpdatedAt = draft.baseCloudUpdatedAt;
  if (baseUpdatedAt == null || latestCloudUpdatedAt == null) {
    return false;
  }
  return !baseUpdatedAt.toUtc().isAtSameMomentAs(latestCloudUpdatedAt.toUtc());
}

String layoutDraftRecoveryMessage({
  required LayoutDraft draft,
  required DateTime? latestCloudUpdatedAt,
}) {
  return layoutDraftHasCloudConflict(draft, latestCloudUpdatedAt)
      ? draftRecoveryConflictMessage
      : draftRecoveryUnsavedMessage;
}

List<LayoutDraftRecoveryAction> layoutDraftRecoveryActions({
  required LayoutDraft draft,
  required DateTime? latestCloudUpdatedAt,
  bool includeContinueSavedVersion = false,
  bool includeRetry = false,
}) {
  final hasCloudConflict = layoutDraftHasCloudConflict(
    draft,
    latestCloudUpdatedAt,
  );
  final shouldOfferRetry =
      includeRetry || draft.syncState == LayoutDraftSyncState.syncFailed;

  return [
    const LayoutDraftRecoveryAction(
      id: LayoutDraftRecoveryActionId.restoreDraft,
      label: draftRecoveryRestoreActionLabel,
    ),
    const LayoutDraftRecoveryAction(
      id: LayoutDraftRecoveryActionId.discardDraft,
      label: draftRecoveryDiscardActionLabel,
      isDestructive: true,
      requiresConfirmation: true,
    ),
    if (hasCloudConflict || includeContinueSavedVersion)
      const LayoutDraftRecoveryAction(
        id: LayoutDraftRecoveryActionId.continueSavedVersion,
        label: draftRecoveryContinueSavedActionLabel,
      ),
    if (shouldOfferRetry)
      const LayoutDraftRecoveryAction(
        id: LayoutDraftRecoveryActionId.retrySave,
        label: draftRecoveryRetrySaveActionLabel,
      ),
  ];
}

String layoutDraftRecoveryAccessibilitySummary({
  required LayoutDraft draft,
  required DateTime? latestCloudUpdatedAt,
  bool includeContinueSavedVersion = false,
  bool includeRetry = false,
}) {
  final actionLabels = layoutDraftRecoveryActions(
    draft: draft,
    latestCloudUpdatedAt: latestCloudUpdatedAt,
    includeContinueSavedVersion: includeContinueSavedVersion,
    includeRetry: includeRetry,
  ).map((action) => action.label).join(', ');

  return '${layoutDraftRecoveryMessage(draft: draft, latestCloudUpdatedAt: latestCloudUpdatedAt)} ${draft.label}. Actions: $actionLabels.';
}
