import 'dart:typed_data';

import 'src/chromaprint_api.dart' as api;

/// Builds a Chromaprint fingerprint string from interleaved signed 16-bit PCM.
///
/// The samples must be signed 16-bit integers arranged in channel order
/// (for example, stereo audio is laid out as left, right, left, right).
/// The [sampleRate] value is measured in Hz, and [channels] must match the
/// number of interleaved channels in [pcm].
///
/// This function processes already-loaded PCM data synchronously and returns
/// the encoded Chromaprint fingerprint string.
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

/// Builds a Chromaprint fingerprint string from a WAV file at [path].
///
/// The file is read and decoded as WAV before fingerprinting. This function
/// returns a future because file I/O is asynchronous.
///
/// On unsupported platforms, this may throw [UnsupportedError]. If the file
/// cannot be read or is not a supported WAV file, it may throw [FileSystemException]
/// or [FormatException] from the underlying reader.
Future<String> fingerprintFromWavFile(String path) {
  return api.fingerprintStringFromWavFile(path);
}
