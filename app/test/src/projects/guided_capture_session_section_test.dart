import 'package:app/src/projects/guided_capture_session_section.dart';
import 'package:app/src/projects/project_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('explains guided capture roles and blocked-wall fallback', (
    tester,
  ) async {
    await tester.pumpGuidedCaptureSection(dimensions: null, started: false);

    expect(find.text('Guided room capture'), findsOneWidget);
    expect(find.textContaining('overview'), findsOneWidget);
    expect(find.textContaining('front_wall'), findsOneWidget);
    expect(find.textContaining('right_wall'), findsOneWidget);
    expect(find.textContaining('back_wall'), findsOneWidget);
    expect(find.textContaining('left_wall'), findsOneWidget);
    expect(find.text('Blocked walls are acceptable'), findsOneWidget);
    expect(
      find.textContaining('visible wall and floor evidence'),
      findsOneWidget,
    );
    expect(find.textContaining('manually correct room shape'), findsOneWidget);

    final startButton = tester.widget<FilledButton>(
      find.byKey(guidedCaptureSessionStartButtonKey),
    );
    expect(startButton.onPressed, isNull);
  });

  testWidgets('starts guided capture after dimensions are confirmed', (
    tester,
  ) async {
    var started = false;

    await tester.pumpGuidedCaptureSection(
      dimensions: _roomDimensions(),
      started: false,
      onStart: () => started = true,
    );

    expect(find.text('Width 4.20 m'), findsOneWidget);
    expect(find.text('Depth 3.60 m'), findsOneWidget);
    expect(find.text('Height 2.70 m'), findsOneWidget);

    final startButton = tester.widget<FilledButton>(
      find.byKey(guidedCaptureSessionStartButtonKey),
    );
    expect(startButton.onPressed, isNotNull);

    await tester.ensureVisible(find.byKey(guidedCaptureSessionStartButtonKey));
    await tester.pump();
    await tester.tap(find.byKey(guidedCaptureSessionStartButtonKey));
    await tester.pump();

    expect(started, isTrue);
  });

  testWidgets('announces started state and disables duplicate start', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpGuidedCaptureSection(
      dimensions: _roomDimensions(),
      started: true,
    );

    expect(find.text('Capture session ready'), findsOneWidget);
    expect(find.text('Guided capture started'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Guided capture session state')),
      findsOneWidget,
    );

    final startButton = tester.widget<FilledButton>(
      find.byKey(guidedCaptureSessionStartButtonKey),
    );
    expect(startButton.onPressed, isNull);

    semantics.dispose();
  });
}

extension on WidgetTester {
  Future<void> pumpGuidedCaptureSection({
    required RoomDimensions? dimensions,
    required bool started,
    VoidCallback? onStart,
  }) {
    return pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GuidedCaptureSessionSection(
                dimensions: dimensions,
                started: started,
                onStart: onStart ?? () {},
              ),
            ),
          ),
        ),
      ),
    );
  }
}

RoomDimensions _roomDimensions() {
  final now = DateTime.utc(2026, 6, 2);
  return RoomDimensions(
    projectId: 'project-1',
    userId: 'user-1',
    widthValue: 4.2,
    depthValue: 3.6,
    heightValue: 2.7,
    unit: 'meters',
    heightSource: 'user_entered',
    createdAt: now,
    updatedAt: now,
  );
}
