import 'dart:collection';
import 'dart:typed_data';

import 'package:photo_manager/photo_manager.dart';

/// Small in-memory LRU cache for thumbnails, bounded by bytes.
class ThumbCache {
  static final LinkedHashMap<String, Uint8List> _m = LinkedHashMap();
  static int _bytes = 0;
  static const int _budget = 96 * 1024 * 1024;

  static String _key(AssetEntity a, int size) => '${a.id}_$size';

  static Uint8List? peek(AssetEntity a, int size) {
    final k = _key(a, size);
    final v = _m.remove(k);
    if (v != null) _m[k] = v;
    return v;
  }

  static Future<Uint8List?> load(AssetEntity a, int size) async {
    final hit = peek(a, size);
    if (hit != null) return hit;
    final data = await a.thumbnailDataWithSize(ThumbnailSize(size, size), quality: 85);
    if (data == null) return null;
    final k = _key(a, size);
    _m[k] = data;
    _bytes += data.length;
    while (_bytes > _budget && _m.isNotEmpty) {
      final first = _m.keys.first;
      _bytes -= _m.remove(first)!.length;
    }
    return data;
  }
}
