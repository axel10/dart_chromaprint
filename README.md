# dart_chromaprint

Pure Dart Chromaprint fingerprinting for PCM and WAV inputs.

## Features

- Convert interleaved signed 16-bit PCM into Chromaprint words
- Encode Chromaprint words into the compact base64 fingerprint string
- Read WAV bytes or WAV files and fingerprint them directly
- Reuse the same pipeline across multiple fingerprint calculations

## Quick Start

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_chromaprint/dart_chromaprint.dart';

final samples = Int16List.fromList(<int>[0, 1200, -1200, 0]);
final fingerprint = fingerprintStringFromInt16Pcm(
  samples: samples,
  sampleRate: 11025,
  channels: 2,
);

print(fingerprint);
```

## WAV Input

```dart
final bytes = await File('song.wav').readAsBytes();
final fingerprint = fingerprintStringFromWavBytes(bytes);
```

## Example

Run the bundled example app to see a generated stereo signal fingerprinted
from both raw PCM and WAV bytes.
