import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:photo_cleaner/services/vault_crypto.dart';

Uint8List _data(int n) {
  final r = Random(7);
  return Uint8List.fromList(List<int>.generate(n, (_) => r.nextInt(256)));
}

void main() {
  final key = Uint8List.fromList(List<int>.generate(32, (i) => i));
  final sizes = [0, 1, 100, VaultCrypto.chunk - 1, VaultCrypto.chunk, VaultCrypto.chunk + 1, VaultCrypto.chunk * 2 + 12345];

  group('bytes', () {
    for (final n in sizes) {
      test('round trip $n bytes', () async {
        final plain = _data(n);
        final enc = await VaultCrypto.encryptBytes(plain, key);
        expect(enc.length, VaultCrypto.expectedLength(n));
        expect(await VaultCrypto.decryptBytes(enc, key), plain);
      });
    }

    test('wrong key fails', () async {
      final enc = await VaultCrypto.encryptBytes(_data(500), key);
      final bad = Uint8List.fromList(List<int>.filled(32, 9));
      expect(() => VaultCrypto.decryptBytes(enc, bad), throwsA(anything));
    });

    test('tampered ciphertext fails', () async {
      final enc = await VaultCrypto.encryptBytes(_data(500), key);
      enc[VaultCrypto.headerLen + 3] ^= 0x01;
      expect(() => VaultCrypto.decryptBytes(enc, key), throwsA(anything));
    });

    test('dropping the last chunk is detected', () async {
      final n = VaultCrypto.chunk * 2 + 10; // 3 chunks
      final enc = await VaultCrypto.encryptBytes(_data(n), key);
      final cut = enc.sublist(0, VaultCrypto.headerLen + 2 * (VaultCrypto.chunk + VaultCrypto.macLen));
      expect(() => VaultCrypto.decryptBytes(Uint8List.fromList(cut), key), throwsA(anything));
    });

    test('not a vault file', () {
      expect(() => VaultCrypto.decryptBytes(Uint8List(64), key), throwsA(anything));
    });
  });

  group('files', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('vault_test'));
    tearDown(() => dir.deleteSync(recursive: true));

    for (final n in [0, 5000, VaultCrypto.chunk + 7]) {
      test('round trip file of $n bytes', () async {
        final plain = _data(n);
        final src = File('${dir.path}/a.bin')..writeAsBytesSync(plain);
        final enc = File('${dir.path}/a.enc');
        final out = File('${dir.path}/a.out');
        await VaultCrypto.encryptFile(src.path, enc.path, key);
        expect(enc.lengthSync(), VaultCrypto.expectedLength(n));
        await VaultCrypto.decryptFile(enc.path, out.path, key);
        expect(out.readAsBytesSync(), plain);
      });
    }

    test('file and bytes formats are interchangeable', () async {
      final plain = _data(3000);
      final enc = await VaultCrypto.encryptBytes(plain, key);
      final f = File('${dir.path}/b.enc')..writeAsBytesSync(enc);
      final out = File('${dir.path}/b.out');
      await VaultCrypto.decryptFile(f.path, out.path, key);
      expect(out.readAsBytesSync(), plain);
    });
  });
}
