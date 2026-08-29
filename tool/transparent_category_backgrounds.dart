// Removes the flat backdrop from category bundle PNGs.
//
// The Shop by categories artwork is drawn on tinted pills and cards. If the
// PNG itself carries a white rectangle, that rectangle fights the card colour.
// This first clears near-white pixels connected to the image border, then
// clears the remaining near-white, low-saturation islands left between product
// packshots. Those islands are what show up as little white boxes on tinted
// category cards.
//
// Run with:
//   dart run tool/transparent_category_backgrounds.dart

import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const String _directory = 'assets/categories';
const int _minChannel = 238;
const int _maxSpread = 22;
const double _distanceFromWhite = 36;
const int _islandMinChannel = 228;
const int _islandMaxSpread = 30;
const double _islandDistanceFromWhite = 58;

void main() {
  final dir = Directory(_directory);
  if (!dir.existsSync()) {
    stderr.writeln('skipped $_directory (not found)');
    return;
  }

  final files =
      dir
          .listSync()
          .whereType<File>()
          .where((file) => file.path.toLowerCase().endsWith('.png'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  var changed = 0;
  for (final file in files) {
    final decoded = img.decodePng(file.readAsBytesSync());
    if (decoded == null) {
      stderr.writeln('!! could not decode ${file.path}');
      continue;
    }

    final image = decoded.convert(numChannels: 4);
    final cleared = _clearBorderBackdrop(image) + _clearBackdropIslands(image);
    if (cleared == 0) {
      stdout.writeln('${file.path}: no backdrop cleared');
      continue;
    }

    file.writeAsBytesSync(img.encodePng(image));
    changed++;
    stdout.writeln('${file.path}: cleared $cleared px');
  }

  stdout.writeln('$changed image(s) updated');
}

int _clearBorderBackdrop(img.Image image) {
  final width = image.width;
  final height = image.height;
  final seen = List<bool>.filled(width * height, false);
  final queue = Queue<int>();
  var cleared = 0;

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

    if (!_isBackdrop(pixel)) {
      continue;
    }

    pixel.a = 0;
    cleared++;
    consider(x - 1, y);
    consider(x + 1, y);
    consider(x, y - 1);
    consider(x, y + 1);
  }

  return cleared;
}

bool _isBackdrop(img.Pixel pixel) {
  if (pixel.a == 0) {
    return true;
  }

  final r = pixel.r.toInt();
  final g = pixel.g.toInt();
  final b = pixel.b.toInt();
  final minChannel = math.min(r, math.min(g, b));
  final maxChannel = math.max(r, math.max(g, b));
  final dr = 255 - r;
  final dg = 255 - g;
  final db = 255 - b;

  return minChannel >= _minChannel &&
      maxChannel - minChannel <= _maxSpread &&
      math.sqrt(dr * dr + dg * dg + db * db) <= _distanceFromWhite;
}

int _clearBackdropIslands(img.Image image) {
  var cleared = 0;
  for (final pixel in image) {
    if (pixel.a != 0 && _isBackdropIsland(pixel)) {
      pixel.a = 0;
      cleared++;
    }
  }
  return cleared;
}

bool _isBackdropIsland(img.Pixel pixel) {
  final r = pixel.r.toInt();
  final g = pixel.g.toInt();
  final b = pixel.b.toInt();
  final minChannel = math.min(r, math.min(g, b));
  final maxChannel = math.max(r, math.max(g, b));
  final dr = 255 - r;
  final dg = 255 - g;
  final db = 255 - b;

  return minChannel >= _islandMinChannel &&
      maxChannel - minChannel <= _islandMaxSpread &&
      math.sqrt(dr * dr + dg * dg + db * db) <= _islandDistanceFromWhite;
}
