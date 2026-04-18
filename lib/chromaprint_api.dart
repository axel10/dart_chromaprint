import 'dart:io';
import 'dart:typed_data';

import 'chromaprint_encoding.dart';
import 'chromaprint_features.dart';
import 'chromaprint_fft.dart';
import 'chromaprint_fingerprint.dart';
import 'chromaprint_preprocessing.dart';
import 'chromaprint_wav.dart';

class ChromaprintPipeline {
  ChromaprintPipeline({
    this.wavReader = const ChromaprintWavReader(),
    this.preprocessor = const ChromaprintPreprocessor(),
    ChromaprintFft? fft,
    ChromaprintChroma? chroma,
    ChromaprintChromaFilter? chromaFilter,
    ChromaprintChromaNormalizer? normalizer,
    ChromaprintFingerprintCalculator? fingerprintCalculator,
  }) : fft = fft ?? ChromaprintFft(),
       chroma = chroma ?? ChromaprintChroma(),
       chromaFilter = chromaFilter ?? ChromaprintChromaFilter(),
       normalizer = normalizer ?? const ChromaprintChromaNormalizer(),
       fingerprintCalculator =
           fingerprintCalculator ?? ChromaprintFingerprintCalculator();

  final ChromaprintWavReader wavReader;
  final ChromaprintPreprocessor preprocessor;
  final ChromaprintFft fft;
  final ChromaprintChroma chroma;
  final ChromaprintChromaFilter chromaFilter;
  final ChromaprintChromaNormalizer normalizer;
  final ChromaprintFingerprintCalculator fingerprintCalculator;

  Uint32List fingerprintWordsFromProcessedPcm(List<double> monoSamples) {
    final spectrum = fft.transformFlattened(monoSamples);
    final chromaValues = chroma.transformFlattened(spectrum);
    final filtered = chromaFilter.transformFlattened(chromaValues);
    final normalized = normalizer.transformFlattened(filtered);
    return fingerprintCalculator.transformFlattened(normalized);
  }

  Uint32List fingerprintWordsFromInt16Pcm({
    required Int16List samples,
    required int sampleRate,
    required int channels,
  }) {
    final processed = preprocessor.processInt16Pcm(
      samples: samples,
      sampleRate: sampleRate,
      channels: channels,
    );
    return fingerprintWordsFromProcessedPcm(processed);
  }

  String fingerprintStringFromProcessedPcm(
    List<double> monoSamples, {
    int algorithmId = chromaprintAlgorithmIdTest2,
  }) {
    final words = fingerprintWordsFromProcessedPcm(monoSamples);
    return encodeFingerprintWords(words, algorithmId: algorithmId);
  }

  String fingerprintStringFromInt16Pcm({
    required Int16List samples,
    required int sampleRate,
    required int channels,
    int algorithmId = chromaprintAlgorithmIdTest2,
  }) {
    final words = fingerprintWordsFromInt16Pcm(
      samples: samples,
      sampleRate: sampleRate,
      channels: channels,
    );
    return encodeFingerprintWords(words, algorithmId: algorithmId);
  }

  Uint32List fingerprintWordsFromWavBytes(Uint8List bytes) {
    final wav = wavReader.parseBytes(bytes);
    return fingerprintWordsFromInt16Pcm(
      samples: wav.samples,
      sampleRate: wav.sampleRate,
      channels: wav.channels,
    );
  }

  Future<Uint32List> fingerprintWordsFromWavFile(String path) async {
    final bytes = await File(path).readAsBytes();
    return fingerprintWordsFromWavBytes(bytes);
  }

  String fingerprintStringFromWavBytes(
    Uint8List bytes, {
    int algorithmId = chromaprintAlgorithmIdTest2,
  }) {
    final words = fingerprintWordsFromWavBytes(bytes);
    return encodeFingerprintWords(words, algorithmId: algorithmId);
  }

  Future<String> fingerprintStringFromWavFile(
    String path, {
    int algorithmId = chromaprintAlgorithmIdTest2,
  }) async {
    final bytes = await File(path).readAsBytes();
    return fingerprintStringFromWavBytes(bytes, algorithmId: algorithmId);
  }
}

Uint32List fingerprintWordsFromProcessedPcm(
  List<double> monoSamples, {
  ChromaprintFft? fft,
  ChromaprintChroma? chroma,
  ChromaprintChromaFilter? chromaFilter,
  ChromaprintChromaNormalizer? normalizer,
  ChromaprintFingerprintCalculator? fingerprintCalculator,
}) {
  final pipeline = ChromaprintPipeline(
    fft: fft,
    chroma: chroma,
    chromaFilter: chromaFilter,
    normalizer: normalizer,
    fingerprintCalculator: fingerprintCalculator,
  );
  return pipeline.fingerprintWordsFromProcessedPcm(monoSamples);
}

Uint32List fingerprintWordsFromInt16Pcm({
  required Int16List samples,
  required int sampleRate,
  required int channels,
  ChromaprintPreprocessor preprocessor = const ChromaprintPreprocessor(),
  ChromaprintFft? fft,
  ChromaprintChroma? chroma,
  ChromaprintChromaFilter? chromaFilter,
  ChromaprintChromaNormalizer? normalizer,
  ChromaprintFingerprintCalculator? fingerprintCalculator,
}) {
  final pipeline = ChromaprintPipeline(
    preprocessor: preprocessor,
    fft: fft,
    chroma: chroma,
    chromaFilter: chromaFilter,
    normalizer: normalizer,
    fingerprintCalculator: fingerprintCalculator,
  );
  return pipeline.fingerprintWordsFromInt16Pcm(
    samples: samples,
    sampleRate: sampleRate,
    channels: channels,
  );
}

String fingerprintStringFromProcessedPcm(
  List<double> monoSamples, {
  ChromaprintFft? fft,
  ChromaprintChroma? chroma,
  ChromaprintChromaFilter? chromaFilter,
  ChromaprintChromaNormalizer? normalizer,
  ChromaprintFingerprintCalculator? fingerprintCalculator,
  int algorithmId = chromaprintAlgorithmIdTest2,
}) {
  final pipeline = ChromaprintPipeline(
    fft: fft,
    chroma: chroma,
    chromaFilter: chromaFilter,
    normalizer: normalizer,
    fingerprintCalculator: fingerprintCalculator,
  );
  return pipeline.fingerprintStringFromProcessedPcm(
    monoSamples,
    algorithmId: algorithmId,
  );
}

String fingerprintStringFromInt16Pcm({
  required Int16List samples,
  required int sampleRate,
  required int channels,
  ChromaprintPreprocessor preprocessor = const ChromaprintPreprocessor(),
  ChromaprintFft? fft,
  ChromaprintChroma? chroma,
  ChromaprintChromaFilter? chromaFilter,
  ChromaprintChromaNormalizer? normalizer,
  ChromaprintFingerprintCalculator? fingerprintCalculator,
  int algorithmId = chromaprintAlgorithmIdTest2,
}) {
  final pipeline = ChromaprintPipeline(
    preprocessor: preprocessor,
    fft: fft,
    chroma: chroma,
    chromaFilter: chromaFilter,
    normalizer: normalizer,
    fingerprintCalculator: fingerprintCalculator,
  );
  return pipeline.fingerprintStringFromInt16Pcm(
    samples: samples,
    sampleRate: sampleRate,
    channels: channels,
    algorithmId: algorithmId,
  );
}

Uint32List fingerprintWordsFromWavBytes(
  Uint8List bytes, {
  ChromaprintWavReader wavReader = const ChromaprintWavReader(),
  ChromaprintPreprocessor preprocessor = const ChromaprintPreprocessor(),
  ChromaprintFft? fft,
  ChromaprintChroma? chroma,
  ChromaprintChromaFilter? chromaFilter,
  ChromaprintChromaNormalizer? normalizer,
  ChromaprintFingerprintCalculator? fingerprintCalculator,
}) {
  final pipeline = ChromaprintPipeline(
    wavReader: wavReader,
    preprocessor: preprocessor,
    fft: fft,
    chroma: chroma,
    chromaFilter: chromaFilter,
    normalizer: normalizer,
    fingerprintCalculator: fingerprintCalculator,
  );
  return pipeline.fingerprintWordsFromWavBytes(bytes);
}

Future<Uint32List> fingerprintWordsFromWavFile(
  String path, {
  ChromaprintWavReader wavReader = const ChromaprintWavReader(),
  ChromaprintPreprocessor preprocessor = const ChromaprintPreprocessor(),
  ChromaprintFft? fft,
  ChromaprintChroma? chroma,
  ChromaprintChromaFilter? chromaFilter,
  ChromaprintChromaNormalizer? normalizer,
  ChromaprintFingerprintCalculator? fingerprintCalculator,
}) async {
  final pipeline = ChromaprintPipeline(
    wavReader: wavReader,
    preprocessor: preprocessor,
    fft: fft,
    chroma: chroma,
    chromaFilter: chromaFilter,
    normalizer: normalizer,
    fingerprintCalculator: fingerprintCalculator,
  );
  return pipeline.fingerprintWordsFromWavFile(path);
}

String fingerprintStringFromWavBytes(
  Uint8List bytes, {
  ChromaprintWavReader wavReader = const ChromaprintWavReader(),
  ChromaprintPreprocessor preprocessor = const ChromaprintPreprocessor(),
  ChromaprintFft? fft,
  ChromaprintChroma? chroma,
  ChromaprintChromaFilter? chromaFilter,
  ChromaprintChromaNormalizer? normalizer,
  ChromaprintFingerprintCalculator? fingerprintCalculator,
  int algorithmId = chromaprintAlgorithmIdTest2,
}) {
  final pipeline = ChromaprintPipeline(
    wavReader: wavReader,
    preprocessor: preprocessor,
    fft: fft,
    chroma: chroma,
    chromaFilter: chromaFilter,
    normalizer: normalizer,
    fingerprintCalculator: fingerprintCalculator,
  );
  return pipeline.fingerprintStringFromWavBytes(
    bytes,
    algorithmId: algorithmId,
  );
}

Future<String> fingerprintStringFromWavFile(
  String path, {
  ChromaprintWavReader wavReader = const ChromaprintWavReader(),
  ChromaprintPreprocessor preprocessor = const ChromaprintPreprocessor(),
  ChromaprintFft? fft,
  ChromaprintChroma? chroma,
  ChromaprintChromaFilter? chromaFilter,
  ChromaprintChromaNormalizer? normalizer,
  ChromaprintFingerprintCalculator? fingerprintCalculator,
  int algorithmId = chromaprintAlgorithmIdTest2,
}) async {
  final pipeline = ChromaprintPipeline(
    wavReader: wavReader,
    preprocessor: preprocessor,
    fft: fft,
    chroma: chroma,
    chromaFilter: chromaFilter,
    normalizer: normalizer,
    fingerprintCalculator: fingerprintCalculator,
  );
  return pipeline.fingerprintStringFromWavFile(path, algorithmId: algorithmId);
}
