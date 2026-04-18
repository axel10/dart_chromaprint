import 'package:flutter_test/flutter_test.dart';
import 'package:dart_chromaprint/dart_chromaprint.dart';
import 'package:dart_chromaprint/dart_chromaprint_platform_interface.dart';
import 'package:dart_chromaprint/dart_chromaprint_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockDartChromaprintPlatform
    with MockPlatformInterfaceMixin
    implements DartChromaprintPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final DartChromaprintPlatform initialPlatform = DartChromaprintPlatform.instance;

  test('$MethodChannelDartChromaprint is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelDartChromaprint>());
  });

  test('getPlatformVersion', () async {
    DartChromaprint dartChromaprintPlugin = DartChromaprint();
    MockDartChromaprintPlatform fakePlatform = MockDartChromaprintPlatform();
    DartChromaprintPlatform.instance = fakePlatform;

    expect(await dartChromaprintPlugin.getPlatformVersion(), '42');
  });
}
