import 'dart:io';
import 'dart:typed_data';

import 'package:dart_chromaprint/dart_chromaprint.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/chromaprint_preprocessing.dart';
import '../lib/chromaprint_wav.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('decodeLittleEndianPcm decodes signed 16-bit samples', () {
    final bytes = Uint8List.fromList(<int>[
      0x34,
      0x12,
      0xCC,
      0xFF,
      0x00,
      0x80,
      0xFF,
      0x7F,
    ]);

    final samples = ChromaprintPreprocessor.decodeLittleEndianPcm(bytes);

    expect(
      samples,
      equals(Int16List.fromList(<int>[0x1234, -52, -32768, 32767])),
    );
  });

  test('PCM and WAV fingerprint APIs stay in sync on the bundled fixture', () {
    const wavPath = 'test/test.wav';

    final wavBytes = File(wavPath).readAsBytesSync();
    final wav = const ChromaprintWavReader().parseBytes(wavBytes);

    final fromPcm = fingerprintFromPcm(
      pcm: wav.samples,
      sampleRate: wav.sampleRate,
      channels: wav.channels,
    );
    final fromWavFile = fingerprintFromWavFile(wavPath);

    expect(fromWavFile, completion(equals(fromPcm)));
    expect(fromPcm, isNotEmpty);
  });

  test('invalid PCM input is rejected', () {
    expect(
      () => ChromaprintPreprocessor.decodeLittleEndianPcm(
        Uint8List.fromList(<int>[0x01]),
      ),
      throwsArgumentError,
    );
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
