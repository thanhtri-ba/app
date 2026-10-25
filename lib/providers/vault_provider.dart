import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/vault_crypto.dart';

class VaultItem {
  final String id;
  final String name;
  final bool video;
  final int width;
  final int height;
  final int addedMs;
  final int bytes;

  /// true  -> stored as `<id>.enc` (AES-256-GCM).  false -> legacy plain file `<id>`.
  final bool enc;
  const VaultItem({
    required this.id,
    required this.name,
    required this.video,
    required this.width,
    required this.height,
    required this.addedMs,
    required this.bytes,
    this.enc = false,
  });

  VaultItem asEncrypted() => VaultItem(
        id: id,
        name: name,
        video: video,
        width: width,
        height: height,
        addedMs: addedMs,
        bytes: bytes,
        enc: true,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'video': video,
        'w': width,
        'h': height,
        'added': addedMs,
        'bytes': bytes,
        'enc': enc,
      };

  factory VaultItem.fromJson(Map<String, dynamic> j) => VaultItem(
        id: j['id'] as String,
        name: j['name'] as String,
        video: j['video'] as bool? ?? false,
        width: j['w'] as int? ?? 0,
        height: j['h'] as int? ?? 0,
        addedMs: j['added'] as int? ?? 0,
        bytes: j['bytes'] as int? ?? 0,
        enc: j['enc'] as bool? ?? false,
      );
}

/// Private vault: photos are moved out of the system library into this app's private
/// storage, encrypted with AES-256-GCM (key in Keychain / Keystore) and protected by a PIN
/// and optional biometrics.
///
/// Honest limits: biometrics only gate the UI (the key is not bound to the fingerprint);
/// the PIN is a local lock, not a recovery mechanism; uninstalling the app or moving to a new
/// phone loses the vault (restore items to the library first).
class VaultProvider extends ChangeNotifier {
  List<VaultItem> items = [];
  bool loaded = false;
  bool _hasPin = false;
  bool bioEnabled = false;
  bool migrating = false;

  /// True while the vault is moving files (add / restore) so it must not auto-lock.
  bool busy = false;
  int _failed = 0;
  int _lockedUntilMs = 0;
  Directory? _dir;
  Uint8List? _key;
  final Map<String, Uint8List> _thumbs = {};
  final LocalAuthentication _auth = LocalAuthentication();

  static const MethodChannel _secure = MethodChannel('photo_cleaner/secure');

  /// Blocks screenshots / screen recording on Android while the vault is on screen.
  static Future<void> setSecure(bool on) async {
    try {
      await _secure.invokeMethod<void>('setSecure', on);
    } catch (_) {} // iOS or an old native shell: nothing to do
  }

  bool get hasPin => _hasPin;

  Duration get lockRemaining {
    final ms = _lockedUntilMs - DateTime.now().millisecondsSinceEpoch;
    return ms > 0 ? Duration(milliseconds: ms) : Duration.zero;
  }

  Future<Directory> _vaultDir() async {
    final d = _dir;
    if (d != null) return d;
    final base = await getApplicationDocumentsDirectory();
    final v = Directory('${base.path}/vault');
    if (!await v.exists()) await v.create(recursive: true);
    return _dir = v;
  }

  Future<Uint8List> _k() async => _key ??= await VaultCrypto.loadOrCreateKey();

  Future<File> fileFor(VaultItem it) async =>
      File('${(await _vaultDir()).path}/${it.id}${it.enc ? '.enc' : ''}');

  Future<File> _thumbFile(String id) async => File('${(await _vaultDir()).path}/$id.thm');

  Future<Directory> _viewDir() async {
    final t = await getTemporaryDirectory();
    final d = Directory('${t.path}/vault_view');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  /// Decrypted copy in the temp folder (call [clearTemp] when done viewing).
  Future<File> openPlain(VaultItem it) async {
    final stored = await fileFor(it);
    if (!it.enc) return stored;
    final safe = it.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final out = File('${(await _viewDir()).path}/${it.id}_$safe');
    await VaultCrypto.decryptFile(stored.path, out.path, await _k());
    return out;
  }

  Future<void> clearTemp() async {
    try {
      final t = await getTemporaryDirectory();
      final d = Directory('${t.path}/vault_view');
      if (await d.exists()) await d.delete(recursive: true);
    } catch (_) {}
  }

  /// Decrypted thumbnail bytes (cached in memory only).
  Future<Uint8List?> thumbFor(VaultItem it) async {
    final c = _thumbs[it.id];
    if (c != null) return c;
    try {
      final f = await _thumbFile(it.id);
      if (!await f.exists()) return null;
      final plain = await VaultCrypto.decryptBytes(await f.readAsBytes(), await _k());
      _thumbs[it.id] = plain;
      return plain;
    } catch (e) {
      debugPrint('vault thumb failed: $e');
      return null;
    }
  }

  Future<void> _writeThumb(String id, Uint8List jpg) async {
    final f = await _thumbFile(id);
    await f.writeAsBytes(await VaultCrypto.encryptBytes(jpg, await _k()), flush: true);
    _thumbs[id] = jpg;
  }

  Future<void> _removeFiles(VaultItem it) async {
    for (final f in [await fileFor(it), await _thumbFile(it.id)]) {
      try {
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    _thumbs.remove(it.id);
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _hasPin = p.getString('vaultPinHash') != null;
    bioEnabled = p.getBool('vaultBio') ?? false;
    _failed = p.getInt('vaultFailed') ?? 0;
    _lockedUntilMs = p.getInt('vaultLockedUntil') ?? 0;
    final raw = p.getString('vaultItems');
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        items = [for (final e in list) VaultItem.fromJson(e as Map<String, dynamic>)];
      } catch (_) {
        items = [];
      }
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> _saveItems() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('vaultItems', jsonEncode([for (final i in items) i.toJson()]));
  }

  // ---- PIN ----
  static String _hash(String pin, String salt) {
    List<int> bytes = utf8.encode('$salt:$pin');
    for (var i = 0; i < 20000; i++) {
      bytes = sha256.convert(bytes).bytes;
    }
    return base64Url.encode(bytes);
  }

  Future<void> setPin(String pin) async {
    final rnd = Random.secure();
    final salt = base64Url.encode(List<int>.generate(16, (_) => rnd.nextInt(256)));
    final p = await SharedPreferences.getInstance();
    await p.setString('vaultPinSalt', salt);
    await p.setString('vaultPinHash', _hash(pin, salt));
    await p.setInt('vaultFailed', 0);
    await p.setInt('vaultLockedUntil', 0);
    _hasPin = true;
    _failed = 0;
    _lockedUntilMs = 0;
    notifyListeners();
  }

  /// Returns true when the PIN is right. After 5 wrong tries the vault locks for 30 s.
  Future<bool> checkPin(String pin) async {
    if (lockRemaining > Duration.zero) return false;
    final p = await SharedPreferences.getInstance();
    final salt = p.getString('vaultPinSalt');
    final hash = p.getString('vaultPinHash');
    if (salt == null || hash == null) return false;
    final ok = _hash(pin, salt) == hash;
    if (ok) {
      _failed = 0;
      await p.setInt('vaultFailed', 0);
    } else {
      _failed++;
      await p.setInt('vaultFailed', _failed);
      if (_failed >= 5) {
        _failed = 0;
        _lockedUntilMs = DateTime.now().millisecondsSinceEpoch + 30000;
        await p.setInt('vaultFailed', 0);
        await p.setInt('vaultLockedUntil', _lockedUntilMs);
      }
    }
    notifyListeners();
    return ok;
  }

  // ---- biometrics ----
  Future<bool> bioAvailable() async {
    try {
      return await _auth.isDeviceSupported() && (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate(String reason) async {
    busy = true; // the system prompt briefly pauses the app: don't auto-lock meanwhile
    try {
      return await _auth.authenticate(localizedReason: reason, biometricOnly: true);
    } catch (e) {
      debugPrint('biometric auth failed: $e');
      return false;
    } finally {
      busy = false;
    }
  }

  /// Turning it on requires one successful biometric check, so we know it works.
  Future<bool> setBio(bool on, String reason) async {
    if (on && !(await bioAvailable() && await authenticate(reason))) return false;
    final p = await SharedPreferences.getInstance();
    await p.setBool('vaultBio', on);
    bioEnabled = on;
    notifyListeners();
    return true;
  }

  // ---- items ----
  /// Encrypts the originals straight into the vault (no plaintext copy is written). Returns
  /// the assets that were stored successfully; the caller then asks the system to delete them
  /// from the library.
  Future<List<AssetEntity>> copyIn(List<AssetEntity> assets) async {
    final dir = await _vaultDir();
    final key = await _k();
    final tmp = (await getTemporaryDirectory()).path;
    final done = <AssetEntity>[];
    for (final a in assets) {
      File? dst;
      try {
        final src = await a.originFile;
        if (src == null) continue;
        final id = '${DateTime.now().microsecondsSinceEpoch}_${done.length}';
        dst = File('${dir.path}/$id.enc');
        final srcLen = await src.length();
        await VaultCrypto.encryptFile(src.path, dst.path, key);
        if (await dst.length() != VaultCrypto.expectedLength(srcLen)) {
          await dst.delete();
          continue;
        }
        // The plugin may hand out a cached plaintext copy: don't leave it behind.
        if (src.path.startsWith(tmp)) {
          try {
            await src.delete();
          } catch (_) {}
        }
        try {
          final td = await a.thumbnailDataWithSize(ThumbnailSize(400, 400));
          if (td != null) await _writeThumb(id, td);
        } catch (_) {} // thumbnail is optional
        final title = await a.titleAsync;
        items.add(VaultItem(
          id: id,
          name: title.isEmpty ? 'IMG_$id.jpg' : title,
          video: a.type == AssetType.video,
          width: a.width,
          height: a.height,
          addedMs: DateTime.now().millisecondsSinceEpoch,
          bytes: srcLen,
          enc: true,
        ));
        done.add(a);
      } catch (e) {
        debugPrint('vault copy failed: $e');
        try {
          if (dst != null && await dst.exists()) await dst.delete();
        } catch (_) {}
      }
    }
    try {
      await PhotoManager.clearFileCache();
    } catch (_) {}
    await _saveItems();
    notifyListeners();
    return done;
  }

  /// Encrypts items that were stored in plain form by the first version of the vault.
  Future<int> migrateLegacy() async {
    final legacy = items.where((e) => !e.enc).toList();
    if (legacy.isEmpty || migrating) return 0;
    migrating = true;
    busy = true;
    notifyListeners();
    final dir = await _vaultDir();
    final key = await _k();
    var n = 0;
    for (final it in legacy) {
      try {
        final plain = File('${dir.path}/${it.id}');
        if (!await plain.exists()) continue;
        final dst = File('${dir.path}/${it.id}.enc');
        final len = await plain.length();
        await VaultCrypto.encryptFile(plain.path, dst.path, key);
        if (await dst.length() != VaultCrypto.expectedLength(len)) {
          await dst.delete();
          continue;
        }
        if (!it.video) {
          final jpg = await compute(_thumbFromFile, plain.path);
          if (jpg != null) await _writeThumb(it.id, jpg);
        }
        await plain.delete();
        final i = items.indexWhere((e) => e.id == it.id);
        if (i >= 0) items[i] = it.asEncrypted();
        n++;
      } catch (e) {
        debugPrint('vault migrate failed: $e');
      }
    }
    await _saveItems();
    migrating = false;
    busy = false;
    notifyListeners();
    return n;
  }

  /// Undo of [copyIn] for assets the user chose not to delete from the library.
  Future<void> discardCopies(int count) async {
    final drop = items.length >= count ? items.sublist(items.length - count) : List<VaultItem>.of(items);
    for (final it in drop) {
      await _removeFiles(it);
      items.remove(it);
    }
    await _saveItems();
    notifyListeners();
  }

  /// Puts items back in the photo library, then removes them from the vault.
  Future<int> restore(List<VaultItem> list) async {
    busy = true;
    var n = 0;
    for (final it in list) {
      try {
        final f = await openPlain(it);
        if (!await f.exists()) continue;
        final AssetEntity? saved;
        if (it.video) {
          saved = await PhotoManager.editor.saveVideo(f, title: it.name);
        } else {
          final Uint8List bytes = await f.readAsBytes();
          saved = await PhotoManager.editor.saveImage(bytes, filename: it.name, title: it.name);
        }
        if (saved != null) {
          await _removeFiles(it);
          items.removeWhere((e) => e.id == it.id);
          n++;
        }
      } catch (e) {
        debugPrint('vault restore failed: $e');
      }
    }
    await clearTemp();
    await _saveItems();
    busy = false;
    notifyListeners();
    return n;
  }

  Future<void> deleteForever(List<VaultItem> list) async {
    for (final it in list) {
      await _removeFiles(it);
      items.removeWhere((e) => e.id == it.id);
    }
    await _saveItems();
    notifyListeners();
  }
}

/// Runs in an isolate: small JPEG thumbnail for a legacy photo.
Uint8List? _thumbFromFile(String path) {
  try {
    final im = img.decodeImage(File(path).readAsBytesSync());
    if (im == null) return null;
    final r = img.copyResize(im, width: im.width >= im.height ? 400 : null, height: im.height > im.width ? 400 : null);
    return Uint8List.fromList(img.encodeJpg(r, quality: 75));
  } catch (_) {
    return null;
  }
}
