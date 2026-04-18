import 'dart:math' as math;
import 'dart:typed_data';

import 'chromaprint_features.dart';

const List<ChromaprintClassifier> chromaprintClassifiersTest2 = [
  ChromaprintClassifier(
    filter: ChromaprintFilter(ChromaprintFilterKind.filter0, 4, 3, 15),
    quantizer: ChromaprintQuantizer(1.98215, 2.35817, 2.63523),
  ),
  ChromaprintClassifier(
    filter: ChromaprintFilter(ChromaprintFilterKind.filter4, 4, 6, 15),
    quantizer: ChromaprintQuantizer(-1.03809, -0.651211, -0.282167),
  ),
  ChromaprintClassifier(
    filter: ChromaprintFilter(ChromaprintFilterKind.filter1, 0, 4, 16),
    quantizer: ChromaprintQuantizer(-0.298702, 0.119262, 0.558497),
  ),
  ChromaprintClassifier(
    filter: ChromaprintFilter(ChromaprintFilterKind.filter3, 8, 2, 12),
    quantizer: ChromaprintQuantizer(-0.105439, 0.0153946, 0.135898),
  ),
  ChromaprintClassifier(
    filter: ChromaprintFilter(ChromaprintFilterKind.filter3, 4, 4, 8),
    quantizer: ChromaprintQuantizer(-0.142891, 0.0258736, 0.200632),
  ),
  ChromaprintClassifier(
    filter: ChromaprintFilter(ChromaprintFilterKind.filter4, 0, 3, 5),
    quantizer: ChromaprintQuantizer(-0.826319, -0.590612, -0.368214),
  ),
  ChromaprintClassifier(
    filter: ChromaprintFilter(ChromaprintFilterKind.filter1, 2, 2, 9),
    quantizer: ChromaprintQuantizer(-0.557409, -0.233035, 0.0534525),
  ),
  ChromaprintClassifier(
    filter: ChromaprintFilter(ChromaprintFilterKind.filter2, 7, 3, 4),
    quantizer: ChromaprintQuantizer(-0.0646826, 0.00620476, 0.0784847),
  ),
  ChromaprintClassifier(
    filter: ChromaprintFilter(ChromaprintFilterKind.filter2, 6, 2, 16),
    quantizer: ChromaprintQuantizer(-0.192387, -0.029699, 0.215855),
  ),
  ChromaprintClassifier(
    filter: ChromaprintFilter(ChromaprintFilterKind.filter2, 1, 3, 2),
    quantizer: ChromaprintQuantizer(-0.0397818, -0.00568076, 0.0292026),
  ),
  ChromaprintClassifier(
    filter: ChromaprintFilter(ChromaprintFilterKind.filter5, 10, 1, 15),
    quantizer: ChromaprintQuantizer(-0.53823, -0.369934, -0.190235),
  ),
  ChromaprintClassifier(
    filter: ChromaprintFilter(ChromaprintFilterKind.filter3, 6, 2, 10),
    quantizer: ChromaprintQuantizer(-0.124877, 0.0296483, 0.139239),
  ),
  ChromaprintClassifier(
    filter: ChromaprintFilter(ChromaprintFilterKind.filter2, 1, 1, 14),
    quantizer: ChromaprintQuantizer(-0.101475, 0.0225617, 0.231971),
  ),
  ChromaprintClassifier(
    filter: ChromaprintFilter(ChromaprintFilterKind.filter3, 5, 6, 4),
    quantizer: ChromaprintQuantizer(-0.0799915, -0.00729616, 0.063262),
  ),
  ChromaprintClassifier(
    filter: ChromaprintFilter(ChromaprintFilterKind.filter1, 9, 2, 12),
    quantizer: ChromaprintQuantizer(-0.272556, 0.019424, 0.302559),
  ),
  ChromaprintClassifier(
    filter: ChromaprintFilter(ChromaprintFilterKind.filter3, 4, 2, 14),
    quantizer: ChromaprintQuantizer(-0.164292, -0.0321188, 0.0846339),
  ),
];

enum ChromaprintFilterKind {
  filter0,
  filter1,
  filter2,
  filter3,
  filter4,
  filter5,
}

class ChromaprintQuantizer {
  const ChromaprintQuantizer(this.t0, this.t1, this.t2);

  final double t0;
  final double t1;
  final double t2;

  int quantize(double value) {
    if (value < t1) {
      return value < t0 ? 0 : 1;
    }
    return value < t2 ? 2 : 3;
  }
}

class ChromaprintFilter {
  const ChromaprintFilter(this.kind, this.y, this.height, this.width);

  final ChromaprintFilterKind kind;
  final int y;
  final int height;
  final int width;

  double apply(ChromaprintRollingIntegralImage image, int x) {
    return switch (kind) {
      ChromaprintFilterKind.filter0 => _filter0(image, x, y, width, height),
      ChromaprintFilterKind.filter1 => _filter1(image, x, y, width, height),
      ChromaprintFilterKind.filter2 => _filter2(image, x, y, width, height),
      ChromaprintFilterKind.filter3 => _filter3(image, x, y, width, height),
      ChromaprintFilterKind.filter4 => _filter4(image, x, y, width, height),
      ChromaprintFilterKind.filter5 => _filter5(image, x, y, width, height),
    };
  }

  static double _subtractLog(double a, double b) {
    return math.log((1.0 + a) / (1.0 + b));
  }

  static double _filter0(
    ChromaprintRollingIntegralImage image,
    int x,
    int y,
    int w,
    int h,
  ) {
    final a = image.area(x, y, x + w, y + h);
    return _subtractLog(a, 0.0);
  }

  static double _filter1(
    ChromaprintRollingIntegralImage image,
    int x,
    int y,
    int w,
    int h,
  ) {
    final h2 = h ~/ 2;
    final a = image.area(x, y + h2, x + w, y + h);
    final b = image.area(x, y, x + w, y + h2);
    return _subtractLog(a, b);
  }

  static double _filter2(
    ChromaprintRollingIntegralImage image,
    int x,
    int y,
    int w,
    int h,
  ) {
    final w2 = w ~/ 2;
    final a = image.area(x + w2, y, x + w, y + h);
    final b = image.area(x, y, x + w2, y + h);
    return _subtractLog(a, b);
  }

  static double _filter3(
    ChromaprintRollingIntegralImage image,
    int x,
    int y,
    int w,
    int h,
  ) {
    final w2 = w ~/ 2;
    final h2 = h ~/ 2;
    final a =
        image.area(x, y + h2, x + w2, y + h) +
        image.area(x + w2, y, x + w, y + h2);
    final b =
        image.area(x, y, x + w2, y + h2) +
        image.area(x + w2, y + h2, x + w, y + h);
    return _subtractLog(a, b);
  }

  static double _filter4(
    ChromaprintRollingIntegralImage image,
    int x,
    int y,
    int w,
    int h,
  ) {
    final h3 = h ~/ 3;
    final a = image.area(x, y + h3, x + w, y + 2 * h3);
    final b =
        image.area(x, y, x + w, y + h3) +
        image.area(x, y + 2 * h3, x + w, y + h);
    return _subtractLog(a, b);
  }

  static double _filter5(
    ChromaprintRollingIntegralImage image,
    int x,
    int y,
    int w,
    int h,
  ) {
    final w3 = w ~/ 3;
    final a = image.area(x + w3, y, x + 2 * w3, y + h);
    final b =
        image.area(x, y, x + w3, y + h) +
        image.area(x + 2 * w3, y, x + w, y + h);
    return _subtractLog(a, b);
  }
}

class ChromaprintClassifier {
  const ChromaprintClassifier({required this.filter, required this.quantizer});

  final ChromaprintFilter filter;
  final ChromaprintQuantizer quantizer;

  int classify(ChromaprintRollingIntegralImage image, int offset) {
    return quantizer.quantize(filter.apply(image, offset));
  }
}

class ChromaprintRollingIntegralImage {
  ChromaprintRollingIntegralImage(int maxRows) : _maxRows = maxRows + 1;

  final int _maxRows;
  int _columns = 0;
  int _rows = 0;
  Float64List _data = Float64List(0);

  int get rows => _rows;

  void addRow(List<double> row) {
    addRowSlice(row, 0, row.length);
  }

  void addRowSlice(List<double> row, int start, int length) {
    _ensureColumns(length);

    var sum = 0.0;
    final rowIndex = _rowOffset(_rows);
    for (var i = 0; i < _columns; i++) {
      sum += row[start + i];
      _data[rowIndex + i] = sum;
    }

    if (_rows > 0) {
      final prevRowIndex = _rowOffset(_rows - 1);
      for (var i = 0; i < _columns; i++) {
        _data[rowIndex + i] += _data[prevRowIndex + i];
      }
    }

    _rows += 1;
  }

  void _ensureColumns(int columns) {
    if (_columns == 0) {
      _columns = columns;
      _data = Float64List(_maxRows * _columns);
    }

    if (columns != _columns) {
      throw ArgumentError.value(
        columns,
        'length',
        'Row width must stay constant.',
      );
    }
  }

  double area(int r1, int c1, int r2, int c2) {
    if (r1 == r2 || c1 == c2) {
      return 0.0;
    }

    if (r1 == 0) {
      final row2 = _rowOffset(r2 - 1);
      if (c1 == 0) {
        return _data[row2 + c2 - 1];
      }
      return _data[row2 + c2 - 1] - _data[row2 + c1 - 1];
    }

    final row1 = _rowOffset(r1 - 1);
    final row2 = _rowOffset(r2 - 1);
    if (c1 == 0) {
      return _data[row2 + c2 - 1] - _data[row1 + c2 - 1];
    }

    return _data[row2 + c2 - 1] -
        _data[row1 + c2 - 1] -
        _data[row2 + c1 - 1] +
        _data[row1 + c1 - 1];
  }

  void reset() {
    _data = Float64List(0);
    _rows = 0;
    _columns = 0;
  }

  void clearRows() {
    _rows = 0;
  }

  int _rowOffset(int row) => (row % _maxRows) * _columns;
}

class ChromaprintFingerprintCalculator {
  ChromaprintFingerprintCalculator({
    List<ChromaprintClassifier> classifiers = chromaprintClassifiersTest2,
  }) : classifiers = List.unmodifiable(classifiers),
       maxFilterWidth = classifiers
           .map((classifier) => classifier.filter.width)
           .reduce((a, b) => a > b ? a : b),
       _image = ChromaprintRollingIntegralImage(255);

  final List<ChromaprintClassifier> classifiers;
  final int maxFilterWidth;
  final ChromaprintRollingIntegralImage _image;

  Uint32List transformFlattened(Float64List flattenedChroma) {
    if (flattenedChroma.length % chromaprintNumBands != 0) {
      throw ArgumentError.value(
        flattenedChroma.length,
        'flattenedChroma',
        'Chroma length must be divisible by $chromaprintNumBands.',
      );
    }

    final frameCount = flattenedChroma.length ~/ chromaprintNumBands;
    final output = Uint32List(math.max(0, frameCount - maxFilterWidth + 1));
    _image.clearRows();
    var writeIndex = 0;
    for (
      var offset = 0;
      offset < flattenedChroma.length;
      offset += chromaprintNumBands
    ) {
      _image.addRowSlice(flattenedChroma, offset, chromaprintNumBands);
      if (_image.rows >= maxFilterWidth) {
        output[writeIndex++] = _calculateSubfingerprint(
          _image.rows - maxFilterWidth,
        );
      }
    }
    return output;
  }

  int _calculateSubfingerprint(int offset) {
    var bits = 0;
    for (final classifier in classifiers) {
      bits = (bits << 2) | _grayCode(classifier.classify(_image, offset));
    }
    return bits;
  }

  static int _grayCode(int value) => const [0, 1, 3, 2][value];
}
