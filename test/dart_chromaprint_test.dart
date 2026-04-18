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

// test_decoded.pcm的指纹结果是 AQAAjE-WUNKy4MKbJDnC5IbmB7mKdkfDPziPpzmaOAquIh_KDnr2JMjjwsepTMLDKSj_IMxCHDpRigqaZzgNLdklotu3QsuU8AhPo_9x1BtWool0tOU8HPiReNN4RPouwVk-9Aw-KS1-fMHf4B9C8Yd8OEaP_9ARmclxC60lo34wapGOWhk8MhWRIG-Gpj--5LiYC_7xq8OP05ERND8q_cOVIxd6Fz8enIVjKRxCK1cCHRcR3oM_VHokPMeH78PvoFeOMJegZ0eoFdaPly_8HQ8Ljz8sijgV4XvQKJRxZ0CEM5A8WsHFOcgSu6inEIiPxMe_4TgTURGenMSHiUWY79iLUzYensIPvWPwEKV0IcwLHo-DSufx6GC4BG-PHzkj4iXUJUzwHcCEMwopAYgFDFGAFAAAAG4AA0QQQog6DGgBABHOQUMkJQBohQChkgIAFCAGEYAcQEgQA4ATRAAnhVCUQAIIUoAAQwAygBABCDMEAAUIEQQISQxCxAgCAHCGGc2BQEYgA5AQCAE

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
