import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'hash.dart';

class _Entry {
  final int mod;
  final ImageSig sig;
  const _Entry(this.mod, this.sig);
}

/// Persistent cache of image signatures (hash / sharpness / brightness).
///
/// Key = asset id; an entry is only valid while the asset's modified time is unchanged, so edited
/// photos are re-analysed automatically. Signatures do not depend on the user's sensitivity
/// settings (thresholds are applied afterwards), so changing settings never invalidates it.
///
/// Text format (one asset per line):  id <TAB> modified <TAB> hash <TAB> sharp <TAB> bright
class SigCache {
  /// Bump when the signature algorithm changes: older caches are then ignored.
  static const String header = 'PCSIG1';

  final Map<String, _Entry> _m = {};
  bool _dirty = false;
  bool _loaded = false;

  int get length => _m.length;
  bool get loaded => _loaded;

  ImageSig? get(String id, int mod) {
    final e = _m[id];
    if (e == null || e.mod != mod) return null;
    return e.sig;
  }

  void put(String id, int mod, ImageSig sig) {
    _m[id] = _Entry(mod, sig);
    _dirty = true;
  }

  /// Drops entries of assets that no longer exist.
  void prune(Set<String> liveIds) {
    final before = _m.length;
    _m.removeWhere((k, _) => !liveIds.contains(k));
    if (_m.length != before) _dirty = true;
  }

  String serialize() {
    final b = StringBuffer()..writeln(header);
    _m.forEach((id, e) {
      b.writeln('$id\t${e.mod}\t${e.sig.hash}\t${e.sig.sharp}\t${e.sig.bright}');
    });
    return b.toString();
  }

  /// Replaces the content with [text]. Bad lines are skipped; a wrong header means "empty".
  void parse(String text) {
    _m.clear();
    final lines = text.split('\n');
    if (lines.isEmpty || lines.first.trim() != header) return;
    for (var i = 1; i < lines.length; i++) {
      final l = lines[i];
      if (l.isEmpty) continue;
      final p = l.split('\t');
      if (p.length != 5) continue;
      final mod = int.tryParse(p[1]);
      final hash = int.tryParse(p[2]);
      final sharp = double.tryParse(p[3]);
      final bright = double.tryParse(p[4]);
      if (mod == null || hash == null || sharp == null || bright == null) continue;
      _m[p[0]] = _Entry(mod, ImageSig(hash, sharp, bright));
    }
  }

  Future<File> _file() async {
    final d = await getApplicationSupportDirectory();
    return File('${d.path}/sig_cache.txt');
  }

  Future<void> load() async {
    if (_loaded) return;
    try {
      final f = await _file();
      if (await f.exists()) parse(await f.readAsString());
    } catch (e) {
      debugPrint('sig cache load failed: $e');
    }
    _loaded = true;
    _dirty = false;
  }

  /// Writes atomically (temp file + rename) so a crash never leaves a half-written cache.
  Future<void> save() async {
    if (!_dirty) return;
    try {
      final f = await _file();
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(serialize(), flush: true);
      await tmp.rename(f.path);
      _dirty = false;
    } catch (e) {
      debugPrint('sig cache save failed: $e');
    }
  }

  Future<void> clear() async {
    _m.clear();
    _dirty = false;
    try {
      final f = await _file();
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
