import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// AES-256-GCM, chunked, used by the private vault.
///
/// File layout:  "PCV1" (4) | random prefix (8) | { ciphertext(<=1 MiB) | tag(16) } ...
///  * Every chunk has its own nonce = prefix || big-endian chunk index.
///  * The chunk index and a "last chunk" flag are authenticated as AAD, so chunks cannot be
///    reordered, dropped or the file silently truncated.
///  * Chunking keeps memory flat for large videos and runs in a background isolate.
class VaultCrypto {
  VaultCrypto._();

  static const int chunk = 1 << 20;
  static const int macLen = 16;
  static const int headerLen = 12;
  static const List<int> _magic = [0x50, 0x43, 0x56, 0x31]; // "PCV1"
  static const String _keyName = 'vault_key_v1';

  // resetOnError:false -> if the keystore hiccups we fail loudly instead of silently
  // wiping the key (which would make every vault file unreadable forever).
  static final FlutterSecureStorage _storage =
      FlutterSecureStorage(aOptions: AndroidOptions(resetOnError: false));

  /// 32-byte random key kept in the Keychain / Android Keystore-backed storage.
  static Future<Uint8List> loadOrCreateKey() async {
    final existing = await _storage.read(key: _keyName);
    if (existing != null) return base64Decode(existing);
    final key = _random(32);
    await _storage.write(key: _keyName, value: base64Encode(key));
    return key;
  }

  /// Size of the encrypted file for a plaintext of [plainLen] bytes.
  static int expectedLength(int plainLen) {
    final chunks = plainLen == 0 ? 1 : (plainLen + chunk - 1) ~/ chunk;
    return headerLen + plainLen + chunks * macLen;
  }

  // ---------------------------------------------------------------- files (isolate)

  static Future<void> encryptFile(String src, String dst, Uint8List key) =>
      compute(_encryptJob, _Job(src, dst, key));

  static Future<void> decryptFile(String src, String dst, Uint8List key) =>
      compute(_decryptJob, _Job(src, dst, key));

  // ---------------------------------------------------------------- bytes (small data)

  static Future<Uint8List> encryptBytes(Uint8List data, Uint8List key) async {
    final algo = AesGcm.with256bits();
    final sk = SecretKey(key);
    final prefix = _random(8);
    final out = BytesBuilder(copy: false)
      ..add(_magic)
      ..add(prefix);
    var offset = 0;
    var index = 0;
    while (true) {
      final n = min(chunk, data.length - offset);
      final last = offset + n >= data.length;
      final box = await algo.encrypt(
        Uint8List.sublistView(data, offset, offset + n),
        secretKey: sk,
        nonce: _nonce(prefix, index),
        aad: _aad(index, last),
      );
      out
        ..add(box.cipherText)
        ..add(box.mac.bytes);
      offset += n;
      index++;
      if (last) break;
    }
    return out.takeBytes();
  }

  static Future<Uint8List> decryptBytes(Uint8List data, Uint8List key) async {
    if (data.length < headerLen + macLen) throw const FormatException('vault data too short');
    _checkMagic(data);
    final prefix = Uint8List.sublistView(data, 4, headerLen);
    final algo = AesGcm.with256bits();
    final sk = SecretKey(key);
    final out = BytesBuilder(copy: false);
    var offset = headerLen;
    var index = 0;
    const enc = chunk + macLen;
    while (offset < data.length) {
      final n = min(enc, data.length - offset);
      if (n < macLen) throw const FormatException('vault chunk too short');
      final last = offset + n >= data.length;
      final plain = await algo.decrypt(
        SecretBox(
          Uint8List.sublistView(data, offset, offset + n - macLen),
          nonce: _nonce(prefix, index),
          mac: Mac(Uint8List.sublistView(data, offset + n - macLen, offset + n)),
        ),
        secretKey: sk,
        aad: _aad(index, last),
      );
      out.add(plain);
      offset += n;
      index++;
    }
    return out.takeBytes();
  }

  // ---------------------------------------------------------------- helpers

  static Uint8List _random(int n) {
    final r = Random.secure();
    return Uint8List.fromList(List<int>.generate(n, (_) => r.nextInt(256)));
  }

  static Uint8List _nonce(Uint8List prefix, int index) {
    final n = Uint8List(12)..setRange(0, 8, prefix);
    ByteData.sublistView(n).setUint32(8, index);
    return n;
  }

  static Uint8List _aad(int index, bool last) {
    final a = Uint8List(5);
    ByteData.sublistView(a).setUint32(0, index);
    a[4] = last ? 1 : 0;
    return a;
  }

  static void _checkMagic(List<int> header) {
    for (var i = 0; i < 4; i++) {
      if (header[i] != _magic[i]) throw const FormatException('not a vault file');
    }
  }
}

class _Job {
  final String src;
  final String dst;
  final Uint8List key;
  const _Job(this.src, this.dst, this.key);
}

Future<void> _encryptJob(_Job j) async {
  final algo = AesGcm.with256bits();
  final sk = SecretKey(j.key);
  final prefix = VaultCrypto._random(8);
  final inp = await File(j.src).open();
  final out = await File(j.dst).open(mode: FileMode.write);
  try {
    final total = await inp.length();
    await out.writeFrom(VaultCrypto._magic);
    await out.writeFrom(prefix);
    var offset = 0;
    var index = 0;
    while (true) {
      final n = min(VaultCrypto.chunk, total - offset);
      final last = offset + n >= total;
      final data = n == 0 ? Uint8List(0) : await inp.read(n);
      if (data.length != n) throw const FileSystemException('short read while encrypting');
      final box = await algo.encrypt(
        data,
        secretKey: sk,
        nonce: VaultCrypto._nonce(prefix, index),
        aad: VaultCrypto._aad(index, last),
      );
      await out.writeFrom(box.cipherText);
      await out.writeFrom(box.mac.bytes);
      offset += n;
      index++;
      if (last) break;
    }
    await out.flush();
  } finally {
    await inp.close();
    await out.close();
  }
}

Future<void> _decryptJob(_Job j) async {
  final algo = AesGcm.with256bits();
  final sk = SecretKey(j.key);
  final inp = await File(j.src).open();
  final out = await File(j.dst).open(mode: FileMode.write);
  try {
    final total = await inp.length();
    if (total < VaultCrypto.headerLen + VaultCrypto.macLen) {
      throw const FormatException('vault file too short');
    }
    final header = await inp.read(VaultCrypto.headerLen);
    VaultCrypto._checkMagic(header);
    final prefix = Uint8List.sublistView(header, 4, VaultCrypto.headerLen);
    const enc = VaultCrypto.chunk + VaultCrypto.macLen;
    var offset = VaultCrypto.headerLen;
    var index = 0;
    while (offset < total) {
      final n = min(enc, total - offset);
      if (n < VaultCrypto.macLen) throw const FormatException('vault chunk too short');
      final last = offset + n >= total;
      final buf = await inp.read(n);
      final plain = await algo.decrypt(
        SecretBox(
          Uint8List.sublistView(buf, 0, n - VaultCrypto.macLen),
          nonce: VaultCrypto._nonce(prefix, index),
          mac: Mac(Uint8List.sublistView(buf, n - VaultCrypto.macLen)),
        ),
        secretKey: sk,
        aad: VaultCrypto._aad(index, last),
      );
      await out.writeFrom(plain);
      offset += n;
      index++;
    }
    await out.flush();
  } finally {
    await inp.close();
    await out.close();
  }
}
