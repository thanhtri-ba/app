import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../providers/activity_provider.dart';
import '../providers/library_provider.dart';
import '../widgets/common.dart';

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
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        children: [
          Text(context.tr('Storage', 'Dung lượng'),
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: pal.text)),
          const SizedBox(height: 12),
          SegControl(
            labels: [context.tr('Library', 'Thư viện'), context.tr('Activity', 'Hoạt động')],
            index: _seg,
            onChanged: (i) => setState(() => _seg = i),
          ),
          const SizedBox(height: 14),
          if (_seg == 0) ..._library(context, lib) else ..._activity(context, act),
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

    Widget row(String label, int n, Color c) {
      final f = total == 0 ? 0.0 : n / total;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Row(
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(child: Text(label, style: TextStyle(fontSize: 15, color: pal.text))),
                Text(fmtCount(n), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: pal.text)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: f.clamp(0.0, 1.0),
                minHeight: 6,
                color: c,
                backgroundColor: pal.line,
              ),
            ),
          ],
        ),
      );
    }

    return [
      HeroCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('In your library', 'Trong thư viện'),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xD9FFFFFF))),
            Text(fmtCount(total),
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1)),
            Text(context.tr('$photos photos · $videos videos', '$photos ảnh · $videos video'),
                style: const TextStyle(fontSize: 14, color: Color(0xE6FFFFFF))),
          ],
        ),
      ),
      const SizedBox(height: 12),
      AppCard(
        child: Column(
          children: [
            row(context.tr('Photos', 'Ảnh'), photos, AppColors.accent),
            row(context.tr('Videos', 'Video'), videos, const Color(0xFF30B067)),
            row(context.tr('Screenshots', 'Ảnh chụp màn hình'), shots, const Color(0xFFFF8A3D)),
          ],
        ),
      ),
      const SizedBox(height: 12),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('Last 12 months', '12 tháng gần nhất'),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: pal.text)),
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
                        child: FractionallySizedBox(
                          heightFactor: (per[i] / maxN).clamp(0.04, 1.0),
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
        case 'rejected':
          return context.tr('Rejected in culling', 'Ảnh loại khi chọn ảnh');
        default:
          return k;
      }
    }

    return [
      HeroCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('Total freed', 'Tổng đã giải phóng'),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xD9FFFFFF))),
            Text(fmtBytes(act.totalBytes),
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1)),
            Text(context.tr('${act.totalCount} items cleaned (size is an estimate)',
                '${act.totalCount} mục đã dọn (dung lượng là ước tính)'),
                style: const TextStyle(fontSize: 13, color: Color(0xE6FFFFFF))),
          ],
        ),
      ),
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
}
