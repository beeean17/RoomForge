import 'package:app/src/layouts/layout_draft_recovery.dart';
import 'package:app/src/layouts/layout_draft_recovery_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders keyboard reachable recovery and retry actions', (
    tester,
  ) async {
    final invoked = <String>[];
    const semanticsLabel =
        'Unsaved draft recovery. Actions: Restore draft, Discard draft, Continue saved version, Retry save.';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LayoutDraftRecoveryControls(
            actions: const [
              LayoutDraftRecoveryAction(
                id: LayoutDraftRecoveryActionId.restoreDraft,
                label: 'Restore draft',
              ),
              LayoutDraftRecoveryAction(
                id: LayoutDraftRecoveryActionId.discardDraft,
                label: 'Discard draft',
                isDestructive: true,
                requiresConfirmation: true,
              ),
              LayoutDraftRecoveryAction(
                id: LayoutDraftRecoveryActionId.continueSavedVersion,
                label: 'Continue saved version',
              ),
              LayoutDraftRecoveryAction(
                id: LayoutDraftRecoveryActionId.retrySave,
                label: 'Retry save',
              ),
            ],
            isHandlingDraft: false,
            semanticsLabel: semanticsLabel,
            onRestoreDraft: () => invoked.add('restore'),
            onDiscardDraft: () => invoked.add('discard'),
            onContinueSavedVersion: () => invoked.add('continue'),
            onRetrySave: () => invoked.add('retry'),
          ),
        ),
      ),
    );

    for (final label in [
      'Restore draft',
      'Discard draft',
      'Continue saved version',
      'Retry save',
    ]) {
      expect(find.text(label), findsOneWidget);
      await tester.tap(find.text(label));
    }

    expect(invoked, ['restore', 'discard', 'continue', 'retry']);
    expect(find.bySemanticsLabel(semanticsLabel), findsOneWidget);
  });

  testWidgets('disables recovery actions while handling a draft', (
    tester,
  ) async {
    var invoked = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LayoutDraftRecoveryControls(
            actions: const [
              LayoutDraftRecoveryAction(
                id: LayoutDraftRecoveryActionId.restoreDraft,
                label: 'Restore draft',
              ),
            ],
            isHandlingDraft: true,
            onRestoreDraft: () => invoked = true,
            onDiscardDraft: () => invoked = true,
            onContinueSavedVersion: () => invoked = true,
            onRetrySave: () => invoked = true,
          ),
        ),
      ),
    );

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(invoked, isFalse);
  });
}
