import 'dart:io';
import 'dart:typed_data';

import 'package:dart_chromaprint/dart_chromaprint.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('WAV reader parses the bundled fixture', () async {
    const wavPath = 'test/test.wav';

    final wav = await const ChromaprintWavReader().readFile(wavPath);

    expect(wav.sampleRate, 44100);
    expect(wav.channels, 2);
    expect(wav.samples, isNotEmpty);
    expect(wav.samples.length.isEven, isTrue);
  });

  test('WAV bytes, file, and parsed PCM inputs all fingerprint the same', () {
    const wavPath = 'test/test.wav';

    final wavBytes = File(wavPath).readAsBytesSync();
    final wav = const ChromaprintWavReader().parseBytes(wavBytes);

    final fromBytes = fingerprintStringFromWavBytes(
      Uint8List.fromList(wavBytes),
    );
    final fromFile = fingerprintStringFromWavFile(wavPath);
    final fromParsedPcm = fingerprintStringFromInt16Pcm(
      samples: wav.samples,
      sampleRate: wav.sampleRate,
      channels: wav.channels,
    );

    expect(fromBytes, equals(fromParsedPcm));
    expect(fromFile, completion(equals(fromParsedPcm)));
  });

  test('invalid WAV data is rejected', () {
    expect(
      () => const ChromaprintWavReader().parseBytes(
        Uint8List.fromList(<int>[0x00, 0x01, 0x02]),
      ),
      throwsFormatException,
    );
  });
}
