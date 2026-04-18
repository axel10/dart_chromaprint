
import 'dart_chromaprint_platform_interface.dart';

class DartChromaprint {
  Future<String?> getPlatformVersion() {
    return DartChromaprintPlatform.instance.getPlatformVersion();
  }
}
