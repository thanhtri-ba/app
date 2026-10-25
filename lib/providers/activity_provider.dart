import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/achievements.dart';
import '../core/format.dart';

class ActivityEntry {
  final int ts; // millisecondsSinceEpoch
  final String kind; // review | blurry | screenshots | large | rejected | ...
  final int count;
  final int bytes;

  const ActivityEntry(this.ts, this.kind, this.count, this.bytes);

  Map<String, dynamic> toJson() => {'t': ts, 'k': kind, 'c': count, 'b': bytes};

  factory ActivityEntry.fromJson(Map<String, dynamic> j) =>
      ActivityEntry(j['t'] as int, j['k'] as String, j['c'] as int, j['b'] as int);
}

/// Cleanup history + lifetime counters.
///
/// `entries` only keeps the latest 200 events (for the history list), so lifetime totals,
/// active days, tools used and monthly totals are stored separately and never shrink.
class ActivityProvider extends ChangeNotifier {
  final List<ActivityEntry> entries = [];

  int _lifeBytes = 0;
  int _lifeCount = 0;
  final Set<String> activeDays = <String>{};
  final Set<String> kindsUsed = <String>{};
  final Map<String, int> monthly = <String, int>{};
  final Set<String> _seen = <String>{};
  int goalMb = 500;

  int get totalBytes => _lifeBytes;
  int get totalCount => _lifeCount;

  int bytesFor(String kind) =>
      entries.where((e) => e.kind == kind).fold<int>(0, (a, e) => a + e.bytes);

  static String monthKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

  int get streak => currentStreak(activeDays, DateTime.now());
  int get longest => longestStreak(activeDays);
  int get monthBytes => monthly[monthKey(DateTime.now())] ?? 0;
  double get goalProgress {
    final goal = goalMb * 1024 * 1024;
    return goal <= 0 ? 0 : (monthBytes / goal).clamp(0.0, 1.0).toDouble();
  }

  AchStats statsFor({int vaultItems = 0}) => AchStats(
        bytes: _lifeBytes,
        count: _lifeCount,
        streak: streak,
        longest: longest,
        toolsUsed: kindsUsed.length,
        vaultItems: vaultItems,
      );

  Set<String> unlockedIds({int vaultItems = 0}) {
    final s = statsFor(vaultItems: vaultItems);
    return {for (final b in kBadges) if (b.test(s)) b.id};
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList('activity') ?? const <String>[];
    entries.clear();
    for (final s in raw) {
      try {
        entries.add(ActivityEntry.fromJson(jsonDecode(s) as Map<String, dynamic>));
      } catch (_) {}
    }

    final life = p.getInt('actLifeBytes');
    if (life == null) {
      // First run of this version: rebuild the counters from the history we have.
      _lifeBytes = entries.fold<int>(0, (a, e) => a + e.bytes);
      _lifeCount = entries.fold<int>(0, (a, e) => a + e.count);
      activeDays.clear();
      kindsUsed.clear();
      monthly.clear();
      for (final e in entries) {
        final d = DateTime.fromMillisecondsSinceEpoch(e.ts);
        activeDays.add(dayKey(d));
        kindsUsed.add(e.kind);
        monthly[monthKey(d)] = (monthly[monthKey(d)] ?? 0) + e.bytes;
      }
    } else {
      _lifeBytes = life;
      _lifeCount = p.getInt('actLifeCount') ?? 0;
      activeDays
        ..clear()
        ..addAll(p.getStringList('actDays') ?? const <String>[]);
      kindsUsed
        ..clear()
        ..addAll(p.getStringList('actKinds') ?? const <String>[]);
      monthly.clear();
      try {
        final m = jsonDecode(p.getString('actMonthly') ?? '{}') as Map<String, dynamic>;
        m.forEach((k, v) => monthly[k] = (v as num).toInt());
      } catch (_) {}
    }
    goalMb = p.getInt('actGoalMb') ?? 500;

    final seen = p.getStringList('actSeen');
    _seen.clear();
    if (seen == null) {
      // Existing users must not get a flood of "new badge" celebrations.
      _seen.addAll(unlockedIds());
      await _save();
    } else {
      _seen.addAll(seen);
    }
    notifyListeners();
  }

  /// Records a cleanup. Returns the badges that were unlocked by it.
  Future<List<BadgeDef>> add(String kind, int count, int bytes) async {
    final now = DateTime.now();
    entries.insert(0, ActivityEntry(now.millisecondsSinceEpoch, kind, count, bytes));
    if (entries.length > 200) entries.removeRange(200, entries.length);

    _lifeBytes += bytes;
    _lifeCount += count;
    activeDays.add(dayKey(now));
    if (activeDays.length > 400) {
      final keep = (activeDays.toList()..sort()).skip(activeDays.length - 400);
      final k = keep.toSet();
      activeDays
        ..clear()
        ..addAll(k);
    }
    kindsUsed.add(kind);
    monthly[monthKey(now)] = (monthly[monthKey(now)] ?? 0) + bytes;

    final unlocked = unlockedIds();
    final fresh = [for (final b in kBadges) if (unlocked.contains(b.id) && !_seen.contains(b.id)) b];
    _seen.addAll(fresh.map((b) => b.id));

    notifyListeners();
    await _save();
    return fresh;
  }

  Future<void> setGoalMb(int mb) async {
    goalMb = mb;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setInt('actGoalMb', mb);
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList('activity', entries.map((e) => jsonEncode(e.toJson())).toList());
    await p.setInt('actLifeBytes', _lifeBytes);
    await p.setInt('actLifeCount', _lifeCount);
    await p.setStringList('actDays', activeDays.toList());
    await p.setStringList('actKinds', kindsUsed.toList());
    await p.setString('actMonthly', jsonEncode(monthly));
    await p.setStringList('actSeen', _seen.toList());
    await p.setInt('actGoalMb', goalMb);
  }
}
