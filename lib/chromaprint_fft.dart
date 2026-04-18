import 'dart:math';
import 'dart:typed_data';

import 'package:fftea/fftea.dart';

const int chromaprintSampleRate = 11025;
const int chromaprintFrameSize = 4096;
const int chromaprintFrameOverlap =
    chromaprintFrameSize - chromaprintFrameSize ~/ 3;
const int chromaprintFrameStride =
    chromaprintFrameSize - chromaprintFrameOverlap;
const int chromaprintSpectrumBins = chromaprintFrameSize ~/ 2 + 1;

class ChromaprintFft {
  ChromaprintFft({
    this.frameSize = chromaprintFrameSize,
    this.frameOverlap = chromaprintFrameOverlap,
  }) : frameStride = frameSize - frameOverlap,
       _fft = FFT(frameSize),
       _window = _makeHammingWindow(frameSize) {
    if (frameOverlap >= frameSize) {
      throw ArgumentError.value(
        frameOverlap,
        'frameOverlap',
        'frameOverlap must be smaller than frameSize.',
      );
    }
    _fftBuffer = Float64x2List(frameSize);
    _fftBufferData = Float64List.view(_fftBuffer.buffer);
  }

  final int frameSize;
  final int frameOverlap;
  final int frameStride;
  final FFT _fft;
  final Float64List _window;
  late final Float64x2List _fftBuffer;
  late final Float64List _fftBufferData;

  int get spectrumBins => frameSize ~/ 2 + 1;

  Float64List transformFlattened(List<double> monoSamples) {
    final frameCount = countFrames(monoSamples.length);
    final output = Float64List(frameCount * spectrumBins);
    var writeOffset = 0;

    for (
      var frameStart = 0;
      frameStart + frameSize <= monoSamples.length;
      frameStart += frameStride
    ) {
      for (var i = 0; i < frameSize; i++) {
        final bufferOffset = i << 1;
        _fftBufferData[bufferOffset] = monoSamples[frameStart + i] * _window[i];
        _fftBufferData[bufferOffset + 1] = 0.0;
      }

      _fft.inPlaceFft(_fftBuffer);
      for (var i = 0; i < frameSize ~/ 2; i++) {
        final value = _fftBuffer[i];
        output[writeOffset++] = value.x * value.x + value.y * value.y;
      }

      // Match rusty-chromaprint's current FFT stage exactly. The Nyquist bin is
      // allocated but never written, so it remains zero.
      output[writeOffset++] = 0.0;
    }

    return output;
  }

  int countFrames(int sampleCount) {
    if (sampleCount < frameSize) {
      return 0;
    }
    return 1 + (sampleCount - frameSize) ~/ frameStride;
  }

  static Float64List _makeHammingWindow(int size) {
    final window = Float64List(size);
    if (size == 1) {
      window[0] = 1.0;
      return window;
    }

    for (var i = 0; i < size; i++) {
      window[i] = 0.54 - 0.46 * cos(2.0 * pi * i / (size - 1.0));
    }
    return window;
  }
}
