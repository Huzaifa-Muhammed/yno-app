// Prepares the launcher/store icon sources from the client's logo.
//
// The supplied file (`assets/yno_logo.jpeg`) is a 626x626 JPEG: a navy YNO
// monogram sitting on a white field with a wide, uneven margin. Three things
// make it unusable as a launcher icon as-is, and this script fixes all three so
// the result is reproducible rather than hand-edited in an image editor:
//
//  1. **No alpha.** An adaptive icon's foreground layer must be transparent —
//     a JPEG's white field would fill the whole masked shape, so the mark could
//     never sit on a coloured background.
//  2. **JPEG artefacts.** A flat two-colour mark compressed as JPEG has noise
//     around every edge, which becomes visible ringing once it is scaled. The
//     mark is re-matted from luminance instead: white becomes fully
//     transparent, the mark becomes flat navy, and the anti-aliased edge is
//     carried as alpha. That also means it upscales cleanly.
//  3. **Wrong padding for the adaptive safe zone.** Android masks the
//     foreground to roughly the inner two thirds of the canvas, so a mark that
//     fills the frame loses its outer edges to a circular mask. The source
//     margin is trimmed away first so the padding is set here deliberately,
//     not inherited from however the logo happened to be exported.
//
// Run with: dart run tool/make_icons.dart
import 'dart:io';

import 'package:image/image.dart';

/// Anything at or above this luminance counts as the white field.
const _whiteCutoff = 244;

/// Fraction of the canvas the mark spans in each output.
///
/// ⚠️ The adaptive figure is NOT the final on-screen size, which is the easy
/// mistake here. flutter_launcher_icons wraps the foreground in an
/// `<inset android:inset="16%">`, so the drawable only ever occupies 68% of the
/// 108dp canvas — and Android then shows just the inner 72dp of that. Sizing
/// this by eye against the safe zone therefore under-shoots twice over and the
/// mark ends up marooned in the middle of the mask.
///
/// Working backwards instead: 0.68 x 0.68 inset = 0.46 of the canvas, which is
/// ~69% of the 72dp visible circle. That is the range Android's own icons sit
/// in. The mark's bounding corners land inside the circular mask with room to
/// spare, and its actual corners are empty anyway.
const _legacySpan = 0.78;
const _adaptiveSpan = 0.68;

void main() {
  final src = decodeJpg(File('assets/yno_logo.jpeg').readAsBytesSync());
  if (src == null) {
    stderr.writeln('Could not decode assets/yno_logo.jpeg');
    exit(1);
  }

  final mark = _matteMark(src);
  stdout.writeln('Trimmed mark: ${mark.width}x${mark.height}');

  _write('assets/icon/yno_icon.png',
      _compose(mark, 1024, _legacySpan, ColorRgba8(255, 255, 255, 255)));
  _write('assets/icon/yno_icon_fg.png',
      _compose(mark, 1024, _adaptiveSpan, ColorRgba8(0, 0, 0, 0)));
  _write('assets/icon/yno_store_512.png',
      _compose(mark, 512, _legacySpan, ColorRgba8(255, 255, 255, 255)));
}

/// Crops the white margin away and re-mattes the mark onto transparency.
///
/// Alpha comes from how far each pixel is from white, so the anti-aliased edge
/// survives as a soft alpha ramp instead of a hard cut; the colour is forced to
/// the mark's own navy, which is what removes the compression noise.
Image _matteMark(Image src) {
  var minX = src.width, minY = src.height, maxX = -1, maxY = -1;
  var rSum = 0, gSum = 0, bSum = 0, count = 0;

  for (var y = 0; y < src.height; y++) {
    for (var x = 0; x < src.width; x++) {
      final p = src.getPixel(x, y);
      if (_luma(p.r, p.g, p.b) >= _whiteCutoff) continue;
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
      // Average only the solid core, so edge pixels do not wash the colour out.
      if (_luma(p.r, p.g, p.b) < 140) {
        rSum += p.r.toInt();
        gSum += p.g.toInt();
        bSum += p.b.toInt();
        count++;
      }
    }
  }
  if (maxX < 0 || count == 0) {
    stderr.writeln('The logo appears to be blank.');
    exit(1);
  }

  final navyR = rSum ~/ count, navyG = gSum ~/ count, navyB = bSum ~/ count;
  final navyLuma = _luma(navyR, navyG, navyB);
  stdout.writeln('Mark colour: #'
      '${navyR.toRadixString(16).padLeft(2, '0')}'
      '${navyG.toRadixString(16).padLeft(2, '0')}'
      '${navyB.toRadixString(16).padLeft(2, '0')}');

  final w = maxX - minX + 1, h = maxY - minY + 1;
  final out = Image(width: w, height: h, numChannels: 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = src.getPixel(minX + x, minY + y);
      final l = _luma(p.r, p.g, p.b);
      // 255 at the mark's own luminance, 0 at white, ramped in between.
      final a = l >= _whiteCutoff
          ? 0
          : l <= navyLuma
              ? 255
              : (255 * (_whiteCutoff - l) / (_whiteCutoff - navyLuma)).round();
      out.setPixelRgba(x, y, navyR, navyG, navyB, a.clamp(0, 255));
    }
  }
  return out;
}

/// Centres [mark] on a [size] square, spanning [span] of it, over [background].
Image _compose(Image mark, int size, double span, Color background) {
  final target = (size * span).round();
  final scale = target / (mark.width > mark.height ? mark.width : mark.height);
  final resized = copyResize(mark,
      width: (mark.width * scale).round(),
      height: (mark.height * scale).round(),
      interpolation: Interpolation.cubic);

  final canvas = Image(width: size, height: size, numChannels: 4);
  fill(canvas, color: background);
  compositeImage(canvas, resized,
      dstX: (size - resized.width) ~/ 2, dstY: (size - resized.height) ~/ 2);
  return canvas;
}

num _luma(num r, num g, num b) => 0.299 * r + 0.587 * g + 0.114 * b;

void _write(String path, Image image) {
  File(path).writeAsBytesSync(encodePng(image));
  stdout.writeln('wrote $path (${image.width}x${image.height})');
}
