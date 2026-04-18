import 'dart:typed_data';

import 'chromaprint_api.dart' as api;
import 'chromaprint_encoding.dart' as encoding;

export 'chromaprint_api.dart';
export 'chromaprint_encoding.dart';
export 'chromaprint_features.dart';
export 'chromaprint_fft.dart';
export 'chromaprint_fingerprint.dart';
export 'chromaprint_preprocessing.dart';
export 'chromaprint_wav.dart';

class DartChromaprint {
  DartChromaprint({api.ChromaprintPipeline? pipeline})
    : _pipeline = pipeline ?? api.ChromaprintPipeline();

  final api.ChromaprintPipeline _pipeline;

  Uint32List fingerprintWordsFromInt16Pcm({
    required Int16List samples,
    required int sampleRate,
    required int channels,
  }) {
    return _pipeline.fingerprintWordsFromInt16Pcm(
      samples: samples,
      sampleRate: sampleRate,
      channels: channels,
    );
  }

  String fingerprintStringFromInt16Pcm({
    required Int16List samples,
    required int sampleRate,
    required int channels,
    int algorithmId = encoding.chromaprintAlgorithmIdTest2,
  }) {
    return _pipeline.fingerprintStringFromInt16Pcm(
      samples: samples,
      sampleRate: sampleRate,
      channels: channels,
      algorithmId: algorithmId,
    );
  }

  Uint32List fingerprintWordsFromWavBytes(Uint8List bytes) {
    return _pipeline.fingerprintWordsFromWavBytes(bytes);
  }

  Future<Uint32List> fingerprintWordsFromWavFile(String path) {
    return _pipeline.fingerprintWordsFromWavFile(path);
  }

  String fingerprintStringFromWavBytes(
    Uint8List bytes, {
    int algorithmId = encoding.chromaprintAlgorithmIdTest2,
  }) {
    return _pipeline.fingerprintStringFromWavBytes(
      bytes,
      algorithmId: algorithmId,
    );
  }

  Future<String> fingerprintStringFromWavFile(
    String path, {
    int algorithmId = encoding.chromaprintAlgorithmIdTest2,
  }) {
    return _pipeline.fingerprintStringFromWavFile(
      path,
      algorithmId: algorithmId,
    );
  }
}
