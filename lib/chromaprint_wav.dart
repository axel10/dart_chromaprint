import 'dart:typed_data';

import 'chromaprint_io_stub.dart'
    if (dart.library.io) 'chromaprint_io.dart'
    as chromaprint_io;

class ChromaprintWavFile {
  const ChromaprintWavFile({
    required this.samples,
    required this.sampleRate,
    required this.channels,
  });

  final Int16List samples;
  final int sampleRate;
  final int channels;
}

class ChromaprintWavReader {
  const ChromaprintWavReader();

  Future<ChromaprintWavFile> readFile(String path) async {
    final bytes = await chromaprint_io.readFileBytes(path);
    return parseBytes(bytes);
  }

  ChromaprintWavFile parseBytes(Uint8List bytes) {
    if (bytes.lengthInBytes < 12) {
      throw const FormatException('WAV file is too small.');
    }

    final data = ByteData.sublistView(bytes);
    if (_readAscii(bytes, 0, 4) != 'RIFF' ||
        _readAscii(bytes, 8, 4) != 'WAVE') {
      throw const FormatException('Only RIFF/WAVE files are supported.');
    }

    int? audioFormat;
    int? channels;
    int? sampleRate;
    int? bitsPerSample;
    Uint8List? sampleBytes;

    var offset = 12;
    while (offset + 8 <= bytes.lengthInBytes) {
      final chunkId = _readAscii(bytes, offset, 4);
      final chunkSize = data.getUint32(offset + 4, Endian.little);
      final chunkDataOffset = offset + 8;
      final chunkDataEnd = chunkDataOffset + chunkSize;
      if (chunkDataEnd > bytes.lengthInBytes) {
        throw const FormatException('WAV chunk extends beyond file bounds.');
      }

      if (chunkId == 'fmt ') {
        if (chunkSize < 16) {
          throw const FormatException('Invalid WAV fmt chunk.');
        }

        audioFormat = data.getUint16(chunkDataOffset, Endian.little);
        channels = data.getUint16(chunkDataOffset + 2, Endian.little);
        sampleRate = data.getUint32(chunkDataOffset + 4, Endian.little);
        bitsPerSample = data.getUint16(chunkDataOffset + 14, Endian.little);

        if (audioFormat == 0xFFFE) {
          if (chunkSize < 40) {
            throw const FormatException(
              'Invalid WAVE_FORMAT_EXTENSIBLE fmt chunk.',
            );
          }
          audioFormat = data.getUint16(chunkDataOffset + 24, Endian.little);
        }
      } else if (chunkId == 'data') {
        sampleBytes = Uint8List.sublistView(
          bytes,
          chunkDataOffset,
          chunkDataEnd,
        );
      }

      offset = chunkDataEnd + (chunkSize.isOdd ? 1 : 0);
    }

    if (audioFormat == null ||
        channels == null ||
        sampleRate == null ||
        bitsPerSample == null ||
        sampleBytes == null) {
      throw const FormatException('WAV file must contain fmt and data chunks.');
    }
    if (channels <= 0) {
      throw const FormatException('WAV channel count must be positive.');
    }

    final samples = _decodeSamples(
      sampleBytes,
      audioFormat: audioFormat,
      bitsPerSample: bitsPerSample,
      channels: channels,
    );

    return ChromaprintWavFile(
      samples: samples,
      sampleRate: sampleRate,
      channels: channels,
    );
  }

  static String _readAscii(Uint8List bytes, int offset, int length) {
    return String.fromCharCodes(bytes.sublist(offset, offset + length));
  }

  static Int16List _decodeSamples(
    Uint8List bytes, {
    required int audioFormat,
    required int bitsPerSample,
    required int channels,
  }) {
    final bytesPerSample = switch (audioFormat) {
      1 => (bitsPerSample + 7) >> 3,
      3 => bitsPerSample >> 3,
      _ => throw FormatException('Unsupported WAV audio format: $audioFormat'),
    };

    if (bytesPerSample <= 0 || bytes.lengthInBytes % bytesPerSample != 0) {
      throw const FormatException('Invalid WAV data chunk size.');
    }

    final sampleCount = bytes.lengthInBytes ~/ bytesPerSample;
    final data = ByteData.sublistView(bytes);
    final output = Int16List(sampleCount);

    switch (audioFormat) {
      case 1:
        _decodePcmSamples(data, output, bitsPerSample);
      case 3:
        _decodeFloatSamples(data, output, bitsPerSample);
      default:
        throw FormatException('Unsupported WAV audio format: $audioFormat');
    }

    if (output.length % channels != 0) {
      throw const FormatException(
        'WAV sample count is not divisible by channel count.',
      );
    }

    return output;
  }

  static void _decodePcmSamples(
    ByteData data,
    Int16List output,
    int bitsPerSample,
  ) {
    switch (bitsPerSample) {
      case 8:
        for (var i = 0; i < output.length; i++) {
          output[i] = ((data.getUint8(i) - 128) << 8).clamp(-32768, 32767);
        }
      case 16:
        for (var i = 0; i < output.length; i++) {
          output[i] = data.getInt16(i * 2, Endian.little);
        }
      case 24:
        for (var i = 0; i < output.length; i++) {
          final offset = i * 3;
          var value =
              data.getUint8(offset) |
              (data.getUint8(offset + 1) << 8) |
              (data.getUint8(offset + 2) << 16);
          if ((value & 0x800000) != 0) {
            value |= ~0xFFFFFF;
          }
          output[i] = (value >> 8).clamp(-32768, 32767);
        }
      case 32:
        for (var i = 0; i < output.length; i++) {
          output[i] = (data.getInt32(i * 4, Endian.little) >> 16).clamp(
            -32768,
            32767,
          );
        }
      default:
        throw FormatException('Unsupported PCM bit depth: $bitsPerSample');
    }
  }

  static void _decodeFloatSamples(
    ByteData data,
    Int16List output,
    int bitsPerSample,
  ) {
    switch (bitsPerSample) {
      case 32:
        for (var i = 0; i < output.length; i++) {
          output[i] = _floatToInt16(data.getFloat32(i * 4, Endian.little));
        }
      case 64:
        for (var i = 0; i < output.length; i++) {
          output[i] = _floatToInt16(data.getFloat64(i * 8, Endian.little));
        }
      default:
        throw FormatException(
          'Unsupported float WAV bit depth: $bitsPerSample',
        );
    }
  }

  static int _floatToInt16(double value) {
    return (value.clamp(-1.0, 1.0) * 32767.0).round().clamp(-32768, 32767);
  }
}
