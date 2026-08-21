// Whitens the studio backdrop behind the product photographs.
//
// The product shots are JPEGs taken on a light grey sweep, so each card draws
// a visible grey rectangle behind the product even though the card itself is
// pure white.
//
// The obvious fix — flood fill the backdrop to transparent — does not work
// here. Most of these products are white bottles on a #EFEFEF sweep, roughly
// 28 units apart in RGB, which is closer than the shading within a single
// bottle. Any tolerance wide enough to clear the sweep also eats the product,
// and the result is a bottle with holes in it.
//
// So this does not cut anything out. It performs the two steps a photographer
// would:
//
//   1. A levels white point, taken just below the darkest part of the sweep,
//      so the whole backdrop clips to pure white. The product keeps its form,
//      because what defines its silhouette is the darker shading at its edges,
//      well below the white point.
//   2. A flood fill from the border that snaps the remaining near-white
//      fringe — the vignette and the outer edge of the drop shadow — to exactly
//      255. Since this paints white rather than punching a hole, a fill that
//      leaks into a white bottle does no damage: it is painting white onto
//      white.
//
// The product's own drop shadow survives, softened. That is deliberate — it
// grounds the product on the card instead of leaving it floating.
//
// Output is PNG, because JPEG's ringing around the product's edges would put
// faint grey speckles back into the flat white this exists to create.
//
// Run with:
//   dart run tool/strip_product_backgrounds.dart

import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Percentile of border brightness used as the levels white point. Not the
/// median: the sweep is vignetted, and a median would leave the darker corners
/// short of pure white.
const double _whitePointPercentile = 0.02;

/// Pulled a little further down so the darkest corner clips too.
const int _whitePointMargin = 4;

/// How far from pure white a pixel may be and still be swept up by the
/// border fill in step 2.
const double _fringeTolerance = 26;

/// Longest edge of the written PNG. The cards draw these at 114 logical
/// pixels, so the 1024px originals are far larger than anything needs.
const int _maxEdge = 512;

const List<String> _directories = ['assets/products', 'assets/categories'];

void main(List<String> args) {
  var converted = 0;

  for (final directory in _directories) {
    final dir = Directory(directory);
    if (!dir.existsSync()) {
      stderr.writeln('skipped $directory (not found)');
      continue;
    }

    final jpegs =
        dir
            .listSync()
            .whereType<File>()
            .where((file) => file.path.toLowerCase().endsWith('.jpg'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    for (final file in jpegs) {
      final decoded = img.decodeImage(file.readAsBytesSync());
      if (decoded == null) {
        stderr.writeln('!! could not decode ${file.path}');
        continue;
      }

      final image = decoded.convert(numChannels: 3);
      final whitePoint = _whitePoint(image);
      _applyWhitePoint(image, whitePoint);
      _clearFringe(image);

      final scaled = _fit(image, _maxEdge);
      final target = file.path.replaceAll(RegExp(r'\.jpg$'), '.png');
      File(target).writeAsBytesSync(img.encodePng(scaled));
      file.deleteSync();

      converted++;
      stdout.writeln(
        '${file.path} ${decoded.width}x${decoded.height} '
        'white point $whitePoint -> $target ${scaled.width}x${scaled.height}',
      );
    }
  }

  stdout.writeln('$converted image(s) converted');
}

/// Brightness at [_whitePointPercentile] of the border, which is all backdrop.
int _whitePoint(img.Image image) {
  final samples = <int>[];

  void sample(int x, int y) {
    final pixel = image.getPixel(x, y);
    samples.add(math.max(pixel.r, math.max(pixel.g, pixel.b)).toInt());
  }

  for (var x = 0; x < image.width; x++) {
    sample(x, 0);
    sample(x, image.height - 1);
  }
  for (var y = 0; y < image.height; y++) {
    sample(0, y);
    sample(image.width - 1, y);
  }

  samples.sort();
  final at = samples[(samples.length * _whitePointPercentile).floor()];
  // Never darker than mid grey, however odd the source: below that the gain
  // would start washing the product out along with the backdrop.
  return (at - _whitePointMargin).clamp(128, 255);
}

/// Scales every channel so that [whitePoint] and everything above it clips to
/// 255, leaving the black point where it is.
void _applyWhitePoint(img.Image image, int whitePoint) {
  final gain = 255 / whitePoint;
  // 256 entries, so the per-pixel work is three lookups rather than three
  // multiplications and three clamps.
  final table = List<int>.generate(
    256,
    (value) => (value * gain).round().clamp(0, 255),
  );

  for (final pixel in image) {
    pixel.setRgb(
      table[pixel.r.toInt()],
      table[pixel.g.toInt()],
      table[pixel.b.toInt()],
    );
  }
}

/// Floods inward from the border, snapping near-white pixels to exactly white.
///
/// This mops up the vignette and the outer edge of the drop shadow, which the
/// white point alone leaves a shade under 255.
void _clearFringe(img.Image image) {
  final width = image.width;
  final height = image.height;
  final seen = List<bool>.filled(width * height, false);
  final queue = Queue<int>();

  void consider(int x, int y) {
    if (x < 0 || y < 0 || x >= width || y >= height) return;
    final index = y * width + x;
    if (seen[index]) return;
    seen[index] = true;
    queue.add(index);
  }

  for (var x = 0; x < width; x++) {
    consider(x, 0);
    consider(x, height - 1);
  }
  for (var y = 0; y < height; y++) {
    consider(0, y);
    consider(width - 1, y);
  }

  while (queue.isNotEmpty) {
    final index = queue.removeFirst();
    final x = index % width;
    final y = index ~/ width;
    final pixel = image.getPixel(x, y);

    final dr = 255 - pixel.r;
    final dg = 255 - pixel.g;
    final db = 255 - pixel.b;
    if (math.sqrt(dr * dr + dg * dg + db * db) > _fringeTolerance) {
      continue;
    }

    pixel.setRgb(255, 255, 255);
    consider(x - 1, y);
    consider(x + 1, y);
    consider(x, y - 1);
    consider(x, y + 1);
  }
}

img.Image _fit(img.Image image, int maxEdge) {
  final longest = math.max(image.width, image.height);
  if (longest <= maxEdge) return image;
  return image.width >= image.height
      ? img.copyResize(image, width: maxEdge)
      : img.copyResize(image, height: maxEdge);
}
