import 'dart:io';
import 'dart:ui' as ui;

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/achievements.dart';
import '../core/format.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../providers/activity_provider.dart';
import 'common.dart';
import 'motion.dart';

/// Result sheet shown after a successful cleanup: freed space counting up, streak, monthly
/// goal, newly unlocked badges and a shareable card.
Future<void> showCelebration(
  BuildContext context, {
  required int count,
  required int bytes,
  required List<BadgeDef> newBadges,
}) {
  HapticFeedback.mediumImpact();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CelebrationSheet(count: count, bytes: bytes, newBadges: newBadges),
  );
}

class _CelebrationSheet extends StatefulWidget {
  final int count;
  final int bytes;
  final List<BadgeDef> newBadges;
  const _CelebrationSheet({required this.count, required this.bytes, required this.newBadges});

  @override
  State<_CelebrationSheet> createState() => _CelebrationSheetState();
}

class _CelebrationSheetState extends State<_CelebrationSheet> {
  final GlobalKey _cardKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share(String text) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final b = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (b == null) return;
      final image = await b.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return;
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/photo_cleaner_share.png');
      await f.writeAsBytes(data.buffer.asUint8List(), flush: true);
      await SharePlus.instance.share(ShareParams(text: text, files: [XFile(f.path)]));
    } catch (e) {
      debugPrint('share failed: $e');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final act = context.watch<ActivityProvider>();
    final streak = act.streak;
    final goalBytes = act.goalMb * 1024 * 1024;
    final shareText = context.tr(
      'I just freed ${fmtBytes(widget.bytes)} with Photo Cleaner!',
      'Mình vừa giải phóng ${fmtBytes(widget.bytes)} bằng Photo Cleaner!',
    );

    return Container(
      decoration: BoxDecoration(
        color: pal.sheet,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: pal.line),
      ),
      padding: EdgeInsets.fromLTRB(20, 10, 20, 16 + MediaQuery.of(context).padding.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 5,
              decoration: BoxDecoration(color: pal.line, borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(height: 16),
            // This card is also what gets shared as an image.
            RepaintBoundary(
              key: _cardKey,
              child: Container(
                color: pal.sheet,
                child: HeroCard(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                  child: Column(
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.4, end: 1),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.elasticOut,
                        builder: (_, v, child) => Transform.scale(scale: v, child: child),
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration:
                              const BoxDecoration(color: Color(0x33FFFFFF), shape: BoxShape.circle),
                          child: const Icon(Icons.check_rounded, size: 38, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(context.tr('Cleaned up!', 'Đã dọn xong!'),
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xE6FFFFFF))),
                      const SizedBox(height: 2),
                      CountUp(
                        value: widget.bytes,
                        format: (v) => fmtBytes(v),
                        style: const TextStyle(
                            fontSize: 42, height: 1.15, fontWeight: FontWeight.w800, letterSpacing: -1),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.tr('${widget.count} items moved to Recently Deleted',
                            '${widget.count} mục đã chuyển vào Đã xoá gần đây'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, color: Color(0xE6FFFFFF)),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.local_fire_department_rounded,
                              size: 20, color: Color(0xFFFFD27A)),
                          const SizedBox(width: 4),
                          Text(
                            context.tr('$streak-day streak', 'Chuỗi $streak ngày'),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 14),
                          const Text('Photo Cleaner',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xB3FFFFFF))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            FadeSlideIn(
              index: 1,
              child: AppCard(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(context.tr('Monthly goal', 'Mục tiêu tháng'),
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700, color: pal.text)),
                        Text('${fmtBytes(act.monthBytes)} / ${fmtBytes(goalBytes)}',
                            style: TextStyle(fontSize: 13, color: pal.sec)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: act.goalProgress),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, __) => LinearProgressIndicator(
                          value: v,
                          minHeight: 8,
                          color: act.goalProgress >= 1 ? pal.ok : AppColors.accent,
                          backgroundColor: pal.line,
                        ),
                      ),
                    ),
                    if (act.goalProgress >= 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(context.tr('Goal reached this month!', 'Đã đạt mục tiêu tháng này!'),
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700, color: pal.ok)),
                      ),
                  ],
                ),
              ),
            ),
            if (widget.newBadges.isNotEmpty) ...[
              const SizedBox(height: 12),
              FadeSlideIn(
                index: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(context.tr('NEW BADGES', 'HUY HIỆU MỚI'),
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: pal.sec)),
                ),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < widget.newBadges.length; i++)
                FadeSlideIn(
                  index: 3 + i,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          BadgeIcon(def: widget.newBadges[i], unlocked: true, size: 44),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(context.tr(widget.newBadges[i].en, widget.newBadges[i].vi),
                                    style: TextStyle(
                                        fontSize: 15, fontWeight: FontWeight.w700, color: pal.text)),
                                Text(
                                    context.tr(widget.newBadges[i].descEn, widget.newBadges[i].descVi),
                                    style: TextStyle(fontSize: 13, color: pal.sec)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: PillButton(
                    label: context.tr('Share', 'Chia sẻ'),
                    icon: Icons.ios_share_rounded,
                    filled: false,
                    onTap: _sharing ? null : () => _share(shareText),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PillButton(
                    label: context.tr('Done', 'Xong'),
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Round badge icon: coloured when unlocked, greyed out with a lock otherwise.
class BadgeIcon extends StatelessWidget {
  final BadgeDef def;
  final bool unlocked;
  final double size;
  const BadgeIcon({super.key, required this.def, required this.unlocked, this.size = 52});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: unlocked
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [def.color.withOpacity(0.95), def.color.withOpacity(0.65)],
              )
            : null,
        color: unlocked ? null : pal.chip,
        boxShadow: unlocked
            ? [BoxShadow(color: def.color.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 6))]
            : null,
      ),
      child: Icon(
        unlocked ? def.icon : Icons.lock_outline_rounded,
        size: size * 0.5,
        color: unlocked ? Colors.white : pal.sec,
      ),
    );
  }
}
