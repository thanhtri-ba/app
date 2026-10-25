import 'package:flutter/material.dart';

import 'format.dart';

/// Number of consecutive active days ending today. If today has no activity yet, the streak
/// is still alive as long as yesterday had some (so it only breaks after a full missed day).
int currentStreak(Set<String> days, DateTime now) {
  var d = DateTime(now.year, now.month, now.day);
  if (!days.contains(dayKey(d))) d = DateTime(d.year, d.month, d.day - 1);
  var n = 0;
  while (days.contains(dayKey(d))) {
    n++;
    d = DateTime(d.year, d.month, d.day - 1);
  }
  return n;
}

/// Longest run of consecutive active days ever recorded.
int longestStreak(Set<String> days) {
  if (days.isEmpty) return 0;
  final list = days.map(parseDayKey).toList()..sort();
  var best = 1;
  var run = 1;
  for (var i = 1; i < list.length; i++) {
    final prev = list[i - 1];
    final next = DateTime(prev.year, prev.month, prev.day + 1);
    if (list[i] == next) {
      run++;
    } else if (list[i] != prev) {
      run = 1;
    }
    if (run > best) best = run;
  }
  return best;
}

class AchStats {
  final int bytes;
  final int count;
  final int streak;
  final int longest;
  final int toolsUsed;
  final int vaultItems;
  const AchStats({
    required this.bytes,
    required this.count,
    required this.streak,
    required this.longest,
    required this.toolsUsed,
    this.vaultItems = 0,
  });
}

class BadgeDef {
  final String id;
  final IconData icon;
  final Color color;
  final String en;
  final String vi;
  final String descEn;
  final String descVi;
  final bool Function(AchStats s) test;
  BadgeDef(this.id, this.icon, this.color, this.en, this.vi, this.descEn, this.descVi, this.test);
}

const int _mb = 1024 * 1024;
const int _gb = 1024 * _mb;

final List<BadgeDef> kBadges = [
  BadgeDef('first', Icons.auto_awesome_rounded, const Color(0xFF0A84FF), 'First clean', 'Lần dọn đầu',
      'Clean your first photos.', 'Dọn những bức ảnh đầu tiên.', (s) => s.count >= 1),
  BadgeDef('mb100', Icons.cleaning_services_rounded, const Color(0xFF30B067), '100 MB freed',
      'Giải phóng 100 MB', 'Free up 100 MB in total.', 'Giải phóng tổng cộng 100 MB.', (s) => s.bytes >= 100 * _mb),
  BadgeDef('gb1', Icons.rocket_launch_rounded, const Color(0xFF7B4DD6), '1 GB freed', 'Giải phóng 1 GB',
      'Free up 1 GB in total.', 'Giải phóng tổng cộng 1 GB.', (s) => s.bytes >= _gb),
  BadgeDef('gb5', Icons.emoji_events_rounded, const Color(0xFFFFB020), '5 GB freed', 'Giải phóng 5 GB',
      'Free up 5 GB in total.', 'Giải phóng tổng cộng 5 GB.', (s) => s.bytes >= 5 * _gb),
  BadgeDef('items100', Icons.photo_library_rounded, const Color(0xFF0A84FF), '100 cleared', 'Dọn 100 mục',
      'Clear 100 photos or videos.', 'Dọn 100 ảnh hoặc video.', (s) => s.count >= 100),
  BadgeDef('items1000', Icons.workspace_premium_rounded, const Color(0xFFFF8A3D), '1,000 cleared',
      'Dọn 1.000 mục', 'Clear 1,000 photos or videos.', 'Dọn 1.000 ảnh hoặc video.', (s) => s.count >= 1000),
  BadgeDef('streak3', Icons.local_fire_department_rounded, const Color(0xFFFF6B3D), '3-day streak',
      'Chuỗi 3 ngày', 'Clean on 3 days in a row.', 'Dọn dẹp 3 ngày liên tiếp.', (s) => s.longest >= 3),
  BadgeDef('streak7', Icons.local_fire_department_rounded, const Color(0xFFFF453A), '7-day streak',
      'Chuỗi 7 ngày', 'Clean on 7 days in a row.', 'Dọn dẹp 7 ngày liên tiếp.', (s) => s.longest >= 7),
  BadgeDef('streak30', Icons.whatshot_rounded, const Color(0xFFD70015), '30-day streak', 'Chuỗi 30 ngày',
      'Clean on 30 days in a row.', 'Dọn dẹp 30 ngày liên tiếp.', (s) => s.longest >= 30),
  BadgeDef('tools4', Icons.handyman_rounded, const Color(0xFF30B067), 'Toolbox', 'Hộp đồ nghề',
      'Use 4 different cleanup tools.', 'Dùng 4 công cụ dọn dẹp khác nhau.', (s) => s.toolsUsed >= 4),
  BadgeDef('vault', Icons.lock_rounded, const Color(0xFF7B4DD6), 'Vault keeper', 'Người giữ két',
      'Hide something in your private vault.', 'Ẩn một mục vào két riêng tư.', (s) => s.vaultItems >= 1),
];
