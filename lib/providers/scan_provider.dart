import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

import '../scanner/analyzer.dart';
import 'library_provider.dart';
import 'settings_provider.dart';

class LargeItem {
  final AssetEntity asset;
  final int bytes;
  const LargeItem(this.asset, this.bytes);
}

class ScanProvider extends ChangeNotifier {
  bool scanning = false;
  int done = 0;
  int total = 0;
  bool _cancel = false;
  ScanResult? result;

  /// Ids marked for deletion in the Review tab.
  final Set<String> reviewMarked = <String>{};

  /// Ids marked for deletion in the Cleanup tools (blurry / screenshots / large).
  final Set<String> toolMarked = <String>{};

  List<LargeItem>? large;
  bool loadingLarge = false;

  List<Cluster> get clusters => result?.clusters ?? const <Cluster>[];
  List<BlurItem> get blurry => result?.blurry ?? const <BlurItem>[];

  Future<void> scan(LibraryProvider lib, SettingsProvider s) async {
    if (scanning) return;
    scanning = true;
    _cancel = false;
    done = 0;
    total = 0;
    reviewMarked.clear();
    toolMarked.clear();
    notifyListeners();
    final list = lib.assets.take(s.scanLimit).toList();
    try {
      result = await Analyzer.run(
        list,
        blurThreshold: s.blurThreshold,
        hashThreshold: s.hashThreshold,
        cancelled: () => _cancel,
        onProgress: (d, t) {
          done = d;
          total = t;
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('scan failed: $e');
    }
    scanning = false;
    notifyListeners();
  }

  void cancelScan() {
    _cancel = true;
  }

  // ---- review selection ----
  void toggleReview(String id) {
    if (!reviewMarked.remove(id)) reviewMarked.add(id);
    notifyListeners();
  }

  void keepBest(int ci) {
    final c = clusters[ci];
    for (var i = 0; i < c.items.length; i++) {
      if (i == c.best) {
        reviewMarked.remove(c.items[i].id);
      } else {
        reviewMarked.add(c.items[i].id);
      }
    }
    notifyListeners();
  }

  void autoAll() {
    reviewMarked.clear();
    for (final c in clusters) {
      for (var i = 0; i < c.items.length; i++) {
        if (i != c.best) reviewMarked.add(c.items[i].id);
      }
    }
    notifyListeners();
  }

  void resetReview() {
    reviewMarked.clear();
    notifyListeners();
  }

  List<AssetEntity> reviewMarkedAssets() {
    final out = <AssetEntity>[];
    for (final c in clusters) {
      for (final a in c.items) {
        if (reviewMarked.contains(a.id)) out.add(a);
      }
    }
    return out;
  }

  // ---- tool selection ----
  void toggleTool(String id) {
    if (!toolMarked.remove(id)) toolMarked.add(id);
    notifyListeners();
  }

  void setTool(Iterable<String> ids, bool on) {
    if (on) {
      toolMarked.addAll(ids);
    } else {
      toolMarked.removeAll(ids);
    }
    notifyListeners();
  }

  // ---- large videos ----
  Future<void> loadLarge(LibraryProvider lib) async {
    if (loadingLarge) return;
    loadingLarge = true;
    notifyListeners();
    final vids = lib.assets.where((a) => a.type == AssetType.video).toList();
    vids.sort((a, b) =>
        (b.width * b.height * (b.duration + 1)).compareTo(a.width * a.height * (a.duration + 1)));
    final out = <LargeItem>[];
    for (final v in vids.take(40)) {
      try {
        final File? f = await v.originFile;
        if (f != null) out.add(LargeItem(v, await f.length()));
      } catch (_) {}
    }
    out.sort((a, b) => b.bytes.compareTo(a.bytes));
    large = out;
    loadingLarge = false;
    notifyListeners();
  }

  // ---- after deletion ----
  void removeIds(Set<String> ids) {
    if (ids.isEmpty) return;
    reviewMarked.removeAll(ids);
    toolMarked.removeAll(ids);
    final r = result;
    if (r != null) {
      final cl = <Cluster>[];
      for (final c in r.clusters) {
        final n = c.without(ids);
        if (n != null) cl.add(n);
      }
      final bl = r.blurry.where((b) => !ids.contains(b.asset.id)).toList();
      result = ScanResult(cl, bl, r.scanned);
    }
    if (large != null) {
      large = large!.where((l) => !ids.contains(l.asset.id)).toList();
    }
    notifyListeners();
  }
}
