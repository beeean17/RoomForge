import 'layout_draft_models.dart';

const draftRecoveryUnsavedMessage = 'Unsaved draft available.';
const draftRecoveryConflictMessage =
    'Cloud saved layout changed since this Unsaved draft.';

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
