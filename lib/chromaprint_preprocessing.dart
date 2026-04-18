import 'dart:typed_data';
import 'dart:math' as math;

import 'package:fftea/resample.dart' as fftea_resample;

import 'chromaprint_fft.dart';

const int chromaprintMinSampleRate = 1000;
const int _chromaprintMaxBufferSize = 1024 * 32;
const int _chromaprintRubatoSincLength = 16;
const int _chromaprintRubatoOversamplingFactor = 128;
const double _chromaprintRubatoCutoff = 0.8;

class ChromaprintPreprocessor {
  const ChromaprintPreprocessor({
    this.targetSampleRate = chromaprintSampleRate,
  });

  final int targetSampleRate;

  Float64List processInt16Pcm({
    required Int16List samples,
    required int sampleRate,
    required int channels,
  }) {
    if (channels <= 0) {
      throw ArgumentError.value(
        channels,
        'channels',
        'At least one channel is required.',
      );
    }
    if (sampleRate <= chromaprintMinSampleRate) {
      throw ArgumentError.value(
        sampleRate,
        'sampleRate',
        'Sample rate must be greater than $chromaprintMinSampleRate.',
      );
    }
    if (samples.length % channels != 0) {
      throw ArgumentError.value(
        samples.length,
        'samples.length',
        'Interleaved PCM length must be divisible by channel count.',
      );
    }

    final mono = _mixToMono(samples, channels);
    if (sampleRate == targetSampleRate) {
      return mono;
    }

    if (sampleRate > targetSampleRate && sampleRate % targetSampleRate == 0) {
      return _downsampleIntegerFactorSinc(mono, sampleRate ~/ targetSampleRate);
    }

    return fftea_resample.resampleByRate(
      mono,
      sampleRate.toDouble(),
      targetSampleRate.toDouble(),
    );
  }

  Float64List processFloatPcm({
    required List<double> samples,
    required int sampleRate,
    required int channels,
  }) {
    final int16Samples = Int16List(samples.length);
    for (var i = 0; i < samples.length; i++) {
      int16Samples[i] = (samples[i] * 32767.0).round().clamp(-32768, 32767);
    }
    return processInt16Pcm(
      samples: int16Samples,
      sampleRate: sampleRate,
      channels: channels,
    );
  }

  static Int16List decodeLittleEndianPcm(Uint8List bytes) {
    if (bytes.lengthInBytes.isOdd) {
      throw ArgumentError.value(
        bytes.lengthInBytes,
        'bytes.lengthInBytes',
        'PCM byte length must be divisible by 2.',
      );
    }

    final sampleCount = bytes.lengthInBytes ~/ 2;
    final output = Int16List(sampleCount);
    final data = ByteData.sublistView(bytes);
    for (var i = 0; i < sampleCount; i++) {
      output[i] = data.getInt16(i * 2, Endian.little);
    }
    return output;
  }

  static Float64List _mixToMono(Int16List samples, int channels) {
    final frameCount = samples.length ~/ channels;
    final output = Float64List(frameCount);

    if (channels == 1) {
      for (var i = 0; i < samples.length; i++) {
        output[i] = samples[i] / 32767.0;
      }
      return output;
    }

    for (var frame = 0; frame < frameCount; frame++) {
      var sum = 0;
      final offset = frame * channels;
      for (var channel = 0; channel < channels; channel++) {
        sum += samples[offset + channel];
      }
      output[frame] = (sum ~/ channels) / 32767.0;
    }

    return output;
  }

  static Float64List _downsampleIntegerFactorSinc(
    Float64List input,
    int factor,
  ) {
    final kernel = _makeRubatoNearestKernel(
      sincLength: _chromaprintRubatoSincLength,
      oversamplingFactor: _chromaprintRubatoOversamplingFactor,
      cutoff: _chromaprintRubatoCutoff / factor,
    );

    var index = -(_chromaprintRubatoSincLength / 2).toDouble();
    final preserved = Float64List(_chromaprintRubatoSincLength * 2);
    final output = <double>[];
    var inputOffset = 0;

    while (inputOffset < input.length) {
      final chunkSize = math.min(
        _chromaprintMaxBufferSize,
        input.length - inputOffset,
      );
      final buffer = Float64List(chunkSize + _chromaprintRubatoSincLength * 2);
      buffer.setRange(0, preserved.length, preserved);
      buffer.setRange(
        preserved.length,
        preserved.length + chunkSize,
        input,
        inputOffset,
      );

      final endIndex = chunkSize - (_chromaprintRubatoSincLength + 1) - factor;
      while (index < endIndex) {
        index += factor;
        final start = index.toInt() + preserved.length;
        var sum = 0.0;
        for (var i = 0; i < kernel.length; i++) {
          sum += buffer[start + i] * kernel[i];
        }
        output.add(sum);
      }

      index -= chunkSize;
      preserved.setRange(0, preserved.length, buffer, chunkSize);
      inputOffset += chunkSize;
    }

    return Float64List.fromList(output);
  }

  static Float64List _makeRubatoNearestKernel({
    required int sincLength,
    required int oversamplingFactor,
    required double cutoff,
  }) {
    final totalPoints = sincLength * oversamplingFactor;
    final window = Float64List(totalPoints);
    final values = Float64List(totalPoints);
    final pi2 = 2.0 * math.pi;
    final pi4 = 4.0 * math.pi;
    var sum = 0.0;

    for (var x = 0; x < totalPoints; x++) {
      final xFloat = x.toDouble();
      window[x] =
          0.42 -
          0.5 * math.cos(pi2 * xFloat / totalPoints) +
          0.08 * math.cos(pi4 * xFloat / totalPoints);
      final sincInput =
          (xFloat - totalPoints / 2.0) * cutoff / oversamplingFactor;
      final sincValue = sincInput == 0.0
          ? 1.0
          : math.sin(math.pi * sincInput) / (math.pi * sincInput);
      final value = window[x] * sincValue;
      values[x] = value;
      sum += value;
    }

    sum /= oversamplingFactor;
    final kernel = Float64List(sincLength);
    for (var p = 0; p < sincLength; p++) {
      kernel[p] = values[oversamplingFactor * p + oversamplingFactor - 1] / sum;
    }
    return kernel;
  }
}
