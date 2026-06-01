import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const arCoreDepthCapabilityChannelName = 'roomforge/arcore_depth';

class ArCoreDepthCapability {
  const ArCoreDepthCapability({
    required this.isAndroid,
    required this.isSupported,
    required this.reason,
  });

  const ArCoreDepthCapability.unsupported({
    String reason = 'ARCore Depth is unavailable on this platform.',
  }) : this(isAndroid: false, isSupported: false, reason: reason);

  final bool isAndroid;
  final bool isSupported;
  final String reason;

  bool get canEnableDepth => isAndroid && isSupported;
}

class ArCoreDepthCapabilityProvider {
  const ArCoreDepthCapabilityProvider({
    MethodChannel channel = const MethodChannel(
      arCoreDepthCapabilityChannelName,
    ),
    TargetPlatform? targetPlatform,
    bool? isWeb,
  }) : _channel = channel,
       _targetPlatform = targetPlatform,
       _isWeb = isWeb;

  final MethodChannel _channel;
  final TargetPlatform? _targetPlatform;
  final bool? _isWeb;

  Future<ArCoreDepthCapability> check() async {
    final platform = _targetPlatform ?? defaultTargetPlatform;
    final runningOnWeb = _isWeb ?? kIsWeb;
    if (runningOnWeb || platform != TargetPlatform.android) {
      return const ArCoreDepthCapability.unsupported(
        reason: 'ARCore Depth requires an Android device.',
      );
    }

    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'isDepthSupported',
      );
      final supported = result?['supported'] == true;
      final reason = result?['reason']?.toString();
      return ArCoreDepthCapability(
        isAndroid: true,
        isSupported: supported,
        reason:
            reason ??
            (supported
                ? 'Android reports ARCore depth capability.'
                : 'Android reports no ARCore depth capability.'),
      );
    } on MissingPluginException {
      return const ArCoreDepthCapability(
        isAndroid: true,
        isSupported: false,
        reason: 'ARCore Depth capability plugin is not available.',
      );
    } on PlatformException catch (error) {
      return ArCoreDepthCapability(
        isAndroid: true,
        isSupported: false,
        reason: error.message ?? 'ARCore Depth capability check failed.',
      );
    }
  }
}
