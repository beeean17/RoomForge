import 'layout_draft_models.dart';

const layoutSyncFailedLabel = 'Sync failed';
const layoutRetryAvailableLabel = 'Retry available';
const layoutRemoteUpdateHeldMessage =
    'Cloud update held for Unsaved draft. Restore, discard, or continue saved version.';

bool shouldHoldRemoteLayoutForDraft({
  required LayoutDraft? draft,
  required bool forceApplyCloud,
}) {
  return !forceApplyCloud && draft != null && draft.isRecoverable;
}
