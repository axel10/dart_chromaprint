import 'dart:typed_data';

Future<Uint8List> readFileBytes(String path) {
  throw UnsupportedError(
    'File-based Chromaprint APIs are only supported on platforms with dart:io.',
  );
}
