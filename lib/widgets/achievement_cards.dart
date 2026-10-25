import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/achievements.dart';
import '../core/format.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../providers/activity_provider.dart';
import '../providers/vault_provider.dart';
import 'celebration.dart';
import 'common.dart';
import 'motion.dart';

/// Streak (with the last 7 days) and monthly goal.
class StreakGoalCard extends StatelessWidget {
  const StreakGoalCard({super.key});

  static const _goals = [250, 500, 1024, 2048];

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final act = context.watch<ActivityProvider>();
    final now = DateTime.now();
    final streak = act.streak;
    final goalBytes = act.goalMb * 1024 * 1024;
    final goalIdx = _goals.indexOf(act.goalMb);
    final wdEn = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final wdVi = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

    return Column(
      children: [
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: streak > 0 ? const Color(0x33FF6B3D) : pal.chip,
                    ),
                    child: Icon(Icons.local_fire_department_rounded,
                        size: 28, color: streak > 0 ? const Color(0xFFFF6B3D) : pal.sec),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            CountUp(
                              value: streak,
                              duration: const Duration(milliseconds: 600),
                              format: (v) => '${v.round()}',
                              style: TextStyle(
                                  fontSize: 30, fontWeight: FontWeight.w800, color: pal.text),
                            ),
                            const SizedBox(width: 6),
                            Text(context.tr('day streak', 'ngày liên tiếp'),
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600, color: pal.sec)),
                          ],
                        ),
                        Text(
                            context.tr('Best: ${act.longest} days', 'Kỷ lục: ${act.longest} ngày'),
                            style: TextStyle(fontSize: 13, color: pal.sec)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  for (var i = 6; i >= 0; i--)
                    Expanded(
                      child: Builder(builder: (context) {
                        final d = DateTime(now.year, now.month, now.day - i);
                        final on = act.activeDays.contains(dayKey(d));
                        final isToday = i == 0;
                        return Column(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: on ? AppColors.accent : Colors.transparent,
                                border: Border.all(
                                    color: on
                                        ? Colors.transparent
                                        : (isToday ? AppColors.accent : pal.line),
                                    width: isToday && !on ? 2 : 1.5),
                              ),
                              child: on
                                  ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(height: 4),
                            Text(
                                context.tr(wdEn[d.weekday - 1], wdVi[d.weekday - 1]),
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                                    color: isToday ? pal.text : pal.sec)),
                          ],
                        );
                      }),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: act.goalProgress),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeOutCubic,
                          builder: (_, v, __) => CircularProgressIndicator(
                            value: v,
                            strokeWidth: 7,
                            color: act.goalProgress >= 1 ? pal.ok : AppColors.accent,
                            backgroundColor: pal.line,
                          ),
                        ),
                        Center(
                          child: Text('${(act.goalProgress * 100).round()}%',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w800, color: pal.text)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.tr('Monthly goal', 'Mục tiêu tháng'),
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700, color: pal.text)),
                        const SizedBox(height: 2),
                        Text('${fmtBytes(act.monthBytes)} / ${fmtBytes(goalBytes)}',
                            style: TextStyle(fontSize: 14, color: pal.sec)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SegControl(
                labels: const ['250 MB', '500 MB', '1 GB', '2 GB'],
                index: goalIdx < 0 ? 1 : goalIdx,
                onChanged: (i) => act.setGoalMb(_goals[i]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Grid of all badges; tap one for its description.
class BadgesCard extends StatelessWidget {
  const BadgesCard({super.key});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final act = context.watch<ActivityProvider>();
    final vaultItems = context.watch<VaultProvider>().items.length;
    final unlocked = act.unlockedIds(vaultItems: vaultItems);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.tr('Badges', 'Huy hiệu'),
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: pal.text)),
              Text('${unlocked.length} / ${kBadges.length}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: pal.sec)),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.92,
            children: [
              for (final b in kBadges)
                Pressable(
                  onTap: () => _show(context, b, unlocked.contains(b.id)),
                  scale: 0.94,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      BadgeIcon(def: b, unlocked: unlocked.contains(b.id)),
                      const SizedBox(height: 8),
                      Text(
                        context.tr(b.en, b.vi),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                          color: unlocked.contains(b.id) ? pal.text : pal.sec,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _show(BuildContext context, BadgeDef b, bool on) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            BadgeIcon(def: b, unlocked: on, size: 40),
            const SizedBox(width: 12),
            Expanded(child: Text(ctx.tr(b.en, b.vi))),
          ],
        ),
        content: Text(
            '${ctx.tr(b.descEn, b.descVi)}\n\n${on ? ctx.tr('Unlocked', 'Đã mở khoá') : ctx.tr('Locked', 'Chưa mở khoá')}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.tr('OK', 'Đóng'))),
        ],
      ),
    );
  }
}
