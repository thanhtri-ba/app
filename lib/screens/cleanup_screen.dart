import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../providers/activity_provider.dart';
import '../providers/library_provider.dart';
import '../providers/scan_provider.dart';
import '../providers/settings_provider.dart';
import '../scanner/suggestions.dart';
import '../widgets/common.dart';
import '../widgets/delete_flow.dart';
import '../widgets/motion.dart';
import 'compress_screen.dart';
import 'video_screen.dart';
import 'cull_screen.dart';
import 'vault_screen.dart';

/// One entry of the Cleanup tab (a card in the grid or a row in the list).
class _Tool {
  final IconData icon;
  final Color tint;
  final Color stroke;
  final String title;
  final String sub;
  final int? count; // null = not available yet (e.g. not scanned)
  final VoidCallback onTap;
  const _Tool({
    required this.icon,
    required this.tint,
    required this.stroke,
    required this.title,
    required this.sub,
    required this.count,
    required this.onTap,
  });
}

class CleanupScreen extends StatelessWidget {
  final VoidCallback onOpenReview;
  const CleanupScreen({super.key, required this.onOpenReview});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final scan = context.watch<ScanProvider>();
    final lib = context.watch<LibraryProvider>();
    final act = context.watch<ActivityProvider>();
    final settings = context.watch<SettingsProvider>();

    final scanned = scan.result != null;
    final notScanned = context.tr('Not scanned yet', 'Chưa quét');

    final blue = pal.accentText;
    final amber = pal.dark ? const Color(0xFFFFB454) : const Color(0xFFB25E00);
    final violet = pal.dark ? const Color(0xFFB794F4) : const Color(0xFF6A3FC0);
    const blueTint = Color(0x240071E3);
    const amberTint = Color(0x29E6820E);
    const violetTint = Color(0x297B4DD6);
    const greenTint = Color(0x291A7F37);

    void open(Widget page) => Navigator.of(context).push(softRoute<void>(page));
    void openTool(ToolKind k, {bool needsScan = false}) {
      if (needsScan && !scanned && !scan.scanning) scan.scan(lib, settings);
      open(ToolScreen(kind: k));
    }

    // ---- smart clean: 2 x 2 grid -------------------------------------------------
    final smart = <_Tool>[
      _Tool(
        icon: Icons.filter_none_rounded,
        tint: blueTint,
        stroke: blue,
        title: context.tr('Similar & duplicates', 'Ảnh giống & trùng'),
        sub: scanned ? context.tr('groups', 'nhóm') : notScanned,
        count: scanned ? scan.clusters.length : null,
        onTap: onOpenReview,
      ),
      _Tool(
        icon: Icons.water_drop_outlined,
        tint: amberTint,
        stroke: amber,
        title: context.tr('Blurry photos', 'Ảnh mờ'),
        sub: scanned ? context.tr('photos', 'ảnh') : notScanned,
        count: scanned ? scan.blurry.length : null,
        onTap: () => openTool(ToolKind.blurry, needsScan: true),
      ),
      _Tool(
        icon: Icons.smartphone_outlined,
        tint: violetTint,
        stroke: violet,
        title: context.tr('Screenshots', 'Ảnh chụp màn hình'),
        sub: context.tr('photos', 'ảnh'),
        count: lib.screenshots.length,
        onTap: () => openTool(ToolKind.screenshots),
      ),
      _Tool(
        icon: Icons.smart_display_outlined,
        tint: greenTint,
        stroke: pal.ok,
        title: context.tr('Large videos', 'Video dung lượng lớn'),
        sub: context.tr('videos', 'video'),
        count: lib.videoCount,
        onTap: () {
          scan.loadLarge(lib);
          open(const ToolScreen(kind: ToolKind.large));
        },
      ),
    ];

    // ---- more tools: grouped list ------------------------------------------------
    final more = <_Tool>[
      _Tool(
        icon: Icons.burst_mode_outlined,
        tint: blueTint,
        stroke: blue,
        title: context.tr('Best of burst', 'Ảnh chụp liên tiếp'),
        sub: context.tr('Keep the best shot of each burst', 'Giữ tấm đẹp nhất mỗi chùm'),
        count: scanned ? scan.bursts.length : null,
        onTap: () => openTool(ToolKind.burst, needsScan: true),
      ),
      _Tool(
        icon: Icons.receipt_long_outlined,
        tint: amberTint,
        stroke: amber,
        title: context.tr('Receipts & docs', 'Biên lai & tài liệu'),
        sub: context.tr('Receipts, invoices, paperwork', 'Biên lai, hoá đơn, giấy tờ'),
        count: scanned ? scan.docsShown.length : null,
        onTap: () => openTool(ToolKind.docs, needsScan: true),
      ),
      _Tool(
        icon: Icons.chat_bubble_outline_rounded,
        tint: greenTint,
        stroke: pal.ok,
        title: context.tr('Chat media', 'Ảnh từ chat'),
        sub: context.tr('Zalo, WhatsApp, Telegram...', 'Zalo, WhatsApp, Telegram...'),
        count: lib.chatMedia.length,
        onTap: () => openTool(ToolKind.chat),
      ),
      _Tool(
        icon: Icons.video_library_outlined,
        tint: violetTint,
        stroke: violet,
        title: context.tr('Duplicate videos', 'Video trùng'),
        sub: context.tr('Identical videos', 'Video giống hệt nhau'),
        count: lib.dupVideos.length,
        onTap: () => openTool(ToolKind.dupVideos),
      ),
      _Tool(
        icon: Icons.compress_rounded,
        tint: blueTint,
        stroke: blue,
        title: context.tr('Compress photos', 'Nén ảnh'),
        sub: context.tr('Shrink size, keep quality', 'Giảm dung lượng, giữ chất lượng'),
        count: null,
        onTap: () => open(const CompressScreen()),
      ),
      _Tool(
        icon: Icons.movie_filter_outlined,
        tint: greenTint,
        stroke: pal.ok,
        title: context.tr('Compress videos', 'Nén video'),
        sub: context.tr('Shrink big videos, keep the original until you confirm', 'Giảm video nặng, giữ bản gốc đến khi bạn xác nhận'),
        count: null,
        onTap: () => open(const VideoCompressScreen()),
      ),
      _Tool(
        icon: Icons.lock_outline_rounded,
        tint: violetTint,
        stroke: violet,
        title: context.tr('Private vault', 'Két riêng tư'),
        sub: context.tr('Hide photos behind a PIN', 'Ẩn ảnh sau mã PIN'),
        count: null,
        onTap: () => open(const VaultScreen()),
      ),
    ];

    // ---- suggestions ------------------------------------------------------------
    final now = DateTime.now();
    final sugg = buildSuggestions(
      now: now,
      lastScan: scan.lastScan,
      scanned: scanned,
      screenshotDates: [for (final a in lib.screenshots) a.createDateTime],
      chatDates: [for (final a in lib.chatMedia) a.createDateTime],
      blurryCount: scan.blurry.length,
      dupGroups: scan.clusters.length,
      dupBytes: scan.estimatedDupBytes,
    );
    _Tool suggestionTool(Suggestion g) {
      switch (g.kind) {
        case SuggestKind.scanNow:
          return _Tool(
            icon: Icons.bolt_rounded,
            tint: blueTint,
            stroke: blue,
            title: context.tr('Time for a fresh scan', 'Đến lúc quét lại'),
            sub: g.n < 0
                ? context.tr("You haven't scanned yet", 'Bạn chưa quét lần nào')
                : context.tr('Last scan ${g.n} days ago', 'Lần quét cuối cách đây ${g.n} ngày'),
            count: null,
            onTap: () {
              if (!scan.scanning) scan.scan(lib, settings);
            },
          );
        case SuggestKind.oldShots:
          return _Tool(
            icon: Icons.smartphone_outlined,
            tint: violetTint,
            stroke: violet,
            title: context.tr('${g.n} old screenshots', '${g.n} ảnh chụp màn hình cũ'),
            sub: context.tr('Older than 3 months, already selected', 'Cũ hơn 3 tháng, đã chọn sẵn'),
            count: null,
            onTap: () => open(const ToolScreen(kind: ToolKind.screenshots, olderThanDays: oldShotDays)),
          );
        case SuggestKind.oldChat:
          return _Tool(
            icon: Icons.chat_bubble_outline_rounded,
            tint: greenTint,
            stroke: pal.ok,
            title: context.tr('${g.n} old chat photos', '${g.n} ảnh chat cũ'),
            sub: context.tr('Older than 2 months, already selected', 'Cũ hơn 2 tháng, đã chọn sẵn'),
            count: null,
            onTap: () => open(const ToolScreen(kind: ToolKind.chat, olderThanDays: oldChatDays)),
          );
        case SuggestKind.blurry:
          return _Tool(
            icon: Icons.water_drop_outlined,
            tint: amberTint,
            stroke: amber,
            title: context.tr('${g.n} blurry photos', '${g.n} ảnh mờ'),
            sub: context.tr('Probably failed shots', 'Có thể là ảnh hỏng'),
            count: null,
            onTap: () => openTool(ToolKind.blurry),
          );
        case SuggestKind.duplicates:
          return _Tool(
            icon: Icons.filter_none_rounded,
            tint: blueTint,
            stroke: blue,
            title: context.tr('~${fmtBytes(g.bytes)} in similar photos',
                '~${fmtBytes(g.bytes)} trong ảnh giống nhau'),
            sub: context.tr('${g.groups} groups to review', '${g.groups} nhóm cần duyệt'),
            count: null,
            onTap: onOpenReview,
          );
      }
    }

    var i = 0;
    return SafeArea(
      bottom: false,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, kTabBarSpace),
        children: [
          FadeSlideIn(index: i++, child: PageTitle(context.tr('Cleanup', 'Dọn dẹp'))),
          const SizedBox(height: 16),
          FadeSlideIn(
            index: i++,
            child: _CleanupHero(
              freed: act.totalBytes,
              canFree: scanned ? scan.estimatedFreeable : null,
              scanning: scan.scanning,
              progress: scan.total == 0 ? 0 : scan.done / scan.total,
              scanned: scanned,
              onScan: () => scan.scan(lib, settings),
            ),
          ),
          if (sugg.isNotEmpty) ...[
            FadeSlideIn(
              index: i++,
              child: _SectionLabel(context.tr('SUGGESTED FOR YOU', 'GỢI Ý CHO BẠN')),
            ),
            FadeSlideIn(
              index: i++,
              child: AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var k = 0; k < sugg.length; k++) ...[
                      if (k > 0)
                        Container(height: 1, margin: const EdgeInsets.only(left: 64), color: pal.line),
                      _ToolRow(tool: suggestionTool(sugg[k])),
                    ],
                  ],
                ),
              ),
            ),
          ],
          FadeSlideIn(
            index: i++,
            child: _SectionLabel(context.tr('SMART CLEAN', 'DỌN THÔNG MINH')),
          ),
          for (var r = 0; r < smart.length; r += 2)
            FadeSlideIn(
              index: i++,
              child: Padding(
                padding: EdgeInsets.only(bottom: r + 2 < smart.length ? 12 : 0),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _ToolTile(tool: smart[r])),
                      const SizedBox(width: 12),
                      Expanded(child: _ToolTile(tool: smart[r + 1])),
                    ],
                  ),
                ),
              ),
            ),
          FadeSlideIn(
            index: i++,
            child: _SectionLabel(context.tr('MORE TOOLS', 'CÔNG CỤ KHÁC')),
          ),
          FadeSlideIn(
            index: i++,
            child: AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var k = 0; k < more.length; k++) ...[
                    if (k > 0)
                      Container(height: 1, margin: const EdgeInsets.only(left: 64), color: pal.line),
                    _ToolRow(tool: more[k]),
                  ],
                ],
              ),
            ),
          ),
          FadeSlideIn(
            index: i++,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 18, 8, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(Icons.history_rounded, size: 18, color: pal.sec),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.tr(
                          'Deleted photos stay in Recently Deleted for 30 days, so you can always get them back.',
                          'Ảnh đã xoá nằm trong Đã xoá gần đây 30 ngày, nên bạn luôn có thể khôi phục.'),
                      style: TextStyle(fontSize: 13, height: 1.4, color: pal.sec),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 24, 6, 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: context.pal.sec,
        ),
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  final _Tool tool;
  final double size;
  const _IconChip(this.tool, {this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: tool.tint, borderRadius: BorderRadius.circular(size * 0.3)),
      child: Icon(tool.icon, color: tool.stroke, size: size * 0.55),
    );
  }
}

/// Compact square-ish card: icon, big animated count, title and unit.
class _ToolTile extends StatelessWidget {
  final _Tool tool;
  const _ToolTile({required this.tool});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final c = tool.count;
    return AppCard(
      onTap: tool.onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconChip(tool),
              const Spacer(),
              if (c != null)
                CountUp(
                  value: c,
                  format: (v) => fmtCount(v.round()),
                  style: TextStyle(
                    fontSize: 26,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: c > 0 ? pal.accentText : pal.sec,
                  ),
                )
              else
                Icon(Icons.north_east_rounded, size: 18, color: pal.sec),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(
                tool.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 15, height: 1.25, fontWeight: FontWeight.w700, color: pal.text),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            tool.sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: pal.sec),
          ),
        ],
      ),
    );
  }
}

/// Row inside the grouped "More tools" card.
class _ToolRow extends StatelessWidget {
  final _Tool tool;
  const _ToolRow({required this.tool});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final c = tool.count;
    return Pressable(
      onTap: tool.onTap,
      scale: 0.985,
      haptic: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            _IconChip(tool, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tool.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600, color: pal.text)),
                  const SizedBox(height: 1),
                  Text(tool.sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: pal.sec)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (c != null && c > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: pal.pill, borderRadius: BorderRadius.circular(99)),
                child: Text(fmtCount(c),
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, color: pal.accentText)),
              ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 22, color: pal.sec),
          ],
        ),
      ),
    );
  }
}

class _CleanupHero extends StatelessWidget {
  final int freed;
  final int? canFree;
  final bool scanning;
  final double progress;
  final bool scanned;
  final VoidCallback onScan;

  const _CleanupHero({
    required this.freed,
    required this.canFree,
    required this.scanning,
    required this.progress,
    required this.scanned,
    required this.onScan,
  });

  Widget _stat(String label, int? value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xE0FFFFFF))),
        const SizedBox(height: 4),
        if (value == null)
          const Text('—',
              style: TextStyle(fontSize: 26, height: 1.1, fontWeight: FontWeight.w800))
        else
          CountUp(
            value: value,
            format: (v) => fmtBytes(v),
            style: const TextStyle(
                fontSize: 26, height: 1.1, fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return HeroCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _stat(context.tr('Freed so far', 'Đã giải phóng'), freed)),
              Container(width: 1, height: 44, color: const Color(0x33FFFFFF)),
              const SizedBox(width: 18),
              Expanded(child: _stat(context.tr('Can free up', 'Có thể giải phóng'), canFree)),
            ],
          ),
          const SizedBox(height: 18),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: scanning ? _ScanBar(progress: progress) : _ScanButton(scanned: scanned, onTap: onScan),
          ),
        ],
      ),
    );
  }
}

class _ScanButton extends StatelessWidget {
  final bool scanned;
  final VoidCallback onTap;
  const _ScanButton({required this.scanned, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      key: const ValueKey('btn'),
      onTap: onTap,
      scale: 0.97,
      haptic: true,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(23)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(scanned ? Icons.refresh_rounded : Icons.bolt_rounded,
                size: 20, color: AppColors.accentDeep),
            const SizedBox(width: 6),
            Text(
              scanned ? context.tr('Scan again', 'Quét lại') : context.tr('Quick scan', 'Quét nhanh'),
              style: const TextStyle(
                  color: AppColors.accentDeep, fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanBar extends StatelessWidget {
  final double progress;
  const _ScanBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);
    return ClipRRect(
      key: const ValueKey('bar'),
      borderRadius: BorderRadius.circular(23),
      child: Container(
        height: 46,
        color: const Color(0x33FFFFFF),
        child: Stack(
          children: [
            Positioned.fill(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: p),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                builder: (_, v, __) => FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: v,
                  child: Container(color: const Color(0x4DFFFFFF)),
                ),
              ),
            ),
            Center(
              child: Text(
                '${context.tr('Scanning', 'Đang quét')} ${(p * 100).round()}%',
                style: const TextStyle(
                    color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum ToolKind { blurry, screenshots, large, burst, docs, chat, dupVideos }

class ToolScreen extends StatefulWidget {
  final ToolKind kind;

  /// Screenshots / chat media: pre-select items older than this many days.
  final int? olderThanDays;
  const ToolScreen({super.key, required this.kind, this.olderThanDays});

  @override
  State<ToolScreen> createState() => _ToolScreenState();
}

class _ToolScreenState extends State<ToolScreen> {
  bool _busy = false;

  String _kindName() {
    switch (widget.kind) {
      case ToolKind.blurry:
        return 'blurry';
      case ToolKind.screenshots:
        return 'screenshots';
      case ToolKind.large:
        return 'large';
      case ToolKind.burst:
        return 'burst';
      case ToolKind.docs:
        return 'docs';
      case ToolKind.chat:
        return 'chat';
      case ToolKind.dupVideos:
        return 'dupvideos';
    }
  }

  @override
  void initState() {
    super.initState();
    // Start with a clean selection for this tool.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final scan = context.read<ScanProvider>();
      scan.toolMarked.clear();
      if (widget.kind == ToolKind.burst) {
        // Pre-select everything except the sharpest shot of each burst.
        scan.setTool([
          for (final c in scan.bursts)
            for (var i = 0; i < c.items.length; i++)
              if (i != c.best) c.items[i].id
        ], true);
      } else if (widget.olderThanDays != null &&
          (widget.kind == ToolKind.screenshots || widget.kind == ToolKind.chat)) {
        final lib = context.read<LibraryProvider>();
        final limit = DateTime.now().subtract(Duration(days: widget.olderThanDays!));
        final src = widget.kind == ToolKind.screenshots ? lib.screenshots : lib.chatMedia;
        scan.setTool([
          for (final a in src)
            if (a.createDateTime.isBefore(limit)) a.id
        ], true);
      } else {
        scan.setTool(const <String>[], false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final scan = context.watch<ScanProvider>();
    final lib = context.watch<LibraryProvider>();

    late final List<AssetEntity> items;
    final extra = <String, String>{};
    var loading = false;
    String title;
    switch (widget.kind) {
      case ToolKind.blurry:
        title = context.tr('Blurry photos', 'Ảnh mờ');
        items = scan.blurry.map((b) => b.asset).toList();
        for (final b in scan.blurry) {
          extra[b.asset.id] = '◎ ${b.sharp.round()}';
        }
        loading = scan.scanning;
        break;
      case ToolKind.screenshots:
        title = context.tr('Screenshots', 'Ảnh chụp màn hình');
        items = lib.screenshots;
        break;
      case ToolKind.large:
        title = context.tr('Large videos', 'Video dung lượng lớn');
        final l = scan.large ?? const <LargeItem>[];
        items = l.map((x) => x.asset).toList();
        for (final x in l) {
          extra[x.asset.id] = fmtBytes(x.bytes);
        }
        loading = scan.loadingLarge || scan.large == null;
        break;
      case ToolKind.burst:
        title = context.tr('Best of burst', 'Ảnh chụp liên tiếp');
        final list = <AssetEntity>[];
        for (final c in scan.bursts) {
          for (var i = 0; i < c.items.length; i++) {
            list.add(c.items[i]);
            extra[c.items[i].id] = i == c.best ? context.tr('BEST', 'ĐẸP NHẤT') : '◎ ${c.sharp[i].round()}';
          }
        }
        items = list;
        loading = scan.scanning;
        break;
      case ToolKind.docs:
        title = context.tr('Receipts & docs', 'Biên lai & tài liệu');
        items = scan.docsShown;
        loading = scan.scanning;
        break;
      case ToolKind.chat:
        title = context.tr('Chat media', 'Ảnh từ ứng dụng chat');
        items = lib.chatMedia;
        break;
      case ToolKind.dupVideos:
        title = context.tr('Duplicate videos', 'Video trùng');
        final dupList = <AssetEntity>[];
        for (var g = 0; g < lib.dupVideos.length; g++) {
          for (final v in lib.dupVideos[g]) {
            dupList.add(v);
            extra[v.id] = '#${g + 1} · ${fmtDuration(v.duration)}';
          }
        }
        items = dupList;
        break;
    }

    final sel = items.where((a) => scan.toolMarked.contains(a.id)).toList();
    final allOn = items.isNotEmpty && sel.length == items.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: () => scan.setTool(items.map((a) => a.id), !allOn),
              child: Text(allOn
                  ? context.tr('Deselect all', 'Bỏ chọn')
                  : context.tr('Select all', 'Chọn tất cả')),
            ),
        ],
      ),
      body: Column(
        children: [
          if (widget.kind == ToolKind.docs) _OcrBar(scan: scan),
          Expanded(
            child: loading && items.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 14),
                  Text(context.tr('Looking...', 'Đang tìm...'), style: TextStyle(color: pal.sec)),
                ],
              ),
            )
          : items.isEmpty
              ? Center(
                  child: FadeSlideIn(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                              color: pal.ok.withOpacity(0.14), shape: BoxShape.circle),
                          child: Icon(Icons.check_rounded, size: 42, color: pal.ok),
                        ),
                        const SizedBox(height: 16),
                        Text(context.tr('Nothing to clean', 'Không có gì cần dọn'),
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w800, color: pal.text)),
                        const SizedBox(height: 4),
                        Text(context.tr('Nothing found here.', 'Không tìm thấy gì ở đây.'),
                            style: TextStyle(color: pal.sec)),
                      ],
                    ),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, mainAxisSpacing: 6, crossAxisSpacing: 6),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final a = items[i];
                    final on = scan.toolMarked.contains(a.id);
                    final tile = GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          scan.toggleTool(a.id);
                        },
                        onLongPress: () => Navigator.of(context).push(MaterialPageRoute<void>(
                            builder: (_) => CullScreen(assets: items, initial: i))),
                        child: AnimatedScale(
                          scale: on ? 0.93 : 1,
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                PhotoThumb(asset: a, size: 300),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  color: on ? const Color(0x66000000) : Colors.transparent,
                                ),
                                if (extra[a.id] != null)
                                  Positioned(left: 5, bottom: 5, child: Tag(extra[a.id]!)),
                                Positioned(
                                  right: 6,
                                  top: 6,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: on ? AppColors.danger : Colors.black38,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: AnimatedScale(
                                      scale: on ? 1 : 0,
                                      duration: const Duration(milliseconds: 200),
                                      curve: Curves.easeOutBack,
                                      child: const Icon(Icons.check_rounded,
                                          size: 14, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    );
                    // Only the first screenful animates in, so scrolling never pops.
                    return i < 18
                        ? FadeSlideIn(
                            index: i ~/ 3,
                            dy: 12,
                            duration: const Duration(milliseconds: 380),
                            child: tile)
                        : tile;
                  },
                ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: PillButton(
            label: sel.isEmpty
                ? context.tr('Tap photos to mark them', 'Chạm ảnh để đánh dấu')
                : context.tr('Delete ${sel.length} items', 'Xoá ${sel.length} mục'),
            danger: sel.isNotEmpty,
            filled: sel.isNotEmpty,
            onTap: sel.isEmpty || _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    await confirmAndDelete(context, assets: sel, kind: _kindName());
                    if (mounted) setState(() => _busy = false);
                  },
          ),
        ),
      ),
    );
  }
}

/// Optional on-device text recognition to keep only real receipts / documents.
class _OcrBar extends StatelessWidget {
  final ScanProvider scan;
  const _OcrBar({required this.scan});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final refined = scan.docsRefined != null;
    final running = scan.ocrRunning;
    final progress = scan.ocrTotal == 0 ? 0.0 : scan.ocrDone / scan.ocrTotal;

    String title;
    String sub;
    if (running) {
      title = context.tr('Reading text...', 'Đang đọc chữ...');
      sub = '${scan.ocrDone} / ${scan.ocrTotal}';
    } else if (refined) {
      title = context.tr('Refined with text recognition', 'Đã lọc bằng nhận dạng chữ');
      sub = context.tr('${scan.docsShown.length} of ${scan.docs.length} kept',
          'Giữ lại ${scan.docsShown.length} / ${scan.docs.length}');
    } else {
      title = context.tr('Refine with text recognition', 'Lọc chính xác bằng nhận dạng chữ');
      sub = context.tr('Keeps only pages that really contain receipt or document text. Runs on this device.',
          'Chỉ giữ ảnh thật sự có chữ biên lai/tài liệu. Chạy ngay trên máy.');
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.text_fields_rounded, color: pal.accentText),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700, color: pal.text)),
                      const SizedBox(height: 2),
                      Text(sub, style: TextStyle(fontSize: 12.5, height: 1.3, color: pal.sec)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: running
                      ? scan.cancelOcr
                      : (refined ? scan.resetRefine : (scan.docs.isEmpty ? null : scan.refineDocs)),
                  child: Text(running
                      ? context.tr('Stop', 'Dừng')
                      : (refined ? context.tr('Reset', 'Đặt lại') : context.tr('Run', 'Chạy'))),
                ),
              ],
            ),
            if (running) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(value: progress, minHeight: 5),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
