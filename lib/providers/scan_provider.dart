import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../scanner/analyzer.dart';
import '../scanner/sig_cache.dart';
import '../services/ocr_service.dart';
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

  /// Persistent signatures: later scans only analyse new or edited photos.
  final SigCache cache = SigCache();
  DateTime? lastScan;

  // OCR refinement of the "Receipts & docs" list.
  Set<String>? docsRefined;
  bool ocrRunning = false;
  int ocrDone = 0;
  int ocrTotal = 0;
  bool _ocrCancel = false;

  /// Ids marked for deletion in the Review tab.
  final Set<String> reviewMarked = <String>{};

  /// Ids marked for deletion in the Cleanup tools (blurry / screenshots / large).
  final Set<String> toolMarked = <String>{};

  List<LargeItem>? large;
  bool loadingLarge = false;

  List<Cluster> get clusters => result?.clusters ?? const <Cluster>[];
  List<BlurItem> get blurry => result?.blurry ?? const <BlurItem>[];
  List<Cluster> get bursts => result?.bursts ?? const <Cluster>[];
  List<AssetEntity> get docs => result?.docs ?? const <AssetEntity>[];

  /// Docs list after optional OCR refinement.
  List<AssetEntity> get docsShown {
    final keep = docsRefined;
    return keep == null ? docs : docs.where((a) => keep.contains(a.id)).toList();
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final ms = p.getInt('lastScanMs');
    if (ms != null) lastScan = DateTime.fromMillisecondsSinceEpoch(ms);
    notifyListeners();
  }

  /// Rough bytes in duplicate groups that could be freed (all but the best shot of each).
  int get estimatedDupBytes {
    var sum = 0;
    for (final c in clusters) {
      for (var i = 0; i < c.items.length; i++) {
        if (i != c.best) sum += (c.items[i].width * c.items[i].height * 0.35).round();
      }
    }
    return sum;
  }

  /// Rough bytes that could be freed (same estimate used by the review screen).
  int get estimatedFreeable {
    var sum = 0;
    for (final c in clusters) {
      for (var i = 0; i < c.items.length; i++) {
        if (i != c.best) sum += (c.items[i].width * c.items[i].height * 0.35).round();
      }
    }
    for (final b in blurry) {
      sum += (b.asset.width * b.asset.height * 0.35).round();
    }
    return sum;
  }

  Future<void> scan(LibraryProvider lib, SettingsProvider s) async {
    if (scanning) return;
    scanning = true;
    _cancel = false;
    done = 0;
    total = 0;
    reviewMarked.clear();
    toolMarked.clear();
    docsRefined = null;
    notifyListeners();
    await cache.load();
    final list = lib.assets.take(s.scanLimit).toList();
    try {
      result = await Analyzer.run(
        list,
        blurThreshold: s.blurThreshold,
        hashThreshold: s.hashThreshold,
        cache: cache,
        cancelled: () => _cancel,
        onProgress: (d, t) {
          done = d;
          total = t;
          notifyListeners();
        },
      );
      if (!_cancel) {
        cache.prune({for (final a in lib.assets) a.id});
        lastScan = DateTime.now();
        final p = await SharedPreferences.getInstance();
        await p.setInt('lastScanMs', lastScan!.millisecondsSinceEpoch);
      }
      await cache.save();
    } catch (e) {
      debugPrint('scan failed: $e');
    }
    scanning = false;
    notifyListeners();
  }

  // ---- OCR refinement ----
  Future<void> refineDocs() async {
    if (ocrRunning || docs.isEmpty) return;
    ocrRunning = true;
    _ocrCancel = false;
    ocrDone = 0;
    ocrTotal = docs.length;
    notifyListeners();
    try {
      final keep = await OcrService.receiptIds(
        docs,
        onProgress: (d, t) {
          ocrDone = d;
          ocrTotal = t;
          notifyListeners();
        },
        cancelled: () => _ocrCancel,
      );
      if (!_ocrCancel) docsRefined = keep;
    } catch (e) {
      debugPrint('ocr refine failed: $e');
    }
    ocrRunning = false;
    notifyListeners();
  }

  void cancelOcr() => _ocrCancel = true;

  void resetRefine() {
    docsRefined = null;
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
    docsRefined?.removeAll(ids);
    final r = result;
    if (r != null) {
      final cl = <Cluster>[];
      for (final c in r.clusters) {
        final n = c.without(ids);
        if (n != null) cl.add(n);
      }
      final bl = r.blurry.where((b) => !ids.contains(b.asset.id)).toList();
      final bu = <Cluster>[];
      for (final c in r.bursts) {
        final n = c.without(ids);
        if (n != null && isBurst(n)) bu.add(n);
      }
      final dc = r.docs.where((a) => !ids.contains(a.id)).toList();
      result = ScanResult(cl, bl, r.scanned, docs: dc, bursts: bu);
    }
    if (large != null) {
      large = large!.where((l) => !ids.contains(l.asset.id)).toList();
    }
    notifyListeners();
  }
}
