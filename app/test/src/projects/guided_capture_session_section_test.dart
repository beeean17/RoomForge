import 'package:app/src/projects/arcore_depth_capability.dart';
import 'package:app/src/projects/guided_capture_session_section.dart';
import 'package:app/src/projects/project_api.dart';
import 'package:app/src/projects/source_image_upload_status.dart';
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

  testWidgets('shows per-role upload recovery without hiding uploaded roles', (
    tester,
  ) async {
    final actions = <String>[];

    await tester.pumpGuidedCaptureSection(
      dimensions: _roomDimensions(),
      started: true,
      roleUploads: {
        'overview': GuidedCaptureRoleUploadSnapshot(
          status: SourceImageUploadStatus.uploaded,
          image: _captureImage(role: 'overview'),
          message: 'Uploaded: overview',
        ),
        'front_wall': const GuidedCaptureRoleUploadSnapshot(
          status: SourceImageUploadStatus.uploadFailed,
          message: 'Network failed',
        ),
      },
      onUploadRole: (role) => actions.add('upload:${role.id}'),
      onRetryRole: (role) => actions.add('retry:${role.id}'),
    );

    expect(find.text('Uploaded'), findsOneWidget);
    expect(find.text('1600 x 900px'), findsOneWidget);
    expect(find.text('Network failed'), findsOneWidget);
    expect(find.text('Upload failed'), findsOneWidget);

    await tester.ensureVisible(find.text('Retry role').first);
    await tester.pump();
    await tester.tap(find.text('Retry role').first);
    await tester.pump();

    expect(actions, ['retry:front_wall']);
  });

  testWidgets('enables ARCore depth enhancement when supported', (
    tester,
  ) async {
    bool? enabled;

    await tester.pumpGuidedCaptureSection(
      dimensions: _roomDimensions(),
      started: false,
      depthCapability: const ArCoreDepthCapability(
        isAndroid: true,
        isSupported: true,
        reason: 'supported by test',
      ),
      depthEnhancementEnabled: true,
      onDepthEnhancementChanged: (value) => enabled = value,
    );

    expect(find.text('Accuracy enhancement'), findsOneWidget);
    expect(find.textContaining('distance metadata'), findsOneWidget);
    expect(find.textContaining('approximate'), findsOneWidget);
    expect(find.textContaining('remains editable'), findsOneWidget);

    final toggle = tester.widget<SwitchListTile>(
      find.byKey(guidedCaptureDepthToggleKey),
    );
    expect(toggle.value, isTrue);
    expect(toggle.onChanged, isNotNull);

    await tester.tap(find.byKey(guidedCaptureDepthToggleKey));
    await tester.pump();

    expect(enabled, isFalse);
  });

  testWidgets('falls back to normal guided photos when depth is unsupported', (
    tester,
  ) async {
    await tester.pumpGuidedCaptureSection(
      dimensions: _roomDimensions(),
      started: false,
      depthCapability: const ArCoreDepthCapability(
        isAndroid: true,
        isSupported: false,
        reason: 'unsupported by test',
      ),
    );

    expect(find.textContaining('normal guided photos'), findsOneWidget);
    expect(find.textContaining('unavailable'), findsOneWidget);

    final toggle = tester.widget<SwitchListTile>(
      find.byKey(guidedCaptureDepthToggleKey),
    );
    expect(toggle.value, isFalse);
    expect(toggle.onChanged, isNull);

    final startButton = tester.widget<FilledButton>(
      find.byKey(guidedCaptureSessionStartButtonKey),
    );
    expect(startButton.onPressed, isNotNull);
  });

  testWidgets('disabled depth enhancement requires no depth metadata', (
    tester,
  ) async {
    await tester.pumpGuidedCaptureSection(
      dimensions: _roomDimensions(),
      started: false,
      depthCapability: const ArCoreDepthCapability(
        isAndroid: true,
        isSupported: true,
        reason: 'supported by test',
      ),
      depthEnhancementEnabled: false,
    );

    expect(find.textContaining('Distance metadata is off'), findsOneWidget);
    expect(
      find.textContaining('no depth metadata is required'),
      findsOneWidget,
    );
  });
}

extension on WidgetTester {
  Future<void> pumpGuidedCaptureSection({
    required RoomDimensions? dimensions,
    required bool started,
    VoidCallback? onStart,
    Map<String, GuidedCaptureRoleUploadSnapshot> roleUploads = const {},
    ValueChanged<GuidedCaptureRoleInstruction>? onUploadRole,
    ValueChanged<GuidedCaptureRoleInstruction>? onRetryRole,
    ArCoreDepthCapability depthCapability =
        const ArCoreDepthCapability.unsupported(),
    bool depthEnhancementEnabled = false,
    ValueChanged<bool>? onDepthEnhancementChanged,
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
                roleUploads: roleUploads,
                depthCapability: depthCapability,
                depthEnhancementEnabled: depthEnhancementEnabled,
                onDepthEnhancementChanged: onDepthEnhancementChanged,
                onUploadRole: onUploadRole,
                onRetryRole: onRetryRole,
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

CaptureImage _captureImage({required String role}) {
  final now = DateTime.utc(2026, 6, 2);
  return CaptureImage(
    id: 'capture-image-$role',
    captureSessionId: 'capture-session-1',
    projectId: 'project-1',
    userId: 'user-1',
    sourceImageId: 'source-image-$role',
    role: role,
    storagePath:
        'users/user-1/projects/project-1/capture-sessions/capture-session-1/images/capture-image-$role/$role.png',
    contentType: 'image/png',
    widthPx: 1600,
    heightPx: 900,
    createdAt: now,
    updatedAt: now,
  );
}
