import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:photo_cleaner/core/format.dart';
import 'package:photo_cleaner/scanner/analyzer.dart';
import 'package:photo_cleaner/scanner/hash.dart';

void main() {
  group('hash', () {
    test('popcount64', () {
      expect(popcount64(0), 0);
      expect(popcount64(1), 1);
      expect(popcount64(0xFF), 8);
      expect(popcount64(-1), 64);
    });

    test('hamming', () {
      expect(hamming(0, 0), 0);
      expect(hamming(0, 3), 2);
      expect(hamming(5, 5), 0);
    });

    test('dHash of constant image is zero, of a descending gradient is all ones', () {
      final flat = Uint8List(72)..fillRange(0, 72, 100);
      expect(dHashFromGray(flat), 0);
      final grad = Uint8List(72);
      for (var y = 0; y < 8; y++) {
        for (var x = 0; x < 9; x++) {
          grad[y * 9 + x] = 255 - x * 20;
        }
      }
      expect(popcount64(dHashFromGray(grad)), 64);
    });

    test('laplacian variance: flat image is 0, checkerboard is large', () {
      const n = 16;
      final flat = Uint8List(n * n)..fillRange(0, n * n, 128);
      expect(laplacianVariance(flat, n), 0);
      final cb = Uint8List(n * n);
      for (var y = 0; y < n; y++) {
        for (var x = 0; x < n; x++) {
          cb[y * n + x] = (x + y) % 2 == 0 ? 0 : 255;
        }
      }
      expect(laplacianVariance(cb, n), greaterThan(1000));
    });
  });

  group('groupSimilar', () {
    test('groups close hashes that are near in time', () {
      final g = groupSimilar([0, 3, 0x7FFFFFFFFFFFFFFF], [0, 1000, 2000], threshold: 4);
      expect(g.length, 1);
      expect(g.first, containsAll([0, 1]));
    });

    test('does not group distant-in-time photos unless almost identical', () {
      const day = 24 * 3600 * 1000;
      final far = groupSimilar([0, 7], [0, 3 * day], threshold: 8);
      expect(far, isEmpty);
      final same = groupSimilar([0, 1], [0, 3 * day], threshold: 8);
      expect(same.length, 1);
    });

    test('exact keys merge identical files', () {
      final g = groupSimilar([0, 0x7FFFFFFFFFFFFFFF], [0, 10],
          threshold: 2, exactKeys: ['a', 'a']);
      expect(g.length, 1);
    });
  });

  group('format', () {
    test('fmtBytes', () {
      expect(fmtBytes(512), '512 B');
      expect(fmtBytes(2048), '2 KB');
      expect(fmtBytes(5 * 1024 * 1024), '5.0 MB');
    });
    test('fmtCount', () {
      expect(fmtCount(999), '999');
      expect(fmtCount(3042), '3,042');
      expect(fmtCount(1234567), '1,234,567');
    });
    test('dayKey round trip', () {
      final d = DateTime(2026, 10, 5);
      expect(dayKey(d), '2026-10-05');
      expect(parseDayKey('2026-10-05'), d);
    });
  });
}
