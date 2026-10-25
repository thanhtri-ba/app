import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ActivityEntry {
  final int ts; // millisecondsSinceEpoch
  final String kind; // review | blurry | screenshots | large | rejected
  final int count;
  final int bytes;

  const ActivityEntry(this.ts, this.kind, this.count, this.bytes);

  Map<String, dynamic> toJson() => {'t': ts, 'k': kind, 'c': count, 'b': bytes};

  factory ActivityEntry.fromJson(Map<String, dynamic> j) =>
      ActivityEntry(j['t'] as int, j['k'] as String, j['c'] as int, j['b'] as int);
}

class ActivityProvider extends ChangeNotifier {
  final List<ActivityEntry> entries = [];

  int get totalBytes => entries.fold<int>(0, (a, e) => a + e.bytes);
  int get totalCount => entries.fold<int>(0, (a, e) => a + e.count);

  int bytesFor(String kind) =>
      entries.where((e) => e.kind == kind).fold<int>(0, (a, e) => a + e.bytes);

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList('activity') ?? const <String>[];
    entries.clear();
    for (final s in raw) {
      try {
        entries.add(ActivityEntry.fromJson(jsonDecode(s) as Map<String, dynamic>));
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> add(String kind, int count, int bytes) async {
    entries.insert(0, ActivityEntry(DateTime.now().millisecondsSinceEpoch, kind, count, bytes));
    if (entries.length > 200) entries.removeRange(200, entries.length);
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setStringList('activity', entries.map((e) => jsonEncode(e.toJson())).toList());
  }
}
