import 'layout_draft_models.dart';
import 'layout_draft_recovery.dart';

const layoutSyncFailedLabel = 'Sync failed';
const layoutRetryAvailableLabel = 'Retry available';
const layoutRemoteUpdateHeldMessage =
    'Cloud update held for Unsaved draft. Restore, discard, or continue saved version.';

class LayoutRemoteUpdateDecision {
  const LayoutRemoteUpdateDecision._({
    required this.applyRemoteLayout,
    required this.holdLocalDraft,
    required this.requiresUserChoice,
    required this.actions,
    this.message,
  });

  const LayoutRemoteUpdateDecision.apply()
    : this._(
        applyRemoteLayout: true,
        holdLocalDraft: false,
        requiresUserChoice: false,
        actions: const [],
      );

  const LayoutRemoteUpdateDecision.hold({
    required List<LayoutDraftRecoveryAction> actions,
  }) : this._(
         applyRemoteLayout: false,
         holdLocalDraft: true,
         requiresUserChoice: true,
         message: layoutRemoteUpdateHeldMessage,
         actions: actions,
       );

  final bool applyRemoteLayout;
  final bool holdLocalDraft;
  final bool requiresUserChoice;
  final String? message;
  final List<LayoutDraftRecoveryAction> actions;
}

class GuardedRemoteLayout<T> {
  const GuardedRemoteLayout({required this.decision, required this.layout});

  final LayoutRemoteUpdateDecision decision;
  final T? layout;
}

bool shouldHoldRemoteLayoutForDraft({
  required LayoutDraft? draft,
  required bool forceApplyCloud,
}) {
  return !forceApplyCloud && draft != null && draft.isRecoverable;
}

GuardedRemoteLayout<T> guardedRemoteLayout<T>({
  required T layout,
  required LayoutDraft? draft,
  required bool forceApplyCloud,
  DateTime? latestCloudUpdatedAt,
}) {
  final decision = layoutRemoteUpdateDecision(
    draft: draft,
    forceApplyCloud: forceApplyCloud,
    latestCloudUpdatedAt: latestCloudUpdatedAt,
  );
  return GuardedRemoteLayout<T>(
    decision: decision,
    layout: decision.applyRemoteLayout ? layout : null,
  );
}

LayoutRemoteUpdateDecision layoutRemoteUpdateDecision({
  required LayoutDraft? draft,
  required bool forceApplyCloud,
  DateTime? latestCloudUpdatedAt,
}) {
  if (!shouldHoldRemoteLayoutForDraft(
    draft: draft,
    forceApplyCloud: forceApplyCloud,
  )) {
    return const LayoutRemoteUpdateDecision.apply();
  }

  return LayoutRemoteUpdateDecision.hold(
    actions: layoutDraftRecoveryActions(
      draft: draft!,
      latestCloudUpdatedAt: latestCloudUpdatedAt,
      includeContinueSavedVersion: true,
    ),
  );
}
