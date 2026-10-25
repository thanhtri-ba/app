import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../providers/activity_provider.dart';
import '../providers/library_provider.dart';
import '../widgets/achievement_cards.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';

class StorageScreen extends StatefulWidget {
  const StorageScreen({super.key});

  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen> {
  int _seg = 0;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final lib = context.watch<LibraryProvider>();
    final act = context.watch<ActivityProvider>();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, kTabBarSpace),
        children: [
          FadeSlideIn(child: PageTitle(context.tr('Storage', 'Dung lượng'))),
          const SizedBox(height: 14),
          FadeSlideIn(
            index: 1,
            child: SegControl(
              labels: [context.tr('Library', 'Thư viện'), context.tr('Activity', 'Hoạt động')],
              index: _seg,
              onChanged: (i) => setState(() => _seg = i),
            ),
          ),
          const SizedBox(height: 16),
          ...stagger(
            _seg == 0 ? _library(context, lib) : _activity(context, act),
            tag: 's$_seg',
            start: 2,
          ),
        ],
      ),
    );
  }

  List<Widget> _library(BuildContext context, LibraryProvider lib) {
    final pal = context.pal;
    final photos = lib.photoCount;
    final videos = lib.videoCount;
    final shots = lib.screenshots.length;
    final total = lib.assets.length;

    // Items per month for the last 12 months.
    final now = DateTime.now();
    final months = <DateTime>[
      for (var i = 11; i >= 0; i--) DateTime(now.year, now.month - i)
    ];
    final per = <int>[];
    for (final m in months) {
      var n = 0;
      final dim = DateTime(m.year, m.month + 1, 0).day;
      for (var d = 1; d <= dim; d++) {
        n += lib.byDay[dayKey(DateTime(m.year, m.month, d))]?.length ?? 0;
      }
      per.add(n);
    }
    var maxN = 1;
    for (final n in per) {
      if (n > maxN) maxN = n;
    }

    final pure = (photos - shots).clamp(0, photos).toInt();
    final segs = <(String, int, Color)>[
      (context.tr('Photos', 'Ảnh'), pure, AppColors.accent),
      (context.tr('Videos', 'Video'), videos, const Color(0xFF30B067)),
      (context.tr('Screenshots', 'Ảnh chụp màn hình'), shots, const Color(0xFFFF8A3D)),
    ];

    return [
      AppCard(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            SizedBox(
              width: 150,
              height: 150,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (_, t, __) => CustomPaint(
                      size: const Size(150, 150),
                      painter: _DonutPainter(
                        values: [for (final x in segs) x.$2.toDouble()],
                        colors: [for (final x in segs) x.$3],
                        track: pal.line,
                        progress: t,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(fmtCount(total),
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                              color: pal.text)),
                      Text(context.tr('items', 'mục'),
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600, color: pal.sec)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                children: [
                  for (var i = 0; i < segs.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(color: segs[i].$3, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(segs[i].$1,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600, color: pal.text)),
                        ),
                        Text(fmtCount(segs[i].$2),
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600, color: pal.sec)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 6),
              child: Text(context.tr('What takes space', 'Cái gì chiếm chỗ'),
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: pal.text)),
            ),
            for (final x in segs) _barRow(pal, x.$1, fmtCount(x.$2), total == 0 ? 0 : x.$2 / total),
          ],
        ),
      ),
      const SizedBox(height: 12),
      AppCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('Last 12 months', '12 tháng gần nhất'),
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: pal.text)),
            const SizedBox(height: 12),
            SizedBox(
              height: 90,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < per.length; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.04, end: (per[i] / maxN).clamp(0.04, 1.0)),
                          duration: Duration(milliseconds: 500 + i * 20),
                          curve: Curves.easeOutCubic,
                          builder: (_, v, child) => FractionallySizedBox(heightFactor: v, child: child),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.accent.withOpacity(i == per.length - 1 ? 1 : 0.55),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (final m in months)
                  Expanded(
                    child: Center(
                      child: Text('${m.month}',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: pal.sec)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      if (lib.limited) ...[
        const SizedBox(height: 12),
        AppCard(
          child: Text(
            context.tr('You granted access to selected photos only. Allow full access in Settings to see everything.',
                'Bạn chỉ cấp quyền cho một số ảnh. Hãy cho phép toàn bộ trong Cài đặt để thấy đầy đủ.'),
            style: TextStyle(fontSize: 13, color: pal.sec, height: 1.4),
          ),
        ),
      ],
    ];
  }

  List<Widget> _activity(BuildContext context, ActivityProvider act) {
    final pal = context.pal;
    String kindName(String k) {
      switch (k) {
        case 'review':
          return context.tr('Similar photos', 'Ảnh giống nhau');
        case 'blurry':
          return context.tr('Blurry photos', 'Ảnh mờ');
        case 'screenshots':
          return context.tr('Screenshots', 'Ảnh chụp màn hình');
        case 'large':
          return context.tr('Large videos', 'Video lớn');
        case 'burst':
          return context.tr('Best of burst', 'Ảnh chụp liên tiếp');
        case 'docs':
          return context.tr('Receipts & docs', 'Biên lai & tài liệu');
        case 'chat':
          return context.tr('Chat media', 'Ảnh từ chat');
        case 'dupvideos':
          return context.tr('Duplicate videos', 'Video trùng');
        case 'compress':
          return context.tr('Compressed photos', 'Ảnh đã nén');
        case 'videocompress':
          return context.tr('Compressed videos', 'Video đã nén');
        case 'rejected':
          return context.tr('Rejected in culling', 'Ảnh loại khi chọn ảnh');
        default:
          return k;
      }
    }

    // Bytes freed per day over the last 30 days.
    final nowD = DateTime.now();
    final today = DateTime(nowD.year, nowD.month, nowD.day);
    final perDay = List<double>.filled(30, 0);
    final perKind = <String, int>{};
    for (final e in act.entries) {
      perKind[e.kind] = (perKind[e.kind] ?? 0) + e.bytes;
      final d = DateTime.fromMillisecondsSinceEpoch(e.ts);
      final dd = today.difference(DateTime(d.year, d.month, d.day)).inDays;
      if (dd >= 0 && dd < 30) perDay[29 - dd] += e.bytes.toDouble();
    }
    var maxDay = 0.0;
    for (final v in perDay) {
      if (v > maxDay) maxDay = v;
    }
    final kinds = perKind.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return [
      const StreakGoalCard(),
      const SizedBox(height: 12),
      const BadgesCard(),
      const SizedBox(height: 12),
      AppCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('Freed in total', 'Tổng đã giải phóng'),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: pal.sec)),
            const SizedBox(height: 2),
            CountUp(
                value: act.totalBytes,
                format: (v) => fmtBytes(v),
                style: TextStyle(
                    fontSize: 44,
                    height: 52 / 44,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.2,
                    color: pal.text)),
            const SizedBox(height: 18),
            SizedBox(
              height: 96,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < perDay.length; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1.5),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.04, end: maxDay == 0 ? 0.04 : (perDay[i] / maxDay).clamp(0.04, 1.0)),
                          duration: Duration(milliseconds: 500 + i * 20),
                          curve: Curves.easeOutCubic,
                          builder: (_, v, child) => FractionallySizedBox(heightFactor: v, child: child),
                          child: Container(
                            decoration: BoxDecoration(
                              color: perDay[i] > 0 ? AppColors.accent : pal.line,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(context.tr('Last 30 days', '30 ngày qua'),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: pal.sec)),
                Text(context.tr('Today', 'Hôm nay'),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: pal.sec)),
              ],
            ),
          ],
        ),
      ),
      if (kinds.isNotEmpty) ...[
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 0, 6),
                child: Text(context.tr('Per tool', 'Theo công cụ'),
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: pal.text)),
              ),
              for (final k in kinds)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: pal.line))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(kindName(k.key),
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600, color: pal.text)),
                      Text(fmtBytes(k.value), style: TextStyle(fontSize: 15, color: pal.sec)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 12),
      if (act.entries.isEmpty)
        AppCard(
          child: Text(context.tr('Nothing cleaned yet.', 'Chưa dọn gì.'),
              style: TextStyle(color: pal.sec)),
        )
      else
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(
            children: [
              for (var i = 0; i < act.entries.length && i < 30; i++)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: i == 0 ? null : Border(top: BorderSide(color: pal.line)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(kindName(act.entries[i].kind),
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w600, color: pal.text)),
                            Text(
                                fmtDateTime(DateTime.fromMillisecondsSinceEpoch(act.entries[i].ts)),
                                style: TextStyle(fontSize: 12, color: pal.sec)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(fmtBytes(act.entries[i].bytes),
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700, color: pal.accentText)),
                          Text(context.tr('${act.entries[i].count} items', '${act.entries[i].count} mục'),
                              style: TextStyle(fontSize: 12, color: pal.sec)),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
    ];
  }

  Widget _barRow(Pal pal, String label, String value, double frac) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: pal.line))),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: pal.text)),
              Text(value, style: TextStyle(fontSize: 15, color: pal.sec)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: frac.clamp(0.0, 1.0),
              minHeight: 6,
              color: AppColors.accent,
              backgroundColor: pal.line,
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final Color track;
  final double progress;
  _DonutPainter(
      {required this.values, required this.colors, required this.track, this.progress = 1});

  @override
  void paint(Canvas canvas, Size size) {
    // Prototype: viewBox 180, r=68, stroke 22 -> scaled to the widget size.
    final k = size.width / 180;
    final stroke = 22 * k;
    final r = 68 * k;
    final c = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: c, radius: r);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawCircle(c, r, base);
    final sum = values.fold<double>(0, (a, b) => a + b);
    if (sum <= 0) return;
    var start = -1.5707963267948966; // -90deg
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / sum * 6.283185307179586 * progress;
      if (sweep <= 0) continue;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = colors[i];
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.values != values ||
      old.colors != colors ||
      old.track != track ||
      old.progress != progress;
}
