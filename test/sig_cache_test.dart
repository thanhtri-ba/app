import 'package:flutter_test/flutter_test.dart';
import 'package:photo_cleaner/scanner/hash.dart';
import 'package:photo_cleaner/scanner/sig_cache.dart';

void main() {
  test('get returns the entry only for the same modified time', () {
    final c = SigCache()..put('a', 100, const ImageSig(42, 12.5, 0.3));
    expect(c.get('a', 100)?.hash, 42);
    expect(c.get('a', 101), isNull); // edited photo -> re-analyse
    expect(c.get('b', 100), isNull);
  });

  test('serialize / parse round trip keeps 64-bit hashes and doubles exactly', () {
    final c = SigCache()
      ..put('1', 5, const ImageSig(-1234567890123456789, 153.123456789, 0.61))
      ..put('IOS/L0/001', 7, const ImageSig(0x7FFFFFFFFFFFFFFF, 0.0, 1.0));
    final d = SigCache()..parse(c.serialize());
    expect(d.length, 2);
    final a = d.get('1', 5)!;
    expect(a.hash, -1234567890123456789);
    expect(a.sharp, 153.123456789);
    expect(a.bright, 0.61);
    expect(d.get('IOS/L0/001', 7)!.hash, 0x7FFFFFFFFFFFFFFF);
  });

  test('wrong header or corrupt lines are ignored', () {
    final bad = SigCache()..parse('OLDFORMAT\n1\t2\t3\t4\t5\n');
    expect(bad.length, 0);
    final partial = SigCache()
      ..parse('${SigCache.header}\nok\t1\t2\t3.5\t0.5\ngarbage\nx\ty\tz\t1\t2\n\n');
    expect(partial.length, 1);
    expect(partial.get('ok', 1)?.sharp, 3.5);
  });

  test('prune removes assets that no longer exist', () {
    final c = SigCache()
      ..put('a', 1, const ImageSig(1, 1, 0))
      ..put('b', 1, const ImageSig(2, 1, 0));
    c.prune({'a'});
    expect(c.length, 1);
    expect(c.get('a', 1), isNotNull);
    expect(c.get('b', 1), isNull);
  });
}
