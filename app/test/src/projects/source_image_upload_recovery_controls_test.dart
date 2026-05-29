import 'package:app/src/projects/source_image_upload_recovery_controls.dart';
import 'package:app/src/projects/source_image_upload_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders reachable choose and retry upload actions', (
    tester,
  ) async {
    final invoked = <String>[];
    const semanticsLabel =
        'Source image upload recovery. Metadata save failed. Actions: Choose photo, Retry upload.';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SourceImageUploadRecoveryControls(
            status: SourceImageUploadStatus.metadataSaveFailed,
            actions: sourceImageUploadActions(
              SourceImageUploadStatus.metadataSaveFailed,
            ),
            semanticsLabel: semanticsLabel,
            onChoosePhoto: () => invoked.add('choose'),
            onRetryUpload: () => invoked.add('retry'),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel(semanticsLabel), findsOneWidget);
    expect(find.text('Choose photo'), findsOneWidget);
    expect(find.text('Retry upload'), findsOneWidget);

    await tester.tap(find.text('Choose photo'));
    await tester.tap(find.text('Retry upload'));

    expect(invoked, ['choose', 'retry']);
  });

  testWidgets('supports keyboard traversal and activation', (tester) async {
    final invoked = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SourceImageUploadRecoveryControls(
            status: SourceImageUploadStatus.metadataSaveFailed,
            actions: sourceImageUploadActions(
              SourceImageUploadStatus.metadataSaveFailed,
            ),
            onChoosePhoto: () => invoked.add('choose'),
            onRetryUpload: () => invoked.add('retry'),
          ),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(invoked, ['choose', 'retry']);
  });

  testWidgets('disables choose photo while upload is in progress', (
    tester,
  ) async {
    var invoked = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SourceImageUploadRecoveryControls(
            status: SourceImageUploadStatus.uploading,
            actions: sourceImageUploadActions(
              SourceImageUploadStatus.uploading,
            ),
            onChoosePhoto: () => invoked = true,
            onRetryUpload: () => invoked = true,
          ),
        ),
      ),
    );

    final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(button.onPressed, isNull);
    expect(find.text('Uploading...'), findsOneWidget);
    expect(invoked, isFalse);
  });
}
