import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../providers/library_provider.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import 'cull_screen.dart';
import 'day_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  int _mode = 0; // 0 calendar, 1 all media
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final lib = context.watch<LibraryProvider>();

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: PageTitle(context.tr('Library', 'Thư viện'))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: pal.card,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: pal.line),
                  ),
                  child: Text(
                      context.tr('${fmtCount(lib.assets.length)} items',
                          '${fmtCount(lib.assets.length)} mục'),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: pal.text)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SegControl(
              labels: [context.tr('Calendar', 'Lịch'), context.tr('All media', 'Tất cả')],
              index: _mode,
              onChanged: (i) => setState(() => _mode = i),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: _mode == 0
                  ? _CalendarView(
                      month: _month,
                      onMonth: (m) => setState(() => _month = m),
                    )
                  : _AllMedia(assets: lib.assets),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllMedia extends StatefulWidget {
  final List<AssetEntity> assets;
  const _AllMedia({required this.assets});

  @override
  State<_AllMedia> createState() => _AllMediaState();
}

class _AllMediaState extends State<_AllMedia> {
  int _f = 0; // 0 all, 1 photos, 2 videos

  @override
  Widget build(BuildContext context) {
    final all = widget.assets;
    final assets = _f == 0
        ? all
        : all.where((a) => (a.type == AssetType.video) == (_f == 2)).toList();
    return Column(
      children: [
        SegControl(
          labels: [
            context.tr('All', 'Tất cả'),
            context.tr('Photos', 'Ảnh'),
            context.tr('Videos', 'Video'),
          ],
          index: _f,
          onChanged: (i) => setState(() => _f = i),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.only(bottom: kTabBarSpace),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, mainAxisSpacing: 6, crossAxisSpacing: 6),
            itemCount: assets.length,
            itemBuilder: (context, i) {
              final a = assets[i];
              return GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => CullScreen(assets: assets, initial: i))),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x66000000), blurRadius: 16, spreadRadius: -8, offset: Offset(0, 6)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        PhotoThumb(asset: a, size: 300),
                        if (a.type == AssetType.video)
                          Positioned(left: 5, bottom: 5, child: Tag('▶ ${fmtDuration(a.duration)}')),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CalendarView extends StatelessWidget {
  final DateTime month;
  final ValueChanged<DateTime> onMonth;
  const _CalendarView({required this.month, required this.onMonth});

  static Color _heat(int n, Pal pal) {
    if (n == 0) return pal.card;
    if (n < 50) return AppColors.accent.withOpacity(0.2);
    if (n < 300) return AppColors.accent.withOpacity(0.42);
    if (n < 1000) return AppColors.accent.withOpacity(0.7);
    return AppColors.accentDeep;
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final lib = context.watch<LibraryProvider>();
    final dim = DateTime(month.year, month.month + 1, 0).day;
    final offset = (DateTime(month.year, month.month, 1).weekday + 6) % 7; // Monday first
    final counts = <int>[];
    for (var d = 1; d <= dim; d++) {
      counts.add(lib.byDay[dayKey(DateTime(month.year, month.month, d))]?.length ?? 0);
    }
    final total = counts.fold<int>(0, (a, b) => a + b);
    final active = counts.where((n) => n > 0).length;
    var maxN = 0;
    var maxDay = 1;
    for (var i = 0; i < counts.length; i++) {
      if (counts[i] > maxN) {
        maxN = counts[i];
        maxDay = i + 1;
      }
    }
    final topDays = (<int>[for (var i = 1; i <= dim; i++) if (counts[i - 1] > 0) i]
          ..sort((a, b) => counts[b - 1].compareTo(counts[a - 1])))
        .take(5)
        .toList();
    final wd = context.tr('Mon Tue Wed Thu Fri Sat Sun', 'T2 T3 T4 T5 T6 T7 CN').split(' ');
    final title = context.tr('${monthsEn[month.month - 1]} ${month.year}',
        'Tháng ${month.month} ${month.year}');
    final today = DateTime.now();

    void openDay(int d) {
      final key = dayKey(DateTime(month.year, month.month, d));
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DayScreen(dayKey: key)));
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: kTabBarSpace),
      children: stagger([
        HeroCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xD9FFFFFF))),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(fmtCount(total),
                      style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1)),
                  const SizedBox(width: 8),
                  Text(context.tr('shots · $active shoot days', 'ảnh · $active ngày chụp'),
                      style: const TextStyle(fontSize: 14, color: Color(0xE6FFFFFF))),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 44,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < counts.length; i++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                                begin: 0.05,
                                end: maxN == 0 ? 0.05 : (counts[i] / maxN).clamp(0.05, 1.0)),
                            duration: Duration(milliseconds: 500 + i * 18),
                            curve: Curves.easeOutCubic,
                            builder: (_, v, child) =>
                                FractionallySizedBox(heightFactor: v, child: child),
                            child: Container(
                              decoration: BoxDecoration(
                                color: counts[i] == maxN && maxN > 0 ? Colors.white : Colors.white54,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Pressable(
                onTap: maxN == 0 ? null : () => openDay(maxDay),
                haptic: true,
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration:
                      BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(19)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        maxN == 0
                            ? context.tr('No shots this month', 'Tháng này chưa có ảnh')
                            : context.tr('Open busiest day · ${fmtCount(maxN)} shots',
                                'Mở ngày đông nhất · ${fmtCount(maxN)} ảnh'),
                        style: const TextStyle(
                            color: AppColors.accentDeep, fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _RoundNav(
                        icon: Icons.chevron_left_rounded,
                        onTap: () => onMonth(DateTime(month.year, month.month - 1))),
                    Column(
                      children: [
                        Text(title,
                            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: pal.text)),
                        Text(
                            context.tr('${fmtCount(total)} shots · $active days',
                                '${fmtCount(total)} ảnh · $active ngày'),
                            style: TextStyle(fontSize: 13, color: pal.sec)),
                      ],
                    ),
                    _RoundNav(
                        icon: Icons.chevron_right_rounded,
                        onTap: () => onMonth(DateTime(month.year, month.month + 1))),
                  ],
                ),
              ),
              Row(
                children: [
                  for (final w in wd)
                    Expanded(
                      child: Center(
                        child: Text(w,
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700, color: pal.sec)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 5),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7, mainAxisSpacing: 5, crossAxisSpacing: 5, childAspectRatio: 1 / 1.08),
                itemCount: offset + dim,
                itemBuilder: (context, i) {
                  if (i < offset) return const SizedBox.shrink();
                  final d = i - offset + 1;
                  final n = counts[d - 1];
                  final isToday =
                      today.year == month.year && today.month == month.month && today.day == d;
                  final strong = n >= 300;
                  return GestureDetector(
                    onTap: n == 0 ? null : () => openDay(d),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _heat(n, pal),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: isToday ? pal.accentText : pal.line, width: isToday ? 2 : 1),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('$d',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: strong ? Colors.white : pal.text)),
                          if (n > 0)
                            Text(n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n',
                                style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: strong ? Colors.white : pal.text)),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(context.tr('Less', 'Ít'),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: pal.sec)),
                  const SizedBox(width: 6),
                  for (final n in const [0, 10, 100, 500, 2000])
                    Container(
                      width: 16,
                      height: 16,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: _heat(n, pal),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: pal.line),
                      ),
                    ),
                  Text(context.tr('More', 'Nhiều'),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: pal.sec)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final (i, st) in [
              (context.tr('Shots', 'Ảnh'), fmtCount(total)),
              (context.tr('Active days', 'Ngày chụp'), '$active'),
              (context.tr('Avg / day', 'TB / ngày'), active == 0 ? '0' : fmtCount((total / active).round())),
            ].indexed) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: AppCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(st.$1,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: pal.sec)),
                      const SizedBox(height: 2),
                      Text(st.$2,
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                              color: pal.text)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        if (maxN > 0) ...[
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
                  child: Text(context.tr('Busiest days', 'Ngày chụp nhiều nhất'),
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: pal.text)),
                ),
                for (final d in topDays)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => openDay(d),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(border: Border(top: BorderSide(color: pal.line))),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(context.tr('${monthsEn[month.month - 1]} $d', '$d/${month.month}'),
                                  style: TextStyle(
                                      fontSize: 15, fontWeight: FontWeight.w600, color: pal.text)),
                              Text(fmtCount(counts[d - 1]),
                                  style: TextStyle(fontSize: 15, color: pal.sec)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: counts[d - 1] / maxN,
                              minHeight: 6,
                              backgroundColor: pal.line,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ], tag: 'm${month.year}-${month.month}'),
    );
  }
}

class _RoundNav extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundNav({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: pal.card,
          shape: BoxShape.circle,
          border: Border.all(color: pal.line),
        ),
        child: Icon(icon, size: 22, color: pal.text),
      ),
    );
  }
}
