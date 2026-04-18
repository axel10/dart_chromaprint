import 'dart:io';
import 'dart:typed_data';

import 'package:dart_chromaprint/dart_chromaprint.dart';
import 'package:flutter_test/flutter_test.dart';

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
    const sampleRate = 44100;
    const channels = 2;
    const pcmPath = 'test/test_decoded.pcm';

    final pcmBytes = File(pcmPath).readAsBytesSync();
    final samples = ChromaprintPreprocessor.decodeLittleEndianPcm(
      Uint8List.sublistView(pcmBytes),
    );
    final wavBytes = _buildPcm16WavBytes(
      samples: samples,
      sampleRate: sampleRate,
      channels: channels,
    );

    final pipeline = ChromaprintPipeline();
    final facade = DartChromaprint(pipeline: pipeline);

    final wordsFromPipeline = pipeline.fingerprintWordsFromInt16Pcm(
      samples: samples,
      sampleRate: sampleRate,
      channels: channels,
    );
    final wordsFromFacade = facade.fingerprintWordsFromInt16Pcm(
      samples: samples,
      sampleRate: sampleRate,
      channels: channels,
    );
    final stringFromPcm = fingerprintStringFromInt16Pcm(
      samples: samples,
      sampleRate: sampleRate,
      channels: channels,
    );
    final stringFromWavBytes = fingerprintStringFromWavBytes(wavBytes);
    expect(wordsFromPipeline, equals(wordsFromFacade));
    expect(stringFromPcm, isNotEmpty);
    expect(stringFromWavBytes, isNotEmpty);
    expect(stringFromPcm, equals(stringFromWavBytes));

    expect(
      pipeline.fingerprintStringFromInt16Pcm(
        samples: samples,
        sampleRate: sampleRate,
        channels: channels,
      ),
      equals(stringFromPcm),
    );
  });

  test('reusing a pipeline keeps fingerprint results stable', () {
    const sampleRate = 44100;
    const channels = 2;

    final bytes = File('test/test_decoded.pcm').readAsBytesSync();
    final samples = ChromaprintPreprocessor.decodeLittleEndianPcm(
      Uint8List.sublistView(bytes),
    );
    final pipeline = ChromaprintPipeline();

    final first = pipeline.fingerprintWordsFromInt16Pcm(
      samples: samples,
      sampleRate: sampleRate,
      channels: channels,
    );
    final second = pipeline.fingerprintWordsFromInt16Pcm(
      samples: samples,
      sampleRate: sampleRate,
      channels: channels,
    );
    final baseline = fingerprintWordsFromInt16Pcm(
      samples: samples,
      sampleRate: sampleRate,
      channels: channels,
    );

    expect(first, equals(baseline));
    expect(second, equals(baseline));
  });

  test('invalid PCM input is rejected', () {
    expect(
      () => ChromaprintPreprocessor.decodeLittleEndianPcm(
        Uint8List.fromList(<int>[0x01]),
      ),
      throwsArgumentError,
    );
  });
}

Uint8List _buildPcm16WavBytes({
  required Int16List samples,
  required int sampleRate,
  required int channels,
}) {
  const bitsPerSample = 16;
  final dataBytes = ByteData(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    dataBytes.setInt16(i * 2, samples[i], Endian.little);
  }

  final bytesPerSample = bitsPerSample ~/ 8;
  final byteRate = sampleRate * channels * bytesPerSample;
  final blockAlign = channels * bytesPerSample;
  final dataSize = dataBytes.lengthInBytes;
  final fileSize = 36 + dataSize;

  final output = BytesBuilder(copy: false)
    ..add('RIFF'.codeUnits)
    ..add(_uint32le(fileSize))
    ..add('WAVE'.codeUnits)
    ..add('fmt '.codeUnits)
    ..add(_uint32le(16))
    ..add(_uint16le(1))
    ..add(_uint16le(channels))
    ..add(_uint32le(sampleRate))
    ..add(_uint32le(byteRate))
    ..add(_uint16le(blockAlign))
    ..add(_uint16le(bitsPerSample))
    ..add('data'.codeUnits)
    ..add(_uint32le(dataSize))
    ..add(dataBytes.buffer.asUint8List());

  return output.takeBytes();
}

Uint8List _uint16le(int value) {
  final data = ByteData(2)..setUint16(0, value, Endian.little);
  return data.buffer.asUint8List();
}

Uint8List _uint32le(int value) {
  final data = ByteData(4)..setUint32(0, value, Endian.little);
  return data.buffer.asUint8List();
}
