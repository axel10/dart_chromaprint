import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'dart_chromaprint_platform_interface.dart';

/// An implementation of [DartChromaprintPlatform] that uses method channels.
class MethodChannelDartChromaprint extends DartChromaprintPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('dart_chromaprint');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
