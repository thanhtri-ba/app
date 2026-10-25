import 'package:flutter_test/flutter_test.dart';
import 'package:photo_cleaner/scanner/video_view.dart';

class _V {
  final int bytes;
  final int sec;
  final DateTime d;
  const _V(this.bytes, this.sec, this.d);
}

void main() {
  final items = [
    _V(50 << 20, 30, DateTime(2026, 1, 1)),
    _V(900 << 20, 10, DateTime(2026, 3, 1)),
    _V(300 << 20, 600, DateTime(2026, 2, 1)),
  ];
  List<_V> run(int min, VideoSort s) => viewVideos<_V>(items,
      bytes: (v) => v.bytes, seconds: (v) => v.sec, date: (v) => v.d, minBytes: min, sort: s);

  test('sorts by size desc', () {
    expect(run(0, VideoSort.size).map((v) => v.bytes >> 20), [900, 300, 50]);
  });
  test('sorts by duration desc', () {
    expect(run(0, VideoSort.duration).map((v) => v.sec), [600, 30, 10]);
  });
  test('sorts by date desc', () {
    expect(run(0, VideoSort.date).first.d, DateTime(2026, 3, 1));
  });
  test('filters by min size', () {
    expect(run(100 << 20, VideoSort.size).length, 2);
    expect(run(500 << 20, VideoSort.size).length, 1);
    expect(run(2000 << 20, VideoSort.size), isEmpty);
  });
  test('worthKeeping needs >=10% saving', () {
    expect(worthKeeping(100, 89), isTrue);
    expect(worthKeeping(100, 90), isFalse);
    expect(worthKeeping(100, 120), isFalse);
    expect(worthKeeping(0, 10), isFalse);
    expect(worthKeeping(100, 0), isFalse);
  });
}
