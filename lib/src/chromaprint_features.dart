import 'dart:math';
import 'dart:typed_data';

import 'chromaprint_fft.dart';

const int chromaprintNumBands = 12;
const int chromaprintMinFrequency = 28;
const int chromaprintMaxFrequency = 3520;
const List<double> chromaprintFilterCoefficients = [
  0.25,
  0.75,
  1.0,
  0.75,
  0.25,
];

class ChromaprintChroma {
  ChromaprintChroma({
    this.minFrequency = chromaprintMinFrequency,
    this.maxFrequency = chromaprintMaxFrequency,
    this.frameSize = chromaprintFrameSize,
    this.sampleRate = chromaprintSampleRate,
    this.interpolate = false,
  }) : spectrumBins = frameSize ~/ 2 + 1,
       minIndex = _freqToIndex(
         minFrequency,
         frameSize,
         sampleRate,
       ).clamp(1, frameSize ~/ 2),
       maxIndex = _freqToIndex(
         maxFrequency,
         frameSize,
         sampleRate,
       ).clamp(0, frameSize ~/ 2),
       _notes = Uint8List(frameSize),
       _notesFrac = Float64List(frameSize) {
    for (var i = minIndex; i < maxIndex; i++) {
      final freq = _indexToFreq(i, frameSize, sampleRate);
      final octave = _freqToOctave(freq);
      final note = chromaprintNumBands * (octave - octave.floorToDouble());
      _notes[i] = note.floor();
      _notesFrac[i] = note - note.floorToDouble();
    }
  }

  final int minFrequency;
  final int maxFrequency;
  final int frameSize;
  final int sampleRate;
  final bool interpolate;
  final int spectrumBins;
  final int minIndex;
  final int maxIndex;
  final Uint8List _notes;
  final Float64List _notesFrac;

  Float64List transformFlattened(Float64List flattenedSpectrum) {
    if (flattenedSpectrum.length % spectrumBins != 0) {
      throw ArgumentError.value(
        flattenedSpectrum.length,
        'flattenedSpectrum',
        'Spectrum length must be divisible by $spectrumBins.',
      );
    }

    final frameCount = flattenedSpectrum.length ~/ spectrumBins;
    final output = Float64List(frameCount * chromaprintNumBands);

    for (var frame = 0; frame < frameCount; frame++) {
      final spectrumOffset = frame * spectrumBins;
      final chromaOffset = frame * chromaprintNumBands;

      for (var i = minIndex; i < maxIndex; i++) {
        final energy = flattenedSpectrum[spectrumOffset + i];
        final note = _notes[i];
        if (interpolate) {
          var note2 = note;
          var a = 1.0;
          if (_notesFrac[i] < 0.5) {
            note2 = (note + chromaprintNumBands - 1) % chromaprintNumBands;
            a = 0.5 + _notesFrac[i];
          }
          if (_notesFrac[i] > 0.5) {
            note2 = (note + 1) % chromaprintNumBands;
            a = 1.5 - _notesFrac[i];
          }
          output[chromaOffset + note] += energy * a;
          output[chromaOffset + note2] += energy * (1.0 - a);
        } else {
          output[chromaOffset + note] += energy;
        }
      }
    }

    return output;
  }

  static int _freqToIndex(int frequency, int frameSize, int sampleRate) =>
      (frameSize * frequency / sampleRate).round();

  static double _indexToFreq(int index, int frameSize, int sampleRate) =>
      index * sampleRate / frameSize;

  static double _freqToOctave(double frequency) {
    const base = 440.0 / 16.0;
    return log(frequency / base) / ln2;
  }
}

class ChromaprintChromaFilter {
  ChromaprintChromaFilter({
    List<double> coefficients = chromaprintFilterCoefficients,
  }) : coefficients = Float64List.fromList(coefficients) {
    if (this.coefficients.isEmpty) {
      throw ArgumentError.value(
        coefficients,
        'coefficients',
        'At least one coefficient is required.',
      );
    }
    if (this.coefficients.length > 8) {
      throw ArgumentError.value(
        coefficients,
        'coefficients',
        'At most 8 coefficients are supported.',
      );
    }
  }

  final Float64List coefficients;

  Float64List transformFlattened(Float64List flattenedChroma) {
    if (flattenedChroma.length % chromaprintNumBands != 0) {
      throw ArgumentError.value(
        flattenedChroma.length,
        'flattenedChroma',
        'Chroma length must be divisible by $chromaprintNumBands.',
      );
    }

    final frameCount = flattenedChroma.length ~/ chromaprintNumBands;
    if (frameCount < coefficients.length) {
      return Float64List(0);
    }

    final outputFrames = frameCount - coefficients.length + 1;
    final output = Float64List(outputFrames * chromaprintNumBands);
    final buffer = List<Float64List>.generate(
      8,
      (_) => Float64List(chromaprintNumBands),
    );
    final result = Float64List(chromaprintNumBands);
    var bufferOffset = 0;
    var bufferSize = 1;
    var writeOffset = 0;

    for (var frame = 0; frame < frameCount; frame++) {
      final inputOffset = frame * chromaprintNumBands;
      buffer[bufferOffset].setRange(
        0,
        chromaprintNumBands,
        flattenedChroma,
        inputOffset,
      );
      bufferOffset = (bufferOffset + 1) % buffer.length;

      if (bufferSize >= coefficients.length) {
        final offset =
            (bufferOffset + buffer.length - coefficients.length) %
            buffer.length;
        result.fillRange(0, result.length, 0.0);
        for (var band = 0; band < chromaprintNumBands; band++) {
          for (var j = 0; j < coefficients.length; j++) {
            result[band] +=
                buffer[(offset + j) % buffer.length][band] * coefficients[j];
          }
        }
        output.setRange(writeOffset, writeOffset + chromaprintNumBands, result);
        writeOffset += chromaprintNumBands;
      } else {
        bufferSize += 1;
      }
    }

    return output;
  }
}

class ChromaprintChromaNormalizer {
  const ChromaprintChromaNormalizer({this.epsilon = 0.01});

  final double epsilon;

  Float64List transformFlattened(Float64List flattenedChroma) {
    if (flattenedChroma.length % chromaprintNumBands != 0) {
      throw ArgumentError.value(
        flattenedChroma.length,
        'flattenedChroma',
        'Chroma length must be divisible by $chromaprintNumBands.',
      );
    }

    final output = Float64List.fromList(flattenedChroma);
    for (
      var offset = 0;
      offset < output.length;
      offset += chromaprintNumBands
    ) {
      var norm = 0.0;
      for (var band = 0; band < chromaprintNumBands; band++) {
        final value = output[offset + band];
        norm += value * value;
      }
      norm = sqrt(norm);
      if (norm < epsilon) {
        for (var band = 0; band < chromaprintNumBands; band++) {
          output[offset + band] = 0.0;
        }
      } else {
        for (var band = 0; band < chromaprintNumBands; band++) {
          output[offset + band] /= norm;
        }
      }
    }
    return output;
  }
}
