import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

import '../core/format.dart';

enum LibState { unknown, loading, ready, denied }

class LibraryProvider extends ChangeNotifier {
  LibState state = LibState.unknown;
  List<AssetEntity> assets = []; // newest first (photos + videos)
  List<AssetEntity> screenshots = [];
  List<AssetEntity> chatMedia = [];
  List<List<AssetEntity>> dupVideos = [];
  Map<String, List<AssetEntity>> byDay = {};
  int loaded = 0;
  int total = 0;
  bool limited = false;
  static const int maxLoad = 30000;

  int get photoCount => assets.where((a) => a.type == AssetType.image).length;
  int get videoCount => assets.where((a) => a.type == AssetType.video).length;

  Future<void> init() async {
    state = LibState.loading;
    notifyListeners();
    final ps = await PhotoManager.requestPermissionExtend();
    if (!ps.hasAccess) {
      state = LibState.denied;
      notifyListeners();
      return;
    }
    limited = ps == PermissionState.limited;
    await reload();
  }

  Future<void> openSettings() => PhotoManager.openSetting();

  Future<void> reload() async {
    state = LibState.loading;
    loaded = 0;
    notifyListeners();
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      onlyAll: true,
    );
    if (paths.isEmpty) {
      assets = [];
      _index();
      state = LibState.ready;
      notifyListeners();
      return;
    }
    final all = paths.first;
    total = await all.assetCountAsync;
    final out = <AssetEntity>[];
    const chunk = 500;
    for (var s = 0; s < total && s < maxLoad; s += chunk) {
      final e = (s + chunk) < total ? s + chunk : total;
      final part = await all.getAssetListRange(start: s, end: e);
      out.addAll(part);
      loaded = out.length;
      if (s == 0) {
        assets = List<AssetEntity>.of(out);
        _index();
        state = LibState.ready;
      }
      notifyListeners();
    }
    assets = out;
    _index();
    state = LibState.ready;
    notifyListeners();
    _findDupVideos();
    await loadScreenshots();
    await loadChatMedia();
  }

  void _index() {
    final m = <String, List<AssetEntity>>{};
    for (final a in assets) {
      m.putIfAbsent(dayKey(a.createDateTime), () => <AssetEntity>[]).add(a);
    }
    byDay = m;
  }

  Future<void> loadScreenshots() async {
    try {
      final ps = await PhotoManager.getAssetPathList(type: RequestType.image);
      AssetPathEntity? hit;
      for (final p in ps) {
        final n = p.name.toLowerCase();
        if (n.contains('screenshot') || n.contains('màn hình')) {
          hit = p;
          break;
        }
      }
      if (hit == null) {
        screenshots = [];
      } else {
        final c = await hit.assetCountAsync;
        screenshots = c == 0 ? <AssetEntity>[] : await hit.getAssetListRange(start: 0, end: c);
      }
    } catch (_) {
      screenshots = [];
    }
    notifyListeners();
  }

  /// Videos with the same duration and dimensions are probably copies.
  void _findDupVideos() {
    final m = <String, List<AssetEntity>>{};
    for (final a in assets) {
      if (a.type != AssetType.video || a.duration <= 0) continue;
      m.putIfAbsent('${a.duration}_${a.width}x${a.height}', () => <AssetEntity>[]).add(a);
    }
    dupVideos = m.values.where((g) => g.length >= 2).toList();
  }

  static const List<String> _chatApps = [
    'whatsapp', 'zalo', 'telegram', 'messenger', 'viber', 'wechat', 'signal', 'kakao', 'line', 'snapchat',
  ];

  /// Media received through messaging apps, found by album name.
  Future<void> loadChatMedia() async {
    try {
      final ps = await PhotoManager.getAssetPathList(type: RequestType.common);
      final seen = <String>{};
      final out = <AssetEntity>[];
      for (final p in ps) {
        final n = p.name.toLowerCase();
        if (!_chatApps.any((k) => n.contains(k))) continue;
        final c = await p.assetCountAsync;
        if (c == 0) continue;
        final list = await p.getAssetListRange(start: 0, end: c > 3000 ? 3000 : c);
        for (final a in list) {
          if (seen.add(a.id)) out.add(a);
        }
      }
      out.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));
      chatMedia = out;
    } catch (_) {
      chatMedia = [];
    }
    notifyListeners();
  }

  /// Rough size estimate: exact file length for videos, pixel-based guess for photos.
  Future<int> estimateBytes(AssetEntity a) async {
    if (a.type == AssetType.video) {
      try {
        final f = await a.originFile;
        if (f != null) return await f.length();
      } catch (_) {}
      return a.width * a.height * (a.duration > 0 ? a.duration : 1) ~/ 8;
    }
    return (a.width * a.height * 0.35).round();
  }

  Future<int> estimateBytesAll(List<AssetEntity> list) async {
    var sum = 0;
    for (final a in list) {
      sum += await estimateBytes(a);
    }
    return sum;
  }

  /// Moves assets to the system trash / Recently Deleted. Returns the ids actually deleted.
  Future<Set<String>> deleteAssets(List<AssetEntity> list) async {
    if (list.isEmpty) return <String>{};
    final ids = list.map((e) => e.id).toList();
    final deleted = await PhotoManager.editor.deleteWithIds(ids);
    final set = deleted.toSet();
    if (set.isNotEmpty) {
      assets.removeWhere((a) => set.contains(a.id));
      screenshots.removeWhere((a) => set.contains(a.id));
      chatMedia.removeWhere((a) => set.contains(a.id));
      for (final g in dupVideos) {
        g.removeWhere((a) => set.contains(a.id));
      }
      dupVideos = dupVideos.where((g) => g.length >= 2).toList();
      _index();
      notifyListeners();
    }
    return set;
  }

  Future<File?> fileOf(AssetEntity a) => a.originFile;
}
