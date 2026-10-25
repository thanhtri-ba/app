import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../providers/library_provider.dart';
import '../providers/scan_provider.dart';
import '../providers/settings_provider.dart';
import '../scanner/analyzer.dart';
import '../widgets/common.dart';
import '../widgets/delete_flow.dart';
import '../widgets/motion.dart';

class ReviewScreen extends StatelessWidget {
  final VoidCallback onOpenCleanup;
  const ReviewScreen({super.key, required this.onOpenCleanup});

  @override
  Widget build(BuildContext context) {
    final scan = context.watch<ScanProvider>();
    final lib = context.watch<LibraryProvider>();
    final settings = context.watch<SettingsProvider>();
    final pal = context.pal;

    Widget body;
    if (scan.scanning) {
      body = _Scanning(scan: scan);
    } else if (scan.result == null) {
      body = _Intro(lib: lib, settings: settings, scan: scan);
    } else if (scan.clusters.isEmpty) {
      body = _Empty(onRescan: () => scan.scan(lib, settings));
    } else {
      body = _Results(scan: scan);
    }

    final shots = scan.clusters.fold<int>(0, (a, c) => a + c.items.length);
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
                Expanded(child: PageTitle(context.tr('Review', 'Duyệt nhanh'))),
                if (scan.result != null && !scan.scanning && scan.clusters.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: pal.card,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: pal.line),
                    ),
                    child: Text('${scan.reviewMarked.length} / $shots',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: pal.text)),
                  ),
                if (scan.result != null && !scan.scanning)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => scan.scan(lib, settings),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 4),
                      child: Icon(Icons.refresh_rounded, color: pal.sec),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  final LibraryProvider lib;
  final SettingsProvider settings;
  final ScanProvider scan;
  const _Intro({required this.lib, required this.settings, required this.scan});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final n = lib.photoCount < settings.scanLimit ? lib.photoCount : settings.scanLimit;
    return ListView(
      padding: const EdgeInsets.only(top: 10, bottom: kTabBarSpace),
      physics: const BouncingScrollPhysics(),
      children: [
        FadeSlideIn(
          child: HeroCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('Find similar shots', 'Tìm ảnh giống nhau'),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                context.tr(
                    'We group near-identical photos, keep the sharpest one of each group, and let you clear the rest in one go.',
                    'Ảnh gần giống nhau được gom nhóm, giữ tấm nét nhất mỗi nhóm, và bạn xoá phần còn lại cùng lúc.'),
                style: const TextStyle(fontSize: 14, height: 1.4, color: Color(0xE6FFFFFF)),
              ),
              const SizedBox(height: 16),
              Pressable(
                onTap: () => scan.scan(lib, settings),
                haptic: true,
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                  child: Text(
                    context.tr('Scan $n photos', 'Quét $n ảnh'),
                    style: const TextStyle(
                        color: AppColors.accentDeep, fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        )),
        const SizedBox(height: 14),
        FadeSlideIn(
          index: 1,
          child: AppCard(
          child: Text(
            context.tr(
                settings.scanLimit >= 1000000
                    ? 'Scanning runs on this device and covers your whole library. Later scans only analyse new photos.'
                    : 'Scanning runs on this device. The newest ${settings.scanLimit} photos are analysed; change this in Settings.',
                settings.scanLimit >= 1000000
                    ? 'Việc quét chạy ngay trên máy và bao phủ cả thư viện. Các lần sau chỉ phân tích ảnh mới.'
                    : 'Việc quét chạy ngay trên máy. ${settings.scanLimit} ảnh mới nhất được phân tích; có thể đổi trong Cài đặt.'),
            style: TextStyle(color: pal.sec, fontSize: 13, height: 1.4),
          ),
        )),
      ],
    );
  }
}

class _Scanning extends StatelessWidget {
  final ScanProvider scan;
  const _Scanning({required this.scan});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final p = scan.total == 0 ? 0.0 : scan.done / scan.total;
    return Padding(
      padding: const EdgeInsets.only(bottom: kTabBarSpace),
      child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              fit: StackFit.expand,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: p),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  builder: (_, v, __) => CircularProgressIndicator(
                    value: p == 0 ? null : v,
                    strokeWidth: 8,
                    backgroundColor: pal.line,
                  ),
                ),
                Center(
                  child: Pulse(
                    child: Text('${(p * 100).round()}%',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: pal.text)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(context.tr('Analysing photos...', 'Đang phân tích ảnh...'),
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: pal.text)),
          const SizedBox(height: 4),
          Text('${scan.done} / ${scan.total}', style: TextStyle(color: pal.sec)),
          const SizedBox(height: 16),
          TextButton(onPressed: scan.cancelScan, child: Text(context.tr('Stop', 'Dừng'))),
        ],
      ),
    ));
  }
}

class _Empty extends StatelessWidget {
  final VoidCallback onRescan;
  const _Empty({required this.onRescan});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Padding(
      padding: const EdgeInsets.only(bottom: kTabBarSpace),
      child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.6, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.elasticOut,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                  color: pal.ok.withOpacity(0.14), borderRadius: BorderRadius.circular(46)),
              child: Icon(Icons.check_rounded, size: 46, color: pal.ok),
            ),
          ),
          const SizedBox(height: 20),
          Text(context.tr('All caught up', 'Đã gọn gàng'),
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: pal.text)),
          const SizedBox(height: 6),
          Text(context.tr('No similar photos found.', 'Không tìm thấy ảnh giống nhau.'),
              style: TextStyle(color: pal.sec)),
          const SizedBox(height: 18),
          PillButton(label: context.tr('Scan again', 'Quét lại'), filled: false, onTap: onRescan),
        ],
      ),
    ));
  }
}

class _Results extends StatefulWidget {
  final ScanProvider scan;
  const _Results({required this.scan});

  @override
  State<_Results> createState() => _ResultsState();
}

class _ResultsState extends State<_Results> {
  bool _busy = false;
  int _src = 0; // 0 worst first, 1 this month, 2 all

  int _bytesFor(Cluster c, bool onlyMarked, Set<String> marked) {
    var sum = 0;
    for (var i = 0; i < c.items.length; i++) {
      final a = c.items[i];
      final include = onlyMarked ? marked.contains(a.id) : i != c.best;
      if (include) sum += (a.width * a.height * 0.35).round();
    }
    return sum;
  }

  Future<void> _delete() async {
    if (_busy) return;
    setState(() => _busy = true);
    final list = widget.scan.reviewMarkedAssets();
    await confirmAndDelete(context, assets: list, kind: 'review');
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final scan = widget.scan;
    final cl = scan.clusters;
    final marked = scan.reviewMarked;
    var shots = 0;
    var potential = 0;
    var markedBytes = 0;
    for (final c in cl) {
      shots += c.items.length;
      potential += _bytesFor(c, false, marked);
      markedBytes += _bytesFor(c, true, marked);
    }
    final pct = potential == 0 ? 0.0 : (markedBytes / potential).clamp(0.0, 1.0);

    // Source filter chips: keep original indices so scan.keepBest(index) stays valid.
    final now = DateTime.now();
    var order = <int>[for (var i = 0; i < cl.length; i++) i];
    if (_src == 0) {
      final free = {for (final i in order) i: _bytesFor(cl[i], false, marked)};
      order.sort((a, b) => free[b]!.compareTo(free[a]!));
    } else if (_src == 1) {
      order = order
          .where((i) =>
              cl[i].items.first.createDateTime.year == now.year &&
              cl[i].items.first.createDateTime.month == now.month)
          .toList();
    }
    final chipLabels = [
      context.tr('Worst first', 'Tệ nhất'),
      context.tr('This month', 'Tháng này'),
      context.tr('All media', 'Tất cả'),
    ];
    final pal = context.pal;

    return Column(
      children: [
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: chipLabels.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final on = i == _src;
              return Pressable(
                onTap: () => setState(() => _src = i),
                scale: 0.94,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: on ? AppColors.accent : pal.card,
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(color: pal.line),
                  ),
                  child: Text(chipLabels[i],
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: on ? Colors.white : pal.text)),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        HeroCard(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('$shots similar shots in ${cl.length} groups',
                              '$shots ảnh giống nhau trong ${cl.length} nhóm'),
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xD9FFFFFF)),
                        ),
                        const SizedBox(height: 2),
                        CountUp(
                            value: markedBytes,
                            duration: const Duration(milliseconds: 450),
                            format: (v) => '~${fmtBytes(v)}',
                            style: const TextStyle(
                                fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.8)),
                      ],
                    ),
                  ),
                  Pressable(
                    onTap: scan.autoAll,
                    haptic: true,
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration:
                          BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                      child: Text(context.tr('Auto-pick', 'Tự chọn'),
                          style: const TextStyle(
                              color: AppColors.accentDeep, fontSize: 14, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: pct),
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => LinearProgressIndicator(
                    value: v,
                    minHeight: 5,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.tr('marked of ~${fmtBytes(potential)} that can be freed',
                        'đã đánh dấu / ~${fmtBytes(potential)} có thể giải phóng'),
                    style: const TextStyle(fontSize: 12, color: Color(0xE6FFFFFF)),
                  ),
                  GestureDetector(
                    onTap: scan.resetReview,
                    child: Text(context.tr('Reset', 'Đặt lại'),
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            decoration: TextDecoration.underline)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 6, bottom: 8),
            itemCount: order.length,
            itemBuilder: (context, i) =>
                _ClusterCard(index: order[i], cluster: cl[order[i]], scan: scan),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: kTabBarSpace),
          child: SizedBox(
            width: double.infinity,
            child: PillButton(
              label: marked.isEmpty
                  ? context.tr('Tap photos to mark them', 'Chạm ảnh để đánh dấu')
                  : context.tr('Delete ${marked.length} photos', 'Xoá ${marked.length} ảnh'),
              danger: marked.isNotEmpty,
              filled: marked.isNotEmpty,
              onTap: marked.isEmpty || _busy ? null : _delete,
            ),
          ),
        ),
      ],
    );
  }
}

class _ClusterCard extends StatelessWidget {
  final int index;
  final Cluster cluster;
  final ScanProvider scan;
  const _ClusterCard({required this.index, required this.cluster, required this.scan});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final c = cluster;
    final marked = scan.reviewMarked;
    final order = <int>[c.best, for (var i = 0; i < c.items.length; i++) if (i != c.best) i];
    final onlyBest = [
      for (var i = 0; i < c.items.length; i++) i == c.best ? !marked.contains(c.items[i].id) : marked.contains(c.items[i].id)
    ].every((x) => x);
    final first = c.items.first.createDateTime;
    final height = order.length > 3 ? 172.0 : 150.0;

    Widget tile(int idx, bool big) {
      final a = c.items[idx];
      final del = marked.contains(a.id);
      final isBest = idx == c.best;
      return GestureDetector(
        onTap: () => scan.toggleReview(a.id),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(big ? 14 : 10),
            border: Border.all(
                color: isBest && !del ? const Color(0xFF30D158) : Colors.transparent, width: 3),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(big ? 11 : 7),
            child: Stack(
              fit: StackFit.expand,
              children: [
                AnimatedOpacity(
                    opacity: del ? 0.35 : 1,
                    duration: const Duration(milliseconds: 180),
                    child: PhotoThumb(asset: a, size: big ? 500 : 300)),
                Positioned(left: 5, top: 5, child: Tag('◎ ${c.sharp[idx].round()}')),
                Positioned(
                  left: 5,
                  bottom: 5,
                  child: Tag(
                    isBest ? context.tr('BEST', 'ĐẸP NHẤT') : context.tr('Softer', 'Kém nét hơn'),
                    color: isBest ? const Color(0xF21A7F37) : const Color(0x8C000000),
                  ),
                ),
                if (del)
                  Positioned(
                    right: 5,
                    top: 5,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.14), shape: BoxShape.circle),
                  child: Text('${index + 1}',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800, color: pal.accentText)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fmtDateTime(first),
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: pal.text)),
                      Text(context.tr('${c.items.length} similar shots', '${c.items.length} ảnh giống nhau'),
                          style: TextStyle(fontSize: 12, color: pal.sec)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => scan.keepBest(index),
                  child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: onlyBest ? pal.ok.withOpacity(0.16) : AppColors.accent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      onlyBest
                          ? context.tr('Best kept ✓', 'Đã giữ đẹp nhất ✓')
                          : context.tr('Keep best', 'Giữ tấm đẹp nhất'),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: onlyBest ? pal.ok : Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: height,
              child: Row(
                children: [
                  Expanded(flex: 17, child: tile(order[0], true)),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 10,
                    child: Column(
                      children: [
                        for (var k = 1; k < order.length; k++) ...[
                          if (k > 1) const SizedBox(height: 6),
                          Expanded(child: tile(order[k], false)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
