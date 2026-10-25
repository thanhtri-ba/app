import 'dart:typed_data';

import 'package:photo_manager/photo_manager.dart';

import 'hash.dart';

/// A group of similar / duplicate photos. [best] indexes into [items].
class Cluster {
  final List<AssetEntity> items;
  final List<double> sharp;
  final int best;

  Cluster(this.items, this.sharp, this.best);

  static int pickBest(List<AssetEntity> items, List<double> sharp) {
    var b = 0;
    for (var i = 1; i < items.length; i++) {
      final better = sharp[i] > sharp[b] + 0.5 ||
          ((sharp[i] - sharp[b]).abs() <= 0.5 &&
              items[i].width * items[i].height > items[b].width * items[b].height);
      if (better) b = i;
    }
    return b;
  }

  /// Cluster without the given ids; null when fewer than 2 photos remain.
  Cluster? without(Set<String> ids) {
    final it = <AssetEntity>[];
    final sh = <double>[];
    for (var i = 0; i < items.length; i++) {
      if (!ids.contains(items[i].id)) {
        it.add(items[i]);
        sh.add(sharp[i]);
      }
    }
    if (it.length < 2) return null;
    return Cluster(it, sh, pickBest(it, sh));
  }
}

class BlurItem {
  final AssetEntity asset;
  final double sharp;
  const BlurItem(this.asset, this.sharp);
}

class ScanResult {
  final List<Cluster> clusters;
  final List<BlurItem> blurry;
  final int scanned;
  const ScanResult(this.clusters, this.blurry, this.scanned);
}

class _UnionFind {
  final List<int> p;
  _UnionFind(int n) : p = List<int>.generate(n, (i) => i);
  int find(int x) {
    while (p[x] != x) {
      p[x] = p[p[x]];
      x = p[x];
    }
    return x;
  }

  void union(int a, int b) {
    final ra = find(a), rb = find(b);
    if (ra != rb) p[rb] = ra;
  }
}

/// Groups indices whose hashes are close. [times] are millisecondsSinceEpoch.
/// Exposed for unit tests.
List<List<int>> groupSimilar(
  List<int> hashes,
  List<int> times, {
  required int threshold,
  int window = 25,
  int maxGapMs = 12 * 3600 * 1000,
  List<String>? exactKeys,
}) {
  final n = hashes.length;
  final uf = _UnionFind(n);
  for (var i = 0; i < n; i++) {
    final end = i + 1 + window < n ? i + 1 + window : n;
    for (var j = i + 1; j < end; j++) {
      final d = hamming(hashes[i], hashes[j]);
      if (d > threshold) continue;
      final gap = (times[i] - times[j]).abs();
      if (gap <= maxGapMs || d <= 1) uf.union(i, j);
    }
  }
  if (exactKeys != null) {
    final first = <String, int>{};
    for (var i = 0; i < n; i++) {
      final k = exactKeys[i];
      final f = first[k];
      if (f == null) {
        first[k] = i;
      } else {
        uf.union(f, i);
      }
    }
  }
  final groups = <int, List<int>>{};
  for (var i = 0; i < n; i++) {
    groups.putIfAbsent(uf.find(i), () => <int>[]).add(i);
  }
  return groups.values.where((g) => g.length >= 2).toList();
}

class Analyzer {
  static final Map<String, ImageSig> _cache = {};

  static Future<ScanResult> run(
    List<AssetEntity> source, {
    required double blurThreshold,
    required int hashThreshold,
    void Function(int done, int total)? onProgress,
    bool Function()? cancelled,
  }) async {
    final images = source.where((a) => a.type == AssetType.image).toList();
    final used = <AssetEntity>[];
    final sigs = <ImageSig>[];
    for (var i = 0; i < images.length; i++) {
      if (cancelled != null && cancelled()) break;
      final a = images[i];
      var sig = _cache[a.id];
      if (sig == null) {
        final Uint8List? bytes =
            await a.thumbnailDataWithSize(const ThumbnailSize(160, 160), quality: 70);
        if (bytes != null) {
          sig = await signatureOf(bytes);
          if (sig != null) _cache[a.id] = sig;
        }
      }
      if (sig != null) {
        used.add(a);
        sigs.add(sig);
      }
      if (i % 8 == 0) {
        onProgress?.call(i + 1, images.length);
        await Future<void>.delayed(Duration.zero);
      }
    }
    onProgress?.call(images.length, images.length);

    final groups = groupSimilar(
      sigs.map((s) => s.hash).toList(),
      used.map((a) => a.createDateTime.millisecondsSinceEpoch).toList(),
      threshold: hashThreshold,
      exactKeys: [
        for (var i = 0; i < used.length; i++) '${sigs[i].hash}_${used[i].width}x${used[i].height}'
      ],
    );

    final clusters = <Cluster>[];
    for (final g in groups) {
      g.sort((a, b) => used[b].createDateTime.compareTo(used[a].createDateTime));
      final items = g.map((i) => used[i]).toList();
      final sh = g.map((i) => sigs[i].sharp).toList();
      clusters.add(Cluster(items, sh, Cluster.pickBest(items, sh)));
    }
    clusters.sort((a, b) => b.items.first.createDateTime.compareTo(a.items.first.createDateTime));

    final blurry = <BlurItem>[];
    for (var i = 0; i < used.length; i++) {
      if (sigs[i].sharp < blurThreshold) blurry.add(BlurItem(used[i], sigs[i].sharp));
    }
    blurry.sort((a, b) => a.sharp.compareTo(b.sharp));

    return ScanResult(clusters, blurry, used.length);
  }
}
