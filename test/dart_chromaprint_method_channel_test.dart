import 'dart:io';

import 'package:dart_chromaprint/dart_chromaprint.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/chromaprint_preprocessing.dart';
import '../lib/chromaprint_wav.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('WAV file API matches the parsed WAV fixture', () async {
    const wavPath = 'test/test.wav';

    final wav = await const ChromaprintWavReader().readFile(wavPath);
    final fromFile = await fingerprintFromWavFile(wavPath);
    final fromPcm = fingerprintFromPcm(
      pcm: wav.samples,
      sampleRate: wav.sampleRate,
      channels: wav.channels,
    );

    expect(fromFile, equals(fromPcm));
  });

  test('PCM API fingerprints the bundled PCM fixture', () {
    const sampleRate = 44100;
    const channels = 2;

    final bytes = File('test/test_decoded.pcm').readAsBytesSync();
    expect(
      fingerprintFromPcm(
        pcm: ChromaprintPreprocessor.decodeLittleEndianPcm(bytes),
        sampleRate: sampleRate,
        channels: channels,
      ),
      isNotEmpty,
    );
  });
}
