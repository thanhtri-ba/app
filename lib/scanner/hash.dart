import 'dart:typed_data';
import 'dart:ui' as ui;

/// Number of set bits in a 64-bit value.
int popcount64(int x) {
  var c = 0;
  while (x != 0) {
    x &= x - 1;
    c++;
  }
  return c;
}

/// Hamming distance between two 64-bit hashes.
int hamming(int a, int b) => popcount64(a ^ b);

class ImageSig {
  final int hash;
  final double sharp;
  const ImageSig(this.hash, this.sharp);
}

Future<Uint8List?> _gray(Uint8List bytes, int w, int h) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: w, targetHeight: h);
    final frame = await codec.getNextFrame();
    final img = frame.image;
    final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    img.dispose();
    codec.dispose();
    if (data == null) return null;
    final px = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    if (px.length < w * h * 4) return null;
    final out = Uint8List(w * h);
    for (var i = 0; i < w * h; i++) {
      final o = i * 4;
      out[i] = (px[o] * 299 + px[o + 1] * 587 + px[o + 2] * 114) ~/ 1000;
    }
    return out;
  } catch (_) {
    return null;
  }
}

/// 64-bit difference hash from a 9x8 grayscale version of the image.
int dHashFromGray(Uint8List g) {
  var hash = 0;
  for (var y = 0; y < 8; y++) {
    for (var x = 0; x < 8; x++) {
      final bit = g[y * 9 + x] > g[y * 9 + x + 1] ? 1 : 0;
      hash = (hash << 1) | bit;
    }
  }
  return hash;
}

/// Variance of the Laplacian over a size x size grayscale image (higher = sharper).
double laplacianVariance(Uint8List g, int size) {
  var sum = 0.0;
  var sumSq = 0.0;
  var n = 0;
  for (var y = 1; y < size - 1; y++) {
    for (var x = 1; x < size - 1; x++) {
      final c = g[y * size + x];
      final l = 4 * c -
          g[(y - 1) * size + x] -
          g[(y + 1) * size + x] -
          g[y * size + x - 1] -
          g[y * size + x + 1];
      sum += l;
      sumSq += l * l;
      n++;
    }
  }
  if (n == 0) return 0;
  final mean = sum / n;
  return sumSq / n - mean * mean;
}

Future<ImageSig?> signatureOf(Uint8List jpeg) async {
  final small = await _gray(jpeg, 9, 8);
  final mid = await _gray(jpeg, 96, 96);
  if (small == null || mid == null) return null;
  return ImageSig(dHashFromGray(small), laplacianVariance(mid, 96));
}
