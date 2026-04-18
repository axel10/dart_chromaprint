import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'dart_chromaprint_method_channel.dart';

abstract class DartChromaprintPlatform extends PlatformInterface {
  /// Constructs a DartChromaprintPlatform.
  DartChromaprintPlatform() : super(token: _token);

  static final Object _token = Object();

  static DartChromaprintPlatform _instance = MethodChannelDartChromaprint();

  /// The default instance of [DartChromaprintPlatform] to use.
  ///
  /// Defaults to [MethodChannelDartChromaprint].
  static DartChromaprintPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [DartChromaprintPlatform] when
  /// they register themselves.
  static set instance(DartChromaprintPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
