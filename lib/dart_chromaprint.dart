import 'dart:typed_data';

import 'chromaprint_api.dart' as api;

/// Builds a Chromaprint fingerprint string from interleaved signed 16-bit PCM.
String fingerprintFromPcm({
  required Int16List pcm,
  required int sampleRate,
  required int channels,
}) {
  return api.fingerprintStringFromInt16Pcm(
    samples: pcm,
    sampleRate: sampleRate,
    channels: channels,
  );
}

/// Builds a Chromaprint fingerprint string from a WAV file path.
Future<String> fingerprintFromWavFile(String path) {
  return api.fingerprintStringFromWavFile(path);
}
