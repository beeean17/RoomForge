import 'package:app/src/projects/arcore_depth_capability.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ArCoreDepthCapabilityProvider', () {
    const channel = MethodChannel('roomforge/arcore_depth_test');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test(
      'reports supported Android capability from platform channel',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              expect(call.method, 'isDepthSupported');
              return {
                'supported': true,
                'reason': 'mock Android depth support',
              };
            });

        final provider = ArCoreDepthCapabilityProvider(
          channel: channel,
          targetPlatform: TargetPlatform.android,
          isWeb: false,
        );

        final capability = await provider.check();

        expect(capability.isAndroid, isTrue);
        expect(capability.isSupported, isTrue);
        expect(capability.canEnableDepth, isTrue);
        expect(capability.reason, contains('mock Android depth support'));
      },
    );

    test('falls back when Android reports unsupported', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            return {'supported': false, 'reason': 'mock unsupported'};
          });

      final provider = ArCoreDepthCapabilityProvider(
        channel: channel,
        targetPlatform: TargetPlatform.android,
        isWeb: false,
      );

      final capability = await provider.check();

      expect(capability.isAndroid, isTrue);
      expect(capability.isSupported, isFalse);
      expect(capability.canEnableDepth, isFalse);
      expect(capability.reason, contains('mock unsupported'));
    });

    test('does not query native channel outside Android', () async {
      var queried = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            queried = true;
            return {'supported': true};
          });

      final provider = ArCoreDepthCapabilityProvider(
        channel: channel,
        targetPlatform: TargetPlatform.iOS,
        isWeb: false,
      );

      final capability = await provider.check();

      expect(queried, isFalse);
      expect(capability.isAndroid, isFalse);
      expect(capability.canEnableDepth, isFalse);
      expect(capability.reason, contains('Android device'));
    });
  });
}
