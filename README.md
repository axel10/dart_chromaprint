# dart_chromaprint

Pure Dart Chromaprint fingerprinting for PCM and WAV inputs.

## Public API

This package exposes only two functions:

- `fingerprintFromPcm`
- `fingerprintFromWavFile`

## PCM

`fingerprintFromPcm` expects interleaved signed 16-bit PCM samples.

```dart
import 'dart:typed_data';

import 'package:dart_chromaprint/dart_chromaprint.dart';

final pcm = Int16List.fromList(<int>[0, 1200, -1200, 0]);
final fingerprint = fingerprintFromPcm(
  pcm: pcm,
  sampleRate: 11025,
  channels: 2,
);

print(fingerprint);
```

## WAV File

`fingerprintFromWavFile` reads a WAV file directly from its path.

```dart
import 'package:dart_chromaprint/dart_chromaprint.dart';

final fingerprint = await fingerprintFromWavFile('song.wav');
print(fingerprint);
```

## Example

Run the bundled example app to pick a PCM file or a WAV file and fingerprint
it with the matching API.
