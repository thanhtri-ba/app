import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Rating / flag / colour label for one asset (kept inside the app only).
class AssetMeta {
  int rating;
  String? flag; // 'pick' | 'reject'
  String? label; // 'red' | 'yellow' | 'green' | 'blue' | 'purple'

  AssetMeta({this.rating = 0, this.flag, this.label});

  bool get isEmpty => rating == 0 && flag == null && label == null;

  Map<String, dynamic> toJson() => {
        if (rating != 0) 'r': rating,
        if (flag != null) 'f': flag,
        if (label != null) 'l': label,
      };

  factory AssetMeta.fromJson(Map<String, dynamic> j) => AssetMeta(
        rating: (j['r'] as int?) ?? 0,
        flag: j['f'] as String?,
        label: j['l'] as String?,
      );
}

class MetaProvider extends ChangeNotifier {
  final Map<String, AssetMeta> _m = {};
  Timer? _timer;

  int rating(String id) => _m[id]?.rating ?? 0;
  String? flag(String id) => _m[id]?.flag;
  String? label(String id) => _m[id]?.label;
  bool reviewed(String id) {
    final x = _m[id];
    return x != null && (x.rating > 0 || x.flag != null);
  }

  Future<File> _file() async {
    final d = await getApplicationDocumentsDirectory();
    return File('${d.path}/photo_cleaner_meta.json');
  }

  Future<void> load() async {
    try {
      final f = await _file();
      if (await f.exists()) {
        final raw = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        raw.forEach((k, v) {
          _m[k] = AssetMeta.fromJson(Map<String, dynamic>.from(v as Map));
        });
        notifyListeners();
      }
    } catch (_) {}
  }

  void _persist() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 600), () async {
      try {
        final f = await _file();
        final out = <String, dynamic>{};
        _m.forEach((k, v) {
          if (!v.isEmpty) out[k] = v.toJson();
        });
        await f.writeAsString(jsonEncode(out));
      } catch (_) {}
    });
  }

  AssetMeta _get(String id) => _m.putIfAbsent(id, () => AssetMeta());

  void _tidy(String id) {
    final x = _m[id];
    if (x != null && x.isEmpty) _m.remove(id);
  }

  void setRating(Iterable<String> ids, int n) {
    for (final id in ids) {
      _get(id).rating = n;
      _tidy(id);
    }
    notifyListeners();
    _persist();
  }

  /// Toggling: setting the same flag again clears it.
  void toggleFlag(Iterable<String> ids, String flag) {
    for (final id in ids) {
      final x = _get(id);
      x.flag = x.flag == flag ? null : flag;
      _tidy(id);
    }
    notifyListeners();
    _persist();
  }

  void setFlag(Iterable<String> ids, String? flag) {
    for (final id in ids) {
      _get(id).flag = flag;
      _tidy(id);
    }
    notifyListeners();
    _persist();
  }

  void setLabel(Iterable<String> ids, String? label) {
    for (final id in ids) {
      _get(id).label = label;
      _tidy(id);
    }
    notifyListeners();
    _persist();
  }

  void toggleLabel(String id, String label) {
    final x = _get(id);
    x.label = x.label == label ? null : label;
    _tidy(id);
    notifyListeners();
    _persist();
  }

  void remove(Iterable<String> ids) {
    for (final id in ids) {
      _m.remove(id);
    }
    notifyListeners();
    _persist();
  }

  int countFlag(Iterable<String> ids, String flag) {
    var n = 0;
    for (final id in ids) {
      if (_m[id]?.flag == flag) n++;
    }
    return n;
  }

  int countReviewed(Iterable<String> ids) {
    var n = 0;
    for (final id in ids) {
      if (reviewed(id)) n++;
    }
    return n;
  }
}
