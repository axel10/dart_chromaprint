import 'dart:convert';
import 'dart:typed_data';

const int chromaprintAlgorithmIdTest2 = 1;
const int _chromaprintNormalBits = 3;
const int _chromaprintMaxNormalValue = (1 << _chromaprintNormalBits) - 1;

String encodeFingerprintWords(
  List<int> fingerprint, {
  int algorithmId = chromaprintAlgorithmIdTest2,
}) {
  final compressed = compressFingerprintWords(
    fingerprint,
    algorithmId: algorithmId,
  );
  return base64UrlEncode(compressed).replaceAll('=', '');
}

Uint8List compressFingerprintWords(
  List<int> fingerprint, {
  int algorithmId = chromaprintAlgorithmIdTest2,
}) {
  final normalValues = <int>[];
  final exceptionalValues = <int>[];
  var lastSubfingerprint = 0;

  for (final currentSubfingerprint in fingerprint) {
    final delta = currentSubfingerprint ^ lastSubfingerprint;
    lastSubfingerprint = currentSubfingerprint;

    for (final (normalValue, exceptionalValue) in _compressSubfingerprint(
      delta,
    )) {
      normalValues.add(normalValue);
      if (exceptionalValue != null) {
        exceptionalValues.add(exceptionalValue);
      }
    }
  }

  final output = BytesBuilder(copy: false)
    ..addByte(algorithmId & 0xFF)
    ..addByte((fingerprint.length >> 16) & 0xFF)
    ..addByte((fingerprint.length >> 8) & 0xFF)
    ..addByte(fingerprint.length & 0xFF)
    ..add(_packIntNArray(normalValues, 3))
    ..add(_packIntNArray(exceptionalValues, 5));

  return output.takeBytes();
}

Iterable<(int, int?)> _compressSubfingerprint(int subfingerprint) sync* {
  var lastBitIndex = 0;

  for (var bitIndex = 0; bitIndex < 32; bitIndex++) {
    if (((subfingerprint >> bitIndex) & 1) == 0) {
      continue;
    }

    final value = (bitIndex + 1) - lastBitIndex;
    if (value >= _chromaprintMaxNormalValue) {
      yield (_chromaprintMaxNormalValue, value - _chromaprintMaxNormalValue);
    } else {
      yield (value, null);
    }

    lastBitIndex = bitIndex + 1;
  }

  yield (0, null);
}

Uint8List _packIntNArray(List<int> values, int bitWidth) {
  if (values.isEmpty) {
    return Uint8List(0);
  }

  final mask = (1 << bitWidth) - 1;
  final output = Uint8List((values.length * bitWidth + 7) >> 3);

  for (var index = 0; index < values.length; index++) {
    final bits = values[index] & mask;
    final rightmostBitIndex = index * bitWidth;
    final leftmostBitIndex = rightmostBitIndex + bitWidth - 1;
    final rightByte = rightmostBitIndex >> 3;
    final leftByte = leftmostBitIndex >> 3;
    final bitOffset = rightmostBitIndex & 7;

    output[rightByte] |= (bits << bitOffset) & 0xFF;
    if (leftByte != rightByte) {
      output[leftByte] |= (bits >> ((8 - bitOffset) & 7)) & 0xFF;
    }
  }

  return output;
}
